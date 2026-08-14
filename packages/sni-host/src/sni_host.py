#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WSLg tray bridge - WSL/Linux side
=================================

Registers as a StatusNotifierHost on the session bus and forwards every
StatusNotifierItem (tray icon) over a localhost TCP socket to main.py
running on Windows, which paints real icons in the Windows notification area
and routes clicks/menu events back.

WSLg ships no StatusNotifierWatcher (microsoft/wslg#158), so when none exists
on the bus this bridge also provides one itself (exported via dbus-next);
on a desktop session with a real watcher it acts as a plain host.

    sni-host [--port 17632]

If python.exe / cmd.exe is found on PATH (WSL interop), the Windows
companion is launched automatically.  Otherwise start it manually on Windows:

    pip install pystray Pillow
    python main.py --port 17632
"""

import argparse
import asyncio
import base64
import json
import logging
import os
import shutil
import signal as os_signal
import subprocess
import sys
import time

from dbus_next import (  # pyright: ignore[reportPrivateImportUsage]
    Message,  # pyright: ignore[reportPrivateImportUsage]
    MessageType,  # pyright: ignore[reportPrivateImportUsage]
    Variant,  # pyright: ignore[reportPrivateImportUsage]
)
from dbus_next.aio import MessageBus  # pyright: ignore[reportPrivateImportUsage]
from dbus_next.constants import NameFlag, RequestNameReply
from sni_spec import (
    DBUS_IFACE,
    ITEM_PATH,
    MENU_IFACES,
    PROPS_IFACE,
    PROTOCOL_VERSION,
    SNI_IFACE,
    WATCHER_IFACE,
    WATCHER_NAMES,
    WATCHER_PATH,
    Watcher,
    find_menu_node,
    icon_png,
    parse_layout_node,
    resolve_bus_address,
)

log = logging.getLogger("sni-host")

HOST_NAME_PREFIX = "org.kde.StatusNotifierHost-wslg-tray-bridge"
POLL_GRACE = 5  # failed polls before a never-responding item is dropped


class Item:
    """One StatusNotifierItem living on `service` (its bus name)."""

    def __init__(self, service: str, path: str = ITEM_PATH):
        self.service = service
        self.path = path
        self.props: dict = {}
        self.title = self.tooltip = self.status = ""
        self.icon_png: bytes | None = None
        self.menu_path: str | None = None
        self.menu_iface: str | None = None
        self.menu_ok = False
        self.menu_cache: list = []
        self.poller: asyncio.Task | None = None


class Bridge:
    def __init__(self, port: int, bus: MessageBus):
        self.port = port
        self.bus = bus
        self.bus_address: str | None = None
        self.host_name = f"{HOST_NAME_PREFIX}-{os.getpid()}"
        self.watcher: tuple[str, str] | None = None  # (name, path) of the live watcher
        self.watcher_own: Watcher | None = None  # our own Watcher, when we are it
        self.items: dict[str, Item] = {}
        self.clients: set[asyncio.StreamWriter] = set()
        self.server: asyncio.Server | None = None
        # hook the raw message stream once; it stays harmless in external
        # watcher mode (on_bus_message only acts on our own Watcher)
        self.bus.add_message_handler(self.on_bus_message)

    # ---------------------------------------------------------------- helpers
    async def dbus_call(self, destination, path, interface, member, signature, body):
        reply = await self.bus.call(
            Message(
                destination=destination,
                path=path,
                interface=interface,
                member=member,
                signature=signature,
                body=body,
            )
        )
        if reply is None:
            raise RuntimeError("no reply from %s.%s" % (destination, member))
        if reply.message_type == MessageType.ERROR:
            text = str(reply.body[0]) if reply.body else ""
            raise RuntimeError(
                f"{reply.error_name}: {text}"
                if reply.error_name
                else text or "dbus error"
            )
        return reply.body

    async def call(self, item, member, signature, body):
        """Call an SNI method on an item."""
        await self.dbus_call(
            item.service, item.path, SNI_IFACE, member, signature, body
        )

    def _spawn(self, coro) -> None:
        asyncio.create_task(self._safe(coro))

    async def _safe(self, coro) -> None:
        try:
            await coro
        except Exception:
            log.exception("background task failed")

    # ------------------------------------------------------------------ dbus
    def on_bus_message(self, msg: Message):
        """Pieces dbus-next can't express triggerlessly: appindicator-style
        registrations (an object path instead of a service name, which needs
        the caller's unique bus name) and liveness cleanup of registered
        items via NameOwnerChanged."""
        if (
            msg.message_type == MessageType.SIGNAL
            and msg.sender == "org.freedesktop.DBus"
            and msg.interface == DBUS_IFACE
            and msg.member == "NameOwnerChanged"
        ):
            name, _old, new = msg.body
            if self.watcher_own and not new:
                if name in self.watcher_own.items:
                    self.watcher_own.unregister(name)
                elif name in self.watcher_own.hosts:
                    self.watcher_own.unregister_host(name)
        elif (
            msg.message_type == MessageType.METHOD_CALL
            and msg.path == WATCHER_PATH
            and msg.interface == WATCHER_IFACE
            and msg.member == "RegisterStatusNotifierItem"
            and msg.signature == "s"
        ):
            service = msg.body[0]
            if (
                isinstance(service, str)
                and service.startswith("/")
                and self.watcher_own
            ):
                self.watcher_own.register(msg.sender, service)
                return Message.new_method_return(msg, "", [])
        return None

    async def _list_names(self) -> list[str] | None:
        try:
            reply = await self.dbus_call(
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                DBUS_IFACE,
                "ListNames",
                "",
                [],
            )
            return [str(n) for n in reply[0]]
        except Exception:
            return None

    async def find_watcher(self) -> str | None:
        """Name of any live StatusNotifierWatcher, or None."""
        for name in await self._list_names() or []:
            if name.endswith(".StatusNotifierWatcher"):
                return name
        return None

    async def claim_watcher(self) -> bool:
        """Become the watcher: claim every free watcher name and serve the
        interface (one export covers all claimed names; Qtile does the same
        with one service instance per name)."""
        attempt = Watcher(self)
        owned = []
        for name in WATCHER_NAMES:
            reply = await self.bus.request_name(name, NameFlag.DO_NOT_QUEUE)
            if reply in (
                RequestNameReply.PRIMARY_OWNER,
                RequestNameReply.ALREADY_OWNER,
            ):
                owned.append(name)
            elif name == WATCHER_NAMES[0]:
                return False  # the preferred watcher name is taken by someone else
        if not owned:
            return False
        self.bus.export(WATCHER_PATH, attempt)
        self.watcher_own = attempt
        self.watcher = (owned[0], WATCHER_PATH)
        log.info("no tray watcher found; providing our own at %s", owned)
        await self.dbus_call(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            DBUS_IFACE,
            "AddMatch",
            "s",
            [
                "type='signal',sender='org.freedesktop.DBus',"
                "member='NameOwnerChanged',path='/org/freedesktop/DBus'"
            ],
        )
        return True

    async def register_host(self) -> None:
        try:
            await self.dbus_call(
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                DBUS_IFACE,
                "RequestName",
                "su",
                [self.host_name, NameFlag.DO_NOT_QUEUE.value],
            )
        except Exception:
            log.debug("could not own %s, will use raw unique name", self.host_name)
        if self.watcher is None:
            return
        name, path = self.watcher
        await self.dbus_call(
            name,
            path,
            WATCHER_IFACE,
            "RegisterStatusNotifierHost",
            "s",
            [self.host_name],
        )
        log.info("registered StatusNotifierHost %s", self.host_name)

    async def setup_watcher_signals(self) -> None:
        """Follow an external watcher: subscribe to its signals, replay its items."""
        if self.watcher is None:
            return
        name, path = self.watcher
        obj = self.bus.get_proxy_object(
            name, path, await self.bus.introspect(name, path)
        )
        iface = obj.get_interface(WATCHER_IFACE)
        for attr, handler in (
            (
                "on_status_notifier_item_registered",
                lambda s: self._spawn(self.on_item_registered(str(s))),
            ),
            (
                "on_status_notifier_item_unregistered",
                lambda s: self._spawn(self.on_item_unregistered(str(s))),
            ),
            (
                "on_status_notifier_host_registered",
                lambda: log.info("another tray host registered"),
            ),
        ):
            if getattr(iface, attr, None):
                getattr(iface, attr)(handler)
        reply = await self.dbus_call(
            name, path, PROPS_IFACE, "GetAll", "s", [WATCHER_IFACE]
        )
        existing = reply[0].get("RegisteredStatusNotifierItems")
        if existing is not None:
            for service in existing.value:
                self._spawn(self.on_item_registered(service))

    async def bootstrap(self) -> bool:
        """Get the tray pipeline going: find a watcher or become one."""
        if self.watcher:
            return True
        name = await self.find_watcher()
        if name:
            self.watcher = (name, WATCHER_PATH)
            log.info("found StatusNotifierWatcher at %s", name)
        elif not await self.claim_watcher():
            return False
        await self.register_host()
        if not self.watcher_own:
            await self.setup_watcher_signals()
        return True

    async def diagnose(self) -> None:
        hints = []
        if os.path.exists("/mnt/wslg"):
            hints.append(
                "this is WSLg, which has no StatusNotifierWatcher; "
                "the bridge can act as one (keep waiting)"
            )
        sni = [n for n in await self._list_names() or [] if "StatusNotifier" in n]
        if sni:
            hints.append(f"StatusNotifier services present: {sni}")
        log.warning(
            "waiting for a tray watcher on %s%s",
            self.bus_address,
            f" ({'; '.join(hints)})" if hints else "",
        )

    # ----------------------------------------------------------- item handling
    async def on_item_registered(self, service: str, path: str = ITEM_PATH) -> None:
        if service in self.items:
            return
        item = Item(service, path)
        self.items[service] = item
        if not await self.fill_props(item):
            self.items.pop(service, None)
            return
        self.broadcast(self.add_message(item))
        await self.refresh_menu(item, force=True)
        await self.monitor(item)
        log.info("tray item: %s (%s)", item.title or service, service)

    async def on_item_unregistered(self, service: str) -> None:
        item = self.items.pop(service, None)
        if not item:
            return
        if item.poller:
            item.poller.cancel()
        self.broadcast({"t": "remove", "key": service})
        log.info("tray item gone: %s", service)

    async def fill_props(self, item: Item, push: bool = False) -> bool:
        try:
            reply = await self.dbus_call(
                item.service, item.path, PROPS_IFACE, "GetAll", "s", [SNI_IFACE]
            )
            props = {
                k: v.value if isinstance(v, Variant) else v for k, v in reply[0].items()
            }
        except Exception as exc:
            log.debug("GetAll(%s) failed: %s", item.service, exc)
            return False
        first = not item.props
        item.props = props

        icon = icon_png(props)
        tt = props.get("ToolTip")
        tooltip = (
            str(tt[2] or "")
            if isinstance(tt, (tuple, list)) and len(tt) >= 3  # (s, a(iiay), s, s)
            else ""
        )
        title, status = str(props.get("Title") or ""), str(props.get("Status") or "")

        changes: dict = {}
        if icon != item.icon_png:
            changes["icon"] = base64.b64encode(icon).decode("ascii") if icon else None
        if title != item.title:
            changes["title"] = title
        if tooltip != item.tooltip:
            changes["tooltip"] = tooltip
        if status != item.status:
            changes["status"] = status
        item.icon_png, item.title, item.tooltip, item.status = (
            icon,
            title,
            tooltip,
            status,
        )

        menu = props.get("Menu") or None
        if menu and menu != item.menu_path:
            item.menu_path, item.menu_ok = menu, False
            if not first:
                await self.refresh_menu(item, force=True)
        elif not menu and item.menu_path:
            item.menu_path, item.menu_ok = None, False

        if push and changes:
            self.broadcast({"t": "update", "key": item.service, **changes})
        return True

    async def refresh_menu(
        self, item: Item, force: bool = False, about_to_show: bool = False
    ) -> None:
        if not item.menu_path or (not force and item.menu_ok is False):
            return
        for iface in MENU_IFACES:
            try:
                if about_to_show:
                    reply = await self.dbus_call(
                        item.service, item.menu_path, iface, "AboutToShow", "i", [0]
                    )
                    if not (reply and len(reply) and reply[0]):
                        return
                body = await self.dbus_call(
                    item.service,
                    item.menu_path,
                    iface,
                    "GetLayout",
                    "iias",
                    [0, -1, []],
                )
                node = body[1] if body and len(body) > 1 else None
                children = (
                    node[2] if isinstance(node, (tuple, list)) and len(node) > 2 else []
                )
                tree = [
                    parse_layout_node(n.value if isinstance(n, Variant) else n)
                    for n in children
                ]
            except Exception:
                continue
            item.menu_cache, item.menu_iface, item.menu_ok = tree, iface, True
            self.broadcast({"t": "menu", "key": item.service, "menu": tree})
            return
        item.menu_ok = False
        if item.menu_cache:
            item.menu_cache = []
            self.broadcast({"t": "menu", "key": item.service, "menu": []})
        log.debug("no working dbusmenu on %s (%s)", item.service, item.menu_path)

    async def monitor(self, item: Item) -> None:
        """Subscribe to item property/signal changes (poll as a fallback),
        then to menu layout updates.  dbus-next proxy listeners require an
        exact argument count, so each lambda mirrors its signal's arity."""
        try:
            obj = self.bus.get_proxy_object(
                item.service,
                item.path,
                await self.bus.introspect(item.service, item.path),
            )
        except Exception as exc:
            log.warning(
                "introspection of %s failed (%s); polling instead", item.service, exc
            )
            item.poller = asyncio.create_task(self.poll(item))
            return
        push = lambda: self._spawn(self.fill_props(item, push=True))
        try:
            listener = getattr(
                obj.get_interface(PROPS_IFACE), "on_properties_changed", None
            )
            if listener:
                listener(lambda _iface, _changed, _invalidated: push())
        except Exception:
            pass
        try:
            sni = obj.get_interface(SNI_IFACE)
            for sig in (
                "new_icon",
                "new_title",
                "new_tool_tip",
                "new_status",
                "new_attention_icon",
                "new_overlay_icon",
                "new_menu",
            ):
                if listener := getattr(sni, f"on_{sig}", None):
                    listener(push)  # zero-argument signals
        except Exception:
            pass
        if item.menu_path:
            try:
                mobj = self.bus.get_proxy_object(
                    item.service,
                    item.menu_path,
                    await self.bus.introspect(item.service, item.menu_path),
                )
                for iface_name in MENU_IFACES:
                    if listener := getattr(
                        mobj.get_interface(iface_name), "on_layout_updated", None
                    ):
                        listener(
                            lambda _rev, _parent, _pos: self._spawn(
                                self.refresh_menu(item, force=True)
                            )
                        )
                        break
            except Exception:
                pass

    async def poll(self, item: Item) -> None:
        """Fallback polling for items we could not introspect.

        An item that never delivers data is dead weight (Qtile drops items
        that fail to start too); give it POLL_GRACE rounds, then remove it.
        Items that worked once keep polling forever across hiccups.
        """
        misses = 0
        while item.service in self.items:
            await asyncio.sleep(3)
            if await self.fill_props(item, push=True) or item.props:
                continue
            misses += 1
            if misses >= POLL_GRACE:
                log.info("tray item %s never answered; dropping it", item.service)
                await self.on_item_unregistered(item.service)
                return

    # ------------------------------------------------------- windows messages
    async def handle_client_message(self, m: dict) -> None:
        t = m.get("t")
        log.debug("client msg: %s", m)
        if t == "hello_ack":
            if m.get("protocol") != PROTOCOL_VERSION:
                log.warning(
                    "protocol mismatch: tray_host=%s, we=%s",
                    m.get("protocol"),
                    PROTOCOL_VERSION,
                )
            return
        item = self.items.get(str(m.get("key") or ""))
        if item is None:
            return
        try:
            if t == "activate":
                await self.call(item, "Activate", "ii", [0, 0])
            elif t == "secondary":
                await self.call(item, "SecondaryActivate", "ii", [0, 0])
            elif t == "context":
                await self.refresh_menu(item, force=True, about_to_show=True)
            elif t == "menu_click" and item.menu_path:
                await self.click_menu_item(item, m)
            elif t == "scroll":
                await self.call(
                    item, "Scroll", "ii", [int(m.get("dx", 0)), int(m.get("dy", 0))]
                )
        except Exception as exc:
            log.debug("forwarding %s to %s failed: %s", t, item.service, exc)

    async def click_menu_item(self, item: Item, m: dict) -> None:
        """Forward a menu click, resolving the target against a fresh layout.

        Some apps (e.g. clash-verge) rebuild their dbusmenu on every change
        and renumber all item ids, so cached ids go stale almost immediately.
        Match by label against the latest layout; fall back to the raw id.
        """
        label = str(m.get("label") or "")
        node = find_menu_node(item.menu_cache, label) if label else None
        if node is None:
            node = {"id": int(m.get("item", 0))}
        try:
            await self.dbus_call(
                item.service,
                item.menu_path,
                item.menu_iface or MENU_IFACES[0],
                "Event",
                "isvu",
                [
                    int(node["id"]),
                    "clicked",
                    Variant("s", ""),
                    int(time.time()) & 0xFFFFFFFF,
                ],
            )
        except Exception as exc:
            log.debug("menu_click(%s) failed: %s", label or node["id"], exc)
            return
        await self.refresh_menu(item, force=True)

    # ------------------------------------------------------------------ tcp
    def send(self, writer: asyncio.StreamWriter, msg: dict) -> None:
        try:
            writer.write((json.dumps(msg, ensure_ascii=False) + "\n").encode("utf-8"))
        except Exception:
            self._drop(writer)

    def broadcast(self, msg: dict) -> None:
        for writer in list(self.clients):
            self.send(writer, msg)

    def _drop(self, writer: asyncio.StreamWriter) -> None:
        self.clients.discard(writer)
        try:
            writer.close()
        except Exception:
            pass

    async def on_client(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None:
        peer = writer.get_extra_info("peername")
        self.clients.add(writer)
        log.info("tray_host connected: %s", peer)
        try:
            self.send(
                writer,
                {
                    "t": "hello",
                    "protocol": PROTOCOL_VERSION,
                    "distro": os.environ.get("WSL_DISTRO_NAME") or "",
                },
            )
            for key, item in self.items.items():
                self.send(writer, self.add_message(item))
                if item.menu_ok:
                    self.send(
                        writer, {"t": "menu", "key": key, "menu": item.menu_cache}
                    )
            while True:
                line = await reader.readline()
                if not line:
                    break
                try:
                    await self.handle_client_message(json.loads(line.decode("utf-8")))
                except Exception as exc:
                    log.debug("bad client message: %s", exc)
        except Exception as exc:
            log.debug("client connection error: %s", exc)
        finally:
            self.clients.discard(writer)
            try:
                writer.close()
            except Exception:
                pass
            log.info("tray_host disconnected: %s", peer)

    def add_message(self, item: Item) -> dict:
        return {
            "t": "add",
            "key": item.service,
            "id": item.props.get("Id") or item.service,
            "title": item.title,
            "tooltip": item.tooltip,
            "status": item.status,
            "icon": (
                base64.b64encode(item.icon_png).decode("ascii")
                if item.icon_png
                else None
            ),
        }

    # ---------------------------------------------------------------- misc
    def spawn_windows_side(self) -> None:
        arg = shutil.which("python.exe")
        if not arg:
            log.warning("python.exe not found; start main.py manually on Windows")
            return
        script = os.path.abspath(__file__)
        try:
            out = subprocess.run(
                ["wslpath", "-w", script], capture_output=True, text=True, check=True
            )
            script = out.stdout.strip()
        except Exception:
            pass
        log.info("launching Windows side: %s %s --port %d", arg, script, self.port)
        try:
            subprocess.Popen(
                [arg, script, "--port", str(self.port)],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception as exc:
            log.warning("failed to launch Windows side: %s", exc)

    async def shutdown(self) -> None:
        self.broadcast({"t": "bye", "reason": "server shutting down"})
        for writer in list(self.clients):
            self._drop(writer)
        if self.server:
            self.server.close()
            await self.server.wait_closed()
        self.bus.disconnect()


async def main(args: argparse.Namespace) -> int:
    logging.basicConfig(
        level=getattr(logging, args.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)-7s %(message)s",
    )
    bus_address = args.dbus_address or resolve_bus_address()
    if not bus_address:
        log.error(
            "no D-Bus session address found; set DBUS_SESSION_BUS_ADDRESS"
            " or run inside WSLg / a desktop session"
        )
        return 1

    bridge = Bridge(args.port, await MessageBus(bus_address=bus_address).connect())
    bridge.bus_address = bus_address
    bridge.server = await asyncio.start_server(bridge.on_client, "127.0.0.1", args.port)
    log.info("listening on 127.0.0.1:%d for tray_host (%s)", args.port, bus_address)

    warned = False

    async def watch_watcher():
        nonlocal warned
        while True:
            try:
                if await bridge.bootstrap():
                    return
            except Exception as exc:
                log.warning("watcher setup failed: %s", exc)
            if not warned:
                warned = True
                await bridge.diagnose()
            await asyncio.sleep(3)

    asyncio.create_task(watch_watcher())
    if args.spawn:
        bridge.spawn_windows_side()

    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (os_signal.SIGINT, os_signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, stop.set)
        except NotImplementedError:
            pass
    await stop.wait()

    log.info("shutting down")
    await bridge.shutdown()
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser(
        description="WSLg SNI -> Windows tray bridge (WSL side)"
    )
    ap.add_argument("--port", type=int, default=17632)
    ap.add_argument(
        "--spawn",
        action="store_true",
        default=True,
        help="auto-launch main.py on Windows (default)",
    )
    ap.add_argument(
        "--no-spawn",
        dest="spawn",
        action="store_false",
        help="do not auto-launch the Windows side",
    )
    ap.add_argument(
        "--dbus-address", default=None, help="override DBUS_SESSION_BUS_ADDRESS"
    )
    ap.add_argument(
        "--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"]
    )
    ap.add_argument(
        "--version", action="version", version=f"protocol {PROTOCOL_VERSION}"
    )
    sys.exit(asyncio.run(main(ap.parse_args())))

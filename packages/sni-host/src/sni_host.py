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
on the bus this bridge also provides one itself (exported via dbus-fast);
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
from dataclasses import dataclass, field

from dbus_fast import (
    Message,
    MessageType,
    Variant,
)
from dbus_fast.aio import MessageBus
from dbus_fast.constants import NameFlag, RequestNameReply
from sni_spec import (
    DBUS_IFACE,
    ITEM_PATH,
    MENU_IFACES,
    NO_DBUSMENU,
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
    tooltip_of,
    unwrap_variants,
)

log = logging.getLogger("sni-host")

HOST_NAME_PREFIX = "org.kde.StatusNotifierHost-wslg-tray-bridge"
POLL_GRACE = 5  # failed polls before a never-responding item is dropped
POLL_INTERVAL = 3  # seconds between fallback polls
DBUS_CALL_TIMEOUT = 5.0  # remote apps must answer within this or be dropped
DEBOUNCE = 0.2  # seconds of signal chatter coalesced into one fetch


@dataclass
class Item:
    """One StatusNotifierItem living on `service` (its bus name)."""

    service: str
    path: str = ITEM_PATH
    props: dict = field(default_factory=dict)
    title: str = ""
    tooltip: str = ""
    status: str = ""
    icon_png: bytes | None = None
    menu_path: str | None = None
    menu_iface: str | None = None
    menu_ok: bool = False
    menu_cache: list = field(default_factory=list)
    poller: asyncio.Task | None = None
    handlers: list = field(default_factory=list)  # (iface, snake, fn) for off_*


class Bridge:
    """Owns the SNI pipeline: finds or emulates the StatusNotifierWatcher,
    tracks items, and serves the TCP socket to the Windows tray-host."""

    def __init__(self, port: int, bus: MessageBus):
        self.port = port
        self.bus = bus
        self.bus_address: str | None = None
        self.host_name = f"{HOST_NAME_PREFIX}-{os.getpid()}"
        self.watcher: str | None = None  # live StatusNotifierWatcher bus name
        self.watcher_own: Watcher | None = None  # our own Watcher, when we are it
        self.items: dict[str, Item] = {}
        self.hosts: set[str] = set()  # registered StatusNotifierHost bus names
        self.clients: set[asyncio.StreamWriter] = set()
        self.server: asyncio.Server | None = None
        self._dirty: dict[str, Item] = {}  # items awaiting a deferred props fetch
        self._flush_task: asyncio.Task | None = None
        self._watcher_loop: asyncio.Task | None = None
        self._watching_names = False
        self._exported_watcher = False
        self._shutdown = False
        self._background_tasks: set[asyncio.Task] = set()
        # hook the raw message stream once: it handles NameOwnerChanged
        # liveness (items, hosts, watcher loss) and appindicator-style
        # registrations; both no-ops while no watcher is established
        self.bus.add_message_handler(self.on_bus_message)

    # ---------------------------------------------------------------- helpers
    async def dbus_call(
        self,
        destination: str,
        path: str,
        interface: str,
        member: str,
        signature: str,
        body: list,
    ) -> list:
        try:
            reply = await asyncio.wait_for(
                self.bus.call(
                    Message(
                        destination=destination,
                        path=path,
                        interface=interface,
                        member=member,
                        signature=signature,
                        body=body,
                    )
                ),
                timeout=DBUS_CALL_TIMEOUT,
            )
        except asyncio.TimeoutError:
            raise RuntimeError(f"{destination}.{member} timed out")
        if reply is None:
            raise RuntimeError(f"no reply from {destination}.{member}")
        if reply.message_type == MessageType.ERROR:
            text = str(reply.body[0]) if reply.body else ""
            raise RuntimeError(
                f"{reply.error_name}: {text}"
                if reply.error_name
                else text or "dbus error"
            )
        return reply.body

    async def bus_call(self, member: str, signature: str, body: list) -> list:
        """Call a method on the org.freedesktop.DBus service itself."""
        return await self.dbus_call(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            DBUS_IFACE,
            member,
            signature,
            body,
        )

    async def introspect(self, destination: str, path: str):
        """Introspect with the same timeout discipline as dbus_call."""
        return await asyncio.wait_for(
            self.bus.introspect(destination, path), timeout=DBUS_CALL_TIMEOUT
        )

    async def call(self, item: Item, member: str, signature: str, body: list) -> None:
        """Call an SNI method on an item."""
        await self.dbus_call(
            item.service, item.path, SNI_IFACE, member, signature, body
        )

    def _spawn(self, coro) -> None:
        task = asyncio.create_task(self._safe(coro))
        self._background_tasks.add(task)
        task.add_done_callback(self._background_tasks.discard)

    async def _safe(self, coro) -> None:
        try:
            await coro
        except Exception:
            log.exception("background task failed")

    def push_item(self, item: Item) -> None:
        """Mark an item dirty and coalesce signal bursts into one fetch.

        Chatty apps fire PropertiesChanged/new_* repeatedly; each signal
        would otherwise trigger a full GetAll + PNG encode + TCP broadcast.
        """
        self._dirty[item.service] = item
        if self._flush_task is None or self._flush_task.done():
            self._flush_task = asyncio.create_task(self._flush_loop())

    async def _flush_loop(self) -> None:
        while True:
            await asyncio.sleep(DEBOUNCE)
            batch, self._dirty = list(self._dirty.values()), {}
            if not batch:
                break
            for item in batch:
                if item.service in self.items:
                    await self.fill_props(item, push=True)
        self._flush_task = None

    async def menu_call(
        self, item: Item, member: str, signature: str, body: list
    ) -> tuple[list | None, str | None]:
        """Call a dbusmenu method on an item, trying each interface spelling
        until one answers.  Returns (reply, iface) or (None, None)."""
        for iface in MENU_IFACES:
            try:
                reply = await self.dbus_call(
                    item.service, item.menu_path, iface, member, signature, body
                )
            except Exception:
                continue
            return reply, iface
        return None, None

    def _menu_attr(self, obj, attr_snake: str):
        """(iface, listener) of the first dbusmenu interface exposing it."""
        for iface_name in MENU_IFACES:
            iface = obj.get_interface(iface_name)
            if listener := getattr(iface, f"on_{attr_snake}", None):
                return iface, listener
        return None, None

    def _set_menu_cache(self, item: Item, tree: list, iface: str) -> None:
        """Cache a fresh menu tree and broadcast it (no-op when unchanged)."""
        if tree != item.menu_cache:
            item.menu_cache, item.menu_iface, item.menu_ok = tree, iface, True
            self.broadcast({"t": "menu", "key": item.service, "menu": tree})

    # ------------------------------------------------------------------ dbus
    def add_host(self, service: str) -> None:
        """Register a StatusNotifierHost and emit the D-Bus signal."""
        service = str(service)
        if service in self.hosts:
            return
        self.hosts.add(service)
        if self.watcher_own:
            self.watcher_own.StatusNotifierHostRegistered()  # pyright: ignore[reportCallIssue] — @signal wrapper
            for name in self.watcher_own.items:
                self.watcher_own.StatusNotifierItemRegistered(name)

    def remove_host(self, service: str) -> None:
        """Unregister a StatusNotifierHost and emit the D-Bus signal."""
        if service in self.hosts:
            self.hosts.discard(service)
            if self.watcher_own:
                self.watcher_own.StatusNotifierHostUnregistered()  # pyright: ignore[reportCallIssue] — @signal wrapper

    def on_bus_message(self, msg: Message) -> Message | None:
        """Raw-stream hooks dbus-fast cannot express through the exported
        interface: NameOwnerChanged liveness and appindicator-style
        registrations (an object path instead of a bus name, which needs
        the caller's unique name from msg.sender).

        The handler is installed once at construction; it only acts when
        it owns the watcher or follows an external one.
        """
        if (
            msg.message_type == MessageType.SIGNAL
            and msg.interface == DBUS_IFACE
            and msg.member == "NameOwnerChanged"
        ):
            self.on_name_owner_changed(str(msg.body[0]), str(msg.body[2]))
            return None
        if msg.message_type == MessageType.METHOD_CALL:
            return self.try_appindicator_register(msg)
        return None

    def try_appindicator_register(self, msg: Message) -> Message | None:
        """Appindicator clients pass an object path as `service`, so the
        caller's unique name stands in as the bus name."""
        if (
            msg.path == WATCHER_PATH
            and msg.interface == WATCHER_IFACE
            and msg.member == "RegisterStatusNotifierItem"
            and msg.signature == "s"
            and isinstance(msg.body[0], str)
            and msg.body[0].startswith("/")
            and self.watcher_own is not None
        ):
            self.watcher_own.register(msg.sender, msg.body[0])
            return Message.new_method_return(msg, "", [])
        return None

    def on_name_owner_changed(self, name: str, new: str) -> None:
        """Liveness pipeline behind a single NameOwnerChanged subscription
        (xapp-sn-watcher uses one subscriber for the same bookkeeping):

        - a vanished item is unregistered (own-watcher mode)
        - a vanished host is dropped
        - a vanished external watcher is re-acquired from scratch
        - a stolen watcher name (REPLACE takeover) is re-acquired
        """
        if new:
            # Non-empty owners are routine (our own claim, external churn);
            # the one exception is our watcher name being taken over with
            # REPLACE while we own it -- re-bootstrap then.
            if (
                self.watcher_own is not None
                and name in WATCHER_NAMES
                and new != getattr(self.bus, "unique_name", "")
            ):
                log.warning(
                    "watcher name %s taken over by %s; re-bootstrapping",
                    name,
                    new,
                )
                self.reset_watcher()
                self.restart_watcher_loop()
            return
        if name in self.hosts:
            self.remove_host(name)
        if self.watcher_own is not None:
            if name in self.watcher_own.items:
                self.watcher_own.unregister(name)
            elif name in WATCHER_NAMES:
                log.warning("watcher name %s lost; re-bootstrapping", name)
                self.reset_watcher()
                self.restart_watcher_loop()
        elif self.watcher is not None and name == self.watcher:
            log.warning("StatusNotifierWatcher %s vanished; re-bootstrapping", name)
            self.reset_watcher()
            self.restart_watcher_loop()

    def reset_watcher(self) -> None:
        """Drop all watcher state: own export, items, hosts.  The next
        watcher-loop pass re-acquires whatever is on the bus."""
        self.watcher_own = None
        self.watcher = None
        if self._exported_watcher:
            try:
                self.bus.unexport(WATCHER_PATH)
            except Exception:
                log.debug("could not unexport watcher", exc_info=True)
            self._exported_watcher = False
        for service in list(self.items):
            self._spawn(self.on_item_unregistered(service))
        self.hosts.clear()

    async def _list_names(self) -> list[str] | None:
        try:
            reply = await self.bus_call("ListNames", "", [])
            return [str(n) for n in reply[0]]
        except Exception as exc:
            log.debug("ListNames failed: %s", exc)
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
                for taken in owned:
                    await self.bus.release_name(taken)
                return False  # the preferred watcher name is taken by someone else
        if not owned:
            return False
        if not self._exported_watcher:
            self.bus.export(WATCHER_PATH, attempt)
            self._exported_watcher = True
        self.watcher_own = attempt
        self.watcher = owned[0]
        log.info("no tray watcher found; providing our own at %s", " + ".join(owned))
        return True

    async def register_host(self) -> None:
        try:
            await self.bus_call(
                "RequestName", "su", [self.host_name, NameFlag.DO_NOT_QUEUE.value]
            )
        except Exception:
            log.debug("could not own %s, will use raw unique name", self.host_name)
        if self.watcher is None:
            return
        await self.dbus_call(
            self.watcher,
            WATCHER_PATH,
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
        obj = self.bus.get_proxy_object(
            self.watcher,
            WATCHER_PATH,
            await self.introspect(self.watcher, WATCHER_PATH),
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
            self.watcher, WATCHER_PATH, PROPS_IFACE, "GetAll", "s", [WATCHER_IFACE]
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
            self.watcher = name
            log.info("found StatusNotifierWatcher at %s", name)
        elif not await self.claim_watcher():
            return False
        await self.register_host()
        if self.watcher_own is None:
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

    def restart_watcher_loop(self) -> None:
        """(Re)start watcher acquisition; a later loss of the watcher re-enters it."""
        if self._watcher_loop is None or self._watcher_loop.done():
            self._watcher_loop = asyncio.create_task(
                self._safe(self.run_watcher_loop())
            )

    async def run_watcher_loop(self) -> None:
        """Find a watcher or become one, retrying with backoff while the
        bus has none.  Returns once a live watcher is established."""
        if not self._watching_names:
            await self.bus_call(
                "AddMatch",
                "s",
                [
                    "type='signal',sender='org.freedesktop.DBus',"
                    "member='NameOwnerChanged',path='/org/freedesktop/DBus'"
                ],
            )
            self._watching_names = True
        delay = POLL_INTERVAL
        warned = False
        while not self._shutdown:
            try:
                if await self.bootstrap():
                    return
            except Exception as exc:
                log.warning("watcher setup failed: %s", exc)
            if not warned:
                warned = True
                await self.diagnose()
            await asyncio.sleep(delay)
            delay = min(delay * 2, 60)

    # ----------------------------------------------------------- item handling
    async def on_item_registered(self, service: str, path: str = ITEM_PATH) -> None:
        if service in self.items:
            return
        item = Item(service, path)
        self.items[service] = item
        if not await self.fill_props(item):
            # Roll the registration back (xapp-sn-watcher syncs the item
            # table the same way on a failed registration), so a dead entry
            # never lingers in RegisteredStatusNotifierItems and a later
            # re-registration can succeed.
            self.items.pop(service, None)
            if self.watcher_own is not None:
                self.watcher_own.unregister(service)
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
        # detach bus signal handlers so a vanished service's subscriptions
        # (and match rules) do not accumulate on the connection
        for iface, snake, fn in item.handlers:
            try:
                if off := getattr(iface, f"off_{snake}", None):
                    off(fn)
            except Exception:
                log.debug("could not detach %s handler for %s", snake, service)
        self.broadcast({"t": "remove", "key": service})
        log.info("tray item gone: %s", service)

    async def fill_props(self, item: Item, push: bool = False) -> bool:
        try:
            reply = await self.dbus_call(
                item.service, item.path, PROPS_IFACE, "GetAll", "s", [SNI_IFACE]
            )
            props = unwrap_variants(reply[0])
        except Exception as exc:
            log.debug("GetAll(%s) failed: %s", item.service, exc)
            return False
        first = not item.props
        item.props = props

        icon = icon_png(props)
        tooltip = tooltip_of(props)
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

        menu = props.get("Menu")
        if menu == NO_DBUSMENU:
            menu = None
        if menu and menu != item.menu_path:
            item.menu_path, item.menu_ok = menu, False
            if not first:
                await self.refresh_menu(item, force=True)
        elif not menu and item.menu_path:
            item.menu_path, item.menu_ok = None, False

        if push and changes:
            self.broadcast({"t": "update", "key": item.service, **changes})
        return True

    async def fetch_layout(self, item: Item) -> tuple[list, str] | None:
        """Current layout tree of the item's menu plus the working iface,
        read with GetLayout(0, -1, []).  GetLayout may be called at any
        time, so this is safe to use right before raising a click.
        Returns None if no iface spelling answered."""
        reply, iface = await self.menu_call(item, "GetLayout", "iias", [0, -1, []])
        if reply is None or iface is None:
            return None
        node = reply[1] if len(reply) > 1 else None
        children = node[2] if isinstance(node, (tuple, list)) and len(node) > 2 else []
        tree = [
            parsed
            for n in children
            if (parsed := parse_layout_node(n.value if isinstance(n, Variant) else n))
            is not None
        ]
        return tree, iface

    async def refresh_menu(
        self, item: Item, force: bool = False, about_to_show: bool = False
    ) -> None:
        if not item.menu_path or (not force and item.menu_ok is False):
            return
        if about_to_show:
            # Best-effort notification that the menu is about to be shown
            # (spec); a missing implementation must not block the read.
            await self.menu_call(item, "AboutToShow", "i", [0])
        layout = await self.fetch_layout(item)
        if not layout:
            item.menu_ok = False
            if item.menu_cache:
                item.menu_cache = []
                self.broadcast({"t": "menu", "key": item.service, "menu": []})
            log.debug("no working dbusmenu on %s (%s)", item.service, item.menu_path)
            return
        self._set_menu_cache(item, *layout)

    async def monitor(self, item: Item) -> None:
        """Subscribe to item property/signal changes (poll as a fallback),
        then to menu layout updates.  dbus-fast proxy listeners require an
        exact argument count, so each lambda mirrors its signal's arity.

        Every subscription is recorded on the item so that it can be
        detached (off_<signal>) when the item goes away.
        """
        try:
            obj = self.bus.get_proxy_object(
                item.service,
                item.path,
                await self.introspect(item.service, item.path),
            )
        except Exception as exc:
            log.warning(
                "introspection of %s failed (%s); polling instead", item.service, exc
            )
            item.poller = asyncio.create_task(self.poll(item))
            return

        def push() -> None:
            self.push_item(item)

        def subscribe(iface, snake: str, fn) -> None:
            if listener := getattr(iface, f"on_{snake}", None):
                listener(fn)
                item.handlers.append((iface, snake, fn))

        try:
            subscribe(
                obj.get_interface(PROPS_IFACE),
                "properties_changed",
                lambda _iface, _changed, _invalidated: push(),
            )
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
                subscribe(sni, sig, push)  # zero-argument signals
        except Exception:
            pass
        if item.menu_path:
            try:
                mobj = self.bus.get_proxy_object(
                    item.service,
                    item.menu_path,
                    await self.introspect(item.service, item.menu_path),
                )
                iface, _listener = self._menu_attr(mobj, "layout_updated")
                if iface:
                    subscribe(
                        iface,
                        "layout_updated",
                        lambda _rev, _parent, _pos: self._spawn(
                            self.refresh_menu(item, force=True)
                        ),
                    )
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
            await asyncio.sleep(POLL_INTERVAL)
            if await self.fill_props(item, push=True) or item.props:
                misses = 0
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
                if item.props.get("ItemIsMenu"):
                    # KDE parity (StatusNotifierItem.qml:46): an item that
                    # declares itself a menu opens its menu on left click
                    # instead of receiving Activate.
                    await self.surface_menu(item)
                else:
                    await self.call(item, "Activate", "ii", [0, 0])
            elif t == "menu_click":
                await self.click_menu_item(item, m)
            elif t == "open_window":
                await self.open_window(item)
        except Exception as exc:
            log.info("forwarding %s to %s failed: %s", t, item.service, exc)

    async def click_menu_item(self, item: Item, m: dict) -> None:
        """Resolve a click against the current layout, then fire Event.

        clash-verge rebuilds its dbusmenu and renumbers item ids on every
        state change, while the Win32 popup is built from our cached layout
        (pystray has no menu-open hook to refresh it), so the id a click
        carries is stale by definition — sending it as-is either does
        nothing or triggers a different item.  GetLayout is therefore read
        again (allowed at any time per spec) and the label resolved against
        it; the raw id is only a last resort.
        """
        label = str(m.get("label") or "")
        cached_id = int(m.get("item") or 0)
        node = None
        if item.menu_path and (layout := await self.fetch_layout(item)):
            self._set_menu_cache(item, *layout)
            if label:
                node = find_menu_node(layout[0], label)
        if node is None and label:
            node = find_menu_node(item.menu_cache, label)
        if not await self._fire_event(item, int(node["id"]) if node else cached_id):
            return
        await self.refresh_menu(item, force=True)

    async def _fire_event(self, item: Item, node_id: int) -> bool:
        """Fire Event(id, "clicked") on the item's dbusmenu; True on success."""
        try:
            await self.dbus_call(
                item.service,
                item.menu_path,
                item.menu_iface or MENU_IFACES[0],
                "Event",
                "isvu",
                [
                    node_id,
                    "clicked",
                    Variant("i", 1),  # X11 left button
                    0,  # timestamp unknown
                ],
            )
            return True
        except Exception as exc:
            log.info("Event(%s) on %s failed: %s", node_id, item.service, exc)
            return False

    # ------------------------------------------------------- open window
    async def app_pid(self, item: Item) -> int | None:
        """PID of the process behind the SNI item.

        The item's bus name is resolved to its unique name first (the
        registered name may be well-known), then GetConnectionUnixProcessID
        maps it to a pid — used to locate the app's X11 windows.
        """
        try:
            reply = await self.bus_call("GetNameOwner", "s", [item.service])
            unique = str(reply[0]) if reply and reply[0] else item.service
            reply = await self.bus_call("GetConnectionUnixProcessID", "s", [unique])
            return int(reply[0]) if reply and reply[0] else None
        except Exception:
            return None

    async def map_x11_windows(self, pid: int) -> bool:
        """Map + raise the app's X11 windows so WSLg shows them again.

        Only windows owned by `pid` (via _NET_WM_PID) are touched, so this
        can never surface a different program.  A single chained xdotool
        call searches by pid and acts on every result (``%@``), keeping
        this to one process spawn and one X connection.  Exit status is
        the "found" signal: chained search is silent on stdout and fails
        with a non-zero status when the window stack is empty.  Returns
        True when at least one window existed and was remapped - i.e. the
        app merely hid its window on close-to-tray and keeps it around.
        """
        try:
            proc = await asyncio.create_subprocess_exec(
                "xdotool",
                "search",
                "--pid",
                str(pid),
                "windowmap",
                "--sync",
                "%@",
                "windowraise",
                "%@",
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
            return await proc.wait() == 0
        except (FileNotFoundError, OSError) as exc:
            log.debug("xdotool unavailable: %s", exc)
            return False

    async def open_window(self, item: Item) -> None:
        """Generic fallback to surface a backgrounded app's window.

        SNI Activate is only a request and many apps ignore it on Linux,
        so when it failed to produce a window: 1) map the app's X11
        windows if it has any (covers apps that merely hide their window),
        else 2) present the app's menu to the user (KDE's behaviour: a
        no-op activate degrades to the context menu instead of guessing
        an item).  All routes are generic and can only ever touch the app
        itself.
        """
        pid = await self.app_pid(item)
        if pid and await self.map_x11_windows(pid):
            return
        await self.surface_menu(item)

    async def surface_menu(self, item: Item) -> None:
        """Present the app's context menu and let the user pick an item.

        Used for left clicks on ``ItemIsMenu`` items (KDE behaviour) and
        as the last fallback when Activate raised no window: instead of
        auto-clicking a menu item that might turn out to be a setting or
        "quit", refresh the menu the way a right-click would and ask the
        Windows side to pop it up at the cursor.  The user then chooses
        the app's own "show window" item by hand.
        """
        await self.refresh_menu(item, force=True, about_to_show=True)
        self.broadcast({"t": "show_menu", "key": item.service})

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
            self._drop(writer)
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
        if self._shutdown:
            return
        self._shutdown = True
        try:
            self.broadcast({"t": "bye", "reason": "server shutting down"})
            for writer in list(self.clients):
                try:
                    await asyncio.wait_for(writer.drain(), timeout=1)
                except Exception:
                    pass
                self._drop(writer)
            if self.server:
                self.server.close()
                await self.server.wait_closed()
        finally:
            # dbus-fast's disconnect() is synchronous (socket teardown is
            # kicked off here; pending calls error out on it)
            try:
                self.bus.disconnect()
            except Exception:
                log.debug("bus disconnect failed", exc_info=True)


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

    try:
        bus = await MessageBus(bus_address=bus_address).connect()
    except Exception as exc:
        log.error("D-Bus connection failed (%s): %s", bus_address, exc)
        return 1
    bridge = Bridge(args.port, bus)
    bridge.bus_address = bus_address
    bridge.server = await asyncio.start_server(bridge.on_client, "127.0.0.1", args.port)
    log.info("listening on 127.0.0.1:%d for tray_host (%s)", args.port, bus_address)

    bridge.restart_watcher_loop()
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
    args = ap.parse_args()
    if not 1 <= args.port <= 65535:
        ap.error("--port must be between 1 and 65535")
    sys.exit(asyncio.run(main(args)))

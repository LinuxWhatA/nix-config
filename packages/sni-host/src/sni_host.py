#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WSLg tray bridge - WSL/Linux side
=================================

Implements the idea from microsoft/wslg#158: a Linux app that registers itself
as a StatusNotifierHost on the session bus, watches every StatusNotifierItem
(tray icon) registered by GTK/Qt apps, and forwards them over a localhost TCP
socket to tray_host.py running on Windows, which paints real icons in the
Windows notification area and routes mouse/menu events back.

WSLg ships no StatusNotifierWatcher, so when none exists on the bus this
bridge also provides one itself (org.kde./org.freedesktop.StatusNotifier
Watcher), letting tray apps register with us in the first place.  On a
desktop session with a real watcher it instead acts as a plain host.

Run inside a WSL2 distro with WSLg (packaged in nix-config as
`wslg-tray-bridge` -> command `sni-host`):

    sni-host [--port 17632]

If python.exe / cmd.exe is found on PATH (WSL interop), the Windows
companion is launched automatically.  Otherwise start it manually on the
Windows side (see the separate `wslg-tray-bridge` Windows project):

    pip install pystray Pillow
    python tray_host.py --port 17632
"""

from __future__ import annotations

import sys
import argparse
import asyncio
import base64
import io
import json
import logging
import os
import shutil
import signal
import subprocess
import time
from typing import Any, Dict, List, Optional, Set, Tuple

from dbus_next import ErrorType, Message, MessageType, Variant
from dbus_next.aio import MessageBus
from PIL import Image

log = logging.getLogger("sni-host")

SNI_IFACE = "org.kde.StatusNotifierItem"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
DBUS_IFACE = "org.freedesktop.DBus"
WATCHER_IFACE = "org.kde.StatusNotifierWatcher"

# "com.canical.dbusmenu" (missing the second 'n') is the legacy KDE spelling;
# try every spelling in order until one answers GetLayout.
MENU_IFACES = (
    "com.canonical.dbusmenu",
    "com.ayatana.dbusmenu",
    "com.canical.dbusmenu",
)

WATCHER_CANDIDATES = (
    "org.kde.StatusNotifierWatcher",
    "org.freedesktop.StatusNotifierWatcher",
    "org.ayatana.StatusNotifierWatcher",
)

ITEM_OBJECT_PATH = "/StatusNotifierItem"
HOST_NAME_PREFIX = "org.kde.StatusNotifierHost-wslg-tray-bridge"
PROTOCOL_VERSION = 1

WATCHER_NAMES = (
    "org.kde.StatusNotifierWatcher",
    "org.freedesktop.StatusNotifierWatcher",
)

WATCHER_INTROSPECT = """<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN" \
"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
  <interface name="org.kde.StatusNotifierWatcher">
    <method name="RegisterStatusNotifierItem">
      <arg type="s" direction="in" name="service"/>
    </method>
    <method name="RegisterStatusNotifierHost">
      <arg type="s" direction="in" name="service"/>
    </method>
    <property name="RegisteredStatusNotifierItems" type="as" access="read"/>
    <property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
    <property name="ProtocolVersion" type="i" access="read"/>
    <signal name="StatusNotifierItemRegistered"><arg type="s"/></signal>
    <signal name="StatusNotifierItemUnregistered"><arg type="s"/></signal>
    <signal name="StatusNotifierHostRegistered"/>
    <signal name="StatusNotifierHostUnregistered"/>
  </interface>
</node>
"""


class OwnWatcher:
    """Minimal StatusNotifierWatcher, behind a raw message handler.

    WSLg ships no tray watcher (microsooft/wslg#158), so we provide one:
    tray apps register their StatusNotifierItems against us and we forward
    them through the normal host path to Windows.  If a real desktop watcher
    exists, claiming fails and we simply act as a host, as before.
    """

    def __init__(self, bridge: "Bridge"):
        self.bridge = bridge
        self.bus = bridge.bus
        self.items: Dict[str, str] = {}  # service -> object path
        self.hosts: Set[str] = set()
        self.names: List[str] = []

    async def claim(self) -> List[str]:
        for name in WATCHER_NAMES:
            reply = await self.bridge.dbus_call(
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                DBUS_IFACE,
                "RequestName",
                "su",
                [name, 0],
            )
            if reply and reply[0] in (1, 4):  # PRIMARY_OWNER / ALREADY_OWNER
                self.names.append(name)
        if not self.names:
            return []
        self.bus.add_message_handler(self.handle)
        try:
            await self.bridge.dbus_call(
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                DBUS_IFACE,
                "AddMatch",
                "s",
                [
                    "type='signal',sender='org.freedesktop.DBus',"
                    "interface='org.freedesktop.DBus',member='NameOwnerChanged',"
                    "path='/org/freedesktop/DBus'"
                ],
            )
        except Exception:
            pass
        return self.names

    def handle(self, msg: Message):
        if msg.message_type == MessageType.SIGNAL:
            if (
                msg.sender == "org.freedesktop.DBus"
                and msg.interface == DBUS_IFACE
                and msg.member == "NameOwnerChanged"
            ):
                name, _old, new = msg.body
                if name in self.items and not new:
                    del self.items[name]
                    self.emit("StatusNotifierItemUnregistered", "s", [name])
                    self.bridge._spawn(self.bridge.on_item_unregistered(name))
            return None
        if (
            msg.message_type != MessageType.METHOD_CALL
            or msg.path != "/StatusNotifierWatcher"
        ):
            return None
        if (
            msg.interface == "org.freedesktop.DBus.Introspectable"
            and msg.member == "Introspect"
            and msg.signature == ""
        ):
            return Message.new_method_return(msg, "s", [WATCHER_INTROSPECT])
        if msg.interface == PROPS_IFACE:
            props = {
                "RegisteredStatusNotifierItems": Variant("as", list(self.items)),
                "IsStatusNotifierHostRegistered": Variant("b", bool(self.hosts)),
                "ProtocolVersion": Variant("i", 0),
            }
            if msg.member == "GetAll" and msg.signature == "s":
                return Message.new_method_return(msg, "a{sv}", [props])
            if msg.member == "Get" and msg.signature == "ss":
                prop = props.get(msg.body[1])
                if prop is not None:
                    return Message.new_method_return(msg, "v", [prop])
                return Message.new_error(
                    msg, ErrorType.UNKNOWN_PROPERTY, f'no such property "{msg.body[1]}"'
                )
            return None
        if msg.interface == WATCHER_IFACE:
            if msg.member == "RegisterStatusNotifierItem" and msg.signature == "s":
                service = msg.body[0]
                path = ITEM_OBJECT_PATH
                if service.startswith("/"):
                    path, service = service, msg.sender
                if service and service not in self.items:
                    self.items[service] = path
                    self.emit("StatusNotifierItemRegistered", "s", [service])
                    self.bridge._spawn(self.bridge.on_item_registered(service, path))
                return Message.new_method_return(msg, "", [])
            if msg.member == "RegisterStatusNotifierHost" and msg.signature == "s":
                self.hosts.add(msg.body[0])
                self.emit("StatusNotifierHostRegistered", "", [])
                for service in list(self.items):
                    self.emit("StatusNotifierItemRegistered", "s", [service])
                return Message.new_method_return(msg, "", [])
        return None

    def emit(self, member: str, signature: str, body) -> None:
        self.bus.send(
            Message(
                message_type=MessageType.SIGNAL,
                path="/StatusNotifierWatcher",
                interface=WATCHER_IFACE,
                member=member,
                signature=signature,
                body=body,
            )
        )


def resolve_bus_address() -> Optional[str]:
    addr = os.environ.get("DBUS_SESSION_BUS_ADDRESS")
    if addr:
        return addr
    for candidate in (
        "unix:path=/mnt/wslg/runtime-dir/bus",
        f"unix:path=/run/user/{os.getuid()}/bus",
    ):
        if os.path.exists(candidate[len("unix:path=") :]):
            return candidate
    return None


def pixmap_to_png(width: int, height: int, data: bytes) -> bytes:
    """Convert a(ibay) ARGB32 pixmap data to PNG, as required by the SNI spec."""
    img = Image.frombytes("RGBA", (width, height), bytes(data), "raw", "ARGB")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def best_pixmap_png(pixmaps: Optional[list]) -> Optional[bytes]:
    """Pick the largest member of an IconPixmap/ToolTip a(iiay) array."""
    best: Optional[Tuple[int, int, bytes]] = None
    for w, h, data in pixmaps or []:
        if not data or w <= 0 or h <= 0:
            continue
        if best is None or w * h > best[0] * best[1]:
            best = (w, h, data)
    if best is None:
        return None
    try:
        return pixmap_to_png(*best)
    except Exception:
        log.exception("failed to convert pixmap")
        return None


def parse_layout_node(node: Tuple[Any, Dict[Any, Any], List[Any]]) -> Dict[str, Any]:
    """Convert a com.canonical.dbusmenu GetLayout node into a plain dict."""
    node_id, props, children = node
    p: Dict[str, Any] = {}
    for k, v in props.items():
        p[k] = v.value if isinstance(v, Variant) else v
    out: Dict[str, Any] = {
        "id": int(node_id),
        "label": str(p.get("label") or ""),
        "type": p.get("type") or "standard",
        "enabled": bool(p.get("enabled", True)),
        "visible": bool(p.get("visible", True)),
        "children": [],
    }
    tt = p.get("toggle-type")
    if tt in ("checkmark", "radio"):
        out["checked"] = bool(p.get("toggle-state", 0))
        out["radio"] = tt == "radio"
    ic = p.get("icon-data")
    if isinstance(ic, (bytes, bytearray)) and ic:
        out["icon_png"] = base64.b64encode(bytes(ic)).decode("ascii")
    for ch in children or []:
        inner = ch.value if isinstance(ch, Variant) else ch
        if isinstance(inner, (tuple, list)):
            out["children"].append(parse_layout_node(inner))
    return out


def find_menu_node(nodes: List[Dict[str, Any]], label: str) -> Optional[Dict[str, Any]]:
    """Depth-first lookup of a menu node by label, recursing into submenus."""
    for node in nodes or []:
        if node.get("label") == label:
            return node
        hit = find_menu_node(node.get("children") or [], label)
        if hit is not None:
            return hit
    return None


class Item:
    """One StatusNotifierItem living on `service` (its well-known bus name)."""

    def __init__(self, service: str, path: str = ITEM_OBJECT_PATH):
        self.service = service
        self.path = path
        self.props: Dict[str, Any] = {}
        self.title = ""
        self.tooltip = ""
        self.status = ""
        self.icon_png: Optional[bytes] = None
        self.menu_path: Optional[str] = None
        self.menu_iface: Optional[str] = None
        self.menu_ok = False
        self.menu_cache: List[Dict[str, Any]] = []
        self.poller: Optional[asyncio.Task] = None


class Bridge:
    def __init__(self, port: int):
        self.port = port
        self.bus: Optional[MessageBus] = None
        self.bus_address: Optional[str] = None
        self.host_name = f"{HOST_NAME_PREFIX}-{os.getpid()}"
        self.watcher: Optional[Tuple[str, str]] = None
        self.own_watcher: Optional[OwnWatcher] = None
        self.items: Dict[str, Item] = {}
        self.clients: Set[asyncio.StreamWriter] = set()
        self.server: Optional[asyncio.Server] = None

    # ------------------------------------------------------------------ dbus
    async def dbus_call(
        self,
        destination: str,
        path: str,
        interface: str,
        member: str,
        signature: str,
        body: List[Any],
    ):
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
        if reply.message_type == MessageType.ERROR:
            # newer dbus-next returns error replies instead of raising
            text = str(reply.body[0]) if reply.body else ""
            raise RuntimeError(
                f"{reply.error_name}: {text}"
                if reply.error_name
                else text or "dbus error"
            )
        return reply.body

    async def find_watcher(self) -> bool:
        for name in WATCHER_CANDIDATES:
            try:
                reply = await self.dbus_call(
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    DBUS_IFACE,
                    "NameHasOwner",
                    "s",
                    [name],
                )
                if reply and reply[0]:
                    self.watcher = (name, "/StatusNotifierWatcher")
                    log.info("found StatusNotifierWatcher at %s", name)
                    return True
            except Exception:
                continue
        try:
            names = (
                await self.dbus_call(
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    DBUS_IFACE,
                    "ListNames",
                    "",
                    [],
                )
            )[0]
            for name in names:
                name = str(name)
                if (
                    "StatusNotifier" in name
                    and "watcher" in name.lower()
                    and "item" not in name.lower()
                ):
                    self.watcher = (name, "/StatusNotifierWatcher")
                    log.info("found StatusNotifierWatcher at %s", name)
                    return True
        except Exception:
            pass
        return False

    async def claim_own_watcher(self) -> bool:
        watcher = OwnWatcher(self)
        claimed = await watcher.claim()
        if not claimed:
            return False
        self.own_watcher = watcher
        self.watcher = (claimed[0], "/StatusNotifierWatcher")
        log.info("no external tray watcher; acting as our own (%s)", ", ".join(claimed))
        return True

    async def bootstrap(self) -> bool:
        """Get the tray pipeline going: find a watcher or become one."""
        if self.watcher:
            return True
        if not (await self.find_watcher()) and not (await self.claim_own_watcher()):
            return False
        await self.export_host_name()
        await self.register_host()
        await self.setup_watcher_signals()
        if self.own_watcher:
            for service, path in list(self.own_watcher.items.items()):
                self._spawn(self.on_item_registered(service, path))
        return True

    async def diagnose(self) -> None:
        hints = []
        if os.path.exists("/mnt/wslg"):
            hints.append(
                "this is WSLg, which has no StatusNotifierWatcher; "
                "the bridge can act as one (keep waiting)"
            )
        names = []
        try:
            names = (
                await self.dbus_call(
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    DBUS_IFACE,
                    "ListNames",
                    "",
                    [],
                )
            )[0]
        except Exception:
            pass
        sni = [n for n in names if "StatusNotifier" in str(n)]
        if sni:
            hints.append(f"StatusNotifier services present: {sni}")
        log.warning(
            "waiting for a tray watcher on %s%s",
            self.bus_address,
            (
                f" ({'; '.join(hints)})"
                if hints
                else " -- start a desktop session or restart your tray apps"
            ),
        )

    async def export_host_name(self) -> None:
        try:
            await self.dbus_call(
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                DBUS_IFACE,
                "RequestName",
                "su",
                [self.host_name, 4],
            )
        except Exception:

            log.debug("could not own %s, will use raw unique name", self.host_name)

    async def register_host(self) -> None:
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
        name, path = self.watcher
        obj = self.bus.get_proxy_object(
            name, path, await self.bus.introspect(name, path)
        )
        iface = obj.get_interface(WATCHER_IFACE)
        for sig, handler in (
            (
                "status_notifier_item_registered",
                lambda s: self._spawn(self.on_item_registered(str(s))),
            ),
            (
                "status_notifier_item_unregistered",
                lambda s: self._spawn(self.on_item_unregistered(str(s))),
            ),
            (
                "status_notifier_host_registered",
                lambda: log.info("another tray host registered"),
            ),
        ):
            listener = getattr(iface, f"on_{sig}", None)
            if listener is not None:
                listener(handler)
        reply = await self.dbus_call(
            name, path, PROPS_IFACE, "GetAll", "s", [WATCHER_IFACE]
        )
        existing = reply[0].get("RegisteredStatusNotifierItems")
        if existing is not None:
            for service in existing.value:
                self._spawn(self.on_item_registered(service))

    # ----------------------------------------------------------- item handling
    async def on_item_registered(
        self, service: str, path: str = ITEM_OBJECT_PATH
    ) -> None:
        if service in self.items:
            return
        item = Item(service, path)
        self.items[service] = item
        if not await self.fill_props(item):
            self.items.pop(service, None)
            return
        self.broadcast(self.add_message(item))
        await self.refresh_menu(item, force=True)
        await self.setup_item_monitors(item)
        await self.monitor_menu(item)
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
            if not reply:
                return False
            props = {
                k: v.value if isinstance(v, Variant) else v for k, v in reply[0].items()
            }
        except Exception as exc:
            log.debug("GetAll(%s) failed: %s", item.service, exc)
            return False
        first = not item.props
        item.props = props

        png = best_pixmap_png(props.get("IconPixmap"))
        if not png:
            icon_name = props.get("IconName")
            if icon_name and str(icon_name).startswith("/") and os.path.exists(str(icon_name)):
                try:
                    with open(str(icon_name), "rb") as f:
                        png = f.read()
                except Exception:
                    png = None
        tooltip = ""
        tt = props.get("ToolTip")
        if isinstance(tt, (tuple, list)) and len(tt) >= 2:
            tooltip = str(tt[1] or "")

        changes: Dict[str, Any] = {}
        if png != item.icon_png:
            changes["icon"] = base64.b64encode(png).decode("ascii") if png else None
        if (props.get("Title") or "") != item.title:
            changes["title"] = props.get("Title") or ""
        if tooltip != item.tooltip:
            changes["tooltip"] = tooltip
        if (props.get("Status") or "") != item.status:
            changes["status"] = props.get("Status") or ""

        item.icon_png, item.title, item.tooltip, item.status = (
            png,
            props.get("Title") or "",
            tooltip,
            props.get("Status") or "",
        )

        if "Menu" in props and props.get("Menu"):
            new_menu = str(props["Menu"])
            if new_menu != item.menu_path:
                item.menu_path = new_menu
                item.menu_ok = False
                if not first:
                    await self.refresh_menu(item, force=True)
        else:
            item.menu_path = None
            item.menu_ok = False

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
                        item.service,
                        item.menu_path,
                        iface,
                        "AboutToShow",
                        "i",
                        [0],
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
                children = node[2] if isinstance(node, (tuple, list)) and len(node) > 2 else []
                tree = [
                    parse_layout_node(
                        n.value if isinstance(n, Variant) else n
                    )
                    for n in children
                ]
            except Exception:
                log.exception("bad menu layout from %s", item.service)
                continue
            item.menu_cache, item.menu_iface, item.menu_ok = tree, iface, True
            self.broadcast({"t": "menu", "key": item.service, "menu": tree})
            return
        item.menu_ok = False
        if item.menu_cache:
            item.menu_cache = []
            self.broadcast({"t": "menu", "key": item.service, "menu": []})
        log.debug("no working dbusmenu on %s (%s)", item.service, item.menu_path)

    async def setup_item_monitors(self, item: Item) -> None:
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
            item.poller = asyncio.create_task(self._poll_props(item))
            return
        try:
            props_iface = obj.get_interface(PROPS_IFACE)
            props_iface.on_properties_changed(
                lambda *a: self._spawn(self.fill_props(item, push=True))
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
                handler = getattr(sni, f"on_{sig}", None)
                if handler is not None:
                    handler(lambda *a: self._spawn(self.fill_props(item, push=True)))
        except Exception:
            pass

    async def monitor_menu(self, item: Item) -> None:
        if not item.menu_path:
            return
        try:
            obj = self.bus.get_proxy_object(
                item.service,
                item.menu_path,
                await self.bus.introspect(item.service, item.menu_path),
            )
        except Exception:
            return
        for iface_name in MENU_IFACES:
            try:
                iface = obj.get_interface(iface_name)
                layout_updated = getattr(iface, "on_layout_updated", None)
                if layout_updated is not None:
                    layout_updated(
                        lambda *a: self._spawn(self.refresh_menu(item, force=True))
                    )
                return
            except Exception:
                continue

    async def _poll_props(self, item: Item) -> None:
        while item.service in self.items:
            await asyncio.sleep(3.0)
            await self.fill_props(item, push=True)

    # ------------------------------------------------------- windows messages
    async def handle_client_message(self, m: Dict[str, Any]) -> None:
        t = m.get("t")
        log.debug("client msg: %s", m)
        item = self.items.get(str(m.get("key") or ""))
        if t == "hello_ack":
            if m.get("protocol") != PROTOCOL_VERSION:
                log.warning(
                    "protocol mismatch: tray_host=%s, we=%s",
                    m.get("protocol"),
                    PROTOCOL_VERSION,
                )
            return
        if item is None:
            return
        try:
            if t == "activate":
                await self.dbus_call(
                    item.service, item.path, SNI_IFACE, "Activate", "ii", [0, 0]
                )
            elif t == "secondary":
                await self.dbus_call(
                    item.service,
                    item.path,
                    SNI_IFACE,
                    "SecondaryActivate",
                    "ii",
                    [0, 0],
                )
            elif t == "context":
                await self.refresh_menu(item, force=True, about_to_show=True)
            elif t == "menu_click" and item.menu_path:
                await self.click_menu_item(item, m)
            elif t == "scroll":
                await self.dbus_call(
                    item.service,
                    item.path,
                    SNI_IFACE,
                    "Scroll",
                    "ii",
                    [int(m.get("dx", 0)), int(m.get("dy", 0))],
                )
        except Exception as exc:
            log.debug("forwarding %s to %s failed: %s", t, item.service, exc)

    async def click_menu_item(self, item: Item, m: Dict[str, Any]) -> None:
        """Forward a menu click, resolving the target against a fresh layout.

        Some apps (e.g. clash-verge) rebuild their dbusmenu on every change
        and renumber all item ids, so cached ids go stale almost immediately.
        Match by label against the latest layout; fall back to the raw id.
        """
        label = str(m.get("label") or "")
        node = None
        if label:
            node = find_menu_node(item.menu_cache, label)
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
            log.debug("menu_click(%s) failed: %s; refreshing menu", label or node["id"], exc)
            await self.refresh_menu(item, force=True)
            return
        await self.refresh_menu(item, force=True)

    # ------------------------------------------------------------------ tcp
    def send(self, writer: asyncio.StreamWriter, msg: Dict[str, Any]) -> None:
        try:
            writer.write((json.dumps(msg, ensure_ascii=False) + "\n").encode("utf-8"))
        except Exception:
            self._drop(writer)

    def broadcast(self, msg: Dict[str, Any]) -> None:
        for writer in list(self.clients):
            self.send(writer, msg)

    def _drop(self, writer: asyncio.StreamWriter) -> None:
        self.clients.discard(writer)
        try:
            writer.close()
        except Exception:
            pass

    async def _on_client(
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

    def add_message(self, item: Item) -> Dict[str, Any]:
        return {
            "t": "add",
            "key": item.service,
            "id": item.props.get("Id") or item.service,
            "title": item.title,
            "tooltip": item.tooltip,
            "status": item.status,
            "category": item.props.get("Category") or "",
            "icon": (
                base64.b64encode(item.icon_png).decode("ascii")
                if item.icon_png
                else None
            ),
            "icon_name": item.props.get("IconName") or "",
            "item_is_menu": bool(item.props.get("ItemIsMenu", False)),
        }

    # ---------------------------------------------------------------- misc
    async def _safe(self, coro) -> None:
        try:
            await coro
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("background task failed")

    def _spawn(self, coro) -> None:
        asyncio.create_task(self._safe(coro))

    def spawn_windows_side(self) -> None:
        arg = shutil.which("python.exe")
        if not arg:
            log.warning("python.exe not found; start tray_host.py manually on Windows")
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
        if self.bus:
            try:
                result = self.bus.disconnect()
                if asyncio.iscoroutine(result):
                    await result
            except Exception:
                pass


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

    bridge = Bridge(args.port)
    bridge.bus_address = bus_address
    bridge.bus = await MessageBus(bus_address=bus_address).connect()

    bridge.server = await asyncio.start_server(
        bridge._on_client, "127.0.0.1", args.port
    )
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
    for sig in (signal.SIGINT, signal.SIGTERM):
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
        help="auto-launch tray_host.py on Windows (default)",
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

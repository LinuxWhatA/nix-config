"""StatusNotifierItem spec glue for the WSLg tray bridge.

Everything in here knows only about the StatusNotifierItem /
StatusNotifierWatcher / dbusmenu specifications and their type gymnastics:
Variant unwrapping, the legacy "com.canical.dbusmenu" spelling, pixmap -> PNG
conversion and D-Bus address resolution.  The bridge logic itself lives in
sni_host.py.
"""

import base64
import io
import logging
import os
from typing import TYPE_CHECKING

from dbus_fast import Variant
from dbus_fast.service import (
    PropertyAccess,
    ServiceInterface,
    dbus_property,
    method,
    signal,
)
from PIL import Image

if TYPE_CHECKING:
    from sni_host import Bridge

log = logging.getLogger(__name__)

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

# The spec's official name plus the freedesktop.org one.  The bridge owns
# both when it acts as the watcher, so clients probing either name find it
# (Qtile does the same with one service instance per name).
WATCHER_NAMES = (
    "org.kde.StatusNotifierWatcher",
    "org.freedesktop.StatusNotifierWatcher",
)
WATCHER_PATH = "/StatusNotifierWatcher"
ITEM_PATH = "/StatusNotifierItem"
NO_DBUSMENU = "/NO_DBUSMENU"  # spec sentinel: the item has no menu
PROTOCOL_VERSION = 1


# ------------------------------------------------------------------- helpers
def unwrap_variants(props: dict) -> dict:
    """Strip dbus-fast Variant wrappers, returning plain Python values."""
    return {k: v.value if isinstance(v, Variant) else v for k, v in props.items()}


def tooltip_of(props: dict) -> str:
    """Tooltip text of an item, tolerating both ToolTip signature variants.

    The spec says ``(sa(iiay)ss)``; some apps emit a bare string instead
    (xapp-sn-watcher handles both, sn-item.c:798-829).  Of the tuple form
    we keep the heading (field 2), matching the pre-existing behaviour.
    """
    tt = props.get("ToolTip")
    if isinstance(tt, (tuple, list)) and len(tt) >= 3:
        return str(tt[2] or "")
    if isinstance(tt, (str, bytes)):
        return tt.decode() if isinstance(tt, bytes) else tt
    return ""


# dbus type codes for the decorator annotations below (dbus-fast reads
# them literally); Pylance would treat "s" as a forward reference.
# pyright: reportInvalidTypeForm=false
class Watcher(ServiceInterface):
    """The StatusNotifierWatcher side of the spec.

    Provides the D-Bus interface (methods, properties, signals) for the
    StatusNotifierWatcher protocol.  Item bookkeeping is delegated to
    Bridge via callbacks; this class only maintains the service→path
    mapping needed for D-Bus introspection (``RegisteredStatusNotifierItems``).
    Host tracking is owned by Bridge (exposed as ``Bridge.hosts``).
    """

    sig_s, sig_as, sig_b, sig_i = "s", "as", "b", "i"

    def __init__(self, bridge: "Bridge"):
        super().__init__(WATCHER_IFACE)
        self.bridge = bridge
        self.items: dict[str, str] = {}  # service -> object path (for introspection)

    def register(self, service: str, path: str = ITEM_PATH) -> None:
        if service not in self.items:
            self.items[service] = path
            self.StatusNotifierItemRegistered(service)
            self.bridge._spawn(self.bridge.on_item_registered(service, path))

    def unregister(self, service: str) -> None:
        if service in self.items:
            del self.items[service]
            self.StatusNotifierItemUnregistered(service)
            self.bridge._spawn(self.bridge.on_item_unregistered(service))

    def register_host(self, service: str) -> None:
        self.bridge.add_host(str(service))

    def unregister_host(self, service: str) -> None:
        self.bridge.remove_host(str(service))

    @method()
    def RegisterStatusNotifierItem(self, service: sig_s):
        self.register(str(service))

    @method()
    def RegisterStatusNotifierHost(self, service: sig_s):
        self.register_host(str(service))

    @dbus_property(access=PropertyAccess.READ)
    def RegisteredStatusNotifierItems(self) -> sig_as:
        return list(self.items)

    @dbus_property(access=PropertyAccess.READ)
    def IsStatusNotifierHostRegistered(self) -> sig_b:
        # When the bridge owns the watcher it IS the host pipeline, so the
        # flag is advertised before its own registration call lands (the
        # xapp-sn-watcher behaviour); otherwise follow the registrations.
        return self.bridge.watcher_own is not None or bool(self.bridge.hosts)

    @dbus_property(access=PropertyAccess.READ)
    def ProtocolVersion(self) -> sig_i:
        return PROTOCOL_VERSION

    @signal()
    def StatusNotifierItemRegistered(self, service: str) -> sig_s:
        return service

    @signal()
    def StatusNotifierItemUnregistered(self, service: str) -> sig_s:
        return service

    @signal()
    def StatusNotifierHostRegistered(self):
        return None

    @signal()
    def StatusNotifierHostUnregistered(self):
        return None


# --------------------------------------------------------------------- icons
def icon_png(props: dict) -> bytes | None:
    """Best icon of an item as PNG bytes: largest convertible IconPixmap,
    else a file IconName.  Pixmaps whose ARGB payload is malformed are
    skipped in favour of the next-smaller one."""
    candidates = []
    for entry in props.get("IconPixmap") or []:
        try:
            w, h, data = entry
        except (TypeError, ValueError):
            continue  # malformed pixmap entry from a misbehaving app
        if not (isinstance(w, int) and isinstance(h, int) and data and w > 0 and h > 0):
            continue
        candidates.append((w, h, data))
    for w, h, data in sorted(candidates, key=lambda e: e[0] * e[1], reverse=True):
        img = None
        try:
            img = Image.frombytes("RGBA", (w, h), bytes(data), "raw", "ARGB", 0, 0)
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            return buf.getvalue()
        except Exception:
            log.warning("skipping malformed pixmap %sx%s", w, h)
        finally:
            if img is not None:
                img.close()
    name = props.get("IconName") or ""
    if name.startswith("/") and os.path.isfile(name):
        try:
            with open(name, "rb") as f:
                return f.read()
        except OSError:
            pass
    return None


# --------------------------------------------------------------------- menu
def parse_layout_node(node: tuple | list) -> dict | None:
    """Convert a com.canonical.dbusmenu GetLayout node into a plain dict.

    Returns None for a malformed node so a single broken node from a
    misbehaving app cannot poison the whole menu tree.
    """
    if not isinstance(node, (tuple, list)) or len(node) < 3:
        return None
    node_id, props, children = node
    p = unwrap_variants(props) if isinstance(props, dict) else {}
    out: dict = {
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
            if parsed := parse_layout_node(inner):
                out["children"].append(parsed)
    return out


def find_menu_node(nodes: list, label: str) -> dict | None:
    """Depth-first lookup of a menu node by label, descending into submenus.

    Iterative on an explicit stack (instead of recursion) so a deeply
    nested layout from a remote app cannot blow the interpreter stack.
    """
    stack = list(reversed(nodes or []))
    while stack:
        node = stack.pop()
        if node.get("label") == label:
            return node
        stack.extend(reversed(node.get("children") or []))
    return None


# ------------------------------------------------------------------- entry
def resolve_bus_address() -> str | None:
    addr = os.environ.get("DBUS_SESSION_BUS_ADDRESS")
    if addr:
        return addr
    for addr in (
        "unix:path=/mnt/wslg/runtime-dir/bus",
        f"unix:path=/run/user/{os.getuid()}/bus",
    ):
        if os.path.exists(addr.removeprefix("unix:path=")):
            return addr
    return None

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""WSLg tray bridge - Windows side.

Connects to sni_host.py inside WSLg over a localhost TCP socket and renders
each StatusNotifierItem as a real icon in the Windows notification area
(pystray). Clicks and menu selections are routed back to the Linux side.

Run on Windows (python.exe beside this file, from the nix build):
    python.exe main.py [--host 127.0.0.1] [--port 17632]
"""

from __future__ import annotations

import argparse
import base64
import ctypes
import io
import json
import queue
import socket
import threading
import time
import traceback
from ctypes import wintypes
from dataclasses import dataclass
from typing import Any

import pystray
from PIL import Image, ImageDraw

PROTOCOL_VERSION = 1
ICON_SIZE = 32

# pystray's Win32 backend treats a notification-area callback message
# (its registered uCallbackMessage, WM_USER+11) as "icon interaction"
# and dispatches it by lParam to the mouse event handlers; a real right
# click arrives as WM_RBUTTONUP there (pystray/_win32.py:_on_notify).
# These let us replay exactly what a right click does — TrackPopupMenuEx
# at the cursor — for sni-host's "show the menu" fallback.
PYSTRAY_WM_NOTIFY = 0x0400 + 11  # WM_USER + 11
WM_RBUTTONUP = 0x0205

# Every WSLg app window lives in the WSLg RDP client process (mstsc.exe,
# per WSLGd's design) and additionally carries a "WslgServerWindowId"
# window property that the WSLg client sets on each remote app window —
# the same marker Microsoft's WSLDVCPlugin uses to find WSLg windows
# (GetPropW(hwnd, L"WslgServerWindowId") in WSLDVCCallback.cpp).  Only
# windows passing that check (or owned by the host process) are ever
# raised, so a same-named native Windows app (e.g. a Windows Clash Verge)
# can never be brought up by mistake.  Update WSLG_HOST_EXES if a future
# WSLg renames its client.
WSLG_HOST_EXES = ("mstsc.exe", "msrdc.exe", "wslg.exe")


@dataclass
class IconRec:
    """Bookkeeping for one rendered tray icon."""

    icon: pystray.Icon
    img: Image.Image
    title: str
    status: str

    def stop(self) -> None:
        try:
            self.icon.stop()
        except Exception:
            pass


def _checked(value: Any) -> Any:
    """Late-binding-safe static checked callback for a menu node.

    pystray calls the callback with the MenuItem itself as its single
    argument (e.g. ``self._checked(self)`` on win32), so it must take it
    even though it is unused here.
    """
    return lambda _item: bool(value)


class TrayHost:
    """Windows side of the bridge: renders SNI items as pystray icons and
    routes clicks/menu selections back to sni-host."""

    def __init__(self, host: str, port: int, reconnect: bool = True):
        self.host = host
        self.port = port
        self.reconnect = reconnect
        self.icons: dict[str, IconRec] = {}
        # icons is mutated by the socket thread (on_*) and read by pystray
        # menu callback threads (_raise_after_click); single .get()/.pop()
        # calls are GIL-atomic, compound sequences take the lock
        self._icons_lock = threading.Lock()
        self.sock: socket.socket | None = None
        self._send_lock = threading.Lock()
        self._stop = threading.Event()
        self._buf = b""
        self.distro = ""
        # one worker for post-click window raising; a thread per click would
        # pile up when clicking through a menu quickly
        self._raise_queue: queue.Queue[tuple[str, bool]] = queue.Queue()
        self._raise_worker = threading.Thread(
            target=self._raise_loop, daemon=True, name="raise-window"
        )
        self._raise_worker.start()

    # ------------------------------------------------------------ lifecycle
    def run(self) -> None:
        print(
            f"[tray-host] targeting {self.host}:{self.port} (protocol {PROTOCOL_VERSION})",
            flush=True,
        )
        while not self._stop.is_set():
            try:
                self._connect()
                self._loop()
            except KeyboardInterrupt:
                self._stop.set()
            except Exception as exc:
                if not self.reconnect:
                    print(f"[tray-host] connection error: {exc}", flush=True)
                    break
                print(
                    f"[tray-host] connection lost ({exc}); retrying in 2s...",
                    flush=True,
                )
                time.sleep(2)
        self._stop_icons()
        print("[tray-host] bye", flush=True)

    def _connect(self) -> None:
        self.sock = socket.create_connection((self.host, self.port), timeout=5)
        self.sock.settimeout(None)
        print(f"[tray-host] connected to {self.host}:{self.port}", flush=True)
        self.send({"t": "hello_ack", "protocol": PROTOCOL_VERSION})

    def _loop(self) -> None:
        while not self._stop.is_set():
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("server closed the connection")
            self._buf += chunk
            while b"\n" in self._buf:
                line, _, self._buf = self._buf.partition(b"\n")
                if not line.strip():
                    continue
                try:
                    self.handle(json.loads(line.decode("utf-8")))
                except Exception:
                    traceback.print_exc()

    def send(self, msg: dict[str, Any]) -> None:
        if not self.sock:
            return
        data = (json.dumps(msg, ensure_ascii=False) + "\n").encode("utf-8")
        with self._send_lock:
            try:
                self.sock.sendall(data)
            except Exception as exc:
                print(f"[tray-host] send failed: {exc}", flush=True)

    # ------------------------------------------------------------ dispatch
    def handle(self, m: dict[str, Any]) -> None:
        fn = getattr(self, f"on_{m.get('t')}", None)
        if fn is None:
            return
        try:
            fn(m)
        except Exception:
            traceback.print_exc()

    def on_hello(self, m: dict[str, Any]) -> None:
        if m.get("protocol") != PROTOCOL_VERSION:
            print(
                f"[tray-host] protocol mismatch: server={m.get('protocol')}, we={PROTOCOL_VERSION}",
                flush=True,
            )
        self.distro = m.get("distro") or ""
        self._stop_icons()

    def on_bye(self, m: dict[str, Any]) -> None:
        print(f"[tray-host] server says bye ({m.get('reason')})", flush=True)
        self._stop.set()

    def _stop_icons(self) -> None:
        with self._icons_lock:
            recs = list(self.icons.values())
            self.icons.clear()
        for rec in recs:
            rec.stop()

    # ---------------------------------------------------------------- icons
    def on_add(self, m: dict[str, Any]) -> None:
        key = m.get("key")
        if not key:
            return
        with self._icons_lock:
            if key in self.icons:
                self.icons.pop(key).stop()
            img = self._image(m.get("icon"))
            title = m.get("tooltip") or m.get("title") or m.get("id") or key
            icon = pystray.Icon(
                key,
                self._overlay_attention(img, m.get("status") or ""),
                title=title,
                menu=self._menu(key, m.get("menu") or []),
            )
            self.icons[key] = IconRec(
                icon=icon,
                img=img,
                title=title,
                status=m.get("status") or "",
            )
        threading.Thread(target=icon.run, daemon=True, name=f"tray:{key[:24]}").start()
        print(f"[tray-host] + {key} ({title})", flush=True)

    def on_update(self, m: dict[str, Any]) -> None:
        rec = self.icons.get(m.get("key"))
        if not rec:
            return
        icon = rec.icon
        if "icon" in m:
            rec.img = self._image(m.get("icon"))
        if "status" in m:
            rec.status = m.get("status") or ""
        if "icon" in m or "status" in m:
            icon.icon = self._overlay_attention(rec.img, rec.status)
        if "tooltip" in m or "title" in m:
            rec.title = m.get("tooltip") or m.get("title") or m.get("id") or rec.title
            icon.title = rec.title
        if "menu" in m:
            icon.menu = self._menu(m["key"], m.get("menu") or [])

    def on_remove(self, m: dict[str, Any]) -> None:
        with self._icons_lock:
            rec = self.icons.pop(m.get("key"), None)
        if rec:
            rec.stop()
            print(f"[tray-host] - {m.get('key')}", flush=True)

    def on_menu(self, m: dict[str, Any]) -> None:
        rec = self.icons.get(m.get("key"))
        if rec:
            rec.icon.menu = self._menu(m["key"], m.get("menu") or [])

    def on_show_menu(self, m: dict[str, Any]) -> None:
        """Pop the icon's menu up programmatically (KDE-style fallback).

        sni-host asks for this when Activate raised no window (or the item
        is ItemIsMenu): show the menu at the cursor so the user picks the
        "open main window" item themselves, instead of an automatic
        menu-item click.  pystray has no public "show menu" call, so the
        same notification-area callback message a real right click produces
        (WM_USER+11, lParam=WM_RBUTTONUP) is posted to the icon's hidden
        window; the pystray Win32 backend then runs TrackPopupMenuEx
        exactly like a genuine right click.
        """
        rec = self.icons.get(m.get("key"))
        if not rec:
            return
        icon = rec.icon  # on Windows pystray.Icon is the Win32 backend itself
        if icon._hwnd:  # only exists once the icon's message loop is up
            ctypes.windll.user32.PostMessageW(
                icon._hwnd, PYSTRAY_WM_NOTIFY, 0, WM_RBUTTONUP
            )

    # ------------------------------------------------------------- menu/img
    def _menu(
        self, key: str, nodes: list[dict[str, Any]], with_default: bool = True
    ) -> pystray.Menu:
        items: list[Any] = []
        if with_default:
            items.append(
                pystray.MenuItem(
                    "", lambda *a, k=key: self._activate(k), visible=False, default=True
                )
            )
        for node in nodes or []:
            if node.get("visible", True) is False:
                continue
            if node.get("type") == "separator":
                items.append(pystray.Menu.SEPARATOR)
                continue
            if node.get("children"):
                items.append(
                    pystray.MenuItem(
                        node.get("label") or "(submenu)",
                        pystray.Menu(
                            *self._menu(key, node["children"], with_default=False)
                        ),
                        enabled=node.get("enabled", True),
                    )
                )
                continue
            checked_val = node.get("checked")
            items.append(
                pystray.MenuItem(
                    node.get("label") or "(item)",
                    lambda *a, k=key, n=node: self._click(k, n),
                    enabled=node.get("enabled", True),
                    checked=_checked(checked_val) if checked_val is not None else None,
                    radio=node.get("radio", False),
                )
            )
        return pystray.Menu(*items)

    def _click(self, key: str, node: dict[str, Any]) -> None:
        print(
            f"[tray-host] menu click: key={key} item={node.get('id')} label={node.get('label')!r}",
            flush=True,
        )
        self.send(
            {
                "t": "menu_click",
                "key": key,
                "item": node["id"],
                "label": node.get("label") or "",
            }
        )
        self._raise_queue.put((key, False))

    def _raise_loop(self) -> None:
        while not self._stop.is_set():
            try:
                key, nudge = self._raise_queue.get(timeout=0.5)
            except queue.Empty:
                continue
            try:
                self._raise_after_click(key, nudge=nudge)
            except Exception:
                traceback.print_exc()

    def _raise_after_click(self, key: str, nudge: bool = False) -> None:
        """After a click, raise the app's window on the Windows desktop.

        The app only raises its own window inside WSLg — nothing pushes the
        Win32 window above the rest of the desktop — so items that open a
        window (仪表板, 打开主界面, ...) depend on this.  Raise when the
        click showed a window, or when one was already up but buried under
        others.  Leave the window alone if the click didn't change it (an
        exit click tears it down; a checkmark just toggles).

        With `nudge` (left-click), the moment no window exists we already
        know the app is backgrounded — SNI Activate is commonly ignored
        (the tray-icon crate never wires it on Linux) — so the Linux side
        is asked to surface the app right away instead of after a dead
        wait, then the poll picks the window up when it appears.

        The poll is capped at 2s: a window surfaced via open_window appears
        within a second (windowmap --sync blocks until mapped), and the
        raise worker is serial — a click that never yields a window must
        not keep later clicks waiting behind it (a no-window click used to
        block the next one for the full 6s).

        NOTE: do NOT collapse this into a single "window exists" check; a
        window can exist yet sit buried (visible != on top), which made
        menu clicks look dead.  Reproduce: left-click the tray icon, switch
        away, then menu-click an item that shows the window.
        """
        rec = self.icons.get(key)
        if not rec:
            return
        titles = self._front_titles(rec.title)
        hwnd_before = self._find_window(titles)
        foreground = self._foreground_window()
        if hwnd_before is None and nudge:
            # Backgrounded app: no window will come from Activate, so
            # surface it through the Linux side immediately.
            self.send({"t": "open_window", "key": key})
            print("[tray-host] no WSLg window; nudging app to open", flush=True)
        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline:
            if key not in self.icons:
                return
            hwnd = self._find_window(titles)
            if hwnd is None:
                time.sleep(0.05)
                continue
            surfaced = hwnd != hwnd_before  # the click revealed a new window
            buried = hwnd != foreground  # visible but not on top
            if surfaced or buried:
                self._front_hwnd(hwnd)
                print(
                    f"[tray-host] raised window to front after click ({titles[0]})",
                    flush=True,
                )
            return

    def _foreground_window(self) -> int | None:
        hwnd = ctypes.windll.user32.GetForegroundWindow()
        return hwnd if hwnd else None

    def _activate(self, key: str) -> None:
        self.send({"t": "activate", "key": key})
        # The app shows its own window; the raise loop waits for the WSLg
        # window to appear (it may not exist yet when the app is
        # backgrounded) and brings it up — never a native window.
        self._raise_queue.put((key, True))

    def _image(self, b64: str | None) -> Image.Image:
        if b64:
            try:
                img = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGBA")
                return img.resize((ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS)
            except Exception:
                pass
        img = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
        ImageDraw.Draw(img).ellipse(
            (0, 0, ICON_SIZE - 1, ICON_SIZE - 1), fill=(130, 139, 150, 255)
        )
        return img

    def _overlay_attention(self, img: Image.Image, status: str) -> Image.Image:
        if status.lower() != "needsattention":
            return img
        img = img.copy()
        d = ImageDraw.Draw(img)
        r = max(6, img.width // 5)
        d.ellipse(
            (img.width - r, img.height - r, img.width - 1, img.height - 1),
            fill=(255, 60, 60, 255),
        )
        return img

    # -------------------------------------------------------- bring to front
    def _front_titles(self, title: str) -> list[str]:
        base = (title or "").strip()
        cands = [base, base.replace("-", " "), base.replace("_", " ")]
        if self.distro:
            cands = [f"{c} ({self.distro})" for c in cands] + cands
        return [c for c in dict.fromkeys(cands) if c]

    def _window_exe(self, hwnd: int) -> str | None:
        """Lowercased executable name of the process owning `hwnd`, or None."""
        user32 = ctypes.windll.user32
        pid = wintypes.DWORD()
        if not user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid)):
            return None
        kernel32 = ctypes.windll.kernel32
        # PROCESS_QUERY_LIMITED_INFORMATION is enough to read the image path.
        handle = kernel32.OpenProcess(0x1000, False, pid.value)
        if not handle:
            return None
        try:
            buf = ctypes.create_unicode_buffer(512)
            size = wintypes.DWORD(ctypes.sizeof(buf))
            if not kernel32.QueryFullProcessImageNameW(
                handle, 0, buf, ctypes.byref(size)
            ):
                return None
            return buf.value.rsplit("\\", 1)[-1].lower()
        finally:
            kernel32.CloseHandle(handle)

    def _is_wslg(self, hwnd: int) -> bool:
        """True when `hwnd` is a WSLg-hosted Linux app window.

        The WSLg RDP client marks every remote app window with a
        "WslgServerWindowId" window property — the same marker Microsoft's
        WSLDVCPlugin matches via GetPropW; as a second line of defense,
        accept windows owned by the WSLg host process.
        """
        user32 = ctypes.windll.user32
        user32.GetPropW.argtypes = (wintypes.HWND, wintypes.LPCWSTR)
        user32.GetPropW.restype = wintypes.HANDLE
        if user32.GetPropW(hwnd, "WslgServerWindowId"):
            return True
        return self._window_exe(hwnd) in WSLG_HOST_EXES

    def _find_window(self, titles: list[str]) -> int | None:
        """Visible WSLg top-level window matching `titles`, or None.

        Only WSLg windows are ever returned, so a same-named native
        Windows app can never be mistaken for the Linux one.
        """
        user32 = ctypes.windll.user32
        found: list[int] = []

        @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        def _cb(hwnd, _lparam):
            if not user32.IsWindowVisible(hwnd):
                return True
            length = user32.GetWindowTextLengthW(hwnd)
            if not length:
                return True
            buf = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buf, len(buf))
            if any(cand and cand.lower() in buf.value.lower() for cand in titles):
                found.append(hwnd)
            return True

        user32.EnumWindows(_cb, 0)
        return next((h for h in found if self._is_wslg(h)), None)

    def _front_hwnd(self, hwnd: int) -> None:
        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32
        if user32.IsIconic(hwnd):
            user32.ShowWindow(hwnd, 9)  # SW_RESTORE
        cur_tid = user32.GetWindowThreadProcessId(user32.GetForegroundWindow(), None)
        my_tid = kernel32.GetCurrentThreadId()
        if cur_tid != my_tid:
            user32.AttachThreadInput(my_tid, cur_tid, True)
        user32.BringWindowToTop(hwnd)
        user32.SetForegroundWindow(hwnd)
        if cur_tid != my_tid:
            user32.AttachThreadInput(my_tid, cur_tid, False)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="WSLg SNI -> Windows tray bridge (Windows side)"
    )
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=17632)
    ap.add_argument(
        "--no-reconnect",
        action="store_true",
        help="exit instead of retrying when the server is unreachable",
    )
    args = ap.parse_args()
    if not 1 <= args.port <= 65535:
        ap.error("--port must be between 1 and 65535")
    TrayHost(args.host, args.port, reconnect=not args.no_reconnect).run()


if __name__ == "__main__":
    main()

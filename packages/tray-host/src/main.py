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
import io
import json
import socket
import threading
import time
import traceback
from typing import Any

import pystray
from PIL import Image, ImageDraw

PROTOCOL_VERSION = 1
ICON_SIZE = 32


class TrayHost:
    def __init__(self, host: str, port: int, reconnect: bool = True):
        self.host = host
        self.port = port
        self.reconnect = reconnect
        self.icons: dict[str, dict[str, Any]] = {}
        self.sock: socket.socket | None = None
        self._send_lock = threading.Lock()
        self._stop = threading.Event()
        self._buf = b""
        self.distro = ""

    # ------------------------------------------------------------ lifecycle
    def run(self) -> None:
        print(f"[tray-host] targeting {self.host}:{self.port} (protocol {PROTOCOL_VERSION})")
        while not self._stop.is_set():
            try:
                self._connect()
                self._loop()
            except KeyboardInterrupt:
                self._stop.set()
            except Exception as exc:
                if not self.reconnect:
                    print(f"[tray-host] connection error: {exc}")
                    break
                print(f"[tray-host] connection lost ({exc}); retrying in 2s...")
                time.sleep(2)
        self._stop_icons()
        print("[tray-host] bye")

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
                line, self._buf = self._buf.split(b"\n", 1)
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
            except Exception:
                pass

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
            print(f"[tray-host] protocol mismatch: server={m.get('protocol')}, we={PROTOCOL_VERSION}")
        self.distro = m.get("distro") or ""
        self._stop_icons()

    def on_bye(self, m: dict[str, Any]) -> None:
        print(f"[tray-host] server says bye ({m.get('reason')})")
        self._stop.set()

    def _stop_icons(self) -> None:
        for rec in list(self.icons.values()):
            try:
                rec["icon"].stop()
            except Exception:
                pass
        self.icons.clear()

    # ---------------------------------------------------------------- icons
    def on_add(self, m: dict[str, Any]) -> None:
        key = m.get("key")
        if not key:
            return
        if key in self.icons:
            try:
                self.icons.pop(key)["icon"].stop()
            except Exception:
                pass
        img = self._image(m.get("icon"))
        title = m.get("tooltip") or m.get("title") or m.get("id") or key
        icon = pystray.Icon(
            key,
            self._overlay_attention(img, m.get("status") or ""),
            title=title,
            menu=self._menu(key, m.get("menu") or []),
        )
        self.icons[key] = {"icon": icon, "img": img, "title": title, "status": m.get("status") or ""}
        threading.Thread(target=icon.run, daemon=True, name=f"tray:{key[:24]}").start()
        print(f"[tray-host] + {key} ({title})", flush=True)

    def on_update(self, m: dict[str, Any]) -> None:
        rec = self.icons.get(m.get("key"))
        if not rec:
            return
        icon = rec["icon"]
        if "icon" in m:
            rec["img"] = self._image(m.get("icon"))
        if "status" in m:
            rec["status"] = m.get("status") or ""
        if "icon" in m or "status" in m:
            icon.icon = self._overlay_attention(rec["img"], rec["status"])
        if "tooltip" in m or "title" in m:
            rec["title"] = m.get("tooltip") or m.get("title") or m.get("id") or rec["title"]
            icon.title = rec["title"]
        if "menu" in m:
            icon.menu = self._menu(m["key"], m.get("menu") or [])

    def on_remove(self, m: dict[str, Any]) -> None:
        rec = self.icons.pop(m.get("key"), None)
        if rec:
            try:
                rec["icon"].stop()
            except Exception:
                pass
            print(f"[tray-host] - {m.get('key')}", flush=True)

    def on_menu(self, m: dict[str, Any]) -> None:
        rec = self.icons.get(m.get("key"))
        if rec:
            rec["icon"].menu = self._menu(m["key"], m.get("menu") or [])

    # ------------------------------------------------------------- menu/img
    def _menu(self, key: str, nodes: list[dict[str, Any]], with_default: bool = True) -> pystray.Menu:
        items: list[Any] = []
        if with_default:
            items.append(
                pystray.MenuItem("", lambda *a, k=key: self._activate(k), visible=False, default=True)
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
                        pystray.Menu(*self._menu(key, node["children"], with_default=False)),
                        enabled=node.get("enabled", True),
                    )
                )
                continue
            checked = node.get("checked")
            if checked is not None:
                checked = lambda *_a, _v=bool(checked): _v
            items.append(
                pystray.MenuItem(
                    node.get("label") or "(item)",
                    lambda *a, k=key, n=node: self._click(k, n),
                    enabled=node.get("enabled", True),
                    checked=checked,
                    radio=node.get("radio", False),
                )
            )
        return pystray.Menu(*items)

    def _click(self, key: str, node: dict[str, Any]) -> None:
        print(
            f"[tray-host] menu click: key={key} item={node.get('id')} label={node.get('label')!r}",
            flush=True,
        )
        self.send({"t": "menu_click", "key": key, "item": node["id"], "label": node.get("label") or ""})
        self._bring_front(key)

    def _activate(self, key: str) -> None:
        self.send({"t": "activate", "key": key})
        self._bring_front(key)

    def _bring_front(self, key: str) -> None:
        rec = self.icons.get(key)
        if rec:
            self.bring_to_front(self._front_titles(rec["title"]))

    def _image(self, b64: str | None) -> Image.Image:
        if b64:
            try:
                img = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGBA")
                return img.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
            except Exception:
                pass
        img = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
        ImageDraw.Draw(img).ellipse((0, 0, ICON_SIZE - 1, ICON_SIZE - 1), fill=(130, 139, 150, 255))
        return img

    def _overlay_attention(self, img: Image.Image, status: str) -> Image.Image:
        if status.lower() != "needsattention":
            return img
        img = img.copy()
        d = ImageDraw.Draw(img)
        r = max(6, img.width // 5)
        d.ellipse((img.width - r, img.height - r, img.width - 1, img.height - 1), fill=(255, 60, 60, 255))
        return img

    # -------------------------------------------------------- bring to front
    def _front_titles(self, title: str) -> list[str]:
        base = (title or "").strip()
        cands = [base, base.replace("-", " "), base.replace("_", " ")]
        if self.distro:
            cands += [f"{c} ({self.distro})" for c in list(cands)]
        return [c for c in dict.fromkeys(cands) if c]

    def bring_to_front(self, titles: list[str]) -> None:
        if not titles:
            return
        try:
            if self._front_native(titles):
                print(f"[tray-host] brought window to front ({titles[0]})", flush=True)
                return
        except Exception:
            traceback.print_exc()
        try:
            self._front_powershell(titles)
        except Exception:
            traceback.print_exc()

    def _front_native(self, titles: list[str]) -> bool:
        import ctypes
        from ctypes import wintypes

        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32
        found: list[int] = []

        @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        def _cb(hwnd, _lparam):
            if not user32.IsWindowVisible(hwnd) or not user32.GetWindowTextLengthW(hwnd):
                return True
            buf = ctypes.create_unicode_buffer(user32.GetWindowTextLengthW(hwnd) + 1)
            user32.GetWindowTextW(hwnd, buf, len(buf))
            if any(cand and cand.lower() in buf.value.lower() for cand in titles):
                found.append(hwnd)
            return True

        user32.EnumWindows(_cb, 0)
        if not found:
            return False
        hwnd = found[0]
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
        return True

    def _front_powershell(self, titles: list[str]) -> None:
        import subprocess

        for title in titles:
            r = subprocess.run(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-Command",
                    "Add-Type -AssemblyName Microsoft.VisualBasic;"
                    f"[Microsoft.VisualBasic.Interaction]::AppActivate('{title.replace(chr(39), '')}')",
                ],
                capture_output=True,
                timeout=10,
            )
            if r.returncode == 0:
                return


def main() -> None:
    ap = argparse.ArgumentParser(description="WSLg SNI -> Windows tray bridge (Windows side)")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=17632)
    ap.add_argument("--no-reconnect", action="store_true", help="exit instead of retrying when the server is unreachable")
    args = ap.parse_args()
    TrayHost(args.host, args.port, reconnect=not args.no_reconnect).run()


if __name__ == "__main__":
    main()

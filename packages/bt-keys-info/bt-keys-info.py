#!/usr/bin/env python3
"""bt-keys-info.py - 从 Windows SYSTEM 配置单元读取蓝牙配对密钥，输出 BlueZ info 格式。"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from Registry.Registry import (
    RegBin,
    RegDWord,
    Registry,
    RegistryKey,
    RegistryKeyNotFoundException,
    RegistryValueNotFoundException,
)

# ── 数据结构 ────────────────────────────────────────────────────────────────


@dataclass
class BondKey:
    adapter_mac: str
    device_mac: str
    ltk_hex: str | None = None
    ediv: int | None = None
    erand: int | None = None
    auth_req: int | None = None
    key_length: int | None = None
    irk_hex: str | None = None
    link_key_hex: str | None = None
    link_key_type: int = 4


class RegError(Exception):
    """携带已读取内容的解析错误。"""

    def __init__(self, context: str, msg: str):
        super().__init__(msg)
        self.context = context
        self.msg = msg


# ── 工具函数 ────────────────────────────────────────────────────────────────

_MAC_RE = re.compile(r"[0-9a-fA-F]{12}")


def _fmt_mac(raw: str) -> str:
    """'aabbccddeeff' -> 'AA:BB:CC:DD:EE:FF'"""
    return ":".join(raw[i : i + 2].upper() for i in range(0, 12, 2))


def _dump_key(key: RegistryKey) -> str:
    """当前读取到的内容。"""
    lines = [key.path()]
    for v in key.values():
        lines.append(f'"{v.name()}"=hex:{v.raw_data().hex()}')
    return "\n".join(lines)


def _subkey(key: RegistryKey, *parts: str) -> RegistryKey:
    for part in parts:
        try:
            key = key.subkey(part)
        except RegistryKeyNotFoundException:
            raise RegError(_dump_key(key), f"缺少子键 {part}") from None
    return key


def _get(key: RegistryKey, name: str, required: bool = True):
    try:
        return key.value(name)
    except RegistryValueNotFoundException:
        if required:
            raise RegError(_dump_key(key), f"缺少 {name}")
        return None


def _hex_value(key: RegistryKey, name: str, required: bool = True) -> str | None:
    """REG_BINARY 值 -> 大写 hex 字符串。"""
    v = _get(key, name, required)
    if v is None:
        return None
    if v.value_type() != RegBin:
        raise RegError(_dump_key(key), f"{name} 不是 REG_BINARY")
    return v.value().hex().upper()


def _dword(key: RegistryKey, name: str) -> int:
    v = _get(key, name)
    if v.value_type() != RegDWord:
        raise RegError(_dump_key(key), f"{name} 不是 REG_DWORD")
    return v.value()


def _erand(key: RegistryKey) -> int:
    """ERand 为 REG_QWORD，库已按小端解析为 int。"""
    return _get(key, "ERand").value()


# ── 注册表解析 ──────────────────────────────────────────────────────────────


def detect_control_set(reg: Registry) -> str:
    """读取 SYSTEM\\Select\\Current 检测活跃控制集。"""
    current = _dword(_subkey(reg.root(), "Select"), "Current")
    return f"ControlSet{current:03d}"


def parse_keys(
    keys: RegistryKey,
    values_as_le: bool = False,
    link_key_type: int = 4,
) -> list[BondKey]:
    """解析 BTHPORT\\Parameters\\Keys，按 (适配器, 设备) 聚合 LE 与经典键。

    values_as_le: 适配器下以 MAC 命名的 REG_BINARY 值既有经典链接密钥，也有
    旧版(蓝牙 4.x)LE 设备以值形式存储的 LTK，注册表数据无法区分两者。
    默认按经典密钥处理；若确认设备为旧版 LE，传 True 将其按 LTK 输出。
    """
    bonds: dict[tuple[str, str], BondKey] = {}

    for adapter in keys.subkeys():
        if not _MAC_RE.fullmatch(adapter.name()):
            continue
        adapter_mac = _fmt_mac(adapter.name())

        # LE 设备：适配器下的子键
        for dev in adapter.subkeys():
            if not _MAC_RE.fullmatch(dev.name()):
                continue
            bonds[(adapter.name().upper(), dev.name().upper())] = BondKey(
                adapter_mac=adapter_mac,
                device_mac=_fmt_mac(dev.name()),
                ltk_hex=_hex_value(dev, "LTK"),
                ediv=_dword(dev, "EDIV"),
                erand=_erand(dev),
                auth_req=_dword(dev, "AuthReq"),
                key_length=_dword(dev, "KeyLength"),
                irk_hex=_hex_value(dev, "IRK", required=False),
            )

        # 经典蓝牙（或旧版 LE）：适配器键下以设备 MAC 命名的 REG_BINARY 值
        for v in adapter.values():
            if v.value_type() != RegBin or not _MAC_RE.fullmatch(v.name()):
                continue
            key = (adapter.name().upper(), v.name().upper())
            bond = bonds.setdefault(
                key, BondKey(adapter_mac=adapter_mac, device_mac=_fmt_mac(v.name()))
            )
            if values_as_le:
                bond.ltk_hex = bond.ltk_hex or v.value().hex().upper()
            else:
                bond.link_key_hex = v.value().hex().upper()
                bond.link_key_type = link_key_type

    return list(bonds.values())


# ── 输出格式化 ──────────────────────────────────────────────────────────────


def format_bond(bond: BondKey) -> str:
    path = f"/var/lib/bluetooth/{bond.adapter_mac}/{bond.device_mac}"
    lines = [
        f"=== 控制器: {bond.adapter_mac} ===",
        f"=== 设备: {bond.device_mac} ===",
        f"\n粘贴到 {path}/info:\n",
    ]

    if bond.ltk_hex:
        lines += [
            "[LongTermKey]",
            f"Key={bond.ltk_hex}",
            f"Authenticated={1 if bond.auth_req & 2 else 0}",
            f"EncSize={bond.key_length}",
            f"EDiv={bond.ediv}",
            f"Rand={bond.erand}",
        ]
        if bond.irk_hex:
            lines += ["", "[IdentityResolvingKey]", f"Key={bond.irk_hex}"]

    if bond.link_key_hex:
        lines += [
            "",
            "# 注：经典链接密钥与旧版(蓝牙 4.x)LE 设备的 LTK 均以 MAC 命名的值存储，",
            "# 无法自动区分；若该设备实为 LE 设备，请用 --treat-values-as-le 重新生成",
            "[General]",
            "Trusted=true",
            "",
            "[LinkKey]",
            f"Key={bond.link_key_hex}",
            f"Type={bond.link_key_type}",
        ]

    return "\n".join(lines)


# ── 入口 ────────────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(
        description="从 Windows SYSTEM 配置单元读取蓝牙配对密钥",
        epilog="路径参考：/mnt/c/Windows/System32/config/system",
    )
    parser.add_argument("hive", help="SYSTEM 配置单元路径")
    parser.add_argument(
        "--linkkey-type",
        type=int,
        default=4,
        help="经典密钥的 BlueZ 链接密钥类型，默认 4（Secure Connections 配对的设备为 5/6）",
    )
    parser.add_argument(
        "--treat-values-as-le",
        action="store_true",
        help="将适配器下以 MAC 命名的值当作旧版(蓝牙 4.x)LE 设备的 LTK 输出",
    )
    args = parser.parse_args()

    hive = Path(args.hive)
    if not hive.is_file():
        sys.exit(f"error: 找不到配置单元: {hive}")

    try:
        reg = Registry(str(hive))
        keys = _subkey(
            reg.root(),
            detect_control_set(reg),
            "Services",
            "BTHPORT",
            "Parameters",
            "Keys",
        )
        bonds = parse_keys(
            keys,
            values_as_le=args.treat_values_as_le,
            link_key_type=args.linkkey_type,
        )
    except RegError as e:
        print(f"error: {e.msg}\n\n--- 读取到的内容 ---\n{e.context}")
        sys.exit(1)
    except Exception as e:
        sys.exit(f"error: {e}")

    if not bonds:
        sys.exit("未找到蓝牙配对密钥。")

    print("\n\n".join(format_bond(b) for b in bonds))


if __name__ == "__main__":
    main()

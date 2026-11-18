# 3ds Max 插件脚本乱码排查与修复（GBK → UTF-8 BOM / .mse 解密重加密）

> 日期：2026-11-18
> 对象：`D:\Software\3Dmax插件神器\安装文件\`（挂载点 `/mnt/Data/Software/3Dmax插件神器/安装文件/`）
> 场景：3ds Max 2026 跑在 Linux 的补丁版 Wine 11.0 上（`WINEPREFIX=~/.wine-3dsmax`），
> `chajian.ms` 插件里所有工具窗口的中文文字显示乱码；同一套文件在真实中文 Windows 下正常。

---

## 1. 问题现象

- 入口：`/mnt/Data/ShareFiles/素材库/脚本/chajian.ms`
- 它 `filein` 两个文件：
  - `D:\Software\3Dmax插件神器\安装文件\安装.mse`（编译加密的主安装器）
  - `D:\ShareFiles\素材库\脚本\计算尺寸.ms`
- 点开工具（如 `014-工具` 下的工具）后，窗口里所有中文（按钮、tooltip、rollout 标题、messageBox）都是乱码。
- 但 `/mnt/Data/ShareFiles/素材库/脚本/` 目录下的 `.ms` 文件显示正常。

## 2. 根因

| 文件类型 | 编码 | 说明 |
|---|---|---|
| 插件工具 `.ms`（`001-建模1`~`014-工具`，124 个） | **GBK/GB2312（ANSI 中文）** | 中文 Windows 的原生编码 |
| 插件 `.mse`（87 个） | 编译产物，源码为 GBK | 字符串编码已固化在加密时 |
| ShareFiles 的 `.ms`（7 个） | UTF-8 无 BOM | 所以显示正常 |

**为什么 Windows 正常、Wine 乱码？**

1. 3ds Max 的 MAXScript 读取 `.ms` 时，**只有带 UTF-8 BOM 的文件会被按 UTF-8 正确解读**；无 BOM 文件按 UTF-8 读（Autodesk 官方文档：只有 UTF-8 BOM 被正确解读）。
2. 插件工具 `.ms` 是 GBK，无 BOM → MAXScript 把 GBK 字节当 UTF-8 解读 → 乱码。
3. 实测证明 **Wine 的 ANSI 代码页已经是 936（GBK）**（注册表 `HKLM\System\CurrentControlSet\Control\Nls\CodePage\ACP=936` 被 Wine 采纳），所以**代码页不是原因**，改代码页（`LANG=zh_CN.GBK` 之类）也救不了——问题在文件编码本身。
4. 因此无论 Windows 还是 Wine，只要 `.ms` 是 GBK 就会乱；ShareFiles 那份恰好是 UTF-8 所以正常。

> 注：`env.sh`（`packages/wine-3dsmax`）不设 `LANG`，Wine 继承桌面 `LANG=zh_CN.UTF-8`；
> 但即使把 locale 改成 GBK，GetACP 依然是 936（Wine 读注册表），对文件编码问题无影响。

**`.mse` 呢？** `.mse` 是 MAXScript `encryptScript` 的产物，源码字符串以源码编码（GBK）固化了进去。
加载时同样会被按 UTF-8 解读 → 也乱码。所以需要「解密 → 源码转 UTF-8 BOM → 重新加密」。

## 3. 排查结论（要点）

- 用微型 Windows 程序打印 `GetACP()`：`LANG=zh_CN.UTF-8` 与 `zh_CN.GBK` 下都是 **936**，`LANG=C` 才是 1252。
  → 证明代码页不是根因，排除"让 Wine 用 GBK"这条路线。
- 插件 `.ms` 全部是 GBK：UTF-8 严格解码失败、GBK/GB18030 解码成功（`file` 会误标成 `ISO-8859 text`）。
- `.mse` 解密算法来自 QuickBMS `Mse_Decrypter.txt`（支持版本 0/1），两个易错点：
  - **`math KEY n= KEY` 是取负（`KEY = -KEY`）**，不是按位取反 `~`。这点搞错会解出乱码。
  - **`math TMP z= 4` 是高低半字节交换**（`0xab → 0xba`），不是位旋转或其它。

## 4. 工具

### 4.1 `ms-encoding.py` — 导入前检测编码

```bash
python3 ms-encoding.py <文件或目录> [更多...]
# 目录递归扫 *.ms / *.mse
```

输出编码：`UTF-8 (BOM)` / `UTF-8 (无 BOM)` / `ASCII` / `GBK/GB2312` / `GB18030` / `加密脚本 (.mse)` / `未知`。

判定表（导入前怎么处理）：

| 检测结果 | 处理 |
|---|---|
| `UTF-8 (BOM)` | ✅ 直接导入，任何系统正常 |
| `UTF-8 (无 BOM)` | ✅ 可导入；保险起见加 BOM |
| `ASCII` | ✅ 直接导入 |
| `GBK/GB2312`、`GB18030` | ⚠️ 必须转 UTF-8 BOM，否则乱码 |
| `加密脚本 (.mse)` | ⚠️ 编码已固化，需解密→转 UTF-8 BOM→重加密 |
| `未知/混合` | ⚠️ 用编辑器另存为 UTF-8 BOM |

### 4.2 `mse2ms.py` — 解密 / 重加密 `.mse`

```bash
# 解密单个 .mse → .ms
python3 mse2ms.py "xxx.mse" [输出.ms]
# 批量解密目录下所有 .mse（输出同名 .ms）
python3 mse2ms.py -d <目录>
```

`mse2ms.py` 内含 `decrypt()` 与 `encrypt_mse()`，`encrypt_mse` 是 `decrypt` 的精确逆：
`decrypt(encrypt_mse(src)) == src`（87/87 往返验证通过）。

支持加密版本：版本 0（首字节非 `0x43`，MODE=1）与版本 1（首字节 `0x43`，MODE=3）。
本插件全部 `.mse` 为版本 1 / MODE 3（首字节 `43 03 00 00 00 ...`）。

## 5. 已执行操作（2026-11-18）

1. **备份**全部 218 个文件（131 `.ms` + 87 `.mse`）→ `/tmp/opencode/restore/`（用户另有备份）。
2. **124 个 GBK `.ms` → UTF-8 带 BOM**（GB18030 解码兜底，含 2 个含非严格 GBK 字节的文件）。
3. **87 个 `.mse`：解密 → 源码 GBK→UTF-8 BOM → `encrypt_mse` 重新加密 → 写回**。
4. 7 个纯 ASCII `.ms`、2 个纯 ASCII `.mse`（`005-清空材质球`、`003-2个视窗`）无中文，未动。

**验证：**
- 124 个 `.ms` 均带 `EF BB BF` 且 UTF-8 可解码、无替换符。
- 87 个 `.mse` 解密后均为合法 UTF-8 源码（85 个带 BOM，2 个纯 ASCII 无需 BOM）。
- 往返 `decrypt(encrypt(x))==x`：87/87。

**结果：** 3ds Max 下打开 `chajian.ms` 各工具，中文显示正常。

## 6. 备份与回滚

- 本次修改前的完整备份：`/tmp/opencode/restore/`（按 `安装文件/` 相对结构保存，共 218 个文件）。
- 回滚：把 `restore/` 下对应文件拷回原路径即可。
- 注意：原插件目录下还有 `.git`（无提交的临时仓库），不要依赖它回滚。

## 7. 其它发现

- Wine 的 `GetACP` 实测：`zh_CN.UTF-8`/`zh_CN.GBK` → 936，`C` → 1252。想确认可编译微型程序打印。
- `packages/wine-3dsmax/default.nix` 的 `env.sh` 不设 `LANG`，无需为此改动。
- 后续若遇到新加入的 GBK 脚本：先 `ms-encoding.py` 检测，是 GBK 就转 UTF-8 BOM（见附录转换命令）。

---

## 附录 A：工具源码

### A.1 `ms-encoding.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ms-encoding.py — 在导入 .ms 前检测文件编码
用法:
    python3 ms-encoding.py <文件或目录> [更多文件/目录...]
"""
import os, sys

def detect(data: bytes):
    if data[:3] == b"\xef\xbb\xbf":
        return "UTF-8 (BOM)", "MAXScript 最可靠：任何系统都按 UTF-8 正确解读"
    if data[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return "UTF-16", "建议转 UTF-8 BOM"
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        pass
    else:
        if all(b < 128 for b in data):
            return "ASCII (纯英文)", "无中文，无编码问题"
        return "UTF-8 (无 BOM)", "建议加 BOM 保持一致"
    for enc, name in (("gbk", "GBK/GB2312 (ANSI 中文)"), ("gb18030", "GB18030")):
        try:
            data.decode(enc)
        except UnicodeDecodeError:
            continue
        return name, "MAXScript 会按 UTF-8 误读 → 乱码。导入前请转成 UTF-8 BOM。"
    return "未知/混合编码", "可能含二进制数据或损坏"

def scan(path):
    if os.path.isdir(path):
        out = []
        for root, _d, names in os.walk(path):
            for n in sorted(names):
                if n.lower().endswith((".ms", ".mse")):
                    out.append(os.path.join(root, n))
        return out
    return [path] if os.path.isfile(path) else []

def main(argv):
    for p in argv:
        files = scan(p)
        if not files:
            print(f"!! 未找到: {p}"); continue
        print(f"=== {p} ===")
        for f in files:
            try:
                raw = open(f, "rb").read()
            except OSError as e:
                print(f"  !! {f}: {e}"); continue
            if f.lower().endswith(".mse"):
                print(f"  {os.path.basename(f):<38} -> 加密脚本 (.mse)")
                print("      编码已固化；需解密→转 UTF-8 BOM→重加密")
                continue
            enc, note = detect(raw)
            print(f"  {os.path.basename(f):<38} -> {enc}")
            print(f"      {note}")
        print()
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

### A.2 `mse2ms.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mse2ms.py — 解密/重加密 3ds Max 加密脚本 (.mse)
算法来源: QuickBMS "3ds Max mse scripts decrypter" (版本 0/1)
用法:
    python3 mse2ms.py <文件.mse> [输出.ms]      # 解密
    python3 mse2ms.py -d <目录>                 # 批量解密
"""
import os, struct, sys

MASK32 = 0xFFFFFFFF

def _rand3(key):
    """MODE 3 RAND: KEY *= 0x4fac51fb; KEY = -KEY; KEY += 0x269ec3; RET=(KEY>>16)&0x7fff"""
    key = (key * 0x4fac51fb) & MASK32
    key = (-key) & MASK32          # BMS `math KEY n= KEY` = 取负（不是按位取反）
    key = (key + 0x269ec3) & MASK32
    return key, (key >> 16) & 0x7FFF

def decrypt(data: bytes) -> bytes:
    """解密 .mse → 源码字节。版本 0 与版本 1 (MODE 0/1/2/3/4)。"""
    if not data:
        return b""
    if data[0] != 0x43:            # 版本 0
        key = 0xECD6D157
        out = bytearray()
        for b in data:
            key = (key * 0x343fd) & MASK32
            key = (key + 0x269ec3) & MASK32
            ret = (key >> 16) & 0x7FFF
            p = (b ^ ret) & 0xFF
            if p == 0xFF:
                break
            out.append(p)
        return bytes(out)
    # 版本 1
    mode, key, tmp = struct.unpack_from("<III", data, 1)
    key = (key + tmp) & MASK32
    key ^= tmp
    pos = 1 + 12
    def rand(m):
        nonlocal key
        if m == 3:
            key, ret = _rand3(key); return key, ret
        key = (key * 0x343fd) & MASK32
        key = (key + 0x269ec3) & MASK32
        return key, (key >> 16) & 0x7FFF
    _k, ret = rand(mode)
    skip = ret & 0x7F
    for _ in range(skip):
        pos += 1; _k, _r = rand(mode)
    off = pos
    out = bytearray()
    for i in range(off, len(data)):
        _k, ret = rand(mode)
        t = data[i]
        if mode == 3:
            if key & 1:
                t = ((t << 4) | (t >> 4)) & 0xFF   # z= 4: 高低半字节交换
            t ^= ret; t &= 0xFF
            if t == 0xFF:
                break
            out.append(t)
            if t & 0x80:
                t |= -0x100
            key = (key + t) & MASK32
        elif mode in (0, 2):
            return data[off:]
        else:
            t ^= ret; t &= 0xFF
            if t == 0xFF:
                break
            out.append(t)
    return bytes(out)

def encrypt_mse(source: bytes, mode: int = 3, key_field: int = None, tmp: int = None) -> bytes:
    """加密源码 → .mse（版本1/MODE3），decrypt 的精确逆。decrypt(encrypt_mse(src))==src。"""
    if key_field is None:
        key_field = int.from_bytes(os.urandom(4), "little")
    if tmp is None:
        tmp = int.from_bytes(os.urandom(4), "little")
    K0 = ((key_field + tmp) & MASK32) ^ tmp
    key, ret = _rand3(K0)
    skip = ret & 0x7F
    skip_bytes = bytes(int.from_bytes(os.urandom(1), "little") for _ in range(skip))
    for _ in range(skip):
        key, _r = _rand3(key)
    out = bytearray()
    for p in source:
        key, ret = _rand3(key)
        c = (p ^ ret) & 0xFF
        if key & 1:
            c = ((c << 4) | (c >> 4)) & 0xFF
        out.append(c)
        sp = p | (-0x100) if p & 0x80 else p
        key = (key + sp) & MASK32
    key, ret = _rand3(key)
    c = (0xFF ^ ret) & 0xFF
    if key & 1:
        c = ((c << 4) | (c >> 4)) & 0xFF
    out.append(c)
    return b"\x43" + struct.pack("<III", mode, key_field, tmp) + skip_bytes + bytes(out)

def decrypt_file(src, dst):
    raw = open(src, "rb").read()
    out = decrypt(raw)
    open(dst, "wb").write(out)
    return out

def main(argv):
    if argv and argv[0] == "-d":
        root = argv[1]; n = 0
        for base, _d, names in os.walk(root):
            for nm in sorted(names):
                if nm.lower().endswith(".mse"):
                    s = os.path.join(base, nm)
                    d = os.path.join(base, nm[:-4] + ".ms")
                    decrypt_file(s, d); n += 1
                    print(f"  {s} -> {d}")
        print(f"完成: 解密 {n} 个 .mse"); return 0
    if not argv:
        print(__doc__); return 1
    src = argv[0]
    dst = argv[1] if len(argv) > 1 else os.path.splitext(src)[0] + ".ms"
    out = decrypt_file(src, dst)
    print(f"已解密: {src} -> {dst} ({len(out)} 字节)")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

## 附录 B：GBK → UTF-8 BOM 转换命令

```bash
# 单文件（转前务必备份）
python3 -c "import sys;d=open(sys.argv[1],'rb').read().decode('gb18030');open(sys.argv[1],'wb').write(b'\xef\xbb\xbf'+d.encode('utf-8'))" 文件名.ms
```

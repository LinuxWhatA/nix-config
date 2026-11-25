# .max 内嵌缩略图提取（技术要点）

## 格式

`.max` 是 OLE2 复合文档；缩略图内嵌在 `\x05SummaryInformation` 属性集的 `PIDSI_THUMBNAIL`
（属性 id=`0x11`）里。属性值不是裸 DIB，而是一段 `VT_CF`（`0x47`）剪贴板数据，按 `CLIPDATA`
布局：

| 偏移 | 类型 | 内容 |
| --- | --- | --- |
| `0x00` | WORD × 2 | `vt=0x47`（`VT_CF`）+ 2 字节 padding |
| `0x04` | DWORD | `cbSize` = WMF 字节数 + 16 |
| `0x08` | DWORD | `ulClipFmt = 0xFFFFFFFF`（-1，自定义格式） |
| `0x0C` | DWORD | `cfFormat = 3` |
| `0x10` | WORD × 4 | `1, width, height, 0`（Max 的 8 字节宽高头） |
| `0x18` | WMF | 长度 = `cbSize - 16` |

WMF 是标准 metafile：18 字节 header（`type=1`、`headerSize=9` words、`version=0x300`），
随后是一条 `META_STRETCHDIB`（function=`0x0F43`）记录，最后是 `META_EOF`（function=0）
记录。`META_STRETCHDIB` 的参数区为 `ROP(4) + usage(2) + 源/目标宽高与坐标(16)`，之后是标准
`BITMAPINFOHEADER` + DIB 像素。

- `biSize≥40`、`biPlanes=1`、`biCompression=0`（`BI_RGB`）、`biBitCount∈{24,32}`；
- 24 位是 BGR、32 位是 BGRX；正 `biHeight` 自下而上，负值自上而下；
- 行按 4 字节对齐（24bpp 且 width 不是 4 的倍数时有 padding）；
- 因为 WMF 从属性值 `0x18` 开始，`BITMAPINFOHEADER` 恰好落在属性值 `+0x46`；这是布局推导
  结果，不应把 `0x46` 当格式常量。

宽度 512 是 Max 的默认缩略图尺寸（`MaxThumbnailSaver.dll` 里 `GetThumbnailSize` 的全局默认
`0x200`，`SetThumbnailSize` 可改），不是格式不变量；提取按 DIB 实际宽高和行跨度解码。

## 与官方 DLL 交叉验证

- **写侧 `MaxThumbnailSaver.dll`**：`CreateMetaFileW` → `StretchDIBits`（ROP=`0x00CC0020`，
  SRCCOPY）→ `GetMetaFileBitsEx`；构造 `PROPVARIANT{vt=VT_CF, pclipdata=CLIPDATA{cbSize=wmf+16,
  ulClipFmt=-1, pClipData={cfFormat=3, {1,w,h,0}, WMF}}}`，`PROPSPEC{propid=0x11}` 交给
  `PropertyManager::AddSummaryInformationEntry`。Saver 内不含 SummaryInformation FMTID；其
  ASCII `SummaryInformation` 的唯一命中是导入符号 `AddSummaryInformationEntry` 的子串，不是
  独立的属性集名。
- **读侧 `MaxThumbnailProvider.dll`**（导出 `?LoadThumbnail@Thumbnails@MaxSDK@@...` 与
  `DLLLoadMaxThumbnail`）：`IPropertySetStorage::Open` 使用内嵌的 SummaryInformation FMTID
  常量（RVA `0x3280`）→ `ReadMultiple(propid=0x11)` → 校验 `vt==0x47`、`ulClipFmt==-1`、
  `cfFormat==3`，从 `pClipData+6/+8` 读宽高 → `SetMetaFileBitsEx(cbSize-16, pClipData+12)`
  → `PlayMetaFile` 到 32bpp DIBSection。读侧直接解析 CLIPDATA，DIB 由 GDI 播放 WMF 得到。
- **`MaxThumbnailShellExt.dll`**：COM 壳（导出 `DllRegisterServer`/`DllGetClassObject` 等），
  导入 `ole32!StringFromGUID2`、`SHELL32!SHChangeNotify`、AdvApi32 等，不含 SummaryInformation
  FMTID。它的宽字符串是 `gMaxThumbnailProvider.dll` 与 `DLLLoadMaxThumbnail`（后者与 Provider
  的导出对应）；安装目录里只有 `MaxThumbnailProvider.dll`、没有 `gMaxThumbnailProvider.dll`，
  所以 ShellExt 只能证明它是动态加载 provider 的 COM 壳，read 路径以 Provider 自身符号为准。

结论：写/读两端对同一套 `\x05SummaryInformation` + propid `0x11` + `VT_CF` + `cfFormat=3`
相互对应；Provider 的 FMTID 是常量（不是运行时传入），可直接按 16 字节搜到。

## 提取算法

1. `olefile` 打开 `.max`，读 `\x05SummaryInformation` 流。
2. 段 0 偏移取自流内 `0x2c`；属性表从段头（8 字节）之后开始，每项 8 字节（属性 id + 值偏移）。
3. 找 id=`0x11` 得值偏移——**相对段起点，不是流起点**。
4. 校验属性值头：`vt=0x47`、`ulClipFmt=-1`、`cfFormat=3`、`cbSize≥16`、WMF 不越界，
   并从 Max 宽高头取出预期宽高。
5. 在 WMF 里逐条扫描记录，找 `0x0F43`（`META_STRETCHDIB`）；记录头 4 字节长度（以 16 位
   words 计）+ 2 字节 function，参数 22 字节，`BITMAPINFOHEADER` 在记录起点 + 28。
6. 校验 `biSize≥40`、`planes=1`、`comp=0`、`bitcnt∈{24,32}`、尺寸合理（≤4096）、
   宽高与 Max 头一致、`biSizeImage`（非 0 时）与行跨度一致；按 `biSize` 和可选调色板算出像素起点。
7. 解码：行跨度 `stride=align4(w*bitcnt/8)`，`Image.frombytes(..., "raw", "BGR"|"BGRX",
   stride, -1 if h>0 else 1)`——BGR 交换 + 正高度垂直翻转。
8. 存 PNG（原生尺寸；不写 `Thumb::Image::Width` tEXt，KIO 的 `matches()` 不会以「原图更大」
   为由拒绝）。

实现见 `packages/max-thumbnail-gen/extract.py`（依赖 `olefile` + `pillow`）。只接受上述
`VT_CF`/WMF/STRETCHDIB + 24/32bpp 组合；其他格式报错退出，不猜、不产出假图。

## 关键注意点

- **值偏移相对段起点**：验证锚点——test.max 的 codepage（id=`0x01`）属性值起点在绝对
  `0x78`（`0x78` 是类型 `0x0002`，数值 65001 在 `0x7c`）；locale 属性（id=`0x80000000`）
  值起点在 `0x80`，数值 2052（zh-CN）在 `0x84`。按「相对流起点」解释会全错位。
- **无内嵌图**：无 `\x05SummaryInformation` 流或无属性 `0x11` → 提取失败（非零退出，不产出）。
- **尾随 6 字节是 WMF 的 `META_EOF` 记录**（size=3 words、function=0），不是属性集 footer。
  只有缩略图恰好是最后一项属性时，像素结束才等于流长 − 6（如 test.max）；其他文件后面还有
  属性值（如 AutoBackup01 尾部还有 75 字节），所以不要把「流长 − 6」当通用规则。
- **宽度 512 是默认值**，不是格式常量；解析时以 DIB 的 `biWidth` 为准并处理行 padding。

## 代码

完整实现见 `packages/max-thumbnail-gen/extract.py`；关键步骤：

```python
vt = struct.unpack_from("<H", data, value_off)[0]          # 0x47 = VT_CF
cb, clip_fmt, cf_format = struct.unpack_from("<III", data, value_off + 4)
wmf = data[value_off + 0x18 : value_off + 0x18 + cb - 16]

pos = struct.unpack_from("<H", wmf, 2)[0] * 2              # WMF headerSize(words)
while pos + 6 <= len(wmf):
    size_words, func = struct.unpack_from("<IH", wmf, pos)
    if func == 0x0F43:                                     # META_STRETCHDIB
        dib = pos + 28
        break
    pos += size_words * 2

bi_size, w, h, planes, bitcnt, comp, img_size, _x, _y, clr_used, _ = struct.unpack_from("<IiiHHIIiiII", wmf, dib)
stride = ((w * (bitcnt // 8) + 3) // 4) * 4
if img_size and img_size != stride * abs(h):            # BI_RGB 允许 0，非 0 才校验
    raise ValueError("biSizeImage 与行跨度不一致")
pixel = dib + bi_size + clr_used * 4
img = Image.frombytes("RGB", (w, abs(h)), wmf[pixel : pixel + stride * abs(h)],
                      "raw", "BGR" if bitcnt == 24 else "BGRX", stride, -1 if h > 0 else 1)
img.save(dst, "PNG")
```

## 实测

- 11 个真实样本全部命中（test.max、AutoBackup01–06、4 个 StartupTemplates），宽度均 512，
  高度 258/275/292/293/314×3/317/419×2。
- 提取壁钟约 130–190ms（含解释器启动，随系统负载浮动）。
- 与官方读路径对照：用 Wine 的 `SetMetaFileBitsEx` + `PlayMetaFile` 复刻 Provider 调用，
  test.max 与 AutoBackup01 均逐像素一致；KIO 缓存中的 test.max 缩略图也与提取结果逐像素一致。
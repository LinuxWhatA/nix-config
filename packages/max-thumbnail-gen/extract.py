#!/usr/bin/env python3
"""从 .max 内嵌缩略图提取 PNG。

格式已对 MaxThumbnailSaver.dll（写）与 MaxThumbnailProvider.dll（读）静态核实：
OLE 属性集 \\x05SummaryInformation 的 PIDSI_THUMBNAIL（属性 id=0x11）值是 VT_CF（0x47）
剪贴板数据，按 CLIPDATA 布局：

    0x00  WORD  vt=0x47, WORD pad
    0x04  DWORD cbSize        （WMF 字节数 + 16）
    0x08  DWORD ulClipFmt     （-1 = 自定义格式）
    0x0C  DWORD cfFormat      （3）
    0x10  WORD 1, WORD width, WORD height, WORD 0   （Max 宽高头）
    0x18  WMF（cbSize-16 字节；标准 header + 一条 META_STRETCHDIB 记录）

META_STRETCHDIB 的参数区之后是标准 BITMAPINFOHEADER + DIB 像素。这里按结构解析：先校验
VT_CF/CLIPDATA 头，再在 WMF 里找 STRETCHDIB 记录，最后取它后面的 BITMAPINFOHEADER，不依赖
固定偏移，也不把未识别的字节猜成 DIB。

用法：extract.py <源 .max> <输出 .png> [请求边长]
  请求边长忽略：输出内嵌图原生尺寸（512 宽是 Max 的默认缩略图尺寸，不是格式常量）。
"""
import struct
import sys

import olefile  # type: ignore[import-untyped]  # 无类型桩
from PIL import Image  # type: ignore[import-not-found]  # 无类型桩

VT_CF = 0x47
CF_METAFILEPICT = 3
META_STRETCHDIB = 0x0F43
# STRETCHDIB 参数：ROP(4) + usage(2) + 8 个 int16(16) = 22 字节，记录头 6 字节
_STRETCHDIB_PARAMS = 22


def _thumbnail_value_off(data: bytes) -> int:
    """返回 PIDSI_THUMBNAIL 属性值的绝对偏移（属性 set 段 0，偏移相对段起点）。"""
    sec_off = struct.unpack_from("<I", data, 0x2C)[0]
    nprop = struct.unpack_from("<I", data, sec_off + 4)[0]
    for i in range(nprop):
        pid, voff = struct.unpack_from("<II", data, sec_off + 8 + i * 8)
        if pid == 0x11:
            return sec_off + voff
    raise ValueError("无 PIDSI_THUMBNAIL(0x11)")


def _read_clipdata(data: bytes, value_off: int) -> tuple[bytes, int, int]:
    """校验属性值头并取出 WMF 字节，返回 (wmf, max_width, max_height)。"""
    if value_off + 0x18 > len(data):
        raise ValueError("缩略图属性值被截断")
    vt = struct.unpack_from("<H", data, value_off)[0]
    if vt != VT_CF:
        raise ValueError("缩略图属性不是 VT_CF: 0x%04x" % vt)
    cb_size, clip_fmt, cf_format = struct.unpack_from("<III", data, value_off + 4)
    if clip_fmt != 0xFFFFFFFF:
        raise ValueError("CLIPDATA.ulClipFmt 异常: 0x%08x" % clip_fmt)
    if cf_format != CF_METAFILEPICT:
        raise ValueError("不支持的剪贴板格式: 0x%x" % cf_format)
    if cb_size < 16:
        raise ValueError("CLIPDATA.cbSize 异常: %d" % cb_size)
    wmf_off = value_off + 0x18
    wmf_len = cb_size - 16
    if wmf_off + wmf_len > len(data):
        raise ValueError("WMF 数据被截断")
    max_w, max_h = struct.unpack_from("<HH", data, value_off + 0x12)
    return data[wmf_off : wmf_off + wmf_len], max_w, max_h


def _find_stretchdib(wmf: bytes) -> tuple[bytes, int, int]:
    """返回 (去 placeable 头后的 wmf, STRETCHDIB 记录偏移, 记录字节数)。"""
    # 兼容可选的 placeable 头（22 字节，key=0x9AC6CDD7）；Max 的 GetMetaFileBitsEx 产物没有它
    if wmf[:4] == b"\xd7\xcd\xc6\x9a":
        if len(wmf) < 22:
            raise ValueError("WMF placeable 头被截断")
        wmf = wmf[22:]
    if len(wmf) < 18:
        raise ValueError("WMF 头被截断")
    wmf_type, hdr_words, _version = struct.unpack_from("<HHH", wmf, 0)
    if wmf_type != 1 or hdr_words < 9:
        raise ValueError("不是标准 WMF: type=%d header=%d" % (wmf_type, hdr_words))
    pos = hdr_words * 2
    while pos + 6 <= len(wmf):
        size_words, func = struct.unpack_from("<IH", wmf, pos)
        rec_size = size_words * 2
        if rec_size < 6 or pos + rec_size > len(wmf):
            raise ValueError("WMF 记录长度异常: 0x%08x" % rec_size)
        if func == META_STRETCHDIB:
            return wmf, pos, rec_size
        if func == 0:  # META_EOF
            break
        pos += rec_size
    raise ValueError("WMF 中找不到 META_STRETCHDIB")


def _dib_image(wmf: bytes, rec_pos: int, rec_size: int, max_w: int, max_h: int) -> Image.Image:
    """从 STRETCHDIB 记录解出 DIB，返回按原生宽高、自上而下的 RGB 图。"""
    dib = rec_pos + 4 + 2 + _STRETCHDIB_PARAMS
    if dib + 40 > len(wmf):
        raise ValueError("BITMAPINFOHEADER 被截断")
    (
        bi_size,
        w,
        h,
        planes,
        bitcnt,
        comp,
        img_size,
        _x_ppm,
        _y_ppm,
        clr_used,
        _clr_imp,
    ) = struct.unpack_from("<IiiHHIIiiII", wmf, dib)
    if bi_size < 40 or dib + bi_size > len(wmf):
        raise ValueError("BITMAPINFOHEADER 尺寸异常: %d" % bi_size)
    if w <= 0 or h == 0 or planes != 1 or comp != 0 or bitcnt not in (24, 32):
        raise ValueError("不支持的 DIB: %dx%d planes=%d bpp=%d comp=%d" % (w, h, planes, bitcnt, comp))
    abs_h = abs(h)
    if w > 4096 or abs_h > 4096:
        raise ValueError("DIB 尺寸异常: %dx%d" % (w, abs_h))
    if max_w and max_h and (max_w, max_h) != (w, abs_h):
        raise ValueError("DIB 尺寸 %dx%d 与 Max 宽高头 %dx%d 不一致" % (w, abs_h, max_w, max_h))

    step = bitcnt // 8
    palette = clr_used * 4 if clr_used else 0
    pixel_off = dib + bi_size + palette
    stride = ((w * step + 3) // 4) * 4
    need = stride * abs_h
    # BI_RGB 允许 biSizeImage=0（规范说"may be 0"），故非 0 时才校验与行跨度一致
    if img_size and img_size != need:
        raise ValueError("DIB biSizeImage 与行跨度不一致: %d vs %d" % (img_size, need))
    if pixel_off + need > len(wmf) or pixel_off + need > rec_pos + rec_size:
        raise ValueError("DIB 像素数据被截断")

    # 正高度 = 自下而上（行序翻转），负高度 = 自上而下；24 位 BGR、32 位 BGRX
    pixels = wmf[pixel_off : pixel_off + need]
    return Image.frombytes(
        "RGB",
        (w, abs_h),
        pixels,
        "raw",
        "BGR" if bitcnt == 24 else "BGRX",
        stride,
        -1 if h > 0 else 1,
    )


def extract(src: str, dst: str) -> None:
    ole = olefile.OleFileIO(src)
    try:
        if not ole.exists("\x05SummaryInformation"):
            raise ValueError("无 \\x05SummaryInformation 流")
        data = ole.openstream("\x05SummaryInformation").read()
    finally:
        ole.close()

    value_off = _thumbnail_value_off(data)
    wmf, max_w, max_h = _read_clipdata(data, value_off)
    wmf, rec_pos, rec_size = _find_stretchdib(wmf)
    _dib_image(wmf, rec_pos, rec_size, max_w, max_h).save(dst, "PNG")


def main() -> None:
    if len(sys.argv) < 3:
        print("用法: extract.py <源 .max> <输出 .png> [请求边长]", file=sys.stderr)
        sys.exit(2)
    try:
        extract(sys.argv[1], sys.argv[2])
    except Exception as e:  # noqa: BLE001 - 任何提取失败都以非零退出交 KIO 处理（不缓存、下次重试）
        print("extract failed: %r" % (e,), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
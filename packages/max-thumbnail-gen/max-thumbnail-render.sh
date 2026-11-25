#!/usr/bin/env bash
# .max 缩略图器：KDE KIO 调 Exec（show），用内嵌缩略图提取（extract.py，纯 Python）写给 KDE 的 %o。
# on-demand：结果写给 %o，KDE 自己缓存到 ~/.cache/thumbnails/（同 tracedraw 的 .cdr 行为），
# 源目录不落任何文件。用法：max-thumbnail-render show <源 .max> <输出 .png> [边长]
#
# 取舍：内嵌图是"保存时的视口快照"（取景/宽高比随保存时视口变），但提取毫秒级，远低于 KIO
# 的 5s 单次时限。正方形问题（Dolphin 单元格）暂搁置：按原生宽高比输出，Dolphin 自行处理；
# 不写 Thumb::Image::Width 让 KIO 的 matches() 不因"原图更大/更小"拒绝。
set -uo pipefail
shopt -s nullglob

: "${MAX_THUMB_REPO:?请通过 max-thumbnail-render 入口运行：包装器才注入 MAX_THUMB_REPO}"
repo="$MAX_THUMB_REPO"
die() { echo "max-thumbnail-render: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
3ds Max .max 缩略图工具（从内嵌 SummaryInformation 属性集提取）

用法:
  max-thumbnail-render show <源 .max> <输出 .png> [边长]   on-demand 提取给 KDE 的 %o

提取结果由 KDE 缓存到 ~/.cache/thumbnails/，源目录不落文件。
EOF
}

case "${1:-}" in
  -h | --help)
    usage
    ;;
  show)
    shift
    src="${1:?用法: max-thumbnail-render show <源 .max> <输出 .png> [边长]}"
    dst="${2:?缺少输出路径}"
    [ -f "$src" ] || die "源文件不存在: $src"
    src="$(realpath -- "$src")" || die "无法解析源路径: $src"
    dst="$(realpath -m -- "$dst")" || die "无法解析输出路径: $dst"
    mkdir -p -- "$(dirname -- "$dst")" || die "无法创建输出目录"
    command -v python3 >/dev/null 2>&1 || die "找不到 python3"

    # 先提取到 %o 同目录的临时文件再原子 mv：%o 是 KIO 预建的临时文件（QTemporaryFile，0600），
    # 本进程退出后 KIO 同进程用 QImage 读它，故 mv 覆盖该路径安全，半成品不会漏给文件管理器。
    # 失败（无内嵌图/坏文件）非零退出：KIO 不缓存、下次重试，日志留 state 目录供诊断。
    state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/max-thumbnail-gen"
    mkdir -p -- "$state_dir" || die "无法创建状态目录: $state_dir"
    tmp="$(mktemp --suffix=.png "$(dirname -- "$dst")/.render-XXXXXX")" || die "无法创建临时文件"
    # KIO 5s 超时会 kill 本进程；trap 保证残留的 .render-*.png 被清掉（成功交付后 mv 已让它消失）
    trap 'rm -f -- "$tmp"' EXIT
    log="$state_dir/render-$(date +%Y%m%d-%H%M%S).log"
    if python3 "$repo/extract.py" "$src" "$tmp" >"$log" 2>&1 && [ -s "$tmp" ]; then
      # 交付（mv）与清理（删日志）分开：删日志失败不该把已写好的缩略图折叠成失败——KIO 见非零退出码
      # 就不缓存、下次重渲，还会把归因指到"提取失败"。成功不留日志：KIO 每次预览都写，日志只为诊断。
      mv -f -- "$tmp" "$dst" || { rm -f -- "$tmp"; die "写入输出失败（日志 $log）: $dst"; }
      rm -f -- "$log" || true
      exit 0
    fi
    rm -f -- "$tmp"
    # 失败日志只保留最近 20 个：KIO 对坏文件每次预览都会重试，不清理会无限增长
    logs=("$state_dir"/render-*.log)
    if (( ${#logs[@]} > 20 )); then
      printf '%s\n' "${logs[@]}" | sort | head -n "$(( ${#logs[@]} - 20 ))" \
        | while IFS= read -r old; do rm -f -- "$old"; done
    fi
    echo "提取失败（日志 $log）: $src" >&2
    exit 1
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

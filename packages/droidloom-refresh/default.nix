# 上游载荷刷新器：把 packages/droidloom 构建出的 pacman 包接进 droidloom-runtime
#
# 为什么需要它：上游既无 release 也无 tag，载荷只能本机构建（见 packages/droidloom），
# 产物要先 `nix-store --add-fixed` 进 store，再把哈希填进 droidloom-runtime 的
# requireFile。手工做这一步很容易踩坑：`nix-prefetch-url --unpack` 给的是 base32，
# 而 requireFile 要 SRI；`nix hash to-sri` 也不行——store 路径里那段是**截断**到
# 160 bit 的哈希，转不成 SRI。正确做法是 `nix hash file --sri --type sha256 <文件>`
# （已核对：结果与包内现用的两个哈希逐字一致）。
#
# 用法：
#   nix run .#droidloom-refresh --                 # 只打印版本与两个 SRI
#   nix run .#droidloom-refresh -- --write         # 顺带 add-fixed 并改写 droidloom-runtime
#   nix run .#droidloom-refresh -- --dist <dir> --version 0.1.0-19
{
  writeShellApplication,
  nix,
  coreutils,
  gnused,
}:
# writeShellApplication（而非 writeShellScript）：后者 $out 就是脚本文件本身，
# 没有 bin/ 目录，nix run 找不到可执行档。
# 另：目标文件不能靠 Nix 的相对路径（../../packages/...）定位——本 flake 是 git flake，
# 求值时源码在 store 副本里，那样会解析到只读的 /nix/store/…-source/…。故运行时按 CWD 找。
writeShellApplication {
  name = "droidloom-refresh";
  text = ''
    set -euo pipefail

    nix=${nix}/bin/nix
    nix_store=${nix}/bin/nix-store
    sed=${gnused}/bin/sed
    ls=${coreutils}/bin/ls
    sort=${coreutils}/bin/sort
    tail=${coreutils}/bin/tail
    cat=${coreutils}/bin/cat

    dist="''${DROIDLOOM_DIST:-$HOME/droidloom/dist/arch}"
    version=""
    target=""
    write=0

    usage() {
      $cat <<'USAGE'
    用法：droidloom-refresh [--dist <dist/arch 目录>] [--version <版本>] [--target <文件>] [--write]

      --dist     产物目录，默认 $HOME/droidloom/dist/arch（或 $DROIDLOOM_DIST）
      --version  默认取该目录下版本号最大的一个
      --target   要改写的载荷定义，默认本仓库的 packages/droidloom-runtime/default.nix
      --write    除了打印，还执行 nix-store --add-fixed 并改写 target；不加则只打印
    USAGE
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --dist)    dist="$2";    shift 2 ;;
        --version) version="$2"; shift 2 ;;
        --target)  target="$2";  shift 2 ;;
        --write)   write=1;      shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "未知参数: $1" >&2; usage; exit 2 ;;
      esac
    done

    # 目标默认为「当前所在仓库」里那份载荷定义（本 flake 是 git flake，不能用 Nix 相对路径）
    if [ -z "$target" ]; then
      target="$PWD/packages/droidloom-runtime/default.nix"
      [ -f "$target" ] || target="$HOME/nix-config/packages/droidloom-runtime/default.nix"
    fi

    if [ -z "$version" ]; then
      version=$($ls -1 "$dist" | $sort -V | $tail -n 1)
    fi
    dir="$dist/$version"
    [ -d "$dir" ] || { echo "找不到产物目录 $dir（用 --dist / --version 指定）" >&2; exit 1; }

    # requireFile 要的就是文件自身的 sha256 的 SRI 形式
    sri_of() {
      local f="$dir/droidloom-$1-$version-x86_64.pkg.tar.zst"
      [ -f "$f" ] || { echo "缺少 $f" >&2; exit 1; }
      $nix hash file --sri --type sha256 "$f"
    }

    runtime_sri=$(sri_of runtime)
    image_sri=$(sri_of image)

    echo "version     = $version"
    echo "runtime SRI = $runtime_sri"
    echo "image   SRI = $image_sri"

    if [ "$write" = 0 ]; then
      echo
      echo "只打印，未改动任何文件。加 --write 会先 nix-store --add-fixed 再改写："
      echo "  $target"
      exit 0
    fi

    for n in runtime image; do
      f="$dir/droidloom-$n-$version-x86_64.pkg.tar.zst"
      p=$($nix_store --add-fixed sha256 "$f")
      echo "store: $p"
    done

    # 只换哈希与 version，文件名里的 ''${version} 保持原样（让它继续跟着变量走）
    $sed -i \
      -e "s|version = \"[^\"]*\";|version = \"$version\";|" \
      -e "s|\(\"droidloom-runtime-[^\"]*-x86_64\.pkg\.tar\.zst\"[[:space:]]*\"\)sha256-[^\"]*|\1$runtime_sri|" \
      -e "s|\(\"droidloom-image-[^\"]*-x86_64\.pkg\.tar\.zst\"[[:space:]]*\"\)sha256-[^\"]*|\1$image_sri|" \
      "$target"

    echo "已写入 $target"
    echo "接下来：sudo nixos-rebuild switch --flake .#redmi"
  '';
}

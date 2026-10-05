# Droidloom 运行期载荷（上游 pacman 包对：droidloom-runtime + droidloom-image）
#
# 上游把这两个包发在同一个 release 里，tag 固定叫 `packages`（与包版本无关，版本号
# 只出现在资产文件名中，也没有独立 tag），故按需拼 URL 用 fetchurl 取；哈希取 GitHub
# 资产自带的 digest 字段。
#
# 载荷重排为 Nix 布局（bin/lib/share），上游二进制与生成的 cell.json 里硬编码的
# /usr/... 路径由 modules/nixos/virtualization/droidloom.nix 用符号链接垫平。
{
  lib,
  stdenvNoCC,
  fetchurl,
  zstd,
}:
let
  version = "0.1.0-20";

  archive =
    name: hash:
    fetchurl {
      name = "droidloom-${name}-${version}-x86_64.pkg.tar.zst";
      url = "https://github.com/denialwm/droidloom/releases/download/packages/droidloom-${name}-${version}-x86_64.pkg.tar.zst";
      inherit hash;
    };
in
stdenvNoCC.mkDerivation {
  pname = "droidloom";
  inherit version;

  srcs = [
    (archive "runtime" "sha256-K24ogIgCFzKB5RCiu/DMJ55dkmHcJc1vXwCf5DLBcOk=")
    (archive "image" "sha256-0OFN74bJ4FnUfoKq2R92QTG54NCx5eAtaPyM4G01Mmc=")
  ];

  nativeBuildInputs = [ zstd ];

  # 两个包安装到同一前缀，解到一棵树里合并
  unpackPhase = ''
    runHook preUnpack
    mkdir payload
    for archive in $srcs; do
      zstd -dc "$archive" | tar -x -C payload
    done
    runHook postUnpack
  '';

  # 载荷里有大量 Android 侧 ELF（bionic 与厂商库）与 2.5 GiB 镜像，一律保持上游字节
  dontFixup = true;

  # 只装运行时真正读取的目录：/usr/share 下的 polkit action 与 libalpm 钩子属 pacman
  # 集成件，NixOS 侧由模块自己声明
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib $out/share
    cp -a payload/usr/bin/. $out/bin/
    cp -a payload/usr/lib/droidloom $out/lib/
    cp -a payload/usr/lib/systemd $out/lib/
    cp -a payload/usr/share/droidloom $out/share/
    runHook postInstall
  '';

  meta = {
    description = "Droidloom runtime and Android image payload (upstream Arch packages)";
    homepage = "https://github.com/denialwm/droidloom";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "droidloomctl";
  };
}

# Droidloom 运行时载荷（上游 pacman 包对：droidloom-runtime + droidloom-image）
#
# 为什么用 requireFile：上游既无 release 也无 tag，这两个包只能由本仓库的
# packages/droidloom 构建器在本机跑出来，既不进 git 也无法下载。按 nixpkgs 惯例改由
# 使用者把文件放进 store（首次求值会打印出 nix-store --add-fixed 命令）。
#
# 载荷重排为 Nix 布局（bin/lib/share），上游二进制与生成的 cell.json 里硬编码的
# /usr/... 路径由 modules/nixos/virtualization/droidloom.nix 用符号链接垫平。
{
  lib,
  stdenvNoCC,
  requireFile,
  zstd,
}:
let
  version = "0.1.0-18";

  archive =
    name: hash:
    requireFile {
      inherit name;
      sha256 = hash;
      message = ''
        请先把本机产物加入 store（路径按需替换）：
          nix-store --add-fixed sha256 <droidloom checkout>/dist/arch/${version}/${name}
      '';
    };
in
stdenvNoCC.mkDerivation {
  pname = "droidloom-runtime";
  inherit version;

  srcs = [
    (archive "droidloom-runtime-${version}-x86_64.pkg.tar.zst" "sha256-NcxNXClK/KgNgqJinUzRf/uQdmYuSfZZ9wPiCAcENXc=")
    (archive "droidloom-image-${version}-x86_64.pkg.tar.zst" "sha256-tRxSBGubcCv8Np0wQztBdqWQQYoSMo98CNtxlZMGFrM=")
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

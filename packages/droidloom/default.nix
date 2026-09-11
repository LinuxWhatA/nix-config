# Droidloom 的构建器（上游 tools/droidloom-package）
#
# 为什么只打包构建器：Droidloom 由 droidloom-runtime（宿主程序）与 droidloom-image
# （Android 镜像）两个 pacman 包组成，上游既无 release 也无 tag，没有任何可下载的
# 预编译产物；唯一的构建入口会在 rootless Podman 的 Arch 容器里跑 makepkg，联网拉取
# 并编译固定的 AOSP 稀疏源（约 120 GiB）。这条链依赖网络、容器与 FHS 布局，无法在
# Nix 沙箱内表达，因此本包只做构建，产物是 pacman 包。
#
# 用法（在 droidloom 源码 checkout 内执行，或用 --source 指定；输出在
# dist/arch/<version>-<release>/）：
#   nix run .#droidloom -- build
# 产出的包对由 packages/droidloom-runtime 收进 store，运行期接线见
# modules/nixos/virtualization/droidloom.nix。
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  podman,
  rsync,
}:
let
  # 构建器在宿主上调 podman/rsync，并在启动自检两者的 --version
  runtimePath = lib.makeBinPath [
    podman
    rsync
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "droidloom";
  version = "0.1.0-unstable-2026-09-10";

  src = fetchFromGitHub {
    owner = "denialwm";
    repo = "droidloom";
    rev = "e380cde064be3847b4d5ee6e8f4e874eb76f9742";
    hash = "sha256-WCTzxbhWt3l6D0eJJ1sJMmB7z7X4MlKWHmqBoRfO6rQ=";
  };

  cargoLock.lockFile = "${finalAttrs.src}/Cargo.lock";

  # 只构建构建器：其余 workspace 成员是 Android 侧组件，或依赖 Android 构建环境
  cargoBuildFlags = [ "-p droidloom-package" ];
  cargoInstallFlags = [ "-p droidloom-package" ];

  nativeBuildInputs = [ makeWrapper ];

  doCheck = false; # 用例跑完整 Android 构建，需要容器与网络

  postInstall = ''
    wrapProgram "$out/bin/droidloom-package" --prefix PATH : ${runtimePath}
  '';

  meta = {
    description = "Build Droidloom runtime and Android image packages (upstream builder)";
    homepage = "https://github.com/denialwm/droidloom";
    license = lib.licenses.gpl3Plus;
    mainProgram = "droidloom-package";
    platforms = lib.platforms.linux;
  };
})

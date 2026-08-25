{
  stdenv,
  lib,
  fetchFromGitHub,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  yad,
  winapps ? throw "Pass in the winapps package",
  ...
}:
let
  rev = "85958fec2aa2e57b781f3a742ea5bea4a93230ca";
  hash = "sha256-V3Y9gQQXNqm/J252f4EixaiWjreHJp3lde4AZe/OBV0=";
in
stdenv.mkDerivation rec {
  pname = "winapps-launcher";
  version = "0-unstable-2026-07-07";

  src = fetchFromGitHub {
    owner = "winapps-org";
    repo = "WinApps-Launcher";

    inherit rev hash;
  };

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ];
  buildInputs = [
    yad
    winapps
  ];

  patches = [ ./winapps-launcher.patch ];

  postPatch = ''
    substituteAllInPlace winapps-launcher.sh
    # Nix 兼容：原生扫描 which winapps 所在目录（传统安装即 ~/.local/bin），此处直接
    # 扫 ~/.local/bin；启动脚本由 overlay 补丁后的 winapps-setup 以相对路径生成，
    # 故以 '^winapps ' 匹配。目录不存在或为空时应用列表为空。
    substituteInPlace winapps-launcher.sh \
      --replace-fail 'find "$WINAPPS_PATH" -maxdepth 1 -type f' 'find "$HOME/.local/bin" -maxdepth 1 -type f 2>/dev/null' \
      --replace-fail 'grep -q "''${WINAPPS_PATH}/winapps" "$FILE"' 'grep -q "^winapps " "$FILE"'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r ./icons $out/icons

    install -m755 -D winapps-launcher.sh $out/bin/winapps-launcher
    install -Dm444 -T icons/AppIcon.svg $out/share/pixmaps/winapps.svg

    wrapProgram $out/bin/winapps-launcher \
      --set LIBVIRT_DEFAULT_URI "qemu:///system" \
      --prefix PATH : "${lib.makeBinPath buildInputs}"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "winapps";
      exec = "winapps-launcher";
      icon = "winapps";
      comment = meta.description;
      desktopName = "WinApps";
      categories = [ "Utility" ];
    })
  ];

  meta = with lib; {
    homepage = "https://github.com/winapps-org/WinApps-Launcher";
    description = "Graphical launcher for WinApps. Run Windows applications (including Microsoft 365 and Adobe Creative Cloud) on GNU/Linux with KDE, GNOME or XFCE, integrated seamlessly as if they were native to the OS. Wayland is currently unsupported.";
    mainProgram = "winapps-launcher";
    platforms = platforms.linux;
    license = licenses.gpl3;
  };
}

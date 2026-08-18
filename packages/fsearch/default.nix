{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  gtk3,
  pcre2,
  glib,
  desktop-file-utils,
  meson,
  ninja,
  pkg-config,
  wrapGAppsHook3,
  gettext,
  icu,
  itstool,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fsearch";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "cboxdoerfer";
    repo = "fsearch";
    rev = finalAttrs.version;
    hash = "sha256-ahIsSR6z7zKCBPqz/W1ATdsJc9krbeXOECa0T8djR6U=";
  };

  # 上游修复 #727（新窗口菜单/Ctrl+N 无效），0.3.2 发布后可移除
  patches = [
    (fetchpatch {
      url = "https://github.com/cboxdoerfer/fsearch/commit/0257fd0a77b28d38fc07ab5981d8e5698147c835.patch";
      hash = "sha256-2FKo3PGkhoZYAzxvAitUvB8Zw51RJNNLrs3N02VoKIA=";
    })
  ];

  nativeBuildInputs = [
    desktop-file-utils
    meson
    ninja
    pkg-config
    wrapGAppsHook3
    gettext
    itstool
  ];

  buildInputs = [
    glib
    gtk3
    pcre2
    icu
  ];

  meta = {
    description = "Fast file search utility for Unix-like systems based on GTK+3";
    homepage = "https://github.com/cboxdoerfer/fsearch/";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; [ artturin ];
    platforms = lib.platforms.unix;
    mainProgram = "fsearch";
    broken = stdenv.hostPlatform.isDarwin; # never built on Hydra https://hydra.nixos.org/job/nixpkgs/trunk/fsearch.x86_64-darwin
  };
})

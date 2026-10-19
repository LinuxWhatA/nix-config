{
  lib,
  stdenv,
  fetchFromGitHub,
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
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "cboxdoerfer";
    repo = "fsearch";
    rev = finalAttrs.version;
    hash = "sha256-IdcNjlloyJEGZ1BbGxaeLGUiDhrku9fIXM45LwQ8iRc=";
  };

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

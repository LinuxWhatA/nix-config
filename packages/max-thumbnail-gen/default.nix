{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  coreutils,
  ...
}:
let
  # 内嵌缩略图提取：olefile 读属性集（\x05SummaryInformation），Pillow 解 WMF 里的 DIB，纯 Python。
  python = python3.withPackages (p: [
    p.olefile
    p.pillow
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "max-thumbnail-gen";
  version = "0-unstable-2026-11-25";

  src = null;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/max-thumbnail-gen $out/bin

    install -m755 ${./max-thumbnail-render.sh} $out/share/max-thumbnail-gen/max-thumbnail-render.sh
    install -m644 ${./extract.py} $out/share/max-thumbnail-gen/extract.py
    patchShebangs $out/share/max-thumbnail-gen/*.sh

    install -Dm444 ${./max.thumbnailer} $out/share/thumbnailers/max.thumbnailer

    # MAX_THUMB_REPO 是脚本所在目录（extract.py 与之同目录）；PATH 只需带 olefile/pillow 的
    # python 与 coreutils（mktemp/mv/realpath/date/dirname/sort/head）。
    makeWrapper $out/share/max-thumbnail-gen/max-thumbnail-render.sh \
      $out/bin/max-thumbnail-render \
      --set MAX_THUMB_REPO "$out/share/max-thumbnail-gen" \
      --prefix PATH : "${
        lib.makeBinPath [
          python
          coreutils
        ]
      }"
    runHook postInstall
  '';

  meta = with lib; {
    description = "3ds Max .max 缩略图：从内嵌 SummaryInformation 属性集提取（KDE 缓存）";
    license = licenses.gpl3Plus;
    mainProgram = "max-thumbnail-render";
    platforms = [ "x86_64-linux" ];
  };
}

{
  lib,
  stdenv,
  makeWrapper,
  python3,
}:

let
  # pinned nixpkgs 中 python-registry 1.4 的打包有误：.dist-info/METADATA 为 1.3.1，
  # 与 derivation 版本不一致导致构建检查失败；按 METADATA 版本对齐即可
  python-registry = python3.pkgs.python-registry.overrideAttrs (o: {
    version = "1.3.1";
    __intentionallyOverridingVersion = true;
  });
  python = python3.withPackages (ps: [ python-registry ]);
in
stdenv.mkDerivation {
  pname = "bt-keys-info";
  version = "0.1.0";

  src = ./.;
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -D -m 0755 bt-keys-info.py $out/libexec/bt-keys-info.py
    makeWrapper ${python}/bin/python3 $out/bin/bt-keys-info \
      --add-flags $out/libexec/bt-keys-info.py
  '';

  meta = {
    description = "从 Windows SYSTEM 配置单元读取蓝牙配对密钥，输出 BlueZ info 格式";
    platforms = lib.platforms.linux;
  };
}

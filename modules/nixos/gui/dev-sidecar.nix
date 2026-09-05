# Dev-sidecar 的 MITM CA 不在构建期生成：私钥写入 store 全局可读（0444），
# 且每次重建都会轮换信任锚，故由首次激活时生成到 ~/.dev-sidecar（私钥 600、证书 644）。
#
# 注意：security.pki 在系统构建期烘焙证书列表，无法引用激活期生成的动态文件；
# 若需系统级信任该 CA（让 curl/git 等走代理的流量也信任 MITM 证书），接入本模块时
# 需另做动态信任方案（如激活期把 crt 并入系统证书库并 update-ca-certificates）。
{ flake, pkgs, ... }:

let
  inherit (pkgs) dev-sidecar;
  caDir = ".dev-sidecar";
in
{
  home-manager.users.${flake.config.me.username}.home = {
    packages = [ dev-sidecar ];

    # CA 首次激活时生成，幂等跳过（两文件齐全即不动）
    activation.DevSidecarCa = ''
      dir="$HOME/${caDir}"
      key="$dir/dev-sidecar.ca.key.pem"
      crt="$dir/dev-sidecar.ca.crt"
      if [ ! -s "$key" ] || [ ! -s "$crt" ]; then
        # umask 收敛在子 shell 内：HM 把各激活条目拼在同一脚本顺序执行，
        # 裸 umask 会泄漏到后续条目（setting.json 等会被静默改成 0600）
        (
          umask 077
          mkdir -p "$dir"
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
            -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=dev-sidecar/CN=DevSidecar" \
            -keyout "$key" -out "$crt"
          chmod 600 "$key"
          chmod 644 "$crt"
        )
      fi
    '';

    activation.DevSidecarSettings = pkgs.mergeJson "${caDir}/setting.json" {
      overwall = true;
    };
  };
}

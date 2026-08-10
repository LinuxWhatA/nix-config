# 生成一段 shell 脚本：把 json 合并进 ~/<file>
# 用于给应用自管理的 JSON 配置注入默认值——默认值仅在用户未设置该键时生效，
# 用户已有配置（含应用运行时写入的）优先。
#
# 用法（home.activation）：
#   let mergeJson = (import (flake.inputs.self + /lib/merge-json.nix) { inherit pkgs; }).mergeJson; in
#   home.activation.mySettings = mergeJson ".config/app/config.json" (builtins.toJSON { ... });
{ pkgs }:

{
  mergeJson = file: json: ''
    file="$HOME/${file}"
    [ -f "$file" ] || (mkdir -p "$(dirname "$file")" && echo "{}" > "$file")
    json=$(${pkgs.fixjson}/bin/fixjson --minify "$file")
    echo '${json}' "$json" | ${pkgs.jq}/bin/jq -s add > "$file"
  '';
}

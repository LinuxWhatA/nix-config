# 生成一段 shell 脚本：把 json 合并进 ~/<file>
# 用于给应用自管理的 JSON 配置注入默认值——默认值仅在用户未设置该键时生效，
# 用户已有配置（含应用运行时写入的）优先。
#
# 通过 overlays/default.nix 注入为 pkgs.mergeJson，所有 home-manager / NixOS
# 模块可直接调用，无需手动 import。
#
# 健壮性说明：
#   JSON 值可能含单引号（如字体名 "'FiraCode'"），用 echo '${json}' 会断裂
#   shell 语法。here-document 以 quoted delimiter 写入临时文件，规避所有引号问题。
#   fixjson 先规范化已有配置（容忍尾部逗号、注释等非标准 JSON），再交给 jq 合并。
#
# 用法（home.activation）：
#   home.activation.mySettings = pkgs.mergeJson ".config/app/config.json" { key = "value"; };
{ pkgs }:

{
  # file: 相对于 $HOME 的目标路径
  # defaults: Nix attrset，由本函数负责序列化
  mergeJson = file: defaults: ''
    file="$HOME/${file}"
    [ -f "$file" ] || (mkdir -p "$(dirname "$file")" && echo "{}" > "$file")
    tmp=$(mktemp)
    cat > "$tmp" <<'MERGEJSON_EOF'
    ${builtins.toJSON defaults}
    MERGEJSON_EOF
    ${pkgs.fixjson}/bin/fixjson --minify "$file" > "$file.fix" 2>/dev/null && mv "$file.fix" "$file" || echo '{}' > "$file"
    ${pkgs.jq}/bin/jq -s add "$tmp" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    rm -f "$tmp"
  '';
}

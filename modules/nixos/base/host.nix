# 主机公共身份属性：所有主机一致的样板，差异项在主机内直接覆盖即可
# （普通赋值优先级高于 mkDefault，无需 mkForce）
{ flake, lib, ... }:

{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = lib.mkDefault "26.11";
  home-manager.users.${flake.config.me.username}.home.stateVersion = lib.mkDefault "26.11";
}

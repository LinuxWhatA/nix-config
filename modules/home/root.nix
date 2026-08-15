# root 用户的 home-manager：仅提供 zsh + starship 的 shell 体验
# 用法：任意主机只需 home-manager.users.root = { imports = [ self.homeModules.root ]; };
# 注意：homeCommon 会用 mkDefault 写 /home/root，这里显式 mkForce 为 /root
{ flake, lib, ... }:
{
  home.homeDirectory = lib.mkForce "/root";
  home.stateVersion = "26.11";
  imports = [
    (flake.inputs.self + /modules/home/cli/zsh.nix)
  ];
}

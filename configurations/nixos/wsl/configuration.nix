{
  flake,
  pkgs,
  lib,
  ...
}:
{
  wsl = {
    enable = true;
    defaultUser = flake.config.me.username;
    interop.register = true; # 解决 binfmt 冲突
    wslConf.interop = {
      enabled = true; # 启用互操作功能
      appendWindowsPath = false; # 不附加Windows PATH以提升速度
    };
  };
  systemd.services.systemd-binfmt.enable = false;
  services.envfs.enable = lib.mkForce false;

  # 避免 tarball 构建时 /etc/nixos 指向只读的 nix store 导致写 configuration.nix 失败
  environment.etc."nixos".enable = false;

  users.mutableUsers = true;

  environment.systemPackages = [
    pkgs.sni-host
    pkgs.tray-host
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "wsl";
  system.stateVersion = "26.11";

  security.sudo-rs.wheelNeedsPassword = false;

  home-manager.users.${flake.config.me.username}.home.stateVersion = "26.11";
}

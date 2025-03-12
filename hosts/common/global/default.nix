# This file (and the global directory) holds config that i use on all hosts
{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./zsh.nix
    ./nix.nix
    ./vim.nix
    ./sops.nix
    ./fonts.nix
    ./locale.nix
    ./openssh.nix
    ./security.nix
    ./optin-persistence.nix
  ] ++ (builtins.attrValues outputs.nixosModules);

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {
    inherit inputs outputs;
  };
  home-manager.backupFileExtension = "hmbackup";

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
    };
  };

  hardware.enableRedistributableFirmware = true;

  environment.systemPackages = with pkgs; [
    file
    tree
    lsof
    wget
  ];

  # 将当前配置写入 /etc/nixos
  environment.etc."nixos".source = ../../..;

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Cleanup stuff included by default
  services.speechd.enable = lib.mkDefault false;
}

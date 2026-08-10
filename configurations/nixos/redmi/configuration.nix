{ flake, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (flake.inputs.self + /modules/nixos/hardware/boot.nix)
  ];

  boot.kernelParams = [
    # FIXME: amdgpu 7.0.13+ 内核回归（Rembrandt APU gfx ring timeout）缓解，
    "amdgpu.cwsr_enable=0"
  ];

  networking.hostName = "redmi";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.11";

  home-manager.users.${flake.config.me.username}.home.stateVersion = "26.11";
}

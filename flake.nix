{
  description = "NixOS configuration of LinuxWhatA";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-unified.url = "github:srid/nixos-unified";
    nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixpkgs-unstable";
    home-manager.url = "git+https://gitee.com/mirrors/home-manager-nix";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "git+https://gitee.com/mirrors/nixos-hardware";
    impermanence.url = "git+https://gitee.com/linuxwhata/mirrors?dir=impermanence";
    disko.url = "git+https://gitcode.com/gh_mirrors/di/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.url = "git+https://gitcode.com/gh_mirrors/pl/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";

    # Software inputs
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = (with builtins; map (fn: ./modules/flake/${fn}) (attrNames (readDir ./modules/flake)));

      perSystem =
        { lib, system, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = lib.attrValues self.overlays;
            config.allowUnfree = true;
          };
        };
    };
}

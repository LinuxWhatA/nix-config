{
  description = "NixOS configuration of LinuxWhatA";

  inputs = {
    nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixpkgs-unstable";
    hardware.url = "git+https://gitee.com/mirrors/nixos-hardware";
    impermanence.url = "git+https://gitee.com/linuxwhata/impermanence";
    disko = {
      url = "git+https://gitee.com/linuxwhata/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "git+https://gitee.com/linuxwhata/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "git+https://gitee.com/mirrors/home-manager-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "git+https://gitee.com/linuxwhata/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      lib = nixpkgs.lib // home-manager.lib;
      forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});
      pkgsFor = lib.genAttrs systems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );
    in
    {
      inherit lib;
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      overlays = import ./overlays { inherit inputs outputs; };

      packages = forEachSystem (pkgs: import ./pkgs { inherit pkgs; });
      devShells = forEachSystem (pkgs: import ./shell.nix { inherit pkgs; });

      nixosConfigurations = {
        # AMD 主机
        naix = lib.nixosSystem {
          modules = [ ./hosts/naix ];
          specialArgs = {
            inherit inputs outputs;
          };
        };
        # X455LJ 笔记本
        asus = lib.nixosSystem {
          modules = [ ./hosts/asus ];
          specialArgs = {
            inherit inputs outputs;
          };
        };
        # cdrom
        cdrom = lib.nixosSystem {
          modules = [
            ./hosts/naix
            ./hosts/cdrom
          ];
          specialArgs = {
            inherit inputs outputs;
          };
        };
      };

      homeConfigurations = {
        "lwa@naix" = lib.homeManagerConfiguration {
          modules = [
            ./home/lwa/naix.nix
            ./home/lwa/nixpkgs.nix
          ];
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
          };
        };

        "lwa@asus" = lib.homeManagerConfiguration {
          modules = [
            ./home/lwa/asus.nix
            ./home/lwa/nixpkgs.nix
          ];
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
          };
        };
      };
    };
}

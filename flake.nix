{
  description = "NixOS configuration of LinuxWhatA";

  inputs = {
    nixpkgs.url = "git+https://mirrors.cernet.edu.cn/nixpkgs.git?ref=nixpkgs-unstable";
    hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      plasma-manager,
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
          modules = [
            ./hosts/naix
            ./home/lwa/nixpkgs.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "bkp";
              home-manager.users.lwa = import ./home/lwa/naix.nix;
              home-manager.extraSpecialArgs = {
                inherit inputs outputs;
              };
            }
          ];
          specialArgs = {
            inherit inputs outputs;
          };
        };
        # X455LJ 笔记本
        asus = lib.nixosSystem {
          modules = [
            ./hosts/asus
            ./home/lwa/nixpkgs.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "bkp";
              home-manager.users.lwa = import ./home/lwa/asus.nix;
              home-manager.extraSpecialArgs = {
                inherit inputs outputs;
              };
            }
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
      };
    };
}

{
  description = "NixOS configuration of LinuxWhatA";

  inputs = {
    # 原则性 inputs
    nixpkgs.url = "git+https://git.nju.edu.cn/nix-mirror/nixpkgs?ref=nixpkgs-unstable&shallow=1";
    nixpkgs-lib.url = "git+https://git.nju.edu.cn/nix-mirror/nixpkgs.lib";
    flake-compat.url = "git+https://git.nju.edu.cn/nix-mirror/flake-compat";
    flake-parts = {
      url = "git+https://gitcode.com/gh_mirrors/fl/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    };
    home-manager = {
      url = "git+https://gitee.com/mirrors/home-manager-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 功能 inputs
    hardware = {
      url = "git+https://gitee.com/mirrors/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "git+https://git.nju.edu.cn/nix-mirror/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    disko = {
      url = "git+https://gitcode.com/gh_mirrors/di/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "git+https://gitcode.com/gh_mirrors/pl/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nixos-wsl = {
      url = "git+https://git.nju.edu.cn/nix-mirror/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };
    nix-index-database = {
      url = "git+https://gitcode.com/gh_mirrors/ni/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien = {
      url = "git+https://gitcode.com/gh_mirrors/ni/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
      inputs.nix-index-database.follows = "nix-index-database";
    };
    flake-utils = {
      url = "git+https://gitcode.com/gh_mirrors/fl/flake-utils";
    };
    winapps = {
      url = "git+https://gitcode.com/GitHub_Trending/wina/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-utils.follows = "flake-utils";
    };
    nixvim = {
      url = "git+https://github.com/nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    NixVirt = {
      url = "git+https://github.com/AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    betterfox = {
      url = "git+https://gitcode.com/GitHub_Trending/be/Betterfox";
      flake = false;
    };
  };

  # 自动接线：modules/flake 下的所有 .nix 文件自动作为 flake-parts 模块导入，
  # 其中 autowire.nix 负责根据目录结构自动生成全部 outputs。
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = map (f: ./modules/flake/${f}) (builtins.attrNames (builtins.readDir ./modules/flake));
    };
}

{
  description = "NixOS configuration of LinuxWhatA";

  nixConfig = {
    # denial 缓存
    extra-substituters = [ "https://denial.cachix.org" ];
    extra-trusted-public-keys = [ "denial.cachix.org-1:wd8YTnvPmugFrtdMJWtR1XdVknR3/g2nmBJkT+vAruo=" ];
    # 系统侧 substituters 要 rebuild 后才生效，而 rebuild 自身就要下载
    substituters = [
      "https://mirror.nju.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];
  };

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
      url = "git+https://git.nju.edu.cn/nix-mirror/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # chaotic = {
    #   url = "git+https://gitcode.com/gh_mirrors/nyx/nyx";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.home-manager.follows = "home-manager";
    # };

    # 工程 inputs：（nixfmt + statix）格式化与静态检查，随 `nix fmt` 与 `nix flake check` 落地
    treefmt-nix = {
      url = "git+https://gitcode.com/gh_mirrors/tr/treefmt-nix";
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
      url = "git+https://git.nju.edu.cn/nix-mirror/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "git+https://git.nju.edu.cn/nix-mirror/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nixos-wsl = {
      url = "git+https://git.nju.edu.cn/nix-mirror/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };
    nix-index-database = {
      url = "git+https://git.nju.edu.cn/nix-mirror/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ! nix-alien 不支持 inputs.follows
    nix-alien.url = "git+https://gitcode.com/gh_mirrors/ni/nix-alien";
    flake-utils = {
      url = "git+https://gitcode.com/gh_mirrors/fl/flake-utils";
    };
    winapps = {
      url = "git+https://gitcode.com/GitHub_Trending/wina/winapps";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
      };
    };
    nixvim = {
      url = "git+https://git.nju.edu.cn/nix-mirror/nixvim";
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
    # denial 明确不建议 follows nixpkgs
    denial.url = "git+https://github.com/denialwm/denial";
    uur = {
      url = "git+https://github.com/panxuc/uur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # 自动接线：modules/flake 下的所有 .nix 文件自动作为 flake-parts 模块导入，
  # 其中 autowire.nix 负责根据目录结构自动生成全部 outputs。
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      flake.inputs = inputs;
      systems = [ "x86_64-linux" ];
      imports = map (f: ./modules/flake/${f}) (builtins.attrNames (builtins.readDir ./modules/flake));
    };
}

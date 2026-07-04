{
  description = "NixOS configuration of LinuxWhatA";

  inputs = {
    nixpkgs.url = "git+https://git.nju.edu.cn/nix-mirror/nixpkgs?ref=nixpkgs-unstable&shallow=1";
    flake-parts.url = "git+https://gitcode.com/gh_mirrors/fl/flake-parts";
    nixos-unified.url = "git+https://gitee.com/linuxwhata/nixos-unified";
    hardware.url = "git+https://gitee.com/mirrors/nixos-hardware";
    impermanence.url = "git+https://git.nju.edu.cn/nix-mirror/impermanence";
    home-manager = {
      url = "git+https://gitee.com/mirrors/home-manager-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
    };
    betterfox = {
      url = "git+https://gitcode.com/GitHub_Trending/be/Betterfox";
      flake = false;
    };
    wechat = {
      url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
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

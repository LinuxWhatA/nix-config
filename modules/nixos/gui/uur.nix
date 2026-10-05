{ flake, pkgs, ... }:

{
  imports = [
    flake.inputs.uur.nixosModules.default
  ];

  programs.uur = {
    enable = true;
    # overlay 里的版本（wine 换成 staging），上游模块默认取 inputs.uur 自带包
    package = pkgs.uur;
  };
}

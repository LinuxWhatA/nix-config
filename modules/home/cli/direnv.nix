# direnv
{
  # https://nixos.asia/en/direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global = {
      # 让 direnv 输出更简洁
      hide_env_diff = true;
    };
  };
}

{
  flake,
  config,
  pkgs,
  ...
}:

let
  # 会话启动交给官方脚本：DRM 探测、outputs.conf、Xwayland 检查、target 生命周期都在里面，
  # 自写启动逻辑必漏其中几项
  denialSession = pkgs.writeShellScript "denial-session" ''
    # 插件管理器是独立包，官方脚本却默认指向主包内不存在的 denial-plugins；显式指定以免
    # 依赖会话 PATH（greetd 给的 PATH 不含 sw/bin）
    export DENIAL_PLUGINS_BINARY=${config.programs.denial.plugins.package}/bin/denial-plugins
    ${config.programs.denial.package}/bin/denial-session "$@"
  '';
in
{
  imports = [ flake.inputs.denial.nixosModules.default ];

  programs.denial = {
    enable = true;
    plugins.enable = true;
  };

  # wlr 与 gtk 都不实现 Secret，denial 模块也没配，不指派则凭据通道无人承接
  xdg.portal.config.denial."org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${denialSession}";
          user = flake.config.me.username;
        };
      };
    };
    upower.enable = true;
    gnome.gnome-keyring.enable = true;
  };
}

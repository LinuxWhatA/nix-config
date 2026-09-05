# Noctalia 桌面伴侣（launcher/dock/bar/剪贴板/控制中心）的用户态声明。
# programs.noctalia 的选项由上游 homeModules.default 提供，本文件是纯 HM 模块，
# 故归 home/gui（autowire 扫入 nixos 树会误暴成 nixosModules.desktop.noctalia）。
{
  flake,
  config,
  lib,
  pkgs,
  ...
}:
let
  # 存储主密钥属于运行时用户数据，不能写进 /nix/store（全局可读，等于明文泄露）。
  # 这里只声明"如何生成"，由 noctalia 服务启动前按需生成：装机后无需任何手工介入。
  # 形如 nixpkgs 中 lldap 的 jwt_secret、roundcube 的 des_key：缺失时才生成，已存在不动。
  storageKey = "${config.xdg.dataHome}/noctalia/storage-key";
  ensureStorageKey = pkgs.writeShellScript "noctalia-storage-key" ''
    set -eu
    if [ -s "${storageKey}" ]; then exit 0; fi
    mkdir -p "$(dirname "${storageKey}")"
    umask 077
    ${lib.getExe pkgs.openssl} rand -hex 32 > "${storageKey}"
  '';
in
{
  imports = [
    flake.inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    settings = {
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };
      bar.default = {
        margin_ends = 0;
        start = [
          "launcher"
          "workspaces"
          "media"
        ];
        end = [
          "network_tx"
          "network_rx"
          "tray"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "battery"
          "session"
        ];
      };
      widget = {
        clock = {
          format = "{:%m月%d日 周%a %H:%M}";
        };
        network = {
          show_label = false;
        };
        network_rx = {
          glyph = "arrow-narrow-down";
          visualization = "none";
        };
        network_tx = {
          glyph = "arrow-narrow-up";
          visualization = "none";
        };
      };
      dock = {
        enabled = true;
        auto_hide = true;
        launcher_position = "start";
        reserve_space = false;
        show_dots = true;
        pinned = [
          "kitty"
          "thunar"
          "clash-verge"
          "code"
          "firefox"
        ];
      };
      hot_corners = {
        enable = true;
        top_left = {
          action = "launcher";
        };
      };
      osd.kinds = {
        keyboard_layout = false;
      };
      # 空闲熄屏由 noctalia 原生 idle.behavior 处理（官方 services/idle.mdx）：
      # 到点自动熄屏、活动即恢复，无需外部命令或具体输出名；timeout=300 对齐 5 分钟空闲。
      # pre_action_fade_seconds = 0：不预渐晕遮罩，到点立即熄。
      idle = {
        pre_action_fade_seconds = 0;
        behavior."screen-off" = {
          action = "screen_off";
          timeout = 300;
        };
      };
      # greetd 免认证自动登录，login keyring 不会解锁，secret-service 取不到主密钥；
      # 文件主密钥（见上方 ensureStorageKey）在服务启动前生成，剪贴板历史才能加密落盘
      storage = {
        key_source = "file";
        key_file = storageKey;
      };
      shell = {
        # 由 noctalia 自身注册 org.freedesktop.PolicyKit1 认证代理，
        # 认证弹窗走 shell 面板（默认 floating + center），无需外部 agent 进程
        polkit_agent = true;
        panel.clipboard_position = "top_right";
      };
    };
  };

  # ExecStartPre 保证密钥一定先于 noctalia 进程生成；已有密钥不会被覆盖
  systemd.user.services.noctalia.Service.ExecStartPre = ensureStorageKey;
}

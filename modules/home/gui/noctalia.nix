# Noctalia 桌面伴侣（launcher/dock/bar/剪贴板/控制中心）的用户态声明。
# 选项全部来自上游 homeModules.default（下方 imports），属纯 HM 模块，
# 必须放 home/gui：autowire 会把 modules/nixos 子树暴露成 nixos 模块，
# 一段纯 HM 配置若落到那边就会被误当系统模块接线。
{
  flake,
  config,
  lib,
  pkgs,
  ...
}:
let
  # 主密钥属运行时用户数据，写入 /nix/store 即明文（store 全局可读），故只声明生成逻辑，
  # 由 noctalia 启动前补生成、装机零手工（同 nixpkgs 的 lldap jwt_secret 先例）。
  # 生成幂等：已存在则不动，否则每次重建都轮换密钥，旧密钥加密的数据将永久无法解密。
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
        enabled = true;
        top_left = {
          action = "launcher";
        };
      };
      osd.kinds = {
        keyboard_layout = false;
      };
      # 空闲熄屏/活动恢复由 idle.behavior 处理。labwc 是 wlroots，无合成器输出电源 IPC：
      # 原生 screen_off 会经 ext-workspace 后端跑 `wlr-randr --off`，发布版强制先 `--output`、
      # 必失败，故按官方 compositor-settings/labwc.mdx 改用 wlopm 命令。
      # wlopm 输出名按 glob 匹配（非 shell 展开），`'*'` 即全部输出，单条覆盖多屏/热插拔；
      # 命令经 /bin/sh 执行，单引号防 `*` 被 shell 展开。timeout=300（5 分钟）；
      # pre_action_fade_seconds=0：免渐晕遮罩，到点立即熄。
      idle = {
        pre_action_fade_seconds = 0;
        behavior."screen-off" = {
          action = "command";
          timeout = 300;
          command = "${lib.getExe pkgs.wlopm} --off '*'";
          resume_command = "${lib.getExe pkgs.wlopm} --on '*'";
        };
      };
      # 默认 secret-service 主密钥取不到——greetd 免认证登录不解锁 login keyring，
      # 故改用文件主密钥；生成与启动时序见 ensureStorageKey / ExecStartPre
      storage = {
        key_source = "file";
        key_file = storageKey;
      };
      shell = {
        # 用 noctalia 自带 polkit 认证代理（org.freedesktop.PolicyKit1）：
        # 弹窗走 shell 面板，无需再注册外部 agent 进程
        polkit_agent = true;
        panel.clipboard_position = "top_right";
      };
    };
  };

  # HM 用户服务无 preStart 钩子；用 ExecStartPre 保证密钥先于 noctalia 进程就绪
  systemd.user.services.noctalia.Service.ExecStartPre = ensureStorageKey;
}

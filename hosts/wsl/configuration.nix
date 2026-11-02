{
  flake,
  pkgs,
  lib,
  ...
}:
{
  wsl = {
    enable = true;
    defaultUser = flake.config.me.username;
    interop.register = true; # 解决 binfmt 冲突
    useWindowsDriver = true; # WSLg OpenGL 用 Windows 宿主驱动
    wslConf.interop = {
      enabled = true; # 启用互操作功能
      appendWindowsPath = false; # 不附加Windows PATH以提升速度
    };
    startMenuLaunchers = true;
    tarball.configPath = flake.inputs.self; # /etc/nixos 由 tarball 写入仓库快照（可写，可在 guest 内 rebuild）
  };
  # WSL 原生挂载 binfmt_misc，而 binfmt 模块因 registrations 非空生成同名
  # automount，与既有挂载冲突（"already a mount point"）；systemd-binfmt 已禁用，
  # 该单元无用，故抑制以免误报。
  systemd = {
    suppressedSystemUnits = [ "proc-sys-fs-binfmt_misc.automount" ];
    services.systemd-binfmt.enable = false;
  };
  services.envfs.enable = lib.mkForce false;

  # 交换与内存额度由 Windows 的 .wslconfig 管，guest 再开 zram 只是和宿主争内存
  zramSwap.enable = false;

  networking.hostName = "wsl";

  environment = {
    # /etc/nixos 已由 tarball.configPath 提供，不再挂 base/host.nix 的只读 store 链接
    etc."nixos".enable = false;

    systemPackages = with pkgs; [
      xdg-utils # xdg-open/xdg-mime，Windows 侧默认程序打开文件依赖
      glib # xdg-open 无桌面环境时的 gio 兜底
      tray-tui # TUI 系统托盘
    ];
    # WSLg 合成器独占 zwp_input_method_v1，fcitx5 的 wayland 前端绑定被拒而崩溃
    # （microsoft/wslg#1430），故只能走 X11 前端，GUI 应用须强制 XWayland 后端。
    # 这些变量是全局 PAM 会话级（SSH/TTY 也会读到），与 base/locale.nix 的"避免污染
    # tty/SSH"原则相悖；WSL 无真实 TTY 且默认无 SSH，故接受该取舍——若日后启用 SSH，
    # 需按会话过滤这些变量。
    sessionVariables = {
      # greetd 是系统服务，其 PAM 会话拿不到 WSLg 注入的显示变量；wlroots 自动后端
      # 靠 WAYLAND_DISPLAY 选 Wayland（否则落 DRM 报 "unable to create backend"）。
      # DISPLAY 是 WSLg 的 X0，labwc 拉起自己的 Xwayland 后会给子进程覆盖成其 display。
      WAYLAND_DISPLAY = "wayland-0";
      DISPLAY = ":0";
      # nixpkgs 在 waylandFrontend=true 时不导出这两个变量，而本桌面走 X11 恰恰需要
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      # Qt 6.8.2+ 使用 QT_IM_MODULES 回退机制；Qt < 6.8.2 需要 QT_IM_MODULE=fcitx
      QT_IM_MODULES = "wayland;fcitx;ibus";
      # SDL2 应用需要显式指定；GLFW 用 ibus 协议连 fcitx
      SDL_IM_MODULE = "fcitx";
      GLFW_IM_MODULE = "ibus";
      # WSLg 的 Wayland 客户端拿不到外部 IME，全部走 XWayland 才有输入法
      GDK_BACKEND = "x11";
      QT_QPA_PLATFORM = "xcb";
      # 覆盖全局 NIXOS_OZONE_WL=1：Chromium/Electron 会加 --ozone-platform-hint=auto
      # 走 Wayland 而失去输入法，置空回落默认 X11。
      NIXOS_OZONE_WL = lib.mkForce "";
      # Firefox 的 wrapper 默认 MOZ_ENABLE_WAYLAND=1；本机全走 X11 才有输入法。
      # 必须放 PAM 会话层：noctalia 等 systemd/D-Bus 拉起的进程不继承 labwc 的
      # environment 文件，只有会话级变量能覆盖到它们。
      MOZ_ENABLE_WAYLAND = "0";
    };
  };

  # WSLg 把 /tmp/.X11-unix 挂成只读 tmpfs 且不带 sticky bit（0777）：wlroots 的
  # Xwayland 因 "sticky bit not set" 拒绝建 socket，而本桌面全走 X11 后端，故须重挂
  # rw 补 sticky，并赶在 tmpfiles-setup 之前（其 x11.conf 的 `D ... 1777` 只在可写时
  # chmod 才不报错）。普通服务默认 After=sysinit.target 会与 tmpfiles-setup 的
  # Before=sysinit.target 成排序环，故 DefaultDependencies=false 按 remount-fs 惯例排。
  systemd.services."fix-x11-socket-dir" = {
    description = "Make /tmp/.X11-unix writable with sticky bit for Xwayland";
    wantedBy = [ "sysinit.target" ];
    after = [ "local-fs.target" ];
    before = [
      "systemd-tmpfiles-setup.service"
      "greetd.service"
    ];
    unitConfig = {
      # 目录不存在说明 WSLg 未启用，跳过即可；再加挂载点判定，防目录存在但
      # 非 WSLg 挂载（残留普通目录）时 remount 失败把单元打红。
      ConditionPathIsDirectory = "/tmp/.X11-unix";
      ConditionPathIsMountPoint = "/tmp/.X11-unix";
      DefaultDependencies = false;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # 不吞错误：失败时单元变红并进 journal，否则只剩下游 "cannot open display"
      ExecStart = "${pkgs.writeShellScript "fix-x11-socket-dir" ''
        set -eu
        ${pkgs.util-linux}/bin/mount -o remount,rw /tmp/.X11-unix
        ${pkgs.coreutils}/bin/chmod 1777 /tmp/.X11-unix
      ''}";
    };
  };

  # WSL 无可用 VT（nixos-wsl 关 console：vt_get_current 越界、vt_waitactive 报 ENXIO），
  # greetd 任一 Terminal 模式都拉不起会话，故 vt="none" 走 Stdin 跳过 tty/VT 等待；
  # 本机是图形 autologin，不依赖终端交互。
  services.greetd.settings.terminal.vt = lib.mkForce "none";

  # vt="none" 不设 XDG_VTNR，而 greetd 固定把会话记为 seat0 上的 greeter；logind 对
  # seat0 要求 VTNr 非 0（否则 CreateSession 回 InvalidParameter），故在 pam_systemd
  # 之前经 pam_env 注入 XDG_VTNR=1。
  environment.etc."pam/environment-greetd".text = ''
    XDG_VTNR DEFAULT=1
  '';

  # 只追加一条规则：nixpkgs 的 greetd 模块已用 useDefaultRules=false 定义 session 栈
  # （login include，order 10100），这里加 pam_env 并以 order=100 排到它之前即可；
  # 不必 mkForce 重建——重建要重复定义 login，还会屏蔽 nixpkgs 未来对规则栈的更新。
  security.pam.services.greetd.rules.session.greetd-env = {
    control = "required";
    modulePath = "${pkgs.pam}/lib/security/pam_env.so";
    order = 100;
    settings = {
      conffile = "/etc/pam/environment-greetd";
      readenv = 0;
    };
  };

  # WSL 的 login 重启会清空 /run/user/<uid>，破坏用户会话与 session DBus
  # （WSL#10205），故声明式启用 linger 保住用户实例。
  # 注意：WSL < 2.6.0 时 linger 会让 systemd 先建 /run/user/<uid>，随后 WSLg 的
  # login 挂载（tmpfs）盖在其上并隐藏 session bus（hy2k.dev 2026-10 复测），须
  # WSL >= 2.6.0（PR microsoft/WSL#13101 移除该挂载，#10205 已关闭）才纯粹安全。
  users.users.${flake.config.me.username}.linger = true;

  security.sudo-rs.wheelNeedsPassword = false;
}

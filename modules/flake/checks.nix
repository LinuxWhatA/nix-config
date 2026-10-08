# 承诺闸门：`nix flake check` 除了"配置能求值"，还断言各主机确实交付了刻意保留的东西
# （无登录墙的会话链、keyring 与门户 Secret、磁盘骨架、ntfs 数据盘）。
#
# 每条断言都写成"条件式不变量"：前提成立才校验（有图形会话才查图形栈、有 ntfs 挂载才查挂载
# 选项）。这样规则与具体机器无关——wsl/test 这类没有桌面栈的主机不会被误报，新增主机也自动
# 纳入，不必再来这里登记。判据只读配置、不做构建；新增承诺时照抄一行。
{
  config,
  lib,
  withSystem,
  ...
}:
let
  hosts = config.flake.nixosConfigurations;
  me = config.me.username;
  # 只借 pkgs 造 check 产物，与某一台具体主机无关：naix 改名或删除不该让门禁先炸。
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # 读不到的选项一律当前提不成立（`or` 兜属性缺失，未赋值的 option 会 throw，由 safe 兜）：
  # 缺项是"这台主机没有这个东西"，不是缺口。
  invariants =
    name: cfg:
    let
      c = cfg.config;
      hasOpt = f: o: lib.elem o (f.options or [ ]);
      ntfs = lib.filter (f: f.fsType == "ntfs") (lib.attrValues (c.fileSystems or { }));

      greetdOn = c.services.greetd.enable or false;
      autologinUser = c.services.getty.autologinUser or null;
      sshdOn = c.services.openssh.enable or false;

      # 图形会话的两半：启动链接的是 labwc，配置来自 Home-manager
      labwcSession = lib.hasInfix "labwc-session" (
        c.services.greetd.settings.default_session.command or ""
      );
      hmLabwc = c.home-manager.users.${me}.wayland.windowManager.labwc.enable or false;
      graphical = labwcSession || hmLabwc;
      # portal 的 config 默认 {}：取深层键缺了就报缺口，而不是求值报错
      portalSecret = lib.any (g: (g."org.freedesktop.impl.portal.Secret" or [ ]) != [ ]) (
        lib.attrValues (c.xdg.portal.config or { })
      );

      sudoRs = c.security.sudo-rs.enable or false;
      sudo = c.security.sudo.enable or false;
    in
    [
      {
        n = "${name}: 主机名与配置名一致";
        ok = c.networking.hostName == name;
      }
      {
        # Home-manager 由 autowire 注入，但用户模块须逐主机经 home-manager.users.<me>.imports
        # 接线，而该选项无法给默认值：漏写的主机会静默地没有任何用户环境
        n = "${name}: Home-manager 用户环境已接线";
        ok = c.home-manager.users.${me}.programs.zsh.enable or false;
      }
      {
        n = "${name}: nix channel 关闭（一律走 flake）";
        ok = !c.nix.channel.enable;
      }
      {
        n = "${name}: 免密入口一律落到 me（全链不留登录墙）";
        ok =
          (!greetdOn || c.services.greetd.settings.default_session.user == me)
          && (autologinUser == null || autologinUser == me);
      }
      {
        n = "${name}: 提权实现唯一";
        ok = (sudoRs || sudo) && !(sudoRs && sudo);
      }
      {
        n = "${name}: sshd 若开则拒 root 与密码登录";
        ok =
          !sshdOn
          || (
            c.services.openssh.settings.PermitRootLogin == "no"
            && c.services.openssh.settings.PasswordAuthentication == false
          );
      }
      {
        n = "${name}: 根是 tmpfs 时 /persist 必须 neededForBoot";
        ok =
          (c.fileSystems."/".fsType or "") != "tmpfs" || (c.fileSystems."/persist".neededForBoot or false);
      }
      {
        # 内核不认 ntfs 的 force 选项；数据盘起不来不该拖住整机，故 nofail 是硬要求
        n = "${name}: ntfs 挂载走内核驱动且 nofail 不带 force";
        ok =
          ntfs == [ ]
          || (
            (c.boot.supportedFilesystems.ntfs or false)
            && lib.all (f: hasOpt f "nofail" && !(hasOpt f "force")) ntfs
          );
      }
      {
        n = "${name}: greetd 拉的会话在 Home-manager 里确有配置";
        ok = !labwcSession || hmLabwc;
      }
      {
        n = "${name}: 图形会话的必备栈齐全（PipeWire/蓝牙/keyring/Secret 门户）";
        ok =
          !graphical
          || (
            (c.services.pipewire.enable or false)
            && (c.hardware.bluetooth.enable or false)
            && (c.services.gnome.gnome-keyring.enable or false)
            && portalSecret
          );
      }
    ];

  claims = lib.concatLists (lib.mapAttrsToList invariants hosts);

  # 断言碰到"未赋值 option"（如未配置的 greetd.settings）会抛 throw，`or` 兜不住：统一折算成
  # 缺口，否则一处缺口会把整棵 flake 求值打挂。属性缺失（未导入的模块）另由各处 `or` 兜。
  safe =
    c:
    let
      r = builtins.tryEval c.ok;
    in
    {
      inherit (c) n;
      ok = r.success && r.value;
    };

  fails = lib.filter (c: !c.ok) (map safe claims);
in
{
  flake.checks.x86_64-linux.host-baseline =
    if fails == [ ] then
      pkgs.runCommand "host-baseline-ok" { } "echo '各主机既定承诺都在' > $out"
    else
      # 失败留成一个"红了的 check"（有名字、有构建日志），而不是把整棵 flake 求值打挂
      pkgs.runCommand "host-baseline-gaps" { } ''
        printf 'host-baseline 缺口：%s\n' "${lib.concatMapStringsSep "；" (c: c.n) fails}" >&2
        exit 1
      '';
}

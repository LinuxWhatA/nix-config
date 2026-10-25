# 承诺闸门：`nix flake check` 除了"配置能求值"，还断言各主机确实交付了刻意保留的东西：
# 无登录墙的会话链（免密入口一律落到 me）、图形栈三大件与 Secret 门户、Home-manager
# 用户环境接线、持久化与数据盘的启动安全、sshd hardening。
#
# 每条断言都写成"条件式不变量"：前提成立才校验（有图形会话才查图形栈、有 ntfs 挂载才查挂载
# 选项、sshd 开了才查 hardening）。这样规则与具体机器无关——wsl/test 这类没有桌面栈的主机
# 不会被误报，新增主机也自动纳入，不必再来这里登记。判据只读配置、不做构建；新增承诺时照抄一行。
#
# 收录标准（奥卡姆剃刀）：只留"静默或延迟发生"的缺口。模块系统求值自会红的事（如 sudo 与
# sudo-rs 同开必撞 security.wrappers.sudo）、默认值本就如此的事（nix.channel.enable 默认
# 关）、命名卫生（主机名与配置名一致）都不占位——它们要么到不了红，要么红了也不是交付缺口。
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

  invariants =
    name: cfg:
    let
      c = cfg.config;
      hasOpt = f: o: lib.elem o (f.options or [ ]);
      ntfs = lib.filter (f: f.fsType == "ntfs") (lib.attrValues (c.fileSystems or { }));

      greetdOn = c.services.greetd.enable or false;
      autologinUser = c.services.getty.autologinUser or null;
      # sddm/cosmic-greeter 等通用 DM 的自动登录同属无密码入口（naix/redmi 的现役路径）
      dmAutoLoginUser = c.services.displayManager.autoLogin.user or null;
      sshdOn = c.services.openssh.enable or false;

      # 未赋值的 option 一访问就抛错，`or` 兜不住（会被下层 safe 折成假缺口），故统一走 tryEval
      read =
        fallback: f:
        let
          r = builtins.tryEval f;
        in
        if r.success then r.value else fallback;

      # 有图形会话只看会话注册表：合成器登记在 displayManager 下，greetd 直拉与 target 只是下游表现
      graphical = (read [ ] c.services.displayManager.sessionPackages) != [ ];
      # portal 的 config 默认 {}：取深层键缺了就报缺口，而不是求值报错
      # Secret 只两条来路：xdg.portal.config 显式指派，或桌面自带的 portal 配置包
      # （*-portals.conf，由上游桌面接管，如 Plasma 的 kde-portals.conf）。包内文件纯 eval
      # 读不到——读它要么触发构建、要么碰本机 store 碰运气，包也无元数据声明，故只校验来路
      # 存在、不逐包验证内容；手写 config 还会整文件遮蔽配置包，得不偿失
      portalSecret =
        lib.any (g: (g."org.freedesktop.impl.portal.Secret" or [ ]) != [ ]) (
          lib.attrValues (read { } c.xdg.portal.config)
        )
        || (read [ ] c.xdg.portal.configPackages) != [ ];
    in
    [
      {
        # Home-manager 由 autowire 注入，但用户模块须逐主机经 home-manager.users.<me>.imports
        # 接线，而该选项无法给默认值：漏写的主机会静默地没有任何用户环境
        n = "${name}: Home-manager 用户环境已接线";
        ok = c.home-manager.users.${me}.programs.zsh.enable or false;
      }
      {
        n = "${name}: 免密入口一律落到 me（全链不留登录墙）";
        ok =
          (!greetdOn || c.services.greetd.settings.default_session.user == me)
          && (autologinUser == null || autologinUser == me)
          && (dmAutoLoginUser == null || dmAutoLoginUser == me);
      }
      {
        # base/openssh 的 hardening 是统一交付：被整段删掉时无任何报错，sshd 只会静默回退到
        # 上游默认（PermitRootLogin=prohibit-password、密码登录敞开），故留此断言
        n = "${name}: sshd 若开则拒 root 与密码登录";
        ok =
          !sshdOn
          || (
            c.services.openssh.settings.PermitRootLogin == "no"
            && c.services.openssh.settings.PasswordAuthentication == false
          );
      }
      {
        # 测试箱只声明 tmpfs 根、不挂持久化根，无从谈 neededForBoot：把"声明了 /persist"也算进
        # 前提，这条才对没有持久化根的主机成立
        n = "${name}: 根是 tmpfs 时 /persist 必须 neededForBoot";
        ok =
          (c.fileSystems."/".fsType or "") != "tmpfs"
          || (c.fileSystems."/persist" or null) == null
          || (read false c.fileSystems."/persist".neededForBoot);
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

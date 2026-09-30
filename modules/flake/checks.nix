# 承诺闸门：`nix flake check` 除了"配置能求值"，还断言各主机确实交付了刻意保留的东西。
# 每条断言对应一处有意为之的选择（无登录墙的会话链、keyring 与门户 Secret、磁盘骨架、
# ntfs 数据盘、wsl 的让路），改动把它们弄丢时应在 check 里响亮失败，而不是等某台机器
# 行为不同才发现。判据只读配置、不做构建；新增承诺时照抄一行。
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

  # 四台主机都由 autowire 注入 Home-manager，但用户模块须逐主机经
  # home-manager.users.<me>.imports 接线，而该选项无法给默认值：漏写的主机会静默地
  # 没有任何用户环境。
  common = name: cfg: [
    {
      n = "${name}: 主机名与配置名一致";
      ok = cfg.config.networking.hostName == name;
    }
    {
      n = "${name}: Home-manager 用户环境已接线（cli 模块生效）";
      ok = cfg.config.home-manager.users.${me}.programs.zsh.enable or false;
    }
    {
      n = "${name}: nix channel 关闭（一律走 flake）";
      ok = !cfg.config.nix.channel.enable;
    }
  ];

  # naix/redmi 共用 desktop-host
  desktop =
    name: cfg:
    let
      inherit (cfg.config)
        boot
        fileSystems
        hardware
        security
        services
        xdg
        ;
      isNtfs = fs: fs.fsType == "ntfs";
      hasOpt = fs: opt: lib.elem opt (fs.options or [ ]);
    in
    [
      {
        n = "${name}: greetd 免密直拉 labwc 会话（无 greeter、无登录墙）";
        ok =
          lib.hasInfix "labwc-session" services.greetd.settings.default_session.command
          && services.greetd.settings.default_session.user == me;
      }
      {
        n = "${name}: getty 控制台免密直达（单用户机，全链不留登录墙）";
        ok = services.getty.autologinUser == me;
      }
      {
        n = "${name}: gnome-keyring 在位（Secret Service）";
        ok = services.gnome.gnome-keyring.enable;
      }
      {
        n = "${name}: 门户 Secret 接口有后端（wlr/gtk 都不实现）";
        # portal 的 config 默认 {}：取深层键缺了就报缺口，而不是求值报错
        ok = (xdg.portal.config.labwc."org.freedesktop.impl.portal.Secret" or [ ]) != [ ];
      }
      {
        n = "${name}: PipeWire";
        ok = services.pipewire.enable;
      }
      {
        n = "${name}: 蓝牙";
        ok = hardware.bluetooth.enable;
      }
      {
        n = "${name}: sshd 拒 root 与密码登录";
        ok =
          services.openssh.enable
          && services.openssh.settings.PermitRootLogin == "no"
          && services.openssh.settings.PasswordAuthentication == false;
      }
      {
        n = "${name}: sudo-rs 是唯一提权实现";
        ok = security.sudo-rs.enable && !security.sudo.enable;
      }
      {
        n = "${name}: 根是 tmpfs，持久化落在 /persist";
        ok = (fileSystems."/".fsType or "") == "tmpfs" && (fileSystems."/persist".neededForBoot or false);
      }
      {
        # 空集合上的 lib.all 恒真，故先要求"确实存在 ntfs 挂载"再逐条校验
        n = "${name}: ntfs 数据盘 nofail 且不带 force（内核不认 force）";
        ok =
          let
            ntfs = lib.filter isNtfs (lib.attrValues fileSystems);
          in
          ntfs != [ ] && lib.all (fs: hasOpt fs "nofail" && !(hasOpt fs "force")) ntfs;
      }
      {
        n = "${name}: ntfs 交给内核驱动（supportedFilesystems）";
        ok = boot.supportedFilesystems.ntfs or false;
      }
      {
        n = "${name}: initrd 能跑 aarch64 二进制（binfmt）";
        ok = lib.elem "aarch64-linux" (boot.binfmt.emulatedSystems or [ ]);
      }
      {
        n = "${name}: plymouth 静默启动（550w 主题）";
        ok = boot.plymouth.enable && boot.plymouth.theme == "550w";
      }
      {
        n = "${name}: envfs 提供 /usr/bin 兜底";
        ok = services.envfs.enable;
      }
      {
        n = "${name}: labwc 的会话配置来自 Home-manager";
        ok = cfg.config.home-manager.users.${me}.wayland.windowManager.labwc.enable or false;
      }
    ];

  # redmi 独有的硬件事实：丢了会静默降级（电源档位卡死、BIOS 表缺陷复现）
  redmiHw = name: cfg: [
    {
      n = "${name}: 屏蔽 bitland_mifs_wmi（否则 ppd 档位卡死）";
      ok = lib.elem "bitland_mifs_wmi" (cfg.config.boot.blacklistedKernelModules or [ ]);
    }
    {
      n = "${name}: initrd 前置 DSDT 覆盖（BIOS PPPB 越界修复）";
      ok = lib.any (p: lib.hasInfix "redmi-acpi-table" p) (cfg.config.boot.initrd.prepend or [ ]);
    }
  ];

  # wsl 是唯一不经 desktop-host 的实机，它靠"关掉"而非"加上"若干东西
  wslOnly =
    name: cfg:
    let
      # nixos-wsl 未导入时 config 里根本没有 wsl 键：属性缺失只有 `or` 兜得住（tryEval 不兜）
      wsl = cfg.config.wsl or { };
    in
    [
      {
        n = "${name}: wsl 模块启用且用 Windows 侧驱动";
        ok = (wsl.enable or false) && (wsl.useWindowsDriver or false);
      }
      {
        n = "${name}: 会话用户是 me（Windows 侧入口）";
        ok = (wsl.defaultUser or "") == me;
      }
      {
        n = "${name}: systemd-binfmt 关闭（与 Windows interop 冲突）";
        ok = !cfg.config.systemd.services.systemd-binfmt.enable;
      }
      {
        n = "${name}: wheel 组免密 sudo";
        ok = !cfg.config.security.sudo-rs.wheelNeedsPassword;
      }
      {
        n = "${name}: /etc/nixos 让路（tarball 构建要往那里写）";
        ok = !cfg.config.environment.etc."nixos".enable;
      }
      {
        n = "${name}: envfs 关闭（FUSE 在 WSL 下不可用）";
        ok = !cfg.config.services.envfs.enable;
      }
    ];

  # 主机 → 它要遵守的专属分组（common 对所有主机自动生效）。断言按 hosts 遍历、分组从这张表
  # 查，于是两张名单漂移时由下面的集合断言报告，而不是中途变成求值错误。
  perHost = {
    naix = [ desktop ];
    redmi = [
      desktop
      redmiHw
    ];
    test = [ ];
    wsl = [ wslOnly ];
  };

  claims =
    lib.concatLists (
      lib.mapAttrsToList (name: cfg: lib.concatMap (group: group name cfg) (perHost.${name} or [ ])) hosts
    )
    ++ lib.concatLists (lib.mapAttrsToList common hosts);

  hostSet = {
    n = "每台主机都在分组表里（新增主机须登记进 perHost）";
    ok = lib.attrNames perHost == lib.attrNames hosts;
  };

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

  fails = lib.filter (c: !c.ok) (lib.map safe (claims ++ [ hostSet ]));
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

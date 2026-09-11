# Droidloom：把 Android 应用跑在原生 Wayland 窗口里（运行期载荷见 packages/droidloom-runtime）
#
# 上游只认 Arch/Omarchy：装包靠 pacman，运行时还认一堆 /usr/... 绝对路径（二进制自身、
# helper 读的模板、生成的 cell.json），首次配置由 droidloom-package-helper 以 root 写
# /etc/droidloom 与 polkit 规则。本模块把这套流程搬进 NixOS：
#   - /usr 兼容层：/usr/lib、/usr/share 用符号链接指向 store；/usr/bin 是 envfs 的只读挂载，
#     改走 `services.envfs.extraFallbackPathCommands` 把上游要的名字补进去。
#     注意：cell 关机路径会执行 `vdc volume abort_fuse`，它写 `/sys/fs/fuse/connections/*/abort`，
#     直接作废 FUSE superblock（跨挂载命名空间生效），宿主 envfs 随即变 ENOTCONN——VSCode 的
#     `#!/usr/bin/env`、所有 bash 脚本、甚至 droidloomd 自己都挂。宿主侧无法阻止，只能自愈，
#     故由 envfs-watchdog 定时探测并重挂（见 systemd.services.envfs-watchdog）
#   - cell 的 cgroup 绕法：上游让 Android 跑在非初始 cgroup namespace 里，netd 却用 flags=0
#     往该 ns 的根挂 BPF 程序 → EPERM → netd abort → cell 关机。本模块让 cell 的 init 先 bind，
#     把可见根换成「ns 根的后代」，见 droidloom-netd-rc 与 systemd.services.droidloom-cell-cgroup-fix
#   - 系统服务 droidloomd 与用户服务 droidloom/droidloom-applications 照抄上游单元
#     注意：用户单元**故意不设** wantedBy（不随会话自启），开机后要跑 cell 就一条
#     `droidloomctl start`（实测：该命令会连带把两个用户单元拉起来，denial_socket
#     native-bridge.sock 随之生成，应用目录也能列出；无需先 systemctl --user start）。
#     不要用 `droidloomctl start --cell`：从普通 shell 跑它会因 PATH 里没有 nft 而 ENOENT。
#   - 首次配置仍交回上游 helper（INSTALL.md 里 sudo 的那条路径），做成 oneshot：它写出的
#     /etc/droidloom/* 属运行期状态，且本机 / 是 tmpfs，声明式管不到
#   - polkit 授权本用户起停 droidloomd.service（上游由 helper 写规则文件，这里声明式给）
{
  flake,
  config,
  pkgs,
  ...
}:
let
  me = flake.config.me.username;
  payload = pkgs.droidloom-runtime;
  systemctl = "${config.systemd.package}/bin/systemctl";

  # droidloom-wayland 是外部二进制、没有 rpath，NEEDED 里的 libgbm/libxkbcommon 起不来，
  # 用 wrapper 补 LD_LIBRARY_PATH：libgbm 取 nixpkgs 自己的 gbm 包（mesa 的输出里没有它），
  # /run/opengl-driver/lib 提供系统 DRI 驱动
  droidloom-wayland =
    pkgs.runCommandLocal "droidloom-wayland"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
      }
      ''
        makeWrapper ${payload}/bin/droidloom-wayland $out/bin/droidloom-wayland \
          --prefix LD_LIBRARY_PATH : "${
            pkgs.lib.makeLibraryPath [
              pkgs.libgbm
              pkgs.libxkbcommon
            ]
          }:/run/opengl-driver/lib"
      '';

  # 运行期按裸名调用这些工具（supervisor 用 ip/nft/iptables 建 cell 网络，mount/nsenter/unshare 进命名空间），
  # 而 NixOS 单元的 PATH 只有 coreutils/findutils/grep/sed/systemd，故单元里补上
  runtimePath = with pkgs; [
    coreutils
    iproute2
    iptables
    nftables
    util-linux
  ];

  # 上游 bug 的绕法（上游 issue 草稿见 ~/droidloom/upstream-issue-drafts.md 的 Issue 1）：
  # droidloom 让 Android 跑在**非初始 cgroup namespace** 里，netd 却用 flags=0 往该 ns 的
  # 根 cgroup 挂 BPF 程序 —— 内核一律 EPERM（本机实测矩阵：挂到「ns 根」EPERM，挂到
  # 「ns 根的后代」或带 BPF_F_ALLOW_MULTI 则 OK）。而 cell 的 /sys/fs/cgroup 正是那个 ns 根，
  # 于是 netd abort → netd1shot 的 reboot_on_failure 把 cell 带走，此前的症状就是这么来的。
  # android_file_overrides 的 target 只允许落在 /system 等分区下（不能 bind /sys/fs/cgroup），
  # 所以改成让 cell 的 init 自己 bind：生成一份「先 bind、再原样起 netd」的 rc 顶掉
  # /system/etc/init/netd.rc。bind 的目标目录里必须预建 Android 惯用的 system/（顺带 apps/）：
  # 换根之后 libprocessgroup 仍按 /sys/fs/cgroup/system/<uid>/pid_<n> 造路径，缺了它服务几毫秒就退。
  # 同一份 rc 还顺带把 FUSE 的 abort 接口盖住（cell 关机会作废宿主 envfs，见 rc 里的注释）。
  droidloom-netd-rc = pkgs.runCommandLocal "droidloom-netd.rc" { } ''
    {
      echo "# 由 modules/nixos/virtualization/droidloom.nix 生成（cell 启动前的两处 init 修正）"
      echo "on post-fs-data"
      echo "    # (1) netd 的 cgroup-BPF attach（上游 bug 绕法，见本文件上方注释）"
      echo "    mount none /sys/fs/cgroup/cellroot /sys/fs/cgroup bind"
      echo "    # (2) 收容 FUSE 的 abort 接口：cell 关机会跑 vdc volume abort_fuse，全量作废"
      echo "    #     FUSE superblock（跨挂载命名空间生效），宿主 envfs 的 /usr/bin、/bin 会因为"
      echo "    #     ENOTCONN 整个废掉。内核只暴露 /sys/fs/fuse/connections/<id>/abort 这一处"
      echo "    #     开关，宿主侧无从拦截，故在 cell 内用空目录盖住它：vold 找不到任何连接，"
      echo "    #     宿主 envfs 便不再受影响（envfs-watchdog 仍保留，作为兜底）。"
      echo "    mkdir /dev/empty-fuse"
      echo "    mount none /dev/empty-fuse /sys/fs/fuse/connections bind"
      echo
      cat ${payload}/lib/droidloom/runtime/compat/netd-mainline-bpf.rc
    } > $out
  '';

  # / 是 tmpfs：cellroot 子 cgroup 与 cell.json 的覆盖每开机都要重建（cell.json 由 helper 在开机时重写），
  # 且 helper 之后还可能重写一次，所以这份脚本同时挂在 droidloomd 的 ExecStartPre 上（起 cell 前必跑）。
  # 注意 Nix 的 '' 字符串只剥掉「最靠左那一行的缩进」，所以 heredoc 里的 Python 必须和结束的 '' 同列，
  # 否则会残留缩进 → IndentationError（踩过）。
  droidloom-cell-cgroup-fix = pkgs.writeShellScript "droidloom-cell-cgroup-fix" ''
    set -eu
    root=/sys/fs/cgroup/system.slice/droidloomd.service/cellroot
    mkdir -p "$root/system" "$root/apps"
    ${pkgs.python3}/bin/python3 - "${droidloom-netd-rc}" <<'PY'
    import json, sys
    rc = sys.argv[1]
    path = "/etc/droidloom/cell.json"
    with open(path) as fh:
        d = json.load(fh)
    for o in d["android_file_overrides"]:
        if o.get("target") == "/system/etc/init/netd.rc":
            o["source"] = rc
    with open(path, "w") as fh:
        json.dump(d, fh, ensure_ascii=False, indent=1)
    PY
  '';

  # NixOS 的 uid 由激活期分配（求值期 option 是 null），插不进 ExecStart，故运行时取
  droidloom-setup = pkgs.writeShellScript "droidloom-setup" ''
    set -eu
    uid="$(${pkgs.coreutils}/bin/id -u ${me})"
    home="$(${pkgs.glibc.getent}/bin/getent passwd ${me} | ${pkgs.coreutils}/bin/cut -d: -f6)"
    exec ${payload}/lib/droidloom/droidloom-package-helper setup \
      --uid "$uid" \
      --data-home "$home/.local/share" \
      --state-home "$home/.local/state"
  '';
in
{
  environment.systemPackages = [ payload ];

  # NixOS 的 /usr/bin 是 envfs 的只读挂载，符号链接塞不进去；上游按绝对路径调用的东西
  # （helper 先 `getent passwd <uid>`，再用 mkfs.ext4/runuser/systemctl/pkexec，droidloomd 用 nsenter
  # 进 cell 命名空间）交给 envfs 的 fallback 目录兜底：某名字在 PATH 里找不到时 envfs 回退到这里。
  # 该目录是写进 envfs 挂载选项的，改完要重启 usr-bin.mount（或整机重启）才生效——switch 只 reload 该单元
  services.envfs.extraFallbackPathCommands = ''
    ln -s ${pkgs.e2fsprogs}/bin/mkfs.ext4 $out/mkfs.ext4
    ln -s ${pkgs.glibc.getent}/bin/getent $out/getent
    ln -s ${pkgs.util-linux}/bin/nsenter $out/nsenter
    ln -s ${pkgs.util-linux}/bin/runuser $out/runuser
    ln -s ${pkgs.polkit}/bin/pkexec $out/pkexec
    ln -s ${systemctl} $out/systemctl
    ln -s ${payload}/bin/droidloom-applications $out/droidloom-applications
    ln -s ${payload}/bin/droidloom-supervisor $out/droidloom-supervisor
    ln -s ${payload}/bin/droidloomctl $out/droidloomctl
    ln -s ${droidloom-wayland}/bin/droidloom-wayland $out/droidloom-wayland
  '';

  # 上游契约要求单个连续 100000 段的 subordinate ID（Android 会话靠它映射 UID/GID），
  # NixOS 自动分配只给 65536；起点仍是 100000，既有 rootless 容器文件的属主不受影响
  users.users.${me} = {
    autoSubUidGidRange = false;
    subUidRanges = [
      {
        startUid = 100000;
        count = 100000;
      }
    ];
    subGidRanges = [
      {
        startGid = 100000;
        count = 100000;
      }
    ];
  };

  systemd = {
    services = {
      # rootless Podman 的 cpuset 受 cgroup v2 委派限制：systemd 的 user@.service 默认只委派
      # cpu/io/memory/pids，而 droidloom 构建器固定传 --cpuset-cpus（编译期给桌面留 2 核），
      # 缺 cpuset 时 crun 直接以 "controller `cpuset` is not available" 退出。委派在
      # user@.service 启动时写入 cgroup，故只对重新登录后的会话生效。
      "user@".serviceConfig.Delegate = "cpu cpuset io memory pids";

      # Android 数据（ext4 镜像与用户文件）由 helper 建在 /var/lib/droidloom 下，root 属主
      droidloom-setup = {
        description = "Droidloom configuration and Android data initialization";
        wantedBy = [ "multi-user.target" ];
        before = [ "droidloomd.service" ];
        unitConfig.ConditionPathExists = "!/etc/droidloom/cell.json";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${droidloom-setup}";
        };
      };

      droidloomd = {
        description = "Droidloom Android cell lifecycle daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = runtimePath;
        serviceConfig = {
          Type = "simple";
          # 每次启动都补建 cell 的 cgroup 子树并重写 netd.rc 覆盖（cell 关机会清掉、
          # helper 也可能重写 cell.json，见 droidloom-netd-rc 的注释）
          ExecStartPre = "${droidloom-cell-cgroup-fix}";
          ExecStart = "${payload}/bin/droidloomd";
          RuntimeDirectory = "droidloom";
          RuntimeDirectoryMode = "0755";
          # 失控时只让 cell 自己承担后果（宿主 16 核 / 15 GiB；cell 实测峰值 2.1 GiB /
          # 13 分钟 32 秒 CPU）：软限先限流+回收，硬限再超就只 OOM 掉这个 cgroup，
          # CPU 封顶 8 核给宿主留一半——跑飞的代价比起拖垮宿主小得多。
          MemoryHigh = "12G";
          MemoryMax = "14G";
          CPUQuota = "1400%";
          KillMode = "mixed";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 20;
        };
      };

      # 上游 netd 的 cgroup-BPF EPERM 绕法（详见 droidloom-netd-rc 的注释）：
      # 预建 cell 的 cgroup 子树，并把 /system/etc/init/netd.rc 的覆盖指向我们那份带 bind 的 rc。
      # 必须在 helper 写出 cell.json 之后、droidloomd 之前。
      droidloom-cell-cgroup-fix = {
        description = "Droidloom cell cgroup workaround (upstream netd BPF attach EPERM)";
        wantedBy = [ "multi-user.target" ];
        after = [ "droidloom-setup.service" ];
        before = [ "droidloomd.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${droidloom-cell-cgroup-fix}";
        };
      };

      # envfs 的 FUSE 连接会被 cell 的关机路径作废（详见文件头注释），宿主侧挡不住，只能自愈：
      # 定时探一次 /usr/bin/env，坏了就重挂 usr-bin.mount（几秒内恢复，VSCode、bash 脚本、
      # droidloomd 自己都因此不再需要人工救场）。
      envfs-watchdog = {
        description = "Re-mount envfs when its FUSE connection was aborted";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "envfs-watchdog" ''
            if ! test -e /usr/bin/env; then
              exec ${systemctl} restart usr-bin.mount
            fi
          '';
        };
      };
    };

    # envfs-watchdog 的定时器：只随 droidloomd 首次启动而启动（cell 不跑就不需要自愈），
    # 且不加 partOf——FUSE abort 发生在 cell 关机路径上，绑定停止会在它跑完前撤掉定时器
    timers.envfs-watchdog = {
      wantedBy = [ "droidloomd.service" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "30s";
      };
    };

    # 兼容层：上游二进制与生成的 cell.json 认这些绝对路径；/ 为 tmpfs，故每次启动重建
    tmpfiles.rules = [
      "d /usr/lib 0755 root root -"
      "d /usr/share 0755 root root -"
      "L+ /usr/lib/droidloom - - - - ${payload}/lib/droidloom"
      "L+ /usr/share/droidloom - - - - ${payload}/share/droidloom"
    ];

    user.services = {
      droidloom-applications = {
        description = "Droidloom native application catalog";
        partOf = [ "droidloom.service" ];
        after = [ "droidloom.service" ];
        path = runtimePath;
        unitConfig.ConditionPathExists = "/etc/droidloom/cell.json";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${payload}/bin/droidloom-applications";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      droidloom = {
        description = "Droidloom Android application runtime";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session-pre.target" ];
        wants = [ "droidloom-applications.service" ];
        # 暂不随会话自启（手动 `systemctl --user start droidloom`）：cell 一旦运行会把宿主 envfs 的
        # FUSE 连接作废（`/usr/bin`、`/bin` 全部 ENOTCONN → VSCode 的 `#!/usr/bin/env`、`#!/bin/bash`
        # 脚本全挂）。开机自启等于每次开机都中招；在查清并修掉那个作废者之前先手动起。
        # wantedBy = [ "graphical-session.target" ];
        path = runtimePath;
        unitConfig.ConditionPathExists = "/etc/droidloom/cell.json";
        serviceConfig = {
          Type = "notify";
          NotifyAccess = "main";
          EnvironmentFile = [
            "/etc/droidloom/runtime.env"
            "-%t/droidloom/session.env"
          ];
          Environment = "DROIDLOOM_MODE=desktop";
          ExecStartPre = "${systemctl} start droidloomd.service";
          ExecStart = "${droidloom-wayland}/bin/droidloom-wayland";
          ExecStartPost = "${payload}/bin/droidloomctl start --cell";
          ExecStopPost = [
            "-${payload}/bin/droidloomctl stop --cell"
            "${systemctl} stop droidloomd.service"
          ];
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStartSec = 150;
          TimeoutStopSec = 150;
        };
      };
    };
  };

  security.polkit.extraConfig = ''
    // 用户单元要替桌面用户起停系统守护 droidloomd.service；上游靠 helper 写
    // /etc/polkit-1/rules.d/49-droidloom.rules，这里声明式给出同一条规则
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.systemd1.manage-units"
          && subject.user === "${me}"
          && action.lookup("unit") === "droidloomd.service"
          && (action.lookup("verb") === "start" || action.lookup("verb") === "stop")) {
        return polkit.Result.YES;
      }
    });
  '';
}

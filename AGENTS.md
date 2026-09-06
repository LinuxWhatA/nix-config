# AGENTS.md

NixOS 配置仓库（flake-parts + 自定义目录自动接线）。注释与文档一律中文（含本文件）；新注释只写"为什么"（动机、约束、取舍），禁历史或变更式表述。无 CI、无测试，靠求值验证。单用户仓库，分支 `master`，远端 gitee；提交用约定式提交，主题用中文。

## 目录结构

```
hosts/                         # 各主机配置（naix、redmi、wsl；test = 模块测试箱）
lib/merge-json.nix             # JSON 合并工具（经 overlay 暴露为 pkgs.mergeJson）
modules/                       # NixOS / Home-manager 模块
├── flake/                     # flake 相关模块
│   ├── autowire.nix           # 接线：扫描目录生成 outputs，声明并填充 nixosModules / homeModules
│   ├── config.nix             # 顶层 me 选项（导入 ../../config.nix 的数据）
│   ├── desktop-host.nix       # 桌面主机顶层组合（dendritic：装配为 nixosModules.desktop-host）
│   ├── packages.nix           # 把 overlay 包暴露为 flake packages（唯一来源）
│   └── per-system.nix         # perSystem（pkgs、formatter、devshell、allowUnfree）
├── home/                      # Home-manager 用户模块
│   ├── cli/                   # CLI 工具（git、zsh、nh、fd、direnv…；default.nix 批量导入）
│   └── gui/                   # GUI 应用（firefox、kitty、vscode、noctalia、mangohud…；default 为批量导入）
└── nixos/                     # NixOS 系统模块
    ├── base/                  # 全主机共享基础（default.nix 批量导入：users、host、fonts、openssh 等）
    ├── desktop/               # 桌面环境（console、gnome、plasma6、xfce、cosmic、labwc、niri…）
    ├── gui/                   # GUI 相关系统配置（clash、dev-sidecar、steam、thunar、uudeck）
    ├── hardware/              # 硬件（bluetooth、boot〔含 plymouth〕、graphics、grub、persist）
    ├── services/              # 系统服务（pipewire、v2raya、nfs-server…）
    └── virtualization/        # 虚拟化（docker、qemu、virtualbox、waydroid…）
overlays/default.nix           # overlay：callPackage packages/ 下各包
packages/                      # 自定义包（overlay 是唯一入口）
config.nix                     # 用户身份数据（me.username / email / sshKey）
flake.nix                      # flake 入口
```

## 接线机制（文件如何成为 outputs）

`modules/flake/autowire.nix` 扫描目录生成 flake outputs，同时声明并填充顶层 config 的
`nixosModules` / `homeModules`（`attrsOf raw` 嵌套树）。`scanTree` 借鉴
[vic/import-tree](https://github.com/denful/import-tree)：递归且保留结构，目录 → 嵌套 attrset，
`default.nix` 即键 `"default"`；任意深度、无同名冲突。主机从 config 引用模块（dendritic 装配），
不手写路径：

- `hosts/<host>/default.nix` → `nixosConfigurations.<host>`（主机：`naix`、`redmi`、`wsl`、`test` = 模块测试箱）。每台主机都注入 Home-manager，但其用户模块须逐主机经 `home-manager.users.<me>.imports` 接线——此选项无法给默认值（见 `modules/nixos/base/users.nix`）。
- `modules/nixos/<dir>/<file>.nix` → `nixosModules.<dir>.<file>`（如 `nixosModules.desktop.plasma6`）；`<dir>/default.nix` → `nixosModules.<dir>.default`（bundle，如 `base`）。`modules/home/<dir>/...` 同理（`homeModules.cli.default`、`homeModules.gui.noctalia`）。主机经 `flake.config.nixosModules.*` / `flake.config.homeModules.*` 引用（`flake` = specialArgs，`config` = 顶层 flake-parts config）。
- `modules/flake/desktop-host.nix` 是顶层组合模块：把桌面共享特性合并为 `nixosModules.desktop-host`，桌面主机只需一行 `flake.config.nixosModules.desktop-host`。
- `packages/<name>/default.nix` 由 `overlays/default.nix` callPackage，并经 `modules/flake/packages.nix` 暴露为 `.#<name>`——这是 flake `packages` 输出的唯一来源（autowire 不再生成 packages）。overlay 是唯一真相，修补/包装的包一律放这里。

所有模块都拿到 `specialArgs.flake = { self, inputs, config }`：仓库内路径用 `flake.inputs.self`，
用户身份用 `flake.config.me.username` / `email` / `sshKey`（数据在根 `config.nix`），勿硬编码。

## 常用命令

- 重建：`sudo nixos-rebuild switch --flake .#<host>`（仓库在 `/home/lwa/nix-config`；已配 `nh`，`nh clean` keep-since 30d）
- 快速验证：`nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`；全量检查：`nix flake check`
- 单包构建：`nix build .#<pkg>`
- 格式化（nixfmt，2 空格 RFC 风格）：`nixfmt <file>`，校验 `nixfmt --check <file>`。`nix fmt` 在本仓库不可用（裸 nixfmt 1.4 拒绝无 `-` 的 stdin）
- 静态检查：`nix run nixpkgs#statix -- check .`
- 验证按成本从小到大：定向 `nix eval` → `nixfmt --check <file>` → `statix check .` → 实机 rebuild

## 注意事项

- flake inputs 刻意锁定国内镜像（git.nju.edu.cn / gitee / gitcode），勿"修"回 github。
- `hardware-configuration.nix`（naix/redmi）为手写 + disko 磁盘配置，勿用 `nixos-generate-config` 重生成。
- `allowUnfree = true` 设在 `modules/flake/per-system.nix`；`pkgs.mergeJson`（`lib/merge-json.nix`，经 overlay）用于向应用自管 JSON 注入默认值。
- `direnv allow` 加载 devshell（python + python-registry，供 `packages/bt-keys-info` 用）。
- flake 求值只认 git 已跟踪文件：新文件须先 `git add -N <path>`（intent-to-add：不产生暂存内容，`git reset -- <path>` 可撤销）才会被 `nix eval` / `nix build` 看到。
- `nixos-rebuild switch`（`nh os switch`）只重启被改动的用户服务；涉及会话启动链（greetd → 合成器 → 环境导入 → 守护自启、portal 配置）的改动须重新登录（退出 labwc，greetd 随即重拉）或整机重启验证。
- 读 nixpkgs / home-manager / noctalia 等上游源码前，先取本机已 fetch 的 store 路径再 grep：`nix eval --raw --impure --expr '(builtins.getFlake "<repo>").inputs.<name>.outPath'`，勿急着联网。
- `nixvim` 刻意不 `follows nixpkgs`（上游 pin 自己的 nixpkgs；加了会触发 eval 警告），勿"修"。
- Home-manager 用户服务没有 `preStart`；服务前初始化用 `Service.ExecStartPre`（例：noctalia 存储密钥生成）。

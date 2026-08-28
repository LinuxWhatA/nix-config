# AGENTS.md

NixOS config repo (flake-parts + custom directory autowiring). All comments/docs are in Chinese — write new comments in Chinese. No CI, no tests; verify by evaluating. Single-user, branch `master`, remote gitee; commits use conventional-commit style with Chinese subjects.

## Project structure

```
configurations/nixos/          # NixOS 各系统主机配置（redmi、naix、wsl、test）
lib/merge-json.nix             # JSON 合并工具函数（通过 overlay 暴露为 pkgs.mergeJson）
modules/                       # NixOS/Home-manager 模块目录
├── flake/                     # Flake 相关配置模块
│   ├── autowire.nix           # 接线：目录扫描生成 outputs，声明并填充 nixosModules/homeModules 选项
│   ├── config.nix             # 用户配置（username、email、sshKey 等）
│   ├── desktop-host.nix       # 桌面主机功能组合（dendritic：顶层 config 装配）
│   ├── packages.nix           # overlay 包暴露为 flake packages
│   └── per-system.nix         # perSystem 配置（pkgs、formatter、devshell）
├── home/                      # Home-manager 用户模块
│   ├── cli/                   # CLI 工具模块（git、zsh、nh、fd 等）
│   └── gui/                   # GUI 应用模块（firefox、vscode、winapps 等）
└── nixos/                     # NixOS 系统模块
    ├── base/                  # 基础模块（所有主机共享，含 default.nix 批量导入）
    ├── desktop/               # 桌面环境模块（console、plasma6、gnome、cosmic、xfce）
    ├── gui/                   # GUI 相关模块（clash、plymouth、steam 等）
    ├── hardware/              # 硬件模块（bluetooth、boot、graphics、grub、persist）
    ├── services/              # 服务模块（pipewire、v2raya、nfs-server 等）
    └── virtualization/        # 虚拟化模块（docker、qemu、rdp-windows、virtualbox、waydroid）
overlays/default.nix           # overlay 定义（callPackage packages/ 下的包）
packages/                      # 自定义包目录（通过 overlay 暴露为 flake outputs）
config.nix                     # 用户身份配置（username、email、sshKey）
flake.nix                      # Flake 入口文件
```

## Wiring — how files become outputs

`modules/flake/autowire.nix` 扫描目录生成 flake outputs，同时声明并填充顶层
config 的 `nixosModules` / `homeModules` 选项（类型 `attrsOf raw`，嵌套树）。
`scanTree` 借鉴 [vic/import-tree](https://github.com/denful/import-tree)：
递归 + 结构保留，目录 → 嵌套 attrset，`default.nix` 即键 `"default"`，任意深度、无同名冲突。
主机从 config 引用模块，而非手写路径（dendritic 装配）：

- `configurations/nixos/<host>/default.nix` → `nixosConfigurations.<host>` (hosts: `naix`, `redmi`, `wsl`, `test` = module test box). Home-manager is injected into every host; its user modules must be wired per host via `home-manager.users.<me>.imports` — this option cannot be defaulted (see `modules/nixos/base/users.nix`).
- `modules/nixos/<dir>/<file>.nix` → `nixosModules.<dir>.<file>`（如 `nixosModules.desktop.plasma6`）；`<dir>/default.nix` → `nixosModules.<dir>.default`（bundle，如 `base`）。`modules/home/<dir>/...` 同理（`homeModules.cli.default`、`homeModules.gui.opencode`）。主机经 `flake.config.nixosModules.*` / `flake.config.homeModules.*` 引用（`flake` = specialArgs，`config` = 顶层 flake-parts config）。
- `modules/flake/desktop-host.nix` 是顶层组合模块：把桌面共享特性合并为 `nixosModules.desktop-host`，桌面主机只需一行 `flake.config.nixosModules.desktop-host`。
- `packages/<name>/default.nix` are callPackage'd by `overlays/default.nix` and exposed as `.#<name>` via `modules/flake/packages.nix` — the sole definition of the flake's `packages` output (autowire 不再生成 packages)。The overlay is the single source of truth; put patched/wrapped packages there.

All modules receive `specialArgs.flake = { self, inputs, config }` — use `flake.inputs.self` for repo paths and `flake.config.me.username`/`email`/`sshKey` (root `config.nix`) instead of hardcoding user identity.

## Commands

- Rebuild: `sudo nixos-rebuild switch --flake .#<host>` (repo lives at `/home/lwa/nix-config`; `nh` is configured, `nh clean` keep-since 30d)
- Fast verify: `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`; full check: `nix flake check`
- Build one package: `nix build .#<pkg>`
- Format with nixfmt (2-space RFC style): `nixfmt <file>`, verify `nixfmt --check <file>`. `nix fmt` is broken here (bare nixfmt 1.4 rejects stdin without `-`).

## Gotchas

- Flake inputs intentionally pin Chinese mirrors (git.nju.edu.cn / gitee / gitcode); do not "fix" them to github.
- `hardware-configuration.nix` (naix/redmi) is hand-written with disko disk config — never regenerate with `nixos-generate-config`.
- `allowUnfree = true` set in `modules/flake/per-system.nix`; `pkgs.mergeJson` (from `lib/merge-json.nix` via overlay) is the utility for injecting defaults into app-managed JSON configs.
- `direnv allow` loads the devshell (python + python-registry, used by `packages/bt-keys-info`).

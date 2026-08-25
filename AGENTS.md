# AGENTS.md

NixOS config repo (flake-parts + custom directory autowiring). All comments/docs are in Chinese — write new comments in Chinese. No CI, no tests; verify by evaluating. Single-user, branch `master`, remote gitee; commits use conventional-commit style with Chinese subjects.

## Project structure

```
configurations/nixos/          # NixOS 各系统主机配置（redmi、naix、wsl、test）
lib/merge-json.nix             # JSON 合并工具函数（通过 overlay 暴露为 pkgs.mergeJson）
modules/                       # NixOS/Home-manager 模块目录
├── flake/                     # Flake 相关配置模块
│   ├── autowire.nix           # 自动发现模块，扫描目录生成 flake outputs
│   ├── config.nix             # 用户配置（username、email、sshKey 等）
│   ├── devshell.nix           # 开发环境 shell 配置
│   ├── overlay-packages.nix   # overlay 包暴露配置
│   └── toplevel.nix           # 顶层 flake 配置（allowUnfree 等）
├── home/                      # Home-manager 用户模块
│   ├── cli/                   # CLI 工具模块（git、zsh、nh、fd 等）
│   └── gui/                   # GUI 应用模块（firefox、vscode、wine 等）
└── nixos/                     # NixOS 系统模块
    ├── base/                  # 基础模块（所有主机共享，含 default.nix 批量导入）
    ├── desktop/               # 桌面环境模块（plasma6、gnome、cosmic、xfce）
    ├── desktop-host.nix       # 桌面主机通用配置
    ├── gui/                   # GUI 相关模块（clash、plymouth、steam 等）
    ├── hardware/              # 硬件模块（bluetooth、graphics、grub、persist）
    ├── services/              # 服务模块（pipewire、v2raya、nfs-server 等）
    └── virtualization/        # 虚拟化模块（docker、qemu、virtualbox、waydroid）
overlays/default.nix           # overlay 定义（callPackage packages/ 下的包）
packages/                      # 自定义包目录（通过 overlay 暴露为 flake outputs）
config.nix                     # 用户身份配置（username、email、sshKey）
flake.nix                      # Flake 入口文件
```

## Autowiring — how files become outputs

`modules/flake/autowire.nix` scans directories to generate flake outputs; every file must live where the scanner expects it:

- `configurations/nixos/<host>/default.nix` → `nixosConfigurations.<host>` (hosts: `naix`, `redmi`, `wsl`, `test` = module test box). Home-manager is injected into every host; its user modules must be wired per host via `home-manager.users.<me>.imports` — this option cannot be defaulted (see `modules/nixos/base/users.nix`).
- `modules/nixos/<name>.nix` and `<dir>/default.nix` → `nixosModules`; `modules/home/<dir>/default.nix` → `homeModules` (`cli`, `gui`). Only `modules/nixos/base/` has a bundle `default.nix` importing all siblings — a file added there is auto-enabled on every host importing `base`. Other categories are imported file-by-file.
- `packages/<name>/default.nix` are callPackage'd by `overlays/default.nix` and exposed as `.#<name>` via `modules/flake/overlay-packages.nix`, which `mkForce`-overrides autowire's packages output. The overlay is the single source of truth; put patched/wrapped packages there.
- Constraint: do not add features to `autowire.nix` (keep parity with nixos-unified); new wiring goes in new files under `modules/flake/`.

All modules receive `specialArgs.flake = { self, inputs, config }` — use `flake.inputs.self` for repo paths and `flake.config.me.username`/`email`/`sshKey` (root `config.nix`) instead of hardcoding user identity.

## Commands

- Rebuild: `sudo nixos-rebuild switch --flake .#<host>` (repo lives at `/home/lwa/nix-config`; `nh` is configured, `nh clean` keep-since 30d)
- Fast verify: `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`; full check: `nix flake check`
- Build one package: `nix build .#<pkg>`
- Format with nixfmt (2-space RFC style): `nixfmt <file>`, verify `nixfmt --check <file>`. `nix fmt` is broken here (bare nixfmt 1.4 rejects stdin without `-`).

## Gotchas

- Flake inputs intentionally pin Chinese mirrors (git.nju.edu.cn / gitee / gitcode); do not "fix" them to github.
- `hardware-configuration.nix` (naix/redmi) is hand-written with disko disk config — never regenerate with `nixos-generate-config`.
- `allowUnfree = true` set in `modules/flake/toplevel.nix`; `pkgs.mergeJson` (from `lib/merge-json.nix` via overlay) is the utility for injecting defaults into app-managed JSON configs.
- `direnv allow` loads the devshell (python + python-registry, used by `packages/bt-keys-info`).

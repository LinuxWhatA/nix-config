# AGENTS.md

NixOS 配置仓库（flake-parts + 自定义目录自动接线）。

- 注释与文档一律中文（含本文件）；新注释只写"为什么"（动机、约束、取舍），禁历史或变更式表述。
- 无 CI、无测试：验证靠 `nix flake check`（treefmt 格式/lint + 各主机承诺断言）与实机 rebuild。
- 单用户仓库，分支 `master`，远端 gitee；提交用约定式提交，主题用中文。

## 工作纪律（必读）

- 原则：奥卡姆剃刀、KISS、DRY、YAGNI、SOLID；上游优先用 nixpkgs、Home-manager、NixOS Wiki（ArchWiki 仅参考）。
- 失败观：宁要响亮失败，不要静默兜底；对黑箱应用（如 bin/、*.desktop、cgroup、信号这些外部边界）不猜测其内部。
- 静默试探：当结论明确时直接拒绝原方案，并给出合法路径（官方许可、Windows VM+GPU 直通、原生替代）。
- 小工具放到 `overlays/default.nix`（不要另增 lib/；豁免项：noctalia.settings、死代码、pkgs.<x> 洁癖）。
- 禁止重引入：登录墙、注销自愈、labwc 主题、labwcSession 改道、原生菜单、推迟 plymouth-start、quit 清屏、--retain-splash。

## 目录结构

方向性地图（文件级职责见各文件注释与「接线机制」）：

- `hosts/` — 各主机配置（naix、redmi、wsl；test 是模块测试箱）
- `modules/flake/` — flake 接线与顶层组合（autowire、checks、config、desktop-host、packages、per-system、treefmt、wshell-shell）
- `modules/home/` — Home-manager 用户模块（`cli/`、`gui/`）
- `modules/nixos/` — NixOS 系统模块（`base/`、`desktop/`、`gui/`、`hardware/`、`services/`、`virtualization/`）
- `overlays/` + `packages/` — 自定义包（overlay 是唯一入口）
- `docs/` — 专题笔记；`config.nix` — 用户身份数据；`flake.nix` — flake 入口

## 接线机制（文件如何成为 outputs）

`modules/flake/autowire.nix` 扫描目录生成 flake outputs，同时声明并填充顶层 config 的
`nixosModules` / `homeModules`（`attrsOf raw` 嵌套树）。`scanTree` 借鉴自
[denful/import-tree](https://github.com/denful/import-tree)：递归且保留结构，目录映射为嵌套 attrset，
`default.nix` 即键 `"default"`；任意深度、无同名冲突。主机从 config 引用模块（dendritic 装配），
不手写路径：

- `hosts/<host>/default.nix` 映射为 `nixosConfigurations.<host>`（主机：`naix`、`redmi`、`wsl`、`test`，其中 `test` 是模块测试箱）。每台主机都注入 Home-manager，但其用户模块必须逐主机经 `home-manager.users.<me>.imports` 接线——此选项无法给默认值（见 `modules/nixos/base/users.nix`）。
- `modules/nixos/<dir>/<file>.nix` 映射为 `nixosModules.<dir>.<file>`（如 `nixosModules.desktop.plasma6`）；`<dir>/default.nix` 映射为 `nixosModules.<dir>.default`（bundle，如 `base`）。`modules/home/<dir>/...` 同理（`homeModules.cli.default`、`homeModules.gui.noctalia`）。主机经 `flake.config.nixosModules.*` / `flake.config.homeModules.*` 引用（`flake` 是 specialArgs，`config` 是顶层 flake-parts config）。
- `modules/flake/desktop-host.nix` 是顶层组合模块：把桌面共享特性合并为 `nixosModules.desktop-host`，桌面主机只需一行 `flake.config.nixosModules.desktop-host`。
- `overlays/<name>.nix` 映射为 `overlays.<name>`（本仓仅 `overlays/default.nix` 映射为 `overlays.default`，overlay 是唯一入口）。
- `packages/<name>/default.nix` 由 `overlays/default.nix` callPackage，并经 `modules/flake/packages.nix` 暴露为 `.#<name>`——这是 flake `packages` 输出的唯一来源（autowire 不再生成 packages）。overlay 是唯一真相，修补/包装的包一律放这里。

所有模块都拿到 `specialArgs.flake = { self, inputs, config }`：仓库内路径用 `flake.inputs.self`，
用户身份用 `flake.config.me.username` / `email` / `sshKey`（数据在根 `config.nix`），不要硬编码。

## 常用命令

- 重建：`sudo nixos-rebuild switch --flake .#<host>`（仓库在 `/home/lwa/nix-config`；已配 `nh`，`nh clean` keep-since 30d）
- 快速验证：`nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`；全量检查：`nix flake check`
- 单包构建：`nix build .#<pkg>`
- 格式化与静态检查：`nix fmt`（treefmt 驱动 nixfmt + statix，就地修复），单文件校验 `nixfmt --check <file>`
- 检查：`nix flake check` 即 treefmt（格式 + statix）加 `checks.host-baseline`（各主机承诺断言，失败一次列出全部缺口）。它会连带求值 `packages.*`，冷 store 缺 FOD 时报 `path '…-source.drv' is not valid`，先 `nix eval --raw '.#<pkg>.drvPath'` 预热；只求值用 `--no-build`
- 验证按成本从小到大：定向 `nix eval`，然后 `nix build '.#checks.x86_64-linux.treefmt'`，再 `nix flake check`，最后实机 rebuild

## 注意事项

- flake inputs 刻意锁定国内镜像（git.nju.edu.cn / gitee / gitcode），不要"修"回 github。
- `hardware-configuration.nix`（naix/redmi/test）为手写 + disko 磁盘配置，不要用 `nixos-generate-config` 重生成。
- 读 nixpkgs / home-manager / noctalia 等上游源码，一律**优先从 `/nix/store` 取本机已 fetch 的路径**再 grep：`nix eval --raw --impure --expr '(builtins.getFlake "<repo>").inputs.<name>.outPath'`；仅当 store 缺该源码时才联网 fetch，不要先联网再查 store。
- 用户级 `nix-env` 装的包不进系统配置，落在 `~/.nix-profile/bin`（`/home/lwa/.nix-profile/bin`）；工具报"找不到"时先查这里。
- 测试 Python 代码优先用 `~/.nix-profile/bin/uv` 在临时目录建项目：`uv init /tmp/xxx && cd /tmp/xxx && uv add <pkg>` 装依赖（uv 自带锁文件与 Python 版本管理），再用 `uv run <script.py>` 运行。不要在临时目录外跑裸 `python3`、不要用 `python3 -m venv` 加 `pip`，也不要为一次性测试把依赖加进本仓或系统配置。
- 会话启动链改动（greetd/DM、合成器、环境导入、守护自启、portal 配置）须重新登录或整机重启验证，`nixos-rebuild switch` 只重启被改动的用户服务。
- 暂存区规则（**只约束 agent / 自动化工具**，不约束用户；用户可手动 `git add` / 改暂存区，agent 不得动用户布局）。flake 只纳入 git 索引里的文件（新文件未 `git add` 不可见），文件内容取工作区（含未暂存改动）；故 agent 只在**一种**情形动暂存区，其余一律不碰：
  - **新文件**（`git cat-file -e HEAD:<path>` 失败表示 HEAD 里没有）：首建时必须 `git add <path>` 才会被 `nix eval` / `nix build` 看到。这是 agent **唯一**允许的暂存区操作。
  - **已有文件的修改**（HEAD 里有的文件）：agent **永不** `git add`，改动留在工作区。`git diff`（工作区 vs 索引）就是"这次改了什么"，推进暂存区会把它藏起来。
  - **已暂存的新文件后来又改了**（状态 `AM`）：改动部分也**不进暂存区**——索引只决定文件是否被纳入（nix 读到的仍是工作区内容，已实测），把后续改动留在工作区不影响 nix 求值，也让 `git diff` 展示后续改动，这样别人才知道你这次到底动了哪一行。
  - **其余一律不动**：agent 也不对任何条目反暂存（`git restore --staged` / `git reset` 等），暂存区的取舍权在用户——用户审查后 `git add` 与否完全自由。

## 架构决策

- 架构：采用 Modular+autowire；已否决迁往 Dendritic（单 class、主机少共性大、迁移是架构级重写）。
- `home-manager.users.<me>` 写**裸 attrset** 时（plasma6.nix 即如此），内部 `config`/`pkgs` 按词法作用域解析为 **NixOS 侧**，HM 选项不可见（kwinrc 的 InputMethod 正靠此拿到 NixOS 侧 fcitx5-with-addons；HM 侧 `i18n.inputMethod.package` 实为 null）；要引用 HM 选项必须改函数模块 `{ config, ... }:`，并把 NixOS 侧值以 let 闭包捕获。

# 我的 NixOS 配置

## 介绍

一个基于 [juspay/nixos-unified-template](https://github.com/juspay/nixos-unified-template) 构建的 NixOS 配置项目，支持 NixOS 系统配置和 Home Manager 用户环境管理。

项目结构清晰，包含以下主要功能模块：

- **系统配置**：支持不同硬件设备（如 ASUS、Naix、Redmi）的 NixOS 系统配置，还包括 WSL（Windows Subsystem for Linux）配置。
- **通用模块**：提供适用于 NixOS 和 Home Manager 的通用配置模块，如字体、SSH、包管理、GUI 支持等。
- **可选功能**：包括 Docker、NVIDIA 驱动、QEMU、RustDesk、ToDesk、VirtualBox、Waydroid、XRDP 等可选模块。
- **自定义包**：包含自定义 Nix 包，如 ntloader、grub-cyberre-theme、winfonts、uudeck 等。

## 目录结构说明

### 核心配置文件
- `flake.nix` 和 `flake.lock`：Flake 项目配置。
- `config.nix`：主配置文件。
- `README.md` 和 `.envrc`：项目说明和开发环境配置。

### 系统配置
- `configurations/nixos/`：包含不同设备的 NixOS 配置，如 ASUS、Naix、NixOS、Redmi 和 WSL。
- `configurations/home/`：Home Manager 用户环境配置，针对不同设备有不同配置。

### 模块
- `modules/nixos/`：NixOS 模块，包括：
  - `cli/`：命令行相关模块（字体、Locale、Nix 配置、 Pipewire、SSH 等）
  - `common/`：通用模块（开发工具、Steam、Sunshine、UUDeck、v2raya 等）
  - `gui/`：桌面环境模块（COSMIC、GNOME、Plasma6、XFCE）
  - `optional/`：可选模块（Docker、NVIDIA 470、QEMU、RustDesk、ToDesk、VirtualBox、Waydroid、XRDP）
- `modules/home/`：Home Manager 模块，用于用户环境配置：
  - `common/`：通用模块（direnv、Git、Zsh 包管理）
  - `gui/`：GUI 应用模块（Firefox、Heroic、MangoHud、VSCode）
- `modules/flake/`：flake-parts 模块。

### 自定义包
- `packages/`：包含多个自定义 Nix 包定义：
  - `dev-sidecar/`：开发辅助工具
  - `fcitx-sogoupinyin/`：搜狗输入法
  - `grub-cyberre-theme/`：GRUB 主题
  - `ntloader/`：NT 加载器
  - `winfonts/`：Windows 字体
  - `uudeck/`：UUDeck 工具
  - `shells/`：各种编程语言环境（C++、Go、Rust）
  - 以及其他实用工具

## 使用说明

### 依赖
- Nix 包管理器（推荐使用 NixOS）
- 启用 Nix Flakes 支持

### 快速开始

1. 克隆本仓库：
   ```bash
   git clone https://gitee.com/linuxwhata/nix-config.git
   cd nix-config
   ```

2. 使用 direnv 自动加载开发环境（如果已配置）：
   ```bash
   direnv allow
   ```

3. 构建指定配置：
   ```bash
   # 构建 NixOS 配置
   sudo nixos-rebuild switch --flake .#主机名

   # 构建 Home Manager 配置
   home-manager switch --flake .#用户名@主机名
   ```

### 自定义

- 修改 `configurations/nixos/` 下的设备配置以适配您的硬件。
- 修改 `configurations/home/` 下的用户配置以满足个人需求。
- 通过 `modules/` 中的模块扩展功能，按需启用可选模块。

## 许可证

本项目基于 MIT 许可证，详细信息请参阅 `LICENSE` 文件。
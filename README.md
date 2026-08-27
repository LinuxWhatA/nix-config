[![MIT License](https://img.shields.io/badge/license-MIT-blue)](https://mit-license.org)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LinuxWhatA/nix-config)
[![NixOS Disko](https://img.shields.io/badge/NixOS-Disko-blue?logo=NixOS)](https://github.com/nix-community/disko)
[![NixOS Home Manager](https://img.shields.io/badge/NixOS-Home_Manager-blue?logo=NixOS)](https://github.com/nix-community/home-manager)
[![NixOS Plasma Manager](https://img.shields.io/badge/NixOS-Plasma_Manager-blue?logo=kdeplasma)](https://github.com/nix-community/plasma-manager)
[![NixOS WSL](https://img.shields.io/badge/NixOS-WSL-blue?logo=Linux)](https://github.com/nix-community/NixOS-WSL)
# 我的 NixOS 配置

## 介绍

一个基于 flake-parts 的 NixOS 配置项目，通过本地 `modules/flake/autowire.nix` 自动生成 NixOS 系统配置，Home Manager 用户环境由系统内嵌托管。

项目结构清晰，包含以下主要功能模块：

- **系统配置**：支持不同硬件设备（naix、redmi）的 NixOS 系统配置，以及 WSL（Windows Subsystem for Linux）配置。
- **通用模块**：提供适用于 NixOS 和 Home Manager 的通用配置模块，如字体、SSH、包管理、GUI 支持等。
- **可选功能**：包括 Docker、NVIDIA 驱动、QEMU、RustDesk、ToDesk、VirtualBox、Waydroid、XRDP 等可选模块。
- **自定义包**：包含自定义 Nix 包，如 ntloader、grub-cyberre-theme、winfonts、uudeck 等。

## 目录结构说明

### 核心配置文件
- `flake.nix` 和 `flake.lock`：Flake 项目配置。
- `config.nix`：主配置文件。
- `README.md` 和 `.envrc`：项目说明和开发环境配置。

### 系统配置
- `configurations/nixos/`：按设备（naix、redmi、wsl）组织的 NixOS 配置，每台设备由 `default.nix` 组合清单 + 分类模块构成，Home Manager 用户环境内嵌于系统配置中。

### 模块
- `modules/nixos/`：NixOS 模块，包括：
  - `cli/`：命令行模块（字体、Locale、Nix、Pipewire、OpenSSH、Vim 等）
  - `desktop/`：桌面环境（COSMIC、GNOME、Plasma6、XFCE）与系统界面（getty、locale）
  - `gui/`：桌面应用（Clash、Dev-Sidecar、Plymouth、Steam）
  - `hardware/`：硬件（蓝牙、图形驱动、persist、swap 等）
  - `services/`：服务（home/网络/安全、NFS、RustDesk、Sunshine、ToDesk、UUDeck、v2raya、Xrdp 等）
  - `virtualization/`：虚拟化（Docker、QEMU、VirtualBox、Waydroid）
- `modules/home/`：Home Manager 模块，由系统托管注入：
  - `default.nix`：用户基础（xdg 目录、stateVersion、nix-index）
  - `cli/`：命令行日常（direnv、git、nix、shell、包）
  - `gui/`：图形应用（Firefox、Heroic、MangoHud、opencode、VSCode）
- `modules/flake/`：flake-parts 模块（`autowire.nix` 负责目录结构自动接线）。

### 自定义包
- `packages/`：自定义 Nix 包。

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

3. 构建并切换指定配置（Home Manager 用户环境随系统一并部署）：
   ```bash
   sudo nixos-rebuild switch --flake .#主机名
   ```

### 自定义

- 修改 `configurations/nixos/<设备>/` 下的设备配置以适配您的硬件（`default.nix` 为组合清单，一行一个模块）。
- 通过 `modules/` 中的模块扩展功能，按需启用。

## 许可证

本项目基于 MIT 许可证，详细信息请参阅 `LICENSE` 文件。
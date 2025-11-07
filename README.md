# 我的 NixOS 配置

## 介绍
一个基于 [juspay/nixos-unified-template](https://github.com/juspay/nixos-unified-template) 构建的 NixOS 配置项目，支持 NixOS 系统配置和 Home Manager 用户环境管理。

项目结构清晰，包含以下主要功能模块：

- **系统配置**：支持不同硬件设备（如 ASUS 和 Naix）的 NixOS 系统配置。
- **通用模块**：提供适用于 NixOS 和 Home Manager 的通用配置模块，如字体、SSH、包管理、GUI 支持等。
- **可选功能**：包括 Docker、NVIDIA 驱动、QEMU、RustDesk、ToDesk、VirtualBox、Waydroid、XRDP 等可选模块。
- **自定义包**：包含自定义 Nix 包，如 ntloader、grub-cyberre-theme、winfonts、uudeck 等。

## 目录结构说明

### 核心配置文件
- `flake.nix` 和 `flake.lock`：Flake 项目配置。
- `config.nix`：主配置文件。
- `README.md` 和 `.envrc`：项目说明和开发环境配置。

### 系统配置
- `configurations/nixos/`：包含不同设备的 NixOS 配置，如 ASUS 和 Naix。
- `configurations/home/`：Home Manager 用户环境配置。

### 模块
- `modules/nixos/`：NixOS 模块，包括通用配置、GUI 支持和可选模块。
- `modules/home/`：Home Manager 模块，用于用户环境配置。
- `modules/flake/`：flake-parts 模块。

### 自定义包
- `packages/`：包含多个自定义 Nix 包定义，如 ntloader、winfonts、uudeck 等。

## 使用说明

### 依赖
- Nix 包管理器（推荐使用 NixOS）
- 启用 Nix Flakes 支持

### 自定义
- 修改 `configurations/nixos/` 和 `configurations/home/` 配置以适配设备和需求。
- 通过 `modules/` 中的模块扩展功能。

## 许可证
本项目基于 MIT 许可证，详细信息请参阅 `LICENSE` 文件。
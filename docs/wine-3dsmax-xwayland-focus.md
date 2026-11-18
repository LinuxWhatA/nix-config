# 3ds Max（Wine）在 labwc 下键盘焦点丢失的排查记录

## 背景

用补丁版 Wine 11.0（`packages/wine-3dsmax`，上游 `cl0nazepamm/3dsmax-wine`）跑 Autodesk 3ds Max 2026，在 labwc（Wayland + XWayland）会话下频繁出现**输入焦点丢失**：

- 焦点落到其他窗口，当前「保存图像」等对话框输入无效；
- 明明在 3ds Max 里输入，按键却被**后台的 kitty 终端**捕获。

原生 Wayland / XWayland 应用没有此问题，只有 Wine 窗口受影响。

## 环境

- 会话：labwc 0.20.2，`XDG_SESSION_TYPE=wayland`，`WAYLAND_DISPLAY=wayland-0`，`DISPLAY=:0`（XWayland）。
- Wine：`wine-3dsmax` 包内的补丁版 `wine-wow64-11.0`（dcomp、ntdll、kernelbase、server 等 74 个补丁），走 **X11 驱动（winex11）+ XWayland**，非 winewayland 原生驱动。
- 前缀：`~/.wine-3dsmax`，3ds Max 2026 已装好。
- 启动方式：`wine-3dsmax run`（内部 `wine ./3dsmax.exe`）。

## 现场实证（连到正在运行的会话）

用 `XGetInputFocus` / `XQueryTree` / `XGetWindowAttributes`（ctypes 直调 libX11）与包内调试工具 `tools/winlist.exe` 观察：

1. **3ds Max 有 6+ 个独立 XWayland 顶层表面**：主窗口、V-Ray 帧缓冲（`x11=0x100014f`）、若干 Qt 窗口、以及「保存图像」对话框（`x11=0x100017b`）——每个都是 labwc 要单独管理、单独给焦点的表面。
2. **X 输入焦点确实在「保存图像」对话框上**（`0x100017b`，`revert=2`），但合成器把键盘路由到了 kitty——**X 焦点正确、Wayland 键盘焦点没跟上**，形成失同步。
3. 存在**几十个 `override_redirect`（OR / labwc 称 "xwayland-unmanaged"）窗口**：菜单、tooltip、flyoff（`PX_FlyoffWnd`）、V-Ray 浮窗、`.NET`/`IME` 辅助窗等。可见主窗与对话框当时是 `managed`，但问题是**间歇性**的——某窗口某刻转成 OR/unmanaged 就会丢焦点且难以找回。

## 社区依据

- **labwc Discussion #3173**「How to debug loss of focus / force focus onto an application window」：原帖与本次现象几乎一致（Wine 跑在 XWayland + labwc 下随机丢键盘焦点、无法重新获得）。labwc 维护者回答点明根因指向 **override-redirect（"xwayland-unmanaged"）表面**（`labwc/src/xwayland.c` 的 `handle_set_override_redirect`），并给出调试方法（`labwc -d 2> log.txt`、`WAYLAND_DEBUG=server labwc`）。**该 issue 仍开放、无修复。**
- **WineHQ Bug #59740**「Programs running under Wayland do not notice when they lose focus」：同一家族的问题（winewayland 原生驱动侧：Wayland 表面丢失键盘焦点时前台窗口未更新，有补丁）。本次走的是 X11 驱动 + XWayland，非同一路径，但印证 Wine 侧焦点失同步属已知缺陷。

## 根因

Wine（X11 驱动）在多个顶层 XWayland 表面（主窗 + 浮窗 + 模态对话框）之间用 `XSetInputFocus` / `_NET_ACTIVE_WINDOW` 切焦点；XWayland 把「键盘焦点变更」转告合成器这件事对这类 **transient / OR 窗口不可靠**，labwc 未跟上 → 合成器键盘焦点停留在上一个表面（如 kitty）。X 层面焦点是对的，但 Wayland 合成器按自己的焦点路由键盘，于是按键去了别处。

## 尝试过的对策与结果

| 方案 | 操作 | 结果 |
|---|---|---|
| B：关指针抓取 | `HKCU\Software\Wine\X11 Driver\GrabPointer = "N"` | ❌ winecfg 单窗口仍丢焦点，排除 |
| A：虚拟桌面（注册表） | `HKCU\Software\Wine\Explorer\Desktops\Default = "1462x914"`（winetricks 格式） | ❌ 未生成虚拟桌面窗口，winecfg 仍挂根窗口 |
| A：虚拟桌面（显式） | `wine explorer /desktop=Default,1462x914 winecfg.exe` | ❌ 同样不生效 |
| labwc 配置 | `<windowRules>` 无"强制给焦点"项；`ignoreFocusRequest` 是反方向（防自激活） | — 无直接可用配置 |

> 虚拟桌面两路都不生效，说明**这个 Wine 11.0 构建在 labwc 下虚拟桌面机制不触发**，故经典"收进单表面"对策在此不可用。

## 回退状态

所有改动均已还原到基线，未留副作用：

- `GrabPointer` / `UseTakeFocus` / `Desktops\Default` 注册表：无残留；
- 临时测试前缀 `/tmp/opencode/wtest*`：已删；
- 运行中的 wineserver：已停；
- `~/.wine-3dsmax` 里 3ds Max 2026 安装：完好未动。

## KDE 复测结果

换 KDE（KWin 6.8.3）会话复测，两个问题分别得出确定结论。

### 焦点：KDE 下正常 → 根因确在 labwc 侧

winecfg 在 KDE 下**输入正常**，3ds Max 同场景不再丢焦点 → 焦点丢失问题确在 **labwc**（#3173 的 XWayland 焦点缺陷），**Wine 侧没问题**。KWin 对 XWayland 焦点路由与 labwc 不同，故不受影响。

> 注：winecfg 这种简单单窗口在 labwc 下也丢焦点，佐证焦点问题与 3ds Max 多窗口复杂性无关，是 Wine × XWayland × labwc 的通用失同步。

### 缩放：KDE 下显小 → Wine 不读 Xft.dpi，需设 LogPixels

KDE 下 Wine 窗口尺寸正常但**视觉上缩小**，与焦点无关，是独立的 HiDPI 缩放问题。证据链（只读核查 + 源码）：

| 环节 | 实测/源码 | 结论 |
|---|---|---|
| KDE 缩放 | `~/.config/kwinrc`: `Scale=1.75` | 桌面放大 1.75× |
| KDE 给 XWayland 的提示 | X 资源串 `Xft.dpi: 168`（=96×1.75） | 合成器侧已给出 1.75× DPI 提示 |
| **Wine 是否读 Xft.dpi** | winex11/win32u 源码**无任何 `Xft.dpi` 读取** | **Wine 11.0 不用 Xft.dpi 做系统 DPI** |
| Wine 系统 DPI 来源 | `win32u/sysparams.c:5772/6027-6040`：`system_dpi` ← `HKCU\Control Panel\Desktop\LogPixels`，缺省回退 96 | 系统 DPI 只认注册表 `LogPixels` |
| 未设 `LogPixels` 时 | `system_dpi = 96` | Wine 按 96 DPI 渲染 → 在 1.75× 桌面显小 |

**修复（已实测生效）**：设 `HKCU\Control Panel\Desktop\LogPixels = 168`（REG_DWORD，=96×1.75），重启 wineserver。winecfg 窗口由 410×411（96 DPI）变为 **745×708**（≈1.75×），缩放正常。winecfg / 3ds Max 的 manifest 均声明 `dpiAware`（DPI 感知），故会用 `system_dpi=168` 渲染。

## 为什么 labwc 下尺寸正常（kanshi + labwc 上采样）

KDE 下显小，但 **labwc 下 Wine 尺寸却正常**——不是 Wine 自己缩放对了，而是合成器侧把它放大了：

- `modules/nixos/desktop/labwc-scale.nix` 的 kanshi 给 labwc 设 **输出缩放 1.75**；
- labwc（wlroots）把**整块 XWayland 表面按 1.75× 上采样**：实测 labwc 会话下 X 屏 **1462×914**（=2560÷1.75），即 XWayland 以逻辑分辨率运行，合成器放大到物理 2560×1600；
- Wine 以 96 DPI 画进 1462×914 逻辑表面，labwc 放大 1.75× → 物理尺寸正常（代价是轻微发软）。

即：**kanshi 提供缩放值 + labwc 整体上采样**缺一不可。KWin 默认不放大 XWayland 表面，改用 `Xft.dpi=168` 提示 X 应用自行缩放，而 Wine 11 不读 `Xft.dpi` → 显小。

## 结论

- **焦点丢失**：确在 **labwc 侧**（#3173 XWayland 焦点缺陷），Wine 侧无问题；KDE 不受影响。labwc 上游 issue 开放、无修复。
- **KDE 下缩放**：已用 `LogPixels=168` 解决，实测生效。
- **labwc 下尺寸正常**：是 kanshi + labwc 上采样的结果，Wine 始终未自缩放。

### 可复制的修复命令

```bash
# KDE 下修复缩放：设 LogPixels=168（96×1.75），重启 wineserver 后生效
export WINEPREFIX=/home/lwa/.wine-3dsmax
wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 168 /f
wine wineserver -k

# 正常启动（焦点已判为 labwc 侧问题，Wine 侧无需任何设置）
wine-3dsmax run
```

### 后续可做

- **labwc 侧**：等 #3173 上游修复；或考虑换合成器（KDE 下焦点正常）；可 `labwc -d 2> log.txt`、`WAYLAND_DEBUG=server labwc` 定位 OR 窗口出现时机。
- **Wine 侧**：若把 `LogPixels=168` 固化进 `packages/wine-3dsmax` 启动脚本，可在任何会话下自缩放（labwc 下亦可，避免上采样发软）。

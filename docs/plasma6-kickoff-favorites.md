# Plasma 6 启动器（kickoff）常用应用的声明式定义——调研与等待上游

## 背景与问题

想用 Nix（plasma-manager）声明式定义 Plasma 6 应用程序启动器（Kickoff）里的**常用/收藏应用**，即置顶的固定应用列表。排查发现：**这类收藏根本不在 kickoff widget 的配置里**，因此 plasma-manager 的 `kickoff` 选项（`modules/widgets/kickoff.nix`）只有显示类开关，没有 favorites 选项。

结论先行：社区正在 plasma-manager 上游做（**PR #694**，2026-11-19 提出，当前仍开放、未合并）。**暂不实现，等上游合并后直接用其 `programs.plasma.kickoff.favorites` 选项。**本文档记录数据位置、社区脉络与合并后的用法。

## 收藏数据实际存在哪

Plasma 6 的 kickoff 收藏由 KDE Activity Manager（KAStats / `kactivitymanagerd`）统一管理，不再存于 widget 的 `~/.config/plasma-org.kde.plasma.desktop-appletsrc` 里（这也是 PR #238 明确"暂不实现 favoritesPortedToKAstats / systemFavorites"的原因）。

| 数据 | 路径 | 内容 |
|---|---|---|
| 收藏**集合** | `~/.local/share/kactivitymanagerd/resources/database`（SQLite） | `ResourceLink` 表，`initiatingAgent=org.kde.plasma.favorites.applications`、`usedActivity=:global`、`targettedResource=applications:xxx.desktop` |
| 收藏**排序** | `~/.config/kactivitymanagerd-statsrc` | `[Favorites-org.kde.plasma.kickoff.favorites.instance-<id>-global]` 段的 `ordering=`（CSV） |
| kickoff applet 实例 ID | `~/.config/plasma-org.kde.plasma.desktop-appletsrc` | `[Applets][<id>]` + `plugin=org.kde.plasma.kickoff` |

本机实证（`~/.config/kactivitymanagerd-statsrc` 现存内容，格式与上游脚本预期一致）：

```ini
[Favorites-org.kde.plasma.kickoff.favorites.instance-26-267cff64-6ec4-4277-9706-6e09aec7ebac]
ordering=preferred://browser,applications:systemsettings.desktop,applications:org.kde.dolphin.desktop,applications:org.kde.discover.desktop,applications:MotrixNext.desktop,applications:clash-verge.desktop,applications:code.desktop,applications:com.heroicgameslauncher.hgl.desktop

[Favorites-org.kde.plasma.kickoff.favorites.instance-26-global]
ordering=preferred://browser,applications:systemsettings.desktop,applications:org.kde.dolphin.desktop,...
```

关键：**只写 `ordering=` 只能改排序，加不进收藏集合**。集合在 SQLite 的 `ResourceLink` 行，`programs.plasma.configFile` 写不了；`configFile` 仅能辅助排序。

## 社区脉络

| 条目 | 时间 | 状态 | 内容 |
|---|---|---|---|
| [PR #238](https://github.com/nix-community/plasma-manager/pull/238) | 2024-07 | 已合并 | kickoff 选项加入，但明确**不实现** `favoritesPortedToKAstats` / `systemFavorites` |
| [Issue #376](https://github.com/nix-community/plasma-manager/issues/376) | 2024-10 | 已关闭 | 确认收藏在 `kactivitymanagerd-statsrc`；当时无声明式支持 |
| [Issue #539](https://github.com/nix-community/plasma-manager/issues/539) | 2025-10 | 仍开放 | "How to declaratively add apps to favorite?"，社区持续等支持 |
| [PR #642](https://github.com/nix-community/plasma-manager/pull/642) | 2026-08→2026-11-01 | **未合并关闭** | 首个 `plasma.kickoff.favorites`，被 #694 取代 |
| [PR #694](https://github.com/nix-community/plasma-manager/pull/694) | 2026-11-19 | **开放（未合并）** | 当前最新、最完整方案，见下 |

**PR #694「feat: declarative kickoff favorites」要点**（`modules/kickoff.nix`，全程序级模块）：

- 新选项 `programs.plasma.kickoff.favorites`（`nullOr (listOf str)`），值形如 `applications:org.kde.dolphin.desktop`、`preferred://browser`；
- 写 `systemd.user.services.kickoff-favorites`（oneshot，`Before=plasma-kactivitymanagerd.service plasma-plasmashell.service`）：在 plasmashell / kactivitymanagerd 启动**前**用 `sqlite3` 直改 `ResourceLink` 行（增删），并重写 `kactivitymanagerd-statsrc` 各 `[Favorites-...instance-<id>-global]` 段的 `ordering=`；
- 兜底：post-login 的 D-Bus 脚本（`startup.startupScript`）处理全新 profile（库尚未建）的情况，走 `LinkResourceToActivity`/`UnlinkResourceFromActivity` 并 `restart plasma-plashell`；
- 注意：**全程序级**（非 per-panel），会改所有 kickoff 实例；面板配置大改导致 applet ID 变化时，首次登录排序退回按 URI 字典序，下次登录才正确（作者注明此边界，且 `.desktop` 文件须以 `applications:<menu-id>.desktop` 全名写）。

## 当前版本状态

本仓库 pin 的 plasma-manager（store `dn410cmp…`）**不含** `modules/kickoff.nix`，即无声明式 favorites 选项。故**暂不实现**，等 #694 合并进主分支后再引入。

## 合并后的用法（预期，取自 #694 示例）

```nix
programs.plasma.kickoff.favorites = [
  "preferred://browser"
  "applications:org.kde.dolphin.desktop"
  "applications:code.desktop"
  "applications:org.kde.systemsettings.desktop"
];
```

## 后续可做

- 关注 **PR #694** 合并状态；合并后升级 plasma-manager input 并启用上述选项；
- 若 #694 长时间未合并、又确需声明式收藏，再考虑把其 `modules/kickoff.nix` 逻辑抄成本地模块（等价于手工 `home.activation` + `sqlite3` + `configFile` 排序，较脆，不优先）。

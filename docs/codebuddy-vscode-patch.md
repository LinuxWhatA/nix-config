# CodeBuddy 启动自动弹出问题的修复记录

## 背景

VS Code 装了腾讯云 CodeBuddy 扩展（`Tencent-Cloud.coding-copilot`）后，每次打开 VS Code，左侧活动栏会自动从「资源管理器」切到 CodeBuddy 面板——等于每次启动都被强制抢焦点刷存在感，且**没有任何开关能关掉**。这不是用户配置问题，是扩展自身的设计缺陷（暗黑模式）。

## 根因

扩展 `package.json` 的 `activationEvents = ["*"]`，窗口一激活就运行。其 `ActivityBarChatWebviewProviderImpl.activate()` **无条件**调用 `forceResolveWithRetry()`（webview「自愈」逻辑）：

- 在 Cursor / Windsurf 上，`workbench.action.forceResolveWebviewView` 存在，可**静默**强制解析 webview（不显示侧栏）。
- 在原生 VS Code 上该命令不存在，于是回退到 `focusChatViewNatively()`，执行 `coding-copilot.webviews.chat.focus`，**把活动栏切到 CodeBuddy**。

关键：**所有**抢焦点路径（启动激活、`waitWebviewReady` 30 秒超时后的自愈重载、按需 `ensureRpc`）最终都汇聚到 `focusChatViewNatively()` 这一处。只堵启动调用不够——堵掉后 30 秒自愈超时仍会把它重新弹出来。

扩展 `package.json` 的全部配置项、product 配置、运行时读取的配置键均无开关可关此行为（`codingcopilot.autoRun` 默认已是 `false`，与此无关）。

## 补丁

扩展是手动装到 `~/.vscode/extensions/`，Nix 侧管不到，故直接改其入口文件 `out/extension/index.js`（即 `package.json` 的 `main`）。

### 补丁 1：启动时不再主动 force-resolve

在 `activate()` 中，把本地启动分支的 `this.forceResolveWithRetry()` 换成仅记日志的 no-op（远端 SSH/WSL 窗口分支保持原样）。

替换前：

```js
Sn.env.remoteName?null===(ar=this.logger)||void 0===ar||ar.info(`[WebviewProvider] Skipping startup force-resolve in remote window: ${Sn.env.remoteName}`):this.forceResolveWithRetry()
```

替换后：

```js
Sn.env.remoteName?null===(ar=this.logger)||void 0===ar||ar.info(`[WebviewProvider] Skipping startup force-resolve in remote window: ${Sn.env.remoteName}`):null===(ar=this.logger)||void 0===ar||ar.info("[WebviewProvider] startup force-resolve disabled by local patch")
```

### 补丁 2：掐断所有 native view-focus 回退

把 `focusChatViewNatively()` 整体改为 no-op。这是唯一会执行 `coding-copilot.webviews.chat.focus` 的地方；掐掉后启动 / 自愈 / 按需三条路径都不会再抢焦点。

替换前（整段方法体）：

```js
async focusChatViewNatively(ir=Sn.commands.executeCommand){var ar,tn,rn,nn;for(const nn of Yn)try{return null===(ar=this.logger)||void 0===ar||ar.info(`[WebviewProvider] native fallback: executing ${nn}`),await ir(nn),null===(tn=this.logger)||void 0===tn||tn.info(`[WebviewProvider] native fallback succeeded via ${nn}`),!0}catch(ir){null===(rn=this.logger)||void 0===rn||rn.warn(`[WebviewProvider] native fallback ${nn} failed: ${ir instanceof Error?ir.message:String(ir)}`)}return null===(nn=this.logger)||void 0===nn||nn.warn("[WebviewProvider] all native view-focus fallbacks failed; the webview will still resolve when the user opens the panel"),!1}
```

替换后：

```js
async focusChatViewNatively(ir=Sn.commands.executeCommand){var ar,tn,rn,nn;return null===(ar=this.logger)||void 0===ar||ar.info("[WebviewProvider] native view-focus suppressed by local patch; the webview will resolve when the user opens the panel"),!1}
```

> 手动点击 CodeBuddy 图标时，VS Code 走原生 `resolveWebviewView` 打开 webview，**不经过** `focusChatViewNatively`，故功能不受影响；唯一代价是启动时不再后台预热 webview（首次点击略慢）。

## 应用方式

先备份，再对 `out/extension/index.js` 做两处替换（用 Python 精确匹配替换，避免 sed 对 `` ` `` / `$` 的转义问题；脚本幂等，可重复跑）。

```bash
EXT=~/.vscode/extensions/tencent-cloud.coding-copilot-4.11.37554360/out/extension/index.js
cp "$EXT" "$EXT.bak-$(date +%Y%m%d)"
python3 - "$EXT" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()

PATCHES = [
  # 补丁 1：启动激活不再 force-resolve
  (
    "Sn.env.remoteName?null===(ar=this.logger)||void 0===ar||ar.info(`[WebviewProvider] Skipping startup force-resolve in remote window: ${Sn.env.remoteName}`):this.forceResolveWithRetry()",
    "Sn.env.remoteName?null===(ar=this.logger)||void 0===ar||ar.info(`[WebviewProvider] Skipping startup force-resolve in remote window: ${Sn.env.remoteName}`):null===(ar=this.logger)||void 0===ar||ar.info(\"[WebviewProvider] startup force-resolve disabled by local patch\")",
  ),
  # 补丁 2：掐断 native view-focus 回退
  (
    "async focusChatViewNatively(ir=Sn.commands.executeCommand){var ar,tn,rn,nn;for(const nn of Yn)try{return null===(ar=this.logger)||void 0===ar||ar.info(`[WebviewProvider] native fallback: executing ${nn}`),await ir(nn),null===(tn=this.logger)||void 0===tn||tn.info(`[WebviewProvider] native fallback succeeded via ${nn}`),!0}catch(ir){null===(rn=this.logger)||void 0===rn||rn.warn(`[WebviewProvider] native fallback ${nn} failed: ${ir instanceof Error?ir.message:String(ir)}`)}return null===(nn=this.logger)||void 0===nn||nn.warn(\"[WebviewProvider] all native view-focus fallbacks failed; the webview will still resolve when the user opens the panel\"),!1}",
    "async focusChatViewNatively(ir=Sn.commands.executeCommand){var ar,tn,rn,nn;return null===(ar=this.logger)||void 0===ar||ar.info(\"[WebviewProvider] native view-focus suppressed by local patch; the webview will resolve when the user opens the panel\"),!1}",
  ),
]

for old, new in PATCHES:
    if new in s:
        print("already applied:", new[:60]); continue
    if s.count(old) != 1:
        raise SystemExit(f"expected exactly 1 occurrence, got {s.count(old)}: {old[:80]}")
    s = s.replace(old, new)

open(p, "w", encoding="utf-8").write(s)
print("patched OK")
PY
```

## 验证

扩展日志位于 `~/.config/Code/logs/<时间>/window1/exthost/Tencent-Cloud.coding-copilot/腾讯云代码助手.log`：

- 补丁生效：出现 `startup force-resolve disabled by local patch` 与 `native view-focus suppressed by local patch`。
- 不再出现：`native fallback: executing coding-copilot.webviews.chat.focus`、`Force resolving chat webview view`。

重载窗口（`Ctrl+Shift+P` → `Developer: Reload Window`）后**等 30 秒以上**再确认——自愈超时阈值是 30 秒，若只堵了启动调用，31 秒左右仍会被自愈重试弹出来。

## 注意事项

- 扩展更新 / 重装会覆盖补丁。用户设置 `extensions.autoCheckUpdates = false` 已禁自动更新，但手动装新版本会失效；失效后按上文重新应用。
- 扩展目录带版本号（`tencent-cloud.coding-copilot-4.11.37554360`），换版本需同步改脚本里的路径。
- 备份在 `index.js.bak-<日期>`，还原即 `cp 备份 原文件`。
- 补丁只去掉了「启动抢焦点」，未改动任何功能；若要彻底不用 CodeBuddy，在 VS Code 里禁用该扩展即可（会同时失去其全部能力）。

# 3ds Max 2026 界面中英混杂修复（应用语言被锁定 ENU）

> 日期：2026-11-18
> 对象：3ds Max 2026（`C:\Program Files\Autodesk\3ds Max 2026\`，版本 28.0）跑在 Linux 补丁版 Wine 11.0 上
> （`WINEPREFIX=~/.wine-3dsmax`，启动命令 `wine-3dsmax-wine ...\3dsmax.exe`）。
> 场景：顶部菜单与渲染设置显示英文，其余界面（材质编辑器、资产浏览器、面板、插件等）显示中文，
> 看起来是中英混合页面；系统区域为简体中文（`zh-CN`）。

---

## 1. 问题现象

- 顶部菜单栏、渲染设置对话框（Render Setup）为**英文**。
- 其余绝大多数界面为**中文**（材质编辑器、命令面板、资产浏览器、大部分插件对话框）。
- 系统区域设置已是简体中文（`LocaleName=zh-CN`、`sLanguage=CHS`、`LANG=zh_CN.UTF-8`）。

## 2. 根因

3ds Max 的 UI 语言由**注册表**决定，但并非只看 `CurrentLanguage` 一个值。启动时它按以下逻辑判定语言：

1. 读取 `HKCU\Software\Autodesk\3dsMax\28.0\CurrentLanguage` 与 `DefaultLanguage`；
2. 读取 `HKLM\Software\Autodesk\3dsMax\28.0\LanguagesInstalled` 下的**语言子键**；
3. 校验当前语言子键里的三个值：
   - `LangSubDir`（资源子目录，如 `zh-CN`）
   - `LCID`（语言 LCID，如 `0x804`）
   - `UIName`（UI 显示名）
4. 校验通过才采用该语言，**否则回退/强制写入 `ENU`**。

本机的 `LanguagesInstalled` 键**根本不存在**（安装时未写入，或只写入了不完整结构）。于是应用
无法确认任何非英文语言「已安装」，每次都判定为 `ENU`，并把 `CurrentLanguage` 写回 `ENU`：

- **原生资源组件**（顶部菜单 `MenuMan`、渲染设置 `CommonRendererUI`/`max.tres`、主程序 `3dsmax.exe`）
  跟随该语言（`ENU`）→ 加载基础英文资源 → 显示**英文**；
- **.NET/WPF 卫星组件**（DevExpress、AdWindows、材质编辑器、资产浏览器等）跟随系统区域
  （`zh-CN`）→ 显示**中文**。

两者不一致 → 中英混杂。`zh-CN` 语言包资源其实**已安装**（`zh-CN\*.mui`、`zh-CN\max.tres`、
`zh-CN\CUI\3dsmaxMenus.mnx.res` 等都在），只是应用因 `LanguagesInstalled` 缺失而拒绝启用。

## 3. 排查过程（关键证据）

1. `user.reg` 只有 `CurrentLanguage="ENU"`，且应用在启动时**总是把它写回 `ENU`**——即使手动设成
   `CHS`、或用 `/Language=CHS` 启动也被覆盖。
2. `WINEDEBUG=+reg` 跟踪显示应用启动序列：
   ```
   RegQueryValueExW "CurrentLanguage"       ; 读
   RegQueryValueExW "DefaultLanguage"       ; 读
   NtOpenKeyEx  "...\LanguagesInstalled"    ; 打开（缺失 → 失败）
   NtCreateKey   "...\28.0"
   NtSetValueKey "CurrentLanguage"          ; 写回 ENU
   ```
3. `WINEDEBUG=+loaddll` 显示应用全程**未加载任何 `zh-CN\*.mui`**（Wine 不解析应用目录的 MUI 卫星，
   但这只是表象；真正原因是语言被判定为 ENU）。
4. 补齐 `LanguagesInstalled` 后，`WINEDEBUG=+reg` 显示应用**枚举** `LanguagesInstalled` 子键
   （ENU、CHS），并读取每个子键的 `LangSubDir`、`LCID`、`UIName`——这正是语言校验逻辑。
5. 修复完成后 `WINEDEBUG=+file` 显示应用加载了 **598 个 `zh-CN` 资源文件**，包括
   `MenuMan.dll.mui`、`CommonRendererUI.dll.mui`、`3dsmax.exe.mui`、`3dsmaxMenus.mnx.res`。

## 4. 修复方法（注册表写入）

关键值（`28.0` = 3ds Max 2026）：

| 注册表键 | 值 | 说明 |
|---|---|---|
| `HKCU\Software\Autodesk\3dsMax\28.0` | `CurrentLanguage` = `CHS` | 当前语言（简体中文） |
| `HKCU\Software\Autodesk\3dsMax\28.0` | `DefaultLanguage` = `CHS` | 默认语言 |
| `HKLM\Software\Autodesk\3dsMax\28.0\LanguagesInstalled\CHS` | `LangSubDir` = `zh-CN` | 资源子目录 |
| `HKLM\Software\Autodesk\3dsMax\28.0\LanguagesInstalled\CHS` | `LCID` = `0x804` | zh-CN LCID |
| `HKLM\Software\Autodesk\3dsMax\28.0\LanguagesInstalled\CHS` | `UIName` = `Simplified Chinese` | UI 显示名 |
| `HKLM\Software\Autodesk\3dsMax\28.0\LanguagesInstalled\ENU` | `LangSubDir` = `en-US` | 资源子目录 |
| `HKLM\Software\Autodesk\3dsMax\28.0\LanguagesInstalled\ENU` | `LCID` = `0x409` | en-US LCID |
| `HKLM\Software\Autodesk\3dsMax\28.0\LanguagesInstalled\ENU` | `UIName` = `English (United States)` | UI 显示名 |

> 注：`LanguagesInstalled` 放在 **HKLM**（应用经根句柄 `0x20`=HKLM 打开）；HKCU 侧同步写入一份以防万一。
> `UIName` 建议用 ASCII（如 `Simplified Chinese`），避免 `wine reg add` 的编码问题。

写入命令示例：

```bash
export WINEPREFIX=~/.wine-3dsmax
R="Software\\Autodesk\\3dsMax\\28.0"
# 语言条目（HKLM，每个语言一个子键）
wine-3dsmax-wine reg add "HKLM\\$R\\LanguagesInstalled\\CHS" /v LangSubDir /t REG_SZ /d "zh-CN" /f
wine-3dsmax-wine reg add "HKLM\\$R\\LanguagesInstalled\\CHS" /v LCID      /t REG_DWORD /d 0x804 /f
wine-3dsmax-wine reg add "HKLM\\$R\\LanguagesInstalled\\CHS" /v UIName    /t REG_SZ /d "Simplified Chinese" /f
wine-3dsmax-wine reg add "HKLM\\$R\\LanguagesInstalled\\ENU" /v LangSubDir /t REG_SZ /d "en-US" /f
wine-3dsmax-wine reg add "HKLM\\$R\\LanguagesInstalled\\ENU" /v LCID      /t REG_DWORD /d 0x409 /f
wine-3dsmax-wine reg add "HKLM\\$R\\LanguagesInstalled\\ENU" /v UIName    /t REG_SZ /d "English (United States)" /f
# 当前/默认语言（HKCU）
wine-3dsmax-wine reg add "HKCU\\$R" /v CurrentLanguage  /t REG_SZ /d CHS /f
wine-3dsmax-wine reg add "HKCU\\$R" /v DefaultLanguage  /t REG_SZ /d CHS /f
```

## 5. 验证结果

- 应用启动后**写回 `CurrentLanguage=CHS`**（不再强制 ENU），并使用 `CHS` 配置目录
  （生成了 `...\2026 - 64bit\CHS\3dsMax.ini`）。
- `WINEDEBUG=+file` 确认加载了 **598 个 `zh-CN` 资源文件**，关键包括：
  - `zh-CN\MenuMan.dll.mui` → 顶部菜单中文
  - `zh-CN\CommonRendererUI.dll.mui` → 渲染设置中文
  - `zh-CN\3dsmax.exe.mui`、`zh-CN\3dsmaxMenus.mnx.res`、大量插件 `.mui`
- 界面整体统一为中文。

## 6. 备份与回滚

- 修改前 `user.reg` / `system.reg` 备份在 `/tmp/opencode/user.reg.bak-*`。
- 回退到英文：把 `CurrentLanguage`、`DefaultLanguage` 改回 `ENU` 即可（`LanguagesInstalled` 保留，
  两种语言都可用）。

## 7. 备注

- 切换语言后用户配置目录从 `ENU` 变为 `CHS`（目录名随语言）；旧 `ENU` 配置完整保留，
  自定义宏/脚本可按需复制到 `CHS`（本次已复制 `usermacros`、`scripts`）。
- Wine 不解析应用目录的 `.mui` 卫星（`WINEDEBUG=+loaddll` 全程 0 个 `.mui`），但 3ds Max 的
  原生资源主要由其内部 `resmgr` 加载（读取 `zh-CN\res*.dll.mui` 等），语言判定正确后即可正常加载，
  故**不依赖 Wine 的 MUI 机制**。
- 语言判定逻辑可能随版本变化；若换版本后再次出现混杂，先 `WINEDEBUG=+reg` 跟踪
  `LanguagesInstalled`/`CurrentLanguage` 的访问序列，再补全对应值。

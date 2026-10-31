# Cursor 界面简体中文汉化包

非官方简体中文补丁，为 **Cursor**（Windows 桌面端）提供尽可能完整的界面中文翻译，覆盖双层本地化体系：

- **Workbench 内核层**（VS Code NLS 消息数组）：**13,625 条全部汉化**（`nls.messages.zh.json`）——覆盖顶部菜单栏、命令面板、编辑器、通知、对话框等所有 VS Code 系 UI；其中 11,559 条来自官方 VS Code 简体中文语言包（1.131.0），889 条英文文本匹配复用、1,176 条 Cursor 特有字符串为手工补译
- **Agent/AI 界面层**（Cursor 专有 UI）：**2,049 条 UI 文案**精确替换（`molten-zh-map.json`），命中约 147 个 bundle——覆盖聊天输入、Agent 窗口、云 Agent、终端、画布、设置页、账单等。真实加载点包括 `out\vs\workbench\workbench.glass.main.js`（内置 Agents Window，47MB）、`workbench.desktop.main.js`（IDE 窗口，40MB）、`workbench.anysphere-ui-automations.js` 及 `molten\dist\**\*.js`；Agents 窗口菜单（文件/编辑/视图/帮助）在 `molten\dist\electron-main\host.cjs` 单独处理
- 一键安装 / 一键还原，自动备份原始文件（`.zhorig`）

## 使用方法

1. 解压到任意位置（桌面、U 盘均可）。
2. 双击运行 **`一键汉化.bat`**，脚本会自动：
   1. 探测 Cursor 安装目录
   2. 用 `nls.messages.zh.json` 替换 `resources\app\out\nls.messages.json`（兜底，先备份 `.zhorig`）
   3. 将 `~\.cursor\argv.json` 的 `locale` 设为 `zh-cn`（**关键步骤**：VS Code 1.128 在 `locale=en` 时不加载 NLS 文件，只用代码内嵌英文）
   4. 若已安装官方 `ms-ceintl.vscode-language-pack-zh-hans` 扩展：把缺失键的补译注入其 `main.i18n.json`，并刷新 `%APPDATA%\Cursor\clp` 语言包缓存为全量中文版
   5. 按 `molten-zh-map.json` 对 `resources\app\molten\dist\**` 与 `resources\app\out\vs\workbench\*.js` 中带引号的 UI 字面量做单次正则替换（每个改动文件先备份 `.zhorig`），并对 `molten\dist\electron-main\host.cjs` 的 Agents 窗口菜单模板做专项中文化
   6. Cursor 未运行时自动清理 `Code Cache`/`CachedData`/`Cache`/`GPUCache` 等目录，强制重新编译已汉化 bundle
3. **完全退出并重启 Cursor**（关闭所有窗口重新打开）。
   - 顶部菜单栏与 Agents 窗口菜单由主进程在启动时加载，`Developer: Reload Window` 只重载渲染进程、不会刷新菜单。
   - 若打完补丁时 Cursor 正在运行，请先完全退出，再重跑一次 `一键汉化.bat`（或手动删除 `%APPDATA%\Cursor\Code Cache` 与 `CachedData`）后再启动——V8 缓存会继续提供旧英文 bundle。

自动探测失败时手动指定安装目录：

```powershell
powershell -File apply-zh.ps1 -InstallDir "D:\Cursor"
```

## 还原英文

双击 **`还原英文.bat`**：将 `resources\app` 下所有 `.zhorig` 备份盖回原文件并删除备份，重启 Cursor 即恢复出厂状态。

## 覆盖范围

| 范围 | 状态 |
| --- | --- |
| 顶部菜单栏及下拉菜单 | ✅（需完全重启） |
| 命令面板命令名 | ✅ |
| 编辑器、终端、通知、对话框等 workbench UI | ✅ |
| Agents 窗口顶部菜单（文件/编辑/视图/帮助） | ✅ host.cjs 专项处理 |
| AI 聊天/Agent 界面文案（按钮、标题、占位符、空状态、设置、云 Agent、终端、画布） | ✅ 2,049 条 |
| AI 界面低频/长文案 | 部分仍为英文（字面量替换按字典进行，可扩充 `molten-zh-map.json`） |
| 专有名词 `Cursor`、`MCP`、`Agent`（命令 ID）、模型名等 | 刻意保留英文 |
| 服务端返回内容（登录态、账单、报错信息等） | 无法汉化 |

## 特性

- **幂等**：重复运行自动跳过/从备份重放，字典更新后重跑即应用新翻译
- **自动备份**：首次补丁前把原文件保存为 `*.zhorig`，`还原英文.bat` 完全还原
- **抗更新**：Cursor 升级覆盖文件后重跑一次 `一键汉化.bat` 即可恢复
- **安装路径自动探测**，优先级：
  1. `-InstallDir` 手动指定
  2. 常见安装目录（`E:\Cursor`、`%LOCALAPPDATA%\Programs\cursor`、`Program Files`、`D:\`、`C:\`）
  3. 正在运行的 `Cursor.exe` 进程路径反推
  4. 注册表卸载条目的安装位置

## 工作原理

Cursor 有两层本地化体系：

**1. Workbench 内核层**（NLS 消息数组）

Cursor 基于 VS Code，菜单栏/命令面板/编辑器等字符串按**索引**从 NLS 消息数组取值（如 `E(2166,null)`）。VS Code 1.128 的加载规则：

- `argv.json` 的 `locale` 为 `en` 时 → 直接使用代码内嵌英文，**不加载任何消息文件**
- `locale` 为 `zh-cn` 且安装了 zh-hans 语言包时 → 从 `%APPDATA%\Cursor\clp` 缓存加载该包构建的中文消息数组
- `locale` 为 `zh-cn` 且无语言包时 → 回退到 `resources\app\out\nls.messages.json`

因此补丁三管齐下：替换默认消息文件（兜底）、设 `locale=zh-cn`、向已装语言包注入补译并刷新其缓存。无论是否装有官方语言包扩展均可生效；装了包则覆盖率更高且可通过「Configure Display Language」正常切换语言。

**2. Molten AI 界面层**（`resources\app\molten\dist\**\*.js`）

Cursor 的 AI 聊天/智能体 UI 是独立 React 应用，文案为代码内硬编码字面量，不走 NLS。补丁按 `molten-zh-map.json` 对**带引号的完整字面量**做精确替换（`"Add to Chat"` → `"添加到聊天"`），模板字符串中的 `${var}` 插值保持原样。为降低误伤风险，字典只收录确定性 UI 文案（多词标签/完整句子），排除可能被代码做 `===` 比较的短通用串。

## 文件清单

| 文件 | 说明 |
| --- | --- |
| `一键汉化.bat` | 应用汉化（双击） |
| `还原英文.bat` | 还原原始英文（双击） |
| `apply-zh.ps1` | 汉化补丁脚本 |
| `restore-zh.ps1` | 还原脚本 |
| `nls.messages.zh.json` | Workbench 内核中文消息数组（13,625 条） |
| `molten-zh-map.json` | Molten AI 界面替换字典（373 条，可自行扩充） |

## 注意事项

- 本项目为第三方非官方补丁，与 Anysphere / Cursor 官方无关。
- 补丁会修改本地安装文件，使用前请知悉风险；`.zhorig` 备份可完全还原。
- **Cursor 版本更新后 NLS 索引可能错位**，会导致文案错乱——届时请先用 `还原英文.bat` 还原，等待语言包更新。
- molten 字面量替换存在理论上的误伤可能（若某字符串同时被代码用作比较值）；如遇到个别功能异常，运行 `还原英文.bat` 即可恢复。
- 扩充汉化：向 `molten-zh-map.json` 追加 `"英文": "中文"` 条目后重跑补丁即可。

# Cursor 界面简体中文汉化包

非官方简体中文补丁，为 **Cursor**（Windows 桌面端）提供尽可能完整的界面中文翻译，覆盖双层本地化体系：

- **Workbench 内核层**（VS Code NLS 消息数组）：**13,625 条全部汉化**（`nls.messages.zh.json`）——覆盖顶部菜单栏、命令面板、编辑器、通知、对话框等所有 VS Code 系 UI；其中 11,559 条来自官方 VS Code 简体中文语言包（1.131.0），889 条英文文本匹配复用、1,176 条 Cursor 特有字符串为手工补译
- **Molten AI 界面层**（Cursor 专有 React UI）：**373 条高价值 UI 文案**精确替换（`molten-zh-map.json`），命中 90 个 bundle、约 1,181 处——覆盖聊天输入占位符、按钮、面板标题、空状态、设置标签等最常见文案
- 一键安装 / 一键还原，自动备份原始文件（`.zhorig`）

## 使用方法

1. 解压到任意位置（桌面、U 盘均可）。
2. 双击运行 **`一键汉化.bat`**，脚本会自动：
   1. 探测 Cursor 安装目录
   2. 用 `nls.messages.zh.json` 替换 `resources\app\out\nls.messages.json`（先备份 `.zhorig`）
   3. 按 `molten-zh-map.json` 对 `resources\app\molten\dist\**\*.js` 中带引号的 UI 字面量做精确替换（每个改动文件先备份 `.zhorig`）
3. **完全退出并重启 Cursor**（关闭所有窗口重新打开）。
   - 顶部菜单栏（文件/编辑/选择/查看/转到/运行/终端/帮助）由 Electron 主进程在启动时读取 NLS 文件，`Developer: Reload Window` 只重载渲染进程、不会刷新菜单。

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
| AI 聊天/智能体界面高频文案（按钮、标题、占位符、空状态） | ✅ 373 条核心串 |
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

**1. Workbench 内核层**（`resources\app\out\nls.messages.json`）

Cursor 基于 VS Code，菜单栏/命令面板/编辑器等字符串按**索引**从全局 NLS 消息数组取值（如 `E(2166,null)`）。补丁用等长中文数组（13,625 条，索引一一对应）整体替换该文件：

- 渲染进程在窗口加载时读取 → 命令面板、编辑器 UI 变中文
- Electron 主进程在启动时读取构建应用菜单 → 顶部菜单栏变中文（需完全重启）

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

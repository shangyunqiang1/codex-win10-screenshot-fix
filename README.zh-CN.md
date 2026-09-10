# Windows 10 的 Codex Computer Use Snipaste 截图后备方案

[![测试](https://github.com/shangyunqiang1/win10-snipaste-fallback/actions/workflows/test.yml/badge.svg)](https://github.com/shangyunqiang1/win10-snipaste-fallback/actions/workflows/test.yml)

这是一个安全、非侵入式的 Codex Skill：窗口选择、无障碍树和输入仍由原生 Computer Use 负责；只有发生 `SetIsBorderRequired` / `0x80004002` 截图错误时，才改用本地 Snipaste 捕获当前活动窗口。项目不会注入 DLL，也不会修改 Codex 程序文件。

[English](README.md)

上游问题：[openai/codex#25178](https://github.com/openai/codex/issues/25178)。Snipaste 官网及下载：[snipaste.com](https://www.snipaste.com/)。

## 环境要求

- Windows 10
- 带有 Computer Use Skill 的 Codex 桌面版
- 后台运行的 Snipaste，或安装在脚本可以自动发现的位置
- 支持 `snip --active-window -o` 命令行输出的 Snipaste 版本

## v0.3 改进

- 截图前后核对前台窗口 HWND 和 PID，焦点变化时拒绝并删除截图。
- 为每张 PNG 生成 JSON 元数据，记录物理尺寸、DPI 缩放、耗时和 SHA-256。
- 默认不保存窗口标题或程序路径，减少隐私泄露。
- 使用 Pester 6.1 测试窗口身份、PNG 解析、前置错误码、诊断隐私、脚本语法和包完整性。
- GitHub Actions 使用两个显式作业覆盖 PowerShell 7 和 Windows PowerShell 5.1，并保留 NUnit 与 JaCoCo 测试产物。

## 安装

将仓库克隆到个人 Codex Skills 目录：

```powershell
git clone https://github.com/shangyunqiang1/win10-snipaste-fallback "$env:USERPROFILE\.codex\skills\win10-snipaste-fallback"
```

重启 Codex，使其重新发现 Skill。

## 诊断与截图

```powershell
./scripts/diagnose.ps1
./scripts/capture-active-window.ps1 -OutputPath ./captures/window.png
```

成功后会同时得到 `window.png` 和 `window.json`。脚本不会覆盖已有文件。只有确认窗口标题可以安全落盘时才使用 `-IncludeWindowTitle`。

## 错误码

| 错误码 | 含义 |
| --- | --- |
| `FOCUS_UNSTABLE` / `FOCUS_CHANGED` | 重新激活已确认的目标，用新路径重试一次。 |
| `TARGET_MISMATCH` | 前台 HWND/PID 不是预期目标，停止操作。 |
| `SNIPASTE_NOT_FOUND` | 启动 Snipaste 或提供程序路径。 |
| `CAPTURE_TIMEOUT` / `INVALID_OUTPUT` | 未生成有效 PNG，先诊断再重试。 |
| `OUTPUT_EXISTS` / `METADATA_EXISTS` | 换用新的输出路径。 |

## 支持范围

| 环境 | 状态 |
| --- | --- |
| Windows 10 22H2 + Snipaste 2.x | 支持的后备方案 |
| 原生截图正常的 Windows 11 | 使用原生 Computer Use |
| 登录、安全、密码管理器界面 | 明确不支持 |

## 与原生截图的边界

Snipaste PNG 是物理像素图片；原生 Computer Use 截图还包含 screenshot ID 和逻辑坐标上下文。因此 Snipaste 不能直接等价替代坐标点击的数据源。输入优先使用无障碍元素或键盘；必须按坐标操作时，应先根据 JSON 中的 DPI 比例换算，并在一次动作后立即验证。

## 安全边界

Skill 拒绝覆盖已有文件，截图只保存在本地，并且默认排除窗口标题。不得用它捕获登录对话框、密码管理器、Windows 安全界面或已知包含秘密的内容。

## 开发与测试

安装固定版本的测试依赖，然后运行测试：

```powershell
Install-Module Pester -RequiredVersion 6.1.0 -Scope CurrentUser -Force -SkipPublisherCheck
./tests/run.ps1
```

测试结果和覆盖率写入 `test-results/`。确定性脚本的覆盖率下限为 40%；由于 CI 没有交互式桌面，真实 Snipaste 截图仍作为端到端测试。GitHub Actions 会在每次推送和拉取请求时，分别使用 PowerShell 7 和 Windows PowerShell 5.1 执行同一套测试。

## 许可证

MIT

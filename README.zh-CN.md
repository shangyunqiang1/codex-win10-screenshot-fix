# Windows 10 的 Codex Computer Use Snipaste 截图后备方案

这是一个安全、非侵入式的 Codex Skill：窗口选择、无障碍树和输入仍由原生 Computer Use 负责；只有发生 `SetIsBorderRequired` / `0x80004002` 截图错误时，才改用本地 Snipaste 捕获当前活动窗口。项目不会注入 DLL，也不会修改 Codex 程序文件。

上游问题：[openai/codex#25178](https://github.com/openai/codex/issues/25178)。Snipaste 官网及下载：[snipaste.com](https://www.snipaste.com/)。

## 0.2 的改进

- 截图前后核对前台窗口 HWND 和 PID，焦点变化时拒绝并删除截图。
- 为每张 PNG 生成 JSON 元数据，记录物理尺寸、DPI 缩放、耗时和 SHA-256。
- 默认不保存窗口标题或程序路径，减少隐私泄露。
- 提供只读诊断脚本、稳定错误码和 Windows CI。

## 使用

```powershell
./scripts/diagnose.ps1
./scripts/capture-active-window.ps1 -OutputPath ./captures/window.png
```

成功后会同时得到 `window.png` 和 `window.json`。脚本不会覆盖已有文件。只有确认窗口标题可以安全落盘时才使用 `-IncludeWindowTitle`。

遇到 `FOCUS_UNSTABLE` 或 `FOCUS_CHANGED` 时，重新激活 Computer Use 已唯一确认的目标窗口，并用新路径重试一次；再次失败就停止。其他错误应先诊断原因。

## 与原生截图的边界

Snipaste PNG 是物理像素图片；原生 Computer Use 截图还包含 screenshot ID 和逻辑坐标上下文。因此 Snipaste 不能直接等价替代坐标点击的数据源。输入优先使用无障碍元素或键盘；必须按坐标操作时，应先根据 JSON 中的 DPI 比例换算，并在一次动作后立即验证。

# Win10 Snipaste fallback for Codex Computer Use

A small Codex skill that keeps native Computer Use for window selection, accessibility, and input while replacing only the broken screenshot step with a local Snipaste capture.

This targets the Windows 10 failure:

```text
SetIsBorderRequired failed: No such interface supported (0x80004002)
```

The upstream issue is tracked at [openai/codex#25178](https://github.com/openai/codex/issues/25178). Snipaste documents `snip --active-window` in its [command-line options](https://github.com/Snipaste/feedback/wiki/Command-Line-Options).

## Requirements

- Windows 10
- Codex desktop with the Computer Use skill
- Snipaste running in the background, or installed where the helper can discover it
- A Snipaste build that supports direct PNG file output from the command line

## Install

Clone this repository into your personal Codex skills directory:

```powershell
git clone https://github.com/shangyunqiang1/win10-snipaste-fallback "$env:USERPROFILE\.codex\skills\win10-snipaste-fallback"
```

Start a new Codex task or restart Codex so the skill list refreshes.

## How it works

1. Computer Use uniquely identifies and activates the target window.
2. Accessibility remains available through text-only state capture.
3. The helper calls Snipaste with `snip --active-window -o <file.png>`.
4. Codex inspects the local PNG and continues input through Computer Use.

This is a compatibility workaround, not a patch to Codex. Native screenshot capture remains preferable when it works because its screenshot IDs and logical coordinates are directly bound to Computer Use actions.

## Privacy and safety

- Captures remain local unless the user separately requests an upload.
- The skill refuses to overwrite existing screenshots.
- It must not capture password managers, authentication dialogs, Windows security surfaces, or known secrets.
- Normal Computer Use confirmation rules still apply.

## License

MIT

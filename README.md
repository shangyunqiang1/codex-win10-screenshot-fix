# Win10 Snipaste fallback for Codex Computer Use

[![Test](https://github.com/shangyunqiang1/win10-snipaste-fallback/actions/workflows/test.yml/badge.svg)](https://github.com/shangyunqiang1/win10-snipaste-fallback/actions/workflows/test.yml)

A small, non-invasive Codex skill that keeps native Computer Use for window selection, accessibility, and input while replacing only the broken screenshot step with a local Snipaste capture. No DLL injection or application binary changes are used.

[简体中文](README.zh-CN.md)

This targets the Windows 10 failure:

```text
SetIsBorderRequired failed: No such interface supported (0x80004002)
```

The upstream issue is tracked at [openai/codex#25178](https://github.com/openai/codex/issues/25178). Snipaste documents `snip --active-window` in its [command-line options](https://github.com/Snipaste/feedback/wiki/Command-Line-Options).

## Requirements

- Windows 10
- Codex desktop with the Computer Use skill
- [Snipaste](https://www.snipaste.com/) running in the background, or installed where the helper can discover it
- A Snipaste build that supports direct PNG file output from the command line

## What 0.3 adds

- Checks that the same foreground HWND/PID remains active before and after capture.
- Deletes a rejected capture if focus changed, then allows one controlled retry.
- Writes a JSON sidecar containing physical dimensions, DPI scale, duration, and SHA-256.
- Keeps window titles and executable paths out of diagnostics by default.
- Adds Pester 6.1 tests for window identity, PNG parsing, preflight error codes, diagnostics privacy, syntax, and package integrity.
- Runs explicit GitHub Actions jobs on both PowerShell 7 and Windows PowerShell 5.1 and preserves NUnit and JaCoCo artifacts.

## Install

Clone this repository into your personal Codex skills directory, keeping `SKILL.md`, `agents/`, and `scripts/` together:

```powershell
git clone https://github.com/shangyunqiang1/win10-snipaste-fallback "$env:USERPROFILE\.codex\skills\win10-snipaste-fallback"
```

Restart Codex so it discovers the skill.

## Diagnose and capture

```powershell
./scripts/diagnose.ps1
./scripts/capture-active-window.ps1 -OutputPath ./captures/window.png
```

The capture command creates `window.png` and `window.json`. Existing output files are never overwritten. Add `-IncludeWindowTitle` only when the title is required and safe to store.

The Snipaste image contains physical pixels. Computer Use screenshot observations additionally carry screenshot IDs and logical coordinate context, so the two implementations are not interchangeable for coordinate clicks. Prefer accessibility or keyboard actions, or establish the DPI scale and verify after every coordinate action.

## Error codes

| Code | Meaning |
| --- | --- |
| `FOCUS_UNSTABLE` / `FOCUS_CHANGED` | Reactivate the verified target and retry once with a new path. |
| `TARGET_MISMATCH` | The foreground HWND/PID is not the expected target; stop. |
| `SNIPASTE_NOT_FOUND` | Start Snipaste or supply its executable path. |
| `CAPTURE_TIMEOUT` / `INVALID_OUTPUT` | Capture did not produce a valid PNG; diagnose before retrying. |
| `OUTPUT_EXISTS` / `METADATA_EXISTS` | Choose a new output path. |

## Support matrix

| Environment | Status |
| --- | --- |
| Windows 10 22H2 + Snipaste 2.x | Supported fallback target |
| Windows 11 with working native capture | Use native Computer Use |
| Authentication/security/password surfaces | Intentionally unsupported |

## Safety boundary

The skill refuses overwrites, stores captures locally, and excludes window titles by default. It never captures authentication dialogs, password managers, Windows security surfaces, or content known to contain secrets.

## Development and tests

Install the pinned test dependency and run the suite:

```powershell
Install-Module Pester -RequiredVersion 6.1.0 -Scope CurrentUser -Force -SkipPublisherCheck
./tests/run.ps1
```

Test results and coverage are written under `test-results/`. The suite enforces a 40% coverage floor for the deterministic scripts; live Snipaste capture remains an end-to-end test because CI has no interactive desktop. GitHub Actions runs the same suite under PowerShell 7 and Windows PowerShell 5.1 on every push and pull request.

## License

MIT

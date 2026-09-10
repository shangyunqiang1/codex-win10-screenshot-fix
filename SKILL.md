---
name: win10-snipaste-fallback
description: Use Snipaste as a local screenshot fallback when Windows 10 Computer Use capture fails with SetIsBorderRequired or 0x80004002. Do not use when native Computer Use screenshots work.
---

# Win10 Snipaste Fallback

Keep Computer Use (`@oai/sky`) for window discovery, activation, accessibility state, and input. Replace only the failed screenshot observation step with Snipaste.

## Workflow

1. Follow the `computer-use` skill, select exactly one returned target window, and activate it.
2. Use native `get_window_state` screenshot capture once unless the failure is already established in the current task. Fall back only for `SetIsBorderRequired`, `0x80004002`, or an explicit user request to use Snipaste.
3. Keep using text-only Computer Use state when available: `get_window_state({ window, include_screenshot: false, include_text: true })`.
4. Optionally run `scripts/diagnose.ps1` before the first capture. It reports readiness without exposing executable paths or window titles by default.
5. Immediately after activating the verified target, run `scripts/capture-active-window.ps1` with a new output path under a local task directory. Pass `-SnipastePath` only if automatic discovery fails. Pass `-ExpectedProcessId` or `-ExpectedWindowHandle` when a trusted value is available.
6. Require both the PNG and its JSON sidecar. Confirm `status` is `ok`, the foreground-window check passed, and image dimensions and SHA-256 are present.
7. Inspect the PNG with the local image-viewing tool. Re-capture after any action that changes layout, focus, or modal state.

## Recovery

Errors have stable codes. For `FOCUS_UNSTABLE` or `FOCUS_CHANGED`, reactivate the uniquely selected Computer Use window and retry exactly once with a new output path. Stop if the retry fails. Do not retry `TARGET_MISMATCH`, `INVALID_OUTPUT`, or an unexpected error without diagnosing the cause.

```powershell
./scripts/capture-active-window.ps1 -OutputPath ./captures/window.png
```

Window titles are excluded from metadata unless `-IncludeWindowTitle` is explicitly requested. Metadata records physical image dimensions plus the window DPI scale; it does not turn the PNG into a Computer Use screenshot observation.

Prefer accessibility elements and keyboard navigation for input. Snipaste images are physical pixels and may not match Computer Use logical coordinates under display scaling; do not derive coordinate clicks from them unless the scale is established and the result is verified after one action.

## Boundaries

- Store captures locally and never upload them unless the user separately requests and authorizes that transmission.
- Do not capture authentication dialogs, password managers, Windows security surfaces, or content known to contain secrets.
- Stop if the target window cannot be uniquely identified or kept active. A rejected capture is deleted because it may belong to the wrong window.
- Preserve the Computer Use confirmation policy for all Windows UI actions.
- If Snipaste cannot be discovered automatically, ask the user for the exact `Snipaste.exe` path.

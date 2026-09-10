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
4. Immediately after activating the verified target, run `scripts/capture-active-window.ps1` with a new output path under a local task directory. Pass `-SnipastePath` only if automatic discovery fails.
5. Inspect the resulting PNG with the local image-viewing tool. Re-capture after any action that changes layout, focus, or modal state.

Prefer accessibility elements and keyboard navigation for input. Snipaste images are physical pixels and may not match Computer Use logical coordinates under display scaling; do not derive coordinate clicks from them unless the scale is established and the result is verified after one action.

## Boundaries

- Store captures locally and never upload them unless the user separately requests and authorizes that transmission.
- Do not capture authentication dialogs, password managers, Windows security surfaces, or content known to contain secrets.
- Stop if the target window cannot be uniquely identified or kept active.
- Preserve the Computer Use confirmation policy for all Windows UI actions.
- If Snipaste cannot be discovered automatically, ask the user for the exact `Snipaste.exe` path.

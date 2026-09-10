# Changelog

## Unreleased

## 0.3.2 - 2026-09-10

- Rename the GitHub repository to `codex-win10-screenshot-fix` and add discovery-focused topics.
- Discover portable Snipaste installations through a persistent per-user configuration or `CODEX_SNIPASTE_PATH` override.
- Add `scripts/configure.ps1`, regression tests, and bilingual setup instructions without scanning unrelated drives.
- Wait until Snipaste releases the PNG before validation, and preserve the original capture error while retrying cleanup.

## 0.3.1 - 2026-09-10

- Use two explicit GitHub Actions jobs after GitHub rejected the equivalent matrix workflow before job creation.

## 0.3.0 - 2026-09-10

- Replace the lightweight validation script with a real Pester 6.1 test suite.
- Test window identity, PNG parsing, error codes, diagnostics privacy, script syntax, and package integrity.
- Run CI jobs on both PowerShell 7 and Windows PowerShell 5.1 and upload NUnit/JaCoCo artifacts.
- Expand and synchronize the English and Simplified Chinese documentation.

## 0.2.1 - 2026-09-10

- Update GitHub Actions checkout to the Node.js 24-based v6 runtime.

## 0.2.0 - 2026-09-10

- Verify that the foreground window is stable before capture and unchanged afterward.
- Write a privacy-conscious JSON sidecar with dimensions, DPI scale, duration, and SHA-256.
- Add stable error codes for safe one-retry recovery.
- Add a read-only diagnostic command and Windows CI validation.
- Document the physical-pixel versus logical-coordinate boundary.

## 0.1.0 - 2026-09-10

- Initial Snipaste active-window screenshot fallback.

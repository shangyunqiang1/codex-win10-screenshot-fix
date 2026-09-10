[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
foreach ($script in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'scripts') -Filter '*.ps1') {
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref] $tokens, [ref] $errors)
    if ($errors.Count -gt 0) { throw "PowerShell parse failure in $($script.Name): $($errors[0].Message)" }
}
$skill = Get-Content -LiteralPath (Join-Path $repoRoot 'SKILL.md') -Raw
if ($skill -notmatch '(?s)^---\s+name:\s*win10-snipaste-fallback\s+description:.+?\s+---') { throw 'SKILL.md frontmatter is missing or invalid.' }
. (Join-Path $repoRoot 'scripts\Win10Snipaste.Common.ps1')
$same = [pscustomobject]@{ handle = '0x123'; processId = 42 }
if (-not (Test-MatchingWindowSnapshot -Before $same -After $same)) { throw 'Identical windows should match.' }
if (Test-MatchingWindowSnapshot -Before $same -After ([pscustomobject]@{ handle = '0x456'; processId = 42 })) { throw 'Different handles should not match.' }
if (Test-MatchingWindowSnapshot -Before $same -After ([pscustomobject]@{ handle = '0x123'; processId = 99 })) { throw 'Different processes should not match.' }
$diagnostic = & (Join-Path $repoRoot 'scripts\diagnose.ps1') | ConvertFrom-Json
if ($diagnostic.schemaVersion -ne 1) { throw 'Unexpected diagnostic schema version.' }
if ($diagnostic.privacy.executablePathsIncluded -ne $false) { throw 'Diagnostics must not expose executable paths.' }
if ($diagnostic.privacy.windowTitleIncluded -ne $false) { throw 'Window titles must be opt-in.' }
'Validation passed.'

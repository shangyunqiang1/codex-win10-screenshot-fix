[CmdletBinding()]
param([string] $SnipastePath, [switch] $IncludeWindowTitle)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Win10Snipaste.Common.ps1')
$windowsInfo = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$snipaste = $null
$snipasteError = $null
try { $snipaste = Find-SnipasteExecutable -ExplicitPath $SnipastePath } catch { $snipasteError = $_.Exception.Message }
$foregroundWindow = $null
$foregroundWindowError = $null
try { $foregroundWindow = Get-ForegroundWindowSnapshot -IncludeWindowTitle:$IncludeWindowTitle } catch { $foregroundWindowError = $_.Exception.Message }
$result = [ordered]@{
    schemaVersion = 1
    status = if ($snipaste) { 'ready' } else { 'action-required' }
    os = [ordered]@{ productName = $windowsInfo.ProductName; displayVersion = $windowsInfo.DisplayVersion; build = "$($windowsInfo.CurrentBuildNumber).$($windowsInfo.UBR)" }
    powershell = [ordered]@{ edition = $PSVersionTable.PSEdition; version = $PSVersionTable.PSVersion.ToString() }
    snipaste = if ($snipaste) { [ordered]@{ found = $true; version = [Diagnostics.FileVersionInfo]::GetVersionInfo($snipaste).ProductVersion; running = [bool](Get-Process -Name 'Snipaste' -ErrorAction SilentlyContinue) } } else { [ordered]@{ found = $false; error = $snipasteError } }
    foregroundWindow = $foregroundWindow
    foregroundWindowError = $foregroundWindowError
    privacy = [ordered]@{ executablePathsIncluded = $false; windowTitleIncluded = [bool] $IncludeWindowTitle }
    nativeCaptureProbe = 'not-run'
}
$result | ConvertTo-Json -Depth 6

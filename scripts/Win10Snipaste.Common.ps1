Set-StrictMode -Version Latest

function Write-FallbackError {
    param([Parameter(Mandatory = $true)][string] $Code, [Parameter(Mandatory = $true)][string] $Message)
    throw "[$Code] $Message"
}

function Find-SnipasteExecutable {
    param([string] $ExplicitPath)
    if ($ExplicitPath) {
        $candidate = [System.IO.Path]::GetFullPath($ExplicitPath)
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        Write-FallbackError -Code 'SNIPASTE_NOT_FOUND' -Message "Snipaste executable not found: $candidate"
    }
    $running = Get-Process -Name 'Snipaste' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($running) {
        try { if ($running.Path -and (Test-Path -LiteralPath $running.Path -PathType Leaf)) { return $running.Path } } catch { }
    }
    foreach ($commandName in @('Snipaste.exe', 'Snipaste')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) { return $command.Source }
    }
    foreach ($key in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\Snipaste.exe',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\Snipaste.exe',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\Snipaste.exe'
    )) {
        $entry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($entry) {
            $property = $entry.PSObject.Properties['(default)']
            $registeredPath = if ($property) { $property.Value } else { $null }
            if ($registeredPath -and (Test-Path -LiteralPath $registeredPath -PathType Leaf)) { return $registeredPath }
        }
    }
    $commonPaths = @()
    if ($env:LOCALAPPDATA) { $commonPaths += Join-Path $env:LOCALAPPDATA 'Snipaste\Snipaste.exe' }
    if ($env:ProgramFiles) { $commonPaths += Join-Path $env:ProgramFiles 'Snipaste\Snipaste.exe' }
    if (${env:ProgramFiles(x86)}) { $commonPaths += Join-Path ${env:ProgramFiles(x86)} 'Snipaste\Snipaste.exe' }
    foreach ($candidate in $commonPaths) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    Write-FallbackError -Code 'SNIPASTE_NOT_FOUND' -Message 'Snipaste.exe was not found. Start Snipaste or pass -SnipastePath with its exact path.'
}

function Initialize-ForegroundWindowApi {
    if ('Win10SnipasteFallback.NativeMethods' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace Win10SnipasteFallback {
    public static class NativeMethods {
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll")][return: MarshalAs(UnmanagedType.Bool)] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
        [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);
    }
}
'@
}

function Get-ForegroundWindowSnapshot {
    param([switch] $IncludeWindowTitle)
    Initialize-ForegroundWindowApi
    $handle = [Win10SnipasteFallback.NativeMethods]::GetForegroundWindow()
    if ($handle -eq [IntPtr]::Zero) { Write-FallbackError -Code 'NO_FOREGROUND_WINDOW' -Message 'Windows did not report a foreground window.' }
    [uint32] $processId = 0
    [void][Win10SnipasteFallback.NativeMethods]::GetWindowThreadProcessId($handle, [ref] $processId)
    $rect = New-Object Win10SnipasteFallback.NativeMethods+RECT
    $hasRect = [Win10SnipasteFallback.NativeMethods]::GetWindowRect($handle, [ref] $rect)
    $dpi = 96
    try { $reportedDpi = [Win10SnipasteFallback.NativeMethods]::GetDpiForWindow($handle); if ($reportedDpi -gt 0) { $dpi = [int] $reportedDpi } } catch [System.EntryPointNotFoundException] { }
    $processName = $null
    try { $processName = (Get-Process -Id $processId -ErrorAction Stop).ProcessName } catch { }
    $snapshot = [ordered]@{
        handle = ('0x{0:X}' -f $handle.ToInt64())
        processId = [int] $processId
        processName = $processName
        rect = if ($hasRect) { [ordered]@{ left = $rect.Left; top = $rect.Top; right = $rect.Right; bottom = $rect.Bottom; width = $rect.Right - $rect.Left; height = $rect.Bottom - $rect.Top } } else { $null }
        dpi = $dpi
        scale = [Math]::Round($dpi / 96.0, 3)
    }
    if ($IncludeWindowTitle) {
        $buffer = New-Object System.Text.StringBuilder 1024
        [void][Win10SnipasteFallback.NativeMethods]::GetWindowText($handle, $buffer, $buffer.Capacity)
        $snapshot.windowTitle = $buffer.ToString()
    }
    [pscustomobject] $snapshot
}

function Get-PngDimensions {
    param([Parameter(Mandatory = $true)][string] $Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try { $header = New-Object byte[] 24; if ($stream.Read($header, 0, $header.Length) -ne $header.Length) { Write-FallbackError -Code 'INVALID_OUTPUT' -Message 'The capture is too short to be a PNG.' } } finally { $stream.Dispose() }
    $signature = @(137, 80, 78, 71, 13, 10, 26, 10)
    for ($index = 0; $index -lt $signature.Count; $index++) { if ($header[$index] -ne $signature[$index]) { Write-FallbackError -Code 'INVALID_OUTPUT' -Message 'The capture does not have a valid PNG signature.' } }
    [pscustomobject]@{
        width = [System.Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($header, 16))
        height = [System.Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($header, 20))
    }
}

function Test-MatchingWindowSnapshot {
    param([Parameter(Mandatory = $true)] $Before, [Parameter(Mandatory = $true)] $After)
    ($Before.handle -eq $After.handle) -and ($Before.processId -eq $After.processId)
}

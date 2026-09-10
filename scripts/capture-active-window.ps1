[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $OutputPath,
    [string] $MetadataPath,
    [string] $SnipastePath,
    [int] $ExpectedProcessId,
    [string] $ExpectedWindowHandle,
    [switch] $IncludeWindowTitle,
    [ValidateRange(1, 30)][int] $TimeoutSeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Win10Snipaste.Common.ps1')

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
if (-not [System.IO.Path]::GetExtension($resolvedOutput).Equals('.png', [StringComparison]::OrdinalIgnoreCase)) {
    Write-FallbackError -Code 'INVALID_ARGUMENT' -Message 'OutputPath must end in .png.'
}
if (Test-Path -LiteralPath $resolvedOutput) {
    Write-FallbackError -Code 'OUTPUT_EXISTS' -Message "Refusing to overwrite an existing capture: $resolvedOutput"
}
$resolvedMetadata = if ($MetadataPath) { [System.IO.Path]::GetFullPath($MetadataPath) } else { [System.IO.Path]::ChangeExtension($resolvedOutput, '.json') }
if (Test-Path -LiteralPath $resolvedMetadata) {
    Write-FallbackError -Code 'METADATA_EXISTS' -Message "Refusing to overwrite existing metadata: $resolvedMetadata"
}

$resolvedSnipaste = Find-SnipasteExecutable -ExplicitPath $SnipastePath
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($resolvedOutput)) | Out-Null
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($resolvedMetadata)) | Out-Null
$running = Get-Process -Name 'Snipaste' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $running) {
    Start-Process -FilePath $resolvedSnipaste -WindowStyle Hidden
    $startDeadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 200
        $running = Get-Process -Name 'Snipaste' -ErrorAction SilentlyContinue | Select-Object -First 1
    } while (-not $running -and [DateTime]::UtcNow -lt $startDeadline)
    if (-not $running) { Write-FallbackError -Code 'SNIPASTE_START_FAILED' -Message 'Snipaste did not start within 5 seconds.' }
}

$before = Get-ForegroundWindowSnapshot -IncludeWindowTitle:$IncludeWindowTitle
Start-Sleep -Milliseconds 150
$stable = Get-ForegroundWindowSnapshot -IncludeWindowTitle:$IncludeWindowTitle
if (-not (Test-MatchingWindowSnapshot -Before $before -After $stable)) {
    Write-FallbackError -Code 'FOCUS_UNSTABLE' -Message 'The foreground window changed immediately before capture. Reactivate the target and retry once.'
}
if ($ExpectedProcessId -and $stable.processId -ne $ExpectedProcessId) {
    Write-FallbackError -Code 'TARGET_MISMATCH' -Message "Foreground PID $($stable.processId) does not match expected PID $ExpectedProcessId."
}
if ($ExpectedWindowHandle -and -not $stable.handle.Equals($ExpectedWindowHandle, [StringComparison]::OrdinalIgnoreCase)) {
    Write-FallbackError -Code 'TARGET_MISMATCH' -Message "Foreground handle $($stable.handle) does not match expected handle $ExpectedWindowHandle."
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    # The target is already uniquely selected and verified above. Passing its
    # exact rectangle avoids Snipaste's second, timing-sensitive active-window
    # lookup, which can silently produce no file on Windows 10.
    $snipasteArguments = Get-SnipasteAreaCaptureArguments -Rect $stable.rect -OutputPath $resolvedOutput
    & $resolvedSnipaste @snipasteArguments
    $captureDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $captureReady = $false
    do {
        Start-Sleep -Milliseconds 100
        $capture = Get-Item -LiteralPath $resolvedOutput -ErrorAction SilentlyContinue
        if ($capture -and $capture.Length -gt 0) {
            $stream = $null
            try {
                $stream = [System.IO.File]::Open($resolvedOutput, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
                $captureReady = $true
            } catch { } finally {
                if ($stream) { $stream.Dispose() }
            }
        }
    } while (-not $captureReady -and [DateTime]::UtcNow -lt $captureDeadline)
    if (-not $captureReady) {
        Write-FallbackError -Code 'CAPTURE_TIMEOUT' -Message "Snipaste did not finish writing a non-empty PNG within $TimeoutSeconds seconds."
    }
    $dimensions = Get-PngDimensions -Path $resolvedOutput
    $after = Get-ForegroundWindowSnapshot -IncludeWindowTitle:$IncludeWindowTitle
    if (-not (Test-MatchingWindowSnapshot -Before $stable -After $after)) {
        Write-FallbackError -Code 'FOCUS_CHANGED' -Message 'The foreground window changed during capture. The untrusted capture was removed; reactivate the target and retry once.'
    }
    $stopwatch.Stop()
    $metadata = [ordered]@{
        schemaVersion = 1
        status = 'ok'
        backend = 'snipaste-window-rect'
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        durationMs = $stopwatch.ElapsedMilliseconds
        image = [ordered]@{
            fileName = [System.IO.Path]::GetFileName($resolvedOutput)
            bytes = $capture.Length
            width = $dimensions.width
            height = $dimensions.height
            sha256 = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        foregroundVerification = [ordered]@{
            stable = $true
            beforeHandle = $stable.handle
            afterHandle = $after.handle
            beforeProcessId = $stable.processId
            afterProcessId = $after.processId
        }
        window = $after
        snipaste = [ordered]@{ version = [Diagnostics.FileVersionInfo]::GetVersionInfo($resolvedSnipaste).ProductVersion }
    }
    $temporaryMetadata = "$resolvedMetadata.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $temporaryMetadata -Encoding UTF8
        Move-Item -LiteralPath $temporaryMetadata -Destination $resolvedMetadata
    } finally {
        if (Test-Path -LiteralPath $temporaryMetadata) { Remove-Item -LiteralPath $temporaryMetadata -Force }
    }
    [pscustomobject]@{
        status = 'ok'
        outputPath = $resolvedOutput
        metadataPath = $resolvedMetadata
        width = $dimensions.width
        height = $dimensions.height
        sha256 = $metadata.image.sha256
    }
} catch {
    $originalError = $_
    $stopwatch.Stop()
    $cleanupFailures = @()
    if (-not (Remove-FallbackArtifact -Path $resolvedOutput)) { $cleanupFailures += $resolvedOutput }
    if (-not (Remove-FallbackArtifact -Path $resolvedMetadata)) { $cleanupFailures += $resolvedMetadata }
    if ($cleanupFailures.Count -gt 0) { Write-Warning 'One or more rejected capture artifacts could not be removed after retrying.' }
    throw $originalError
}

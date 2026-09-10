[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $OutputPath,

    [string] $SnipastePath,

    [ValidateRange(1, 30)]
    [int] $TimeoutSeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-SnipasteExecutable {
    param([string] $ExplicitPath)

    if ($ExplicitPath) {
        $candidate = [System.IO.Path]::GetFullPath($ExplicitPath)
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
        throw "Snipaste executable not found: $candidate"
    }

    $running = Get-Process -Name 'Snipaste' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($running) {
        try {
            if ($running.Path -and (Test-Path -LiteralPath $running.Path -PathType Leaf)) {
                return $running.Path
            }
        } catch {
            # Continue with non-process discovery methods.
        }
    }

    foreach ($commandName in @('Snipaste.exe', 'Snipaste')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
            return $command.Source
        }
    }

    $registryKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\Snipaste.exe',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\Snipaste.exe',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\Snipaste.exe'
    )
    foreach ($key in $registryKeys) {
        $entry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($entry) {
            $defaultProperty = $entry.PSObject.Properties['(default)']
            $registeredPath = if ($defaultProperty) { $defaultProperty.Value } else { $null }
            if ($registeredPath -and (Test-Path -LiteralPath $registeredPath -PathType Leaf)) {
                return $registeredPath
            }
        }
    }

    $commonPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Snipaste\Snipaste.exe'),
        (Join-Path $env:ProgramFiles 'Snipaste\Snipaste.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $commonPaths += Join-Path ${env:ProgramFiles(x86)} 'Snipaste\Snipaste.exe'
    }
    foreach ($candidate in $commonPaths) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw 'Snipaste.exe was not found. Start Snipaste or pass -SnipastePath with its exact path.'
}

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
if ([System.IO.Path]::GetExtension($resolvedOutput) -ne '.png') {
    throw 'OutputPath must end in .png.'
}
if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Refusing to overwrite an existing capture: $resolvedOutput"
}

$resolvedSnipaste = Find-SnipasteExecutable -ExplicitPath $SnipastePath
$outputDirectory = [System.IO.Path]::GetDirectoryName($resolvedOutput)
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null

$running = Get-Process -Name 'Snipaste' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $running) {
    Start-Process -FilePath $resolvedSnipaste -WindowStyle Hidden
    $startDeadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 200
        $running = Get-Process -Name 'Snipaste' -ErrorAction SilentlyContinue | Select-Object -First 1
    } while (-not $running -and [DateTime]::UtcNow -lt $startDeadline)
    if (-not $running) {
        throw 'Snipaste did not start within 5 seconds.'
    }
}

& $resolvedSnipaste snip --active-window -o $resolvedOutput

$captureDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
do {
    Start-Sleep -Milliseconds 200
    $capture = Get-Item -LiteralPath $resolvedOutput -ErrorAction SilentlyContinue
} while ((-not $capture -or $capture.Length -le 0) -and [DateTime]::UtcNow -lt $captureDeadline)

if (-not $capture -or $capture.Length -le 0) {
    throw "Snipaste did not create a non-empty PNG within $TimeoutSeconds seconds. Check that this Snipaste build supports direct file output."
}

$capture | Select-Object FullName, Length, LastWriteTime

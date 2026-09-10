Describe 'Win10Snipaste common helpers' {
    BeforeAll {
        $scriptRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts'
        . (Join-Path $scriptRoot 'Win10Snipaste.Common.ps1')
    }

    Context 'Test-MatchingWindowSnapshot' {
        It 'accepts an unchanged HWND and PID' {
            $snapshot = [pscustomobject]@{ handle = '0x123'; processId = 42 }
            Test-MatchingWindowSnapshot -Before $snapshot -After $snapshot | Should -Be $true
        }

        It 'rejects a changed HWND' {
            $before = [pscustomobject]@{ handle = '0x123'; processId = 42 }
            $after = [pscustomobject]@{ handle = '0x456'; processId = 42 }
            Test-MatchingWindowSnapshot -Before $before -After $after | Should -Be $false
        }

        It 'rejects a changed PID' {
            $before = [pscustomobject]@{ handle = '0x123'; processId = 42 }
            $after = [pscustomobject]@{ handle = '0x123'; processId = 99 }
            Test-MatchingWindowSnapshot -Before $before -After $after | Should -Be $false
        }
    }

    Context 'Get-PngDimensions' {
        It 'reads big-endian dimensions from a PNG header' {
            $path = Join-Path $TestDrive 'sample.png'
            [byte[]] $header = New-Object byte[] 24
            [byte[]] $signature = 137, 80, 78, 71, 13, 10, 26, 10
            [Array]::Copy($signature, 0, $header, 0, $signature.Length)
            $header[16] = 0; $header[17] = 0; $header[18] = 1; $header[19] = 2
            $header[20] = 0; $header[21] = 0; $header[22] = 0; $header[23] = 129
            [IO.File]::WriteAllBytes($path, $header)

            $dimensions = Get-PngDimensions -Path $path
            $dimensions.width | Should -Be 258
            $dimensions.height | Should -Be 129
        }

        It 'rejects a file without the PNG signature' {
            $path = Join-Path $TestDrive 'invalid.png'
            [IO.File]::WriteAllBytes($path, (New-Object byte[] 24))
            try {
                Get-PngDimensions -Path $path
                throw 'Expected Get-PngDimensions to reject the file.'
            } catch {
                $_.Exception.Message | Should -Match '\[INVALID_OUTPUT\]'
            }
        }
    }

    Context 'Remove-FallbackArtifact' {
        It 'removes a rejected capture artifact' {
            $path = Join-Path $TestDrive 'rejected.png'
            Set-Content -LiteralPath $path -Value 'untrusted'

            Remove-FallbackArtifact -Path $path -Attempts 1 -DelayMilliseconds 0 | Should -Be $true
            Test-Path -LiteralPath $path | Should -Be $false
        }

        It 'succeeds when the artifact is already absent' {
            Remove-FallbackArtifact -Path (Join-Path $TestDrive 'absent.png') -Attempts 1 -DelayMilliseconds 0 | Should -Be $true
        }
    }

    Context 'Find-SnipasteExecutable' {
        BeforeEach {
            $script:previousExecutableOverride = $env:CODEX_SNIPASTE_PATH
            $script:previousConfigOverride = $env:CODEX_SNIPASTE_CONFIG
            $script:previousPath = $env:PATH
            Remove-Item Env:CODEX_SNIPASTE_PATH -ErrorAction SilentlyContinue
            $env:CODEX_SNIPASTE_CONFIG = Join-Path $TestDrive 'missing-config.json'
        }

        AfterEach {
            if ($null -eq $script:previousExecutableOverride) { Remove-Item Env:CODEX_SNIPASTE_PATH -ErrorAction SilentlyContinue } else { $env:CODEX_SNIPASTE_PATH = $script:previousExecutableOverride }
            if ($null -eq $script:previousConfigOverride) { Remove-Item Env:CODEX_SNIPASTE_CONFIG -ErrorAction SilentlyContinue } else { $env:CODEX_SNIPASTE_CONFIG = $script:previousConfigOverride }
            $env:PATH = $script:previousPath
        }

        It 'returns an explicitly supplied existing executable' {
            $path = Join-Path $TestDrive 'Snipaste.exe'
            Set-Content -LiteralPath $path -Value ''
            Find-SnipasteExecutable -ExplicitPath $path | Should -Be ([IO.Path]::GetFullPath($path))
        }

        It 'uses a stable error code for a missing explicit executable' {
            $path = Join-Path $TestDrive 'missing\Snipaste.exe'
            try {
                Find-SnipasteExecutable -ExplicitPath $path
                throw 'Expected Find-SnipasteExecutable to reject the path.'
            } catch {
                $_.Exception.Message | Should -Match '\[SNIPASTE_NOT_FOUND\]'
            }
        }

        It 'discovers a portable executable from the environment override' {
            $path = Join-Path $TestDrive 'portable-after-stale-config\Snipaste.exe'
            New-Item -ItemType Directory -Path (Split-Path -Parent $path) | Out-Null
            Set-Content -LiteralPath $path -Value ''
            $env:CODEX_SNIPASTE_PATH = $path

            Find-SnipasteExecutable | Should -Be ([IO.Path]::GetFullPath($path))
        }

        It 'discovers a portable executable from saved configuration' {
            $path = Join-Path $TestDrive 'portable-config\Snipaste.exe'
            New-Item -ItemType Directory -Path (Split-Path -Parent $path) | Out-Null
            Set-Content -LiteralPath $path -Value ''
            Set-SnipasteConfiguration -SnipastePath $path -ConfigPath $env:CODEX_SNIPASTE_CONFIG | Out-Null

            Find-SnipasteExecutable | Should -Be ([IO.Path]::GetFullPath($path))
        }

        It 'ignores a stale saved path and continues discovery' {
            @{ schemaVersion = 1; snipastePath = (Join-Path $TestDrive 'gone\Snipaste.exe') } |
                ConvertTo-Json | Set-Content -LiteralPath $env:CODEX_SNIPASTE_CONFIG
            $directory = Join-Path $TestDrive 'portable-on-path'
            $path = Join-Path $directory 'Snipaste.exe'
            New-Item -ItemType Directory -Path $directory | Out-Null
            Set-Content -LiteralPath $path -Value ''
            $env:PATH = "$directory;$env:PATH"

            Find-SnipasteExecutable | Should -Be ([IO.Path]::GetFullPath($path))
        }
    }

    Context 'Get-SnipasteAreaCaptureArguments' {
        It 'uses the already verified physical window rectangle instead of a second active-window lookup' {
            $arguments = Get-SnipasteAreaCaptureArguments -Rect ([pscustomobject]@{
                    left = -12; top = 24; width = 1280; height = 720
                }) -OutputPath 'C:\captures\window.png'

            $arguments | Should -Be @('snip', '--area', '-12', '24', '1280', '720', '-o', 'C:\captures\window.png')
        }

        It 'rejects a missing or empty window rectangle' {
            {
                Get-SnipasteAreaCaptureArguments -Rect ([pscustomobject]@{ left = 0; top = 0; width = 0; height = 10 }) -OutputPath 'C:\captures\window.png'
            } | Should -Throw '*[INVALID_WINDOW_RECT]*'
        }
    }
}

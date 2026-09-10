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

    Context 'Find-SnipasteExecutable' {
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
    }
}

Describe 'capture-active-window preflight' {
    BeforeAll {
        $script:captureScript = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts') 'capture-active-window.ps1'
    }

    It 'rejects a non-PNG output before invoking Snipaste' {
        try {
            & $captureScript -OutputPath (Join-Path $TestDrive 'capture.txt')
            throw 'Expected the capture script to reject the extension.'
        } catch {
            $_.Exception.Message | Should -Match '\[INVALID_ARGUMENT\]'
        }
    }

    It 'refuses to overwrite an existing PNG' {
        $output = Join-Path $TestDrive 'capture.png'
        Set-Content -LiteralPath $output -Value 'existing'
        try {
            & $captureScript -OutputPath $output
            throw 'Expected the capture script to refuse the overwrite.'
        } catch {
            $_.Exception.Message | Should -Match '\[OUTPUT_EXISTS\]'
        }
    }

    It 'refuses to overwrite existing metadata' {
        $output = Join-Path $TestDrive 'capture-metadata.png'
        $metadata = [IO.Path]::ChangeExtension($output, '.json')
        Set-Content -LiteralPath $metadata -Value '{}'
        try {
            & $captureScript -OutputPath $output
            throw 'Expected the capture script to refuse the metadata overwrite.'
        } catch {
            $_.Exception.Message | Should -Match '\[METADATA_EXISTS\]'
        }
    }
}

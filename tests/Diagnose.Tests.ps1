Describe 'diagnose output' {
    BeforeAll {
        $diagnoseScript = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts') 'diagnose.ps1'
        $fakeSnipaste = Join-Path $TestDrive 'Snipaste.exe'
        Set-Content -LiteralPath $fakeSnipaste -Value ''
        $script:json = & $diagnoseScript -SnipastePath $fakeSnipaste
        $script:result = $json | ConvertFrom-Json
    }

    It 'emits versioned valid JSON' {
        $result.schemaVersion | Should -Be 1
        $result.status | Should -Be 'ready'
        $result.snipaste.found | Should -Be $true
    }

    It 'keeps sensitive window details opt-in' {
        $result.privacy.executablePathsIncluded | Should -Be $false
        $result.privacy.windowTitleIncluded | Should -Be $false
        $json | Should -Not -Match '"windowTitle"'
    }

    It 'does not claim that native capture was probed' {
        $result.nativeCaptureProbe | Should -Be 'not-run'
    }
}

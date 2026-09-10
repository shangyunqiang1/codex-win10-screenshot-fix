Describe 'skill package' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent $PSScriptRoot
    }

    It 'contains the required skill resources' {
        @(
            'SKILL.md',
            'agents\openai.yaml',
            'scripts\Win10Snipaste.Common.ps1',
            'scripts\capture-active-window.ps1',
            'scripts\diagnose.ps1',
            'README.md',
            'README.zh-CN.md'
        ) | ForEach-Object {
            Test-Path -LiteralPath (Join-Path $repoRoot $_) | Should -Be $true
        }
    }

    It 'has valid skill frontmatter' {
        $skill = Get-Content -LiteralPath (Join-Path $repoRoot 'SKILL.md') -Raw
        $skill | Should -Match '(?s)^---\s+name:\s*win10-snipaste-fallback\s+description:.+?\s+---'
    }

    It 'parses every PowerShell script without syntax errors' {
        $scriptDirectories = @((Join-Path $repoRoot 'scripts'), (Join-Path $repoRoot 'tests'))
        foreach ($script in Get-ChildItem -LiteralPath $scriptDirectories -Filter '*.ps1' -Recurse) {
            $tokens = $null
            $errors = $null
            [void][Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref] $tokens, [ref] $errors)
            $errors.Count | Should -Be 0 -Because "$($script.Name) must parse"
        }
    }

    It 'keeps both guides connected to the executable workflow' {
        foreach ($guide in @('README.md', 'README.zh-CN.md')) {
            $content = Get-Content -LiteralPath (Join-Path $repoRoot $guide) -Raw
            $content | Should -Match 'scripts/capture-active-window\.ps1'
            $content | Should -Match 'scripts/diagnose\.ps1'
            $content | Should -Match 'https://www\.snipaste\.com/'
        }
    }
}

[CmdletBinding()]
param(
    [string] $OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'test-results')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pester = Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [Version]'6.1.0' } | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester) {
    throw 'Pester 6.1.0 or newer is required. Run: Install-Module Pester -RequiredVersion 6.1.0 -Scope CurrentUser -Force -SkipPublisherCheck'
}
Import-Module $pester.Path -Force
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$configuration = New-PesterConfiguration
$configuration.Run.Path = $PSScriptRoot
$configuration.Run.Exit = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputPath = Join-Path $OutputDirectory 'test-results.xml'
$configuration.TestResult.OutputFormat = 'NUnitXml'
$configuration.CodeCoverage.Enabled = $true
$configuration.CodeCoverage.Path = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\*.ps1'
$configuration.CodeCoverage.CoveragePercentTarget = 40
$configuration.CodeCoverage.OutputPath = Join-Path $OutputDirectory 'coverage.xml'
$configuration.CodeCoverage.OutputFormat = 'JaCoCo'

Invoke-Pester -Configuration $configuration

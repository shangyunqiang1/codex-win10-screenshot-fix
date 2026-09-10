[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $SnipastePath,
    [string] $ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Win10Snipaste.Common.ps1')

$saved = Set-SnipasteConfiguration -SnipastePath $SnipastePath -ConfigPath $ConfigPath
[ordered]@{
    schemaVersion = 1
    status = 'configured'
    configPath = $saved.configPath
    snipasteFound = $true
} | ConvertTo-Json

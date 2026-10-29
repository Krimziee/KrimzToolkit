#Requires -Version 5.1
<#
    Copies the toolkit's ui\Theme.xaml (the main copy of the shared look) to
    each tool next to the toolkit folder, so their own windows look the same.
    Edit the theme here only, run this, then commit the change in each tool.

    Run:  powershell -ExecutionPolicy Bypass -File Sync-Theme.ps1
          add -Check to only list the copies that differ (changes nothing)
#>
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$parent = Split-Path $root -Parent
$main = [IO.File]::ReadAllBytes((Join-Path $root 'ui\Theme.xaml'))
$tools = (Import-PowerShellDataFile (Join-Path $root 'tools.psd1')).Tabs

Write-Host ''
foreach ($t in $tools) {
    $copy = Join-Path $parent "$($t.Folder)\ui\Theme.xaml"
    if (-not (Test-Path -LiteralPath $copy)) { Write-Host "  - $($t.Folder): not found next to the toolkit" -ForegroundColor Gray; continue }
    if ([Linq.Enumerable]::SequenceEqual([byte[]][IO.File]::ReadAllBytes($copy), [byte[]]$main)) { Write-Host "  = $($t.Folder): up to date"; continue }
    if ($Check) { Write-Host "  ! $($t.Folder): differs" -ForegroundColor Yellow; continue }
    # Byte for byte, so line endings and encoding stay exactly as in the main copy
    [IO.File]::WriteAllBytes($copy, $main)
    Write-Host "  + $($t.Folder): updated - commit it in $($t.Folder)" -ForegroundColor Green
}
Write-Host ''

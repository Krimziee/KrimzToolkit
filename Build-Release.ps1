#Requires -Version 5.1
<#
    Builds a release of Krimz's Toolkit: one folder (and a zip of it) with the
    toolkit and the four tools, ready to copy to another PC or share.

        release\KrimzToolkit\                 the toolkit
        release\KrimzToolkit\tools\<Tool>\    each tool (still works on its own too)
        release\KrimzToolkit-<version>.zip

    Every project is taken from its last commit (git archive), so half-finished
    changes never end up in a release. Projects with uncommitted changes are
    listed as a warning. The tools are looked for next to the toolkit folder.

    The toolkit's ui\Theme.xaml is the main copy of the shared look. Each tool
    has its own copy so it works on its own; the release gets the main copy,
    and tools whose own copy differs are listed so it can be updated there.

    Run:  powershell -ExecutionPolicy Bypass -File Build-Release.ps1
#>

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$parent = Split-Path $root -Parent

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git is needed to build a release (it takes each project from its last commit).' }

$version = if ((Get-Content (Join-Path $root 'Toolkit.ps1') -Raw) -match "\`$script:Version = '([^']+)'") { $Matches[1] } else { 'dev' }
$tools = (Import-PowerShellDataFile (Join-Path $root 'tools.psd1')).Tabs
$release = Join-Path $root 'release'
$output = Join-Path $release 'KrimzToolkit'
$zip = Join-Path $release "KrimzToolkit-$version.zip"
$work = Join-Path $release '.work'

function Export-Project {
    # Copies a project's last commit into a folder (without .git)
    param([string]$Source, [string]$Target)
    $status = git -C $Source status --porcelain
    if ($LASTEXITCODE -ne 0) { throw "$Source is not a git repository." }
    if ($status) { Write-Host "  ! $(Split-Path $Source -Leaf) has uncommitted changes - the release uses its last commit." -ForegroundColor Yellow }
    $archive = Join-Path $work ((Split-Path $Source -Leaf) + '.zip')
    git -C $Source archive --format=zip -o $archive HEAD
    if ($LASTEXITCODE -ne 0) { throw "git archive failed for $Source." }
    Expand-Archive -Path $archive -DestinationPath $Target -Force
    "$(Split-Path $Source -Leaf) $(git -C $Source log -1 --format='%h %s')"
}

Write-Host ''
Write-Host " Building Krimz's Toolkit $version" -ForegroundColor Cyan
if (Test-Path $output) { Remove-Item $output -Recurse -Force }
if (Test-Path $zip) { Remove-Item $zip -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null

$built = @()
$built += Export-Project $root $output
$theme = Get-Content (Join-Path $root 'ui\Theme.xaml') -Raw

foreach ($t in $tools) {
    $source = Join-Path $parent $t.Folder
    if (-not (Test-Path $source)) { throw "$($t.Folder) wasn't found next to the toolkit ($source)." }
    $target = Join-Path $output "tools\$($t.Folder)"
    $built += Export-Project $source $target

    # Same look everywhere: the release gets the toolkit's theme
    $toolTheme = Join-Path $target 'ui\Theme.xaml'
    if ((Test-Path $toolTheme) -and (Get-Content $toolTheme -Raw) -ne $theme) {
        Write-Host "  ! $($t.Folder)\ui\Theme.xaml differs from the toolkit's - the release uses the toolkit's. Copy it over in $($t.Folder) too." -ForegroundColor Yellow
    }
    Copy-Item (Join-Path $root 'ui\Theme.xaml') $toolTheme -Force
}

# The build script itself and the release folder don't belong in the release
Remove-Item (Join-Path $output 'Build-Release.ps1') -Force -ErrorAction SilentlyContinue
Remove-Item $work -Recurse -Force

Compress-Archive -Path $output -DestinationPath $zip
Write-Host ''
Write-Host ' Included:' -ForegroundColor Gray
foreach ($line in $built) { Write-Host "   $line" }
Write-Host ''
Write-Host " Done:  $output" -ForegroundColor Green
Write-Host "        $zip" -ForegroundColor Green

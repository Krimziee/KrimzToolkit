<#
    Krimz's Toolkit - online starter

    Run this in PowerShell (it downloads the newest Krimz's Toolkit from
    GitHub and opens it):

        irm https://raw.githubusercontent.com/Krimziee/KrimzToolkit/main/install.ps1 | iex

    What it does:
      1. Downloads the toolkit and its four tools from github.com/Krimziee
         (KrimzToolkit, WindowsSetup, CrashExplainer, ConnectionDoctor, SecureBootCheck)
      2. Puts them together in C:\KrimzToolkit (replacing an older copy),
         with the tools in C:\KrimzToolkit\tools
      3. Starts the toolkit with admin rights (Windows asks "Yes/No")
    Nothing is changed on the PC by the tools until you choose to - Windows
    Setup asks for confirmation first, the other three only read or measure.
#>

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference    = 'SilentlyContinue'   # much faster downloads in Windows PowerShell
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $owner  = 'Krimziee'
    $tools  = 'WindowsSetup', 'CrashExplainer', 'ConnectionDoctor', 'SecureBootCheck'
    $target = 'C:\KrimzToolkit'
    $work   = Join-Path $env:TEMP 'KrimzToolkit-download'

    function Get-Project {
        # Downloads one repository's newest version and returns the unpacked folder
        param([string]$Name)
        $zip = Join-Path $work "$Name.zip"
        Invoke-WebRequest -Uri "https://github.com/$owner/$Name/archive/refs/heads/main.zip" -OutFile $zip -UseBasicParsing
        $unpack = Join-Path $work $Name
        Expand-Archive -Path $zip -DestinationPath $unpack -Force
        # GitHub puts everything in one folder named "<repo>-<branch>"
        (Get-ChildItem $unpack -Directory | Select-Object -First 1).FullName
    }

    try {
        Write-Host ''
        Write-Host " Krimz's Toolkit" -ForegroundColor Cyan
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $work -Force | Out-Null

        Write-Host ' Downloading the toolkit...' -ForegroundColor Gray
        $stage = Get-Project 'KrimzToolkit'
        if (-not (Test-Path (Join-Path $stage 'Toolkit.ps1'))) { throw 'The download looks incomplete (Toolkit.ps1 is missing).' }
        New-Item -ItemType Directory -Path (Join-Path $stage 'tools') -Force | Out-Null
        foreach ($tool in $tools) {
            Write-Host " Downloading $tool..." -ForegroundColor Gray
            $folder = Get-Project $tool
            if (-not (Test-Path (Join-Path $folder 'modules\Page.ps1'))) { throw "The download of $tool looks incomplete (modules\Page.ps1 is missing)." }
            Move-Item $folder (Join-Path $stage "tools\$tool")
        }

        Write-Host " Putting it together in $target..." -ForegroundColor Gray
        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        Copy-Item $stage $target -Recurse
        # Files from the internet are marked as "downloaded"; clear that so Windows doesn't block them
        Get-ChildItem $target -Recurse -File | Unblock-File

        Write-Host ' Starting - click "Yes" when Windows asks for permission.' -ForegroundColor Gray
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$target\Toolkit.ps1`""
        )
        Write-Host " Krimz's Toolkit is opening. You can close this window." -ForegroundColor Green
        Write-Host " Next time you can also start it from $target\Krimz's Toolkit.cmd" -ForegroundColor Gray
    }
    catch {
        Write-Host ''
        Write-Host " Couldn't start Krimz's Toolkit: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ' Check your internet connection and try again, and click "Yes" on the admin prompt.' -ForegroundColor Gray
    }
    finally {
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

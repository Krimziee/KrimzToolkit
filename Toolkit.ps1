#Requires -Version 5.1
<#
    Krimz's Toolkit
    Windows Setup, Secure Boot Check, Crash Explainer and Connection Doctor in
    one window, with a tab for each tool.

    Runs with admin rights (Windows Setup and Secure Boot Check need them).
    Started without them, it asks Windows for them and starts again.
    The toolkit itself writes nothing. Each tool keeps its own rules.

    -DryRun   Passed on to the tools: Windows Setup shows what would happen
              without changing anything (for testing)
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$script:Version = '0.1.0'

Add-Type -AssemblyName PresentationFramework

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    try {
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$PSCommandPath`"")
        if ($DryRun) { $arguments += '-DryRun' }
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments
    } catch {
        # "No" on the admin prompt
        [System.Windows.MessageBox]::Show("Krimz's Toolkit needs admin rights. Start it again and click `"Yes`".",
            "Krimz's Toolkit", 'OK', 'Information') | Out-Null
    }
    return
}

try {
    . (Join-Path $PSScriptRoot 'modules\Shell.ps1')
    Show-ToolkitWindow -Root $PSScriptRoot -Version $script:Version -IsAdmin $isAdmin -DryRun $DryRun
} catch {
    # The launcher hides the console, so errors must be shown in a message box
    [System.Windows.MessageBox]::Show("Krimz's Toolkit could not start:`n$($_.Exception.Message)", "Krimz's Toolkit", 'OK', 'Error') | Out-Null
}

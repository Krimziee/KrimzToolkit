<#
    The toolkit window: header tabs and one page per tool.

    THE TOOLKIT ITSELF WRITES NOTHING: no settings, logs or temp files. That is
    why Windows functions are declared in memory below instead of with Add-Type
    (which runs the C# compiler and writes temp files).

    Each tool's page is loaded into its own private module, so the tools can
    have functions and $script: variables with the same names without
    overwriting each other. A page file (<tool>\modules\Page.ps1) provides:

        New-ToolPage   -Root <tool folder> -Shell <hashtable>   returns the page (a WPF element)   required
        Start-ToolPrefetch -Root <tool folder>               starts slow reading in the background  optional
                                                              (returns a handle; New-ToolPage finds it in $Shell.Prefetch)
        Enter-ToolPage                       the tab was selected                                    optional
        Exit-ToolPage                        another tab was selected                                optional
        Test-ToolPageCanClose                $false keeps the window open (the page asks the user)   optional
        Close-ToolPage                       the window is closing: stop timers and background work  optional

    $Shell, given to every page:
        Window             the toolkit window (owner for dialogs)
        SetBusy            & $Shell.SetBusy $true / $false   shows or hides the working dot on the tab
        IsAdmin            whether the toolkit runs with admin rights
        DryRun             Toolkit.ps1 -DryRun: tools that change things only show what they would do
        Prefetch           what Start-ToolPrefetch returned ($null if the page has none)

    The window opens first. Pages are built after it is on screen (the first tab
    straight away, the others when the computer is idle, or at once when their
    tab is clicked), so slow tools don't hold up the start.
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$script:Shell = @{
    Window = $null
    Tabs   = [System.Collections.Generic.List[object]]::new()   # one entry per tab, see Add-ToolTab
    Active = $null
    BuildQueue = [System.Collections.Queue]::new()   # tabs whose page is still to be built
    WindowShown = $false
}

# ------------------------------------------------------------------
#  Windows functions (in memory, no files)
# ------------------------------------------------------------------

function Get-NativeMethods {
    if ($script:Native) { return $script:Native }
    $assembly = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object Reflection.AssemblyName 'KrimzToolkitNative'), 'Run')
    $type = $assembly.DefineDynamicModule('KrimzToolkitNative').DefineType('Native', 'Public, Class')
    $functions = @(
        @{ Dll = 'user32.dll'; Name = 'SetProcessDpiAwarenessContext'; Returns = [bool]; Parameters = @([IntPtr]) }
        @{ Dll = 'user32.dll'; Name = 'SetProcessDPIAware';            Returns = [bool]; Parameters = @() }
        @{ Dll = 'dwmapi.dll'; Name = 'DwmSetWindowAttribute';         Returns = [int];  Parameters = @([IntPtr], [int], [int].MakeByRefType(), [int]) }
    )
    foreach ($f in $functions) {
        $method = $type.DefinePInvokeMethod($f.Name, $f.Dll, 'Public, Static, PinvokeImpl', 'Standard', $f.Returns,
                                            [Type[]]$f.Parameters, 'Winapi', 'Auto')
        $method.SetImplementationFlags('PreserveSig')
    }
    $script:Native = $type.CreateType()
    $script:Native
}

function Enable-DpiAwareness {
    # Sharp text on high-resolution screens (otherwise Windows stretches the window and it looks blurry)
    try {
        $native = Get-NativeMethods
        if (-not $native::SetProcessDpiAwarenessContext([IntPtr]::new(-4))) { [void]$native::SetProcessDPIAware() }
    } catch { }
}

# ------------------------------------------------------------------
#  Helpers
# ------------------------------------------------------------------

function Show-ShellError {
    param([string]$Message)
    [System.Windows.MessageBox]::Show($Message, "Krimz's Toolkit", 'OK', 'Warning') | Out-Null
}

function Invoke-UiSafely {
    # An error inside a click or tab handler must never close the window
    param([scriptblock]$Action)
    try { & $Action }
    catch { Show-ShellError "Something went wrong:`n$($_.Exception.Message)" }
}

function Import-Theme {
    # The theme becomes the application's resources, so the window and every
    # page find its styles. WPF allows one Application per process.
    param([string]$Root)
    [xml]$xaml = Get-Content (Join-Path $Root 'ui\Theme.xaml') -Raw -Encoding UTF8
    $theme = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
    $app = [System.Windows.Application]::Current
    if (-not $app) { $app = New-Object System.Windows.Application }
    $app.ShutdownMode = 'OnExplicitShutdown'
    $app.Resources = $theme
}

function Resolve-ToolFolder {
    # Release copy first (tools\<Folder>), then the folder next to the toolkit
    param([string]$Root, [string]$Folder)
    foreach ($path in (Join-Path $Root "tools\$Folder"), (Join-Path (Split-Path $Root -Parent) $Folder)) {
        if (Test-Path -LiteralPath $path -PathType Container) { return (Resolve-Path -LiteralPath $path).ProviderPath }
    }
}

function Invoke-PageFunction {
    # Calls a page function inside the tool's own module. Missing optional
    # functions are skipped (returns $null).
    param($Tab, [string]$Name, [hashtable]$Arguments = @{})
    if (-not $Tab.Module) { return }
    & $Tab.Module {
        param($name, $arguments)
        if (Get-Command $name -CommandType Function -ErrorAction SilentlyContinue) { & $name @arguments }
    } $Name $Arguments
}

function New-ErrorPage {
    param([string]$Title, [string]$Message)
    $panel = New-Object System.Windows.Controls.StackPanel -Property @{ Margin = '28,26,28,20'; MaxWidth = 640; HorizontalAlignment = 'Left' }
    $head = New-Object System.Windows.Controls.TextBlock -Property @{ Text = $Title; FontSize = 20; FontWeight = 'SemiBold'; Margin = '0,0,0,8' }
    $body = New-Object System.Windows.Controls.TextBlock -Property @{ Text = $Message; TextWrapping = 'Wrap'; Foreground = '#FF99A4' }
    [void]$panel.Children.Add($head); [void]$panel.Children.Add($body)
    $panel
}

function New-LoadingPage {
    param([string]$Title)
    $panel = New-Object System.Windows.Controls.StackPanel -Property @{ Margin = '28,26,28,20'; MaxWidth = 640; HorizontalAlignment = 'Left' }
    $body = New-Object System.Windows.Controls.TextBlock -Property @{ Text = "Opening $Title..."; FontSize = 16; Foreground = '#99A4B0' }
    [void]$panel.Children.Add($body)
    $panel
}

# ------------------------------------------------------------------
#  Tabs
# ------------------------------------------------------------------

function Add-ToolTab {
    param([string]$Root, [hashtable]$Info, [bool]$IsAdmin, [bool]$DryRun)

    $tab = @{
        Info    = $Info
        Folder  = Resolve-ToolFolder $Root $Info.Folder
        Module  = $null
        Page    = $null
        Busy    = $false
        Built   = $false     # the page is built after the window is shown, see Build-ToolPage
    }

    # The tab itself: the name and a small dot shown while the tool is working
    $label = New-Object System.Windows.Controls.StackPanel -Property @{ Orientation = 'Horizontal' }
    [void]$label.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text = $Info.Title; VerticalAlignment = 'Center' }))
    $dot = New-Object System.Windows.Shapes.Ellipse -Property @{ Width = 7; Height = 7; Margin = '8,1,0,0'; VerticalAlignment = 'Center'; Visibility = 'Collapsed' }
    $dot.Fill = $script:Shell.Window.FindResource('Accent')
    [void]$label.Children.Add($dot)
    $button = New-Object System.Windows.Controls.RadioButton -Property @{ GroupName = 'Tabs'; Content = $label; Tag = $Info.Key }
    $button.Style = $script:Shell.Window.FindResource('TabButton')
    $tab.Button = $button
    $tab.Dot    = $dot

    # Page file: the tool's own page, or the placeholder until its phase is done
    $pageFile = if ($tab.Folder) { Join-Path $tab.Folder 'modules\Page.ps1' }
    $usePlaceholder = -not ($pageFile -and (Test-Path -LiteralPath $pageFile))
    if ($usePlaceholder) { $pageFile = Join-Path $Root 'pages\Placeholder.ps1' }
    $pageRoot = if ($usePlaceholder) { $Root } else { $tab.Folder }

    # SetBusy is bound to this tab; pages call & $Shell.SetBusy $true
    $setBusy = {
        param([bool]$Busy)
        $tab.Busy = $Busy
        $tab.Dot.Visibility = if ($Busy) { 'Visible' } else { 'Collapsed' }
    }.GetNewClosure()
    $shellForPage = @{ Window = $script:Shell.Window; SetBusy = $setBusy; IsAdmin = $IsAdmin; DryRun = $DryRun }

    $tab.PageRoot       = $pageRoot
    $tab.UsePlaceholder = $usePlaceholder
    $tab.ShellForPage   = $shellForPage
    $shellForPage.Prefetch = $null

    try {
        # Private module: nothing is exported, so pages can't overwrite each other's functions
        $tab.Module = New-Module -Name "KrimzToolkit.$($Info.Key)" -ArgumentList $pageFile -ScriptBlock {
            param($file)
            . $file
            Export-ModuleMember -Function @() -Variable @()
        }
        # Slow reading (hardware, network) starts now, in the background, while the window opens
        try { $shellForPage.Prefetch = Invoke-PageFunction $tab 'Start-ToolPrefetch' @{ Root = $pageRoot } } catch { $shellForPage.Prefetch = $null }
    } catch {
        $tab.Module = $null
        $tab.LoadError = $_.Exception.Message
    }

    # Each page sits in a scroll area that only scrolls when the window is shorter than the
    # page's MinHeight (small laptop screens). Otherwise the page gets exactly the visible
    # height, so its own lists and graphs size and scroll as usual.
    $frame = New-Object System.Windows.Controls.ScrollViewer -Property @{
        VerticalScrollBarVisibility = 'Auto'; HorizontalScrollBarVisibility = 'Disabled'; Focusable = $false
    }
    $frame.Content = New-LoadingPage $Info.Title
    $frame.Add_SizeChanged({
        $page = $this.Content
        $page.Height = [Math]::Max($this.ActualHeight, $page.MinHeight)
    })
    $frame.Visibility = 'Collapsed'
    $tab.Frame = $frame
    [void]$script:Shell.Window.FindName('PageHost').Children.Add($frame)
    [void]$script:Shell.Window.FindName('TabBar').Children.Add($button)
    $script:Shell.Tabs.Add($tab)

    $button.Add_Checked({ Invoke-UiSafely { Select-ToolTab $this.Tag } })
}

function Build-ToolPage {
    # Builds the tab's page (once). Until then the tab shows "Opening...".
    param($Tab)
    if ($Tab.Built) { return }
    $Tab.Built = $true
    $info = $Tab.Info
    try {
        if ($Tab.LoadError) { throw $Tab.LoadError }
        $arguments = @{ Root = $Tab.PageRoot; Shell = $Tab.ShellForPage }
        if ($Tab.UsePlaceholder) { $arguments.Tool = $info; $arguments.ToolFolder = $Tab.Folder }
        $Tab.Page = Invoke-PageFunction $Tab 'New-ToolPage' $arguments
        if (-not ($Tab.Page -is [System.Windows.UIElement])) { throw 'New-ToolPage did not return a page.' }
    } catch {
        $Tab.Module = $null
        $Tab.Page = New-ErrorPage "$($info.Title) couldn't open" $_.Exception.Message
    }
    $Tab.Frame.Content = $Tab.Page
    $Tab.Page.Height = [Math]::Max($Tab.Frame.ActualHeight, $Tab.Page.MinHeight)
}

function Enter-ToolTab {
    param($Tab)
    try { Invoke-PageFunction $Tab 'Enter-ToolPage' } catch { Show-ShellError "$($Tab.Info.Title): $($_.Exception.Message)" }
}

function Build-NextPage {
    # Runs when the computer is idle: one page per turn, so clicks and typing stay responsive
    $queue = $script:Shell.BuildQueue
    if ($queue.Count -eq 0) { return }
    $tab = $queue.Dequeue()
    if (-not $tab.Built) {
        Invoke-UiSafely {
            Build-ToolPage $tab
            if ($script:Shell.Active -eq $tab) { Enter-ToolTab $tab }
        }
    }
    if ($queue.Count -gt 0) {
        [void]$script:Shell.Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ApplicationIdle, [Action]{ Build-NextPage })
    }
}

function Select-ToolTab {
    param([string]$Key)
    $next = $script:Shell.Tabs | Where-Object { $_.Info.Key -eq $Key } | Select-Object -First 1
    if (-not $next) { return }
    $previous = $script:Shell.Active
    if ($previous -eq $next) { return }

    if ($previous) {
        $previous.Frame.Visibility = 'Collapsed'
        if ($previous.Built) {
            try { Invoke-PageFunction $previous 'Exit-ToolPage' } catch { Show-ShellError "$($previous.Info.Title): $($_.Exception.Message)" }
        }
    }
    $script:Shell.Active = $next
    $next.Frame.Visibility = 'Visible'
    if (-not $next.Button.IsChecked) { $next.Button.IsChecked = $true }
    # Clicked before its turn: build it now. The very first tab is built by Build-NextPage once the window is on screen.
    if (-not $next.Built -and $script:Shell.WindowShown) { Build-ToolPage $next }
    if ($next.Built) { Enter-ToolTab $next }
}

function Select-TabByOffset {
    param([int]$Offset)
    $tabs = $script:Shell.Tabs
    $index = $tabs.IndexOf($script:Shell.Active)
    $next = $tabs[(($index + $Offset) % $tabs.Count + $tabs.Count) % $tabs.Count]
    Select-ToolTab $next.Info.Key
}

# ------------------------------------------------------------------
#  Window
# ------------------------------------------------------------------

function Show-ToolkitWindow {
    # -NoShow builds the window without opening it (used for automated screenshots)
    param([string]$Root, [string]$Version, [bool]$IsAdmin, [bool]$DryRun, [switch]$NoShow)

    Enable-DpiAwareness
    Import-Theme $Root
    [xml]$xaml = Get-Content (Join-Path $Root 'ui\MainWindow.xaml') -Raw -Encoding UTF8
    $window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
    $script:Shell.Window = $window
    $window.FindName('VersionText').Text = "v$Version"

    # Never bigger than the screen (small laptop screens): pages scroll instead
    $area = [System.Windows.SystemParameters]::WorkArea
    if ($window.Height -gt $area.Height) { $window.Height = $area.Height }
    if ($window.Width  -gt $area.Width)  { $window.Width  = $area.Width }
    if ($window.MinHeight -gt $area.Height) { $window.MinHeight = $area.Height }
    if ($window.MinWidth  -gt $area.Width)  { $window.MinWidth  = $area.Width }

    # Dark title bar to match the window (Windows 10 2004+ / Windows 11)
    $window.Add_SourceInitialized({
        try {
            $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $script:Shell.Window).Handle
            $on = 1
            [void](Get-NativeMethods)::DwmSetWindowAttribute($hwnd, 20, [ref]$on, 4)
        } catch { }
    })

    $config = Import-PowerShellDataFile (Join-Path $Root 'tools.psd1')
    foreach ($info in $config.Tabs) { Add-ToolTab $Root $info $IsAdmin $DryRun }

    # Ctrl+Tab / Ctrl+Shift+Tab and Ctrl+1..9 switch tabs
    $window.Add_PreviewKeyDown({
        param($sender, $e)
        if (-not ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) { return }
        $shift = [bool]([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift)
        if ($e.Key -eq 'Tab') {
            Invoke-UiSafely { Select-TabByOffset $(if ($shift) { -1 } else { 1 }) }
            $e.Handled = $true
        } elseif ($e.Key -ge [System.Windows.Input.Key]::D1 -and $e.Key -le [System.Windows.Input.Key]::D9) {
            $index = [int]$e.Key - [int][System.Windows.Input.Key]::D1
            if ($index -lt $script:Shell.Tabs.Count) {
                Invoke-UiSafely { Select-ToolTab $script:Shell.Tabs[$index].Info.Key }
                $e.Handled = $true
            }
        }
    })

    $window.Add_Closing({
        param($sender, $e)
        # Every page may keep the window open (for example while setup runs). It asks the user itself.
        foreach ($tab in $script:Shell.Tabs) {
            if (-not $tab.Built) { continue }
            $canClose = $true
            try { $answer = Invoke-PageFunction $tab 'Test-ToolPageCanClose'; if ($answer -eq $false) { $canClose = $false } }
            catch { }
            if (-not $canClose) { $e.Cancel = $true; Select-ToolTab $tab.Info.Key; return }
        }
        if ($script:Shell.Active -and $script:Shell.Active.Built) { try { Invoke-PageFunction $script:Shell.Active 'Exit-ToolPage' } catch { } }
        foreach ($tab in $script:Shell.Tabs) {
            if ($tab.Built) { try { Invoke-PageFunction $tab 'Close-ToolPage' } catch { } }
            # A prefetch that is still running is told to stop
            try { $tab.ShellForPage.Prefetch.PowerShell.BeginStop($null, $null) | Out-Null } catch { }
        }
    })

    # Always opens on the first tab (nothing is remembered between runs)
    foreach ($tab in $script:Shell.Tabs) { $script:Shell.BuildQueue.Enqueue($tab) }
    Select-ToolTab $script:Shell.Tabs[0].Info.Key

    if ($NoShow) {
        # Automated screenshots want finished pages straight away
        $script:Shell.WindowShown = $true
        foreach ($tab in $script:Shell.Tabs) { Build-ToolPage $tab }
        Enter-ToolTab $script:Shell.Active
        return $window
    }

    # The window opens first, with "Opening..." on the first tab. Once it is on screen the first
    # page is built, then the others one by one while the computer is idle.
    $window.Add_ContentRendered({
        if ($script:Shell.WindowShown) { return }
        $script:Shell.WindowShown = $true
        [void]$script:Shell.Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{ Build-NextPage })
    })
    [void]$window.ShowDialog()
}

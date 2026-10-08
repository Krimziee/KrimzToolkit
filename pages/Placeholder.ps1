<#
    Placeholder page for a tool whose toolkit page isn't built yet.
    Loaded like a real page (in its own module), once per tab.
#>

function New-ToolPage {
    param([string]$Root, [hashtable]$Shell, [hashtable]$Tool, [string]$ToolFolder)

    $xamlText = @'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Margin="28,26,28,20">
    <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0" Margin="0,0,0,18">
        <TextBlock x:Name="TitleText" FontFamily="{StaticResource Display}" FontSize="26" FontWeight="SemiBold"/>
        <TextBlock x:Name="SubtitleText" Foreground="{StaticResource Muted}" Margin="0,4,0,0"/>
    </StackPanel>
    <Border Grid.Row="1" Style="{StaticResource Card}" VerticalAlignment="Top" HorizontalAlignment="Left" MinWidth="460" Padding="20,18">
        <StackPanel Orientation="Horizontal">
            <TextBlock x:Name="StatusIcon" FontFamily="{StaticResource Icons}" FontSize="22" VerticalAlignment="Top" Margin="0,2,16,0"/>
            <StackPanel>
                <TextBlock x:Name="StatusTitle" FontWeight="SemiBold"/>
                <TextBlock x:Name="StatusText" Foreground="{StaticResource Muted}" FontSize="13" Margin="0,4,0,0" TextWrapping="Wrap" MaxWidth="560"/>
            </StackPanel>
        </StackPanel>
    </Border>
</Grid>
'@
    $page = [Windows.Markup.XamlReader]::Parse($xamlText)
    $page.FindName('TitleText').Text    = $Tool.Title
    $page.FindName('SubtitleText').Text = "This tab gets its page in phase $($Tool.Phase)."

    $icon = $page.FindName('StatusIcon')
    if ($ToolFolder) {
        $icon.Text = [string][char]0xE73E
        $icon.Foreground = $page.FindResource('Ok')
        $page.FindName('StatusTitle').Text = 'Tool found'
        $page.FindName('StatusText').Text  = $ToolFolder
    } else {
        $icon.Text = [string][char]0xE7BA
        $icon.Foreground = $page.FindResource('Warn')
        $page.FindName('StatusTitle').Text = 'Tool folder not found'
        $page.FindName('StatusText').Text  = "Put the $($Tool.Folder) folder next to the toolkit folder, or inside its tools folder."
    }
    $page
}

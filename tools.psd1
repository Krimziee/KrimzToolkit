# The tabs, in order. Folder is the tool's own folder, looked for in
# tools\<Folder> (release copy) first, then next to the toolkit (..\<Folder>).
# Each tool shows its page from <Folder>\modules\Page.ps1. Until a tool has
# one, its tab shows a placeholder saying which phase brings it.
@{
    Tabs = @(
        @{ Key = 'WindowsSetup';     Title = 'Windows Setup';     Folder = 'WindowsSetup';     Phase = 1 }
        @{ Key = 'CrashExplainer';   Title = 'Crash Explainer';   Folder = 'CrashExplainer';   Phase = 3 }
        @{ Key = 'ConnectionDoctor'; Title = 'Connection Doctor'; Folder = 'ConnectionDoctor'; Phase = 4 }
        @{ Key = 'SecureBoot';       Title = 'Secure Boot';       Folder = 'SecureBootCheck';  Phase = 2 }
    )
}

# Krimz's Toolkit

Four PC tools in one window, with a tab for each:

- **Windows Setup**: sets up a fresh Windows install. Asks for confirmation before it changes anything.
- **Crash Explainer**: explains crashes and blue screens in plain words (read-only)
- **Connection Doctor**: watches your connection live and explains where lag comes from (read-only)
- **Secure Boot**: checks whether Secure Boot and TPM 2.0 are on and ready (read-only)

## How to start

### One command (any PC)

Right-click the Start button, open **Terminal** or **PowerShell**, then paste this and press Enter:

```powershell
irm https://raw.githubusercontent.com/Krimziee/KrimzToolkit/main/install.ps1 | iex
```

It downloads the newest toolkit and its four tools from GitHub into `C:\KrimzToolkit`
(replacing an older copy) and opens it. Click **Yes** when Windows asks for admin rights.
Next time you can start it from `C:\KrimzToolkit\Krimz's Toolkit.cmd`, or run the command
again to update.

### From a download

Double-click **Krimz's Toolkit.cmd** and click **Yes** on the admin prompt.

A tool that's working in the background (setup running, logs being read, a test running) shows a
small blue dot on its tab. Connection Doctor only measures while its tab is open.

## Shortcuts

- **Ctrl+Tab / Ctrl+Shift+Tab**: next / previous tab
- **Ctrl+1 to Ctrl+4**: go to a tab

## Good to know

- The toolkit runs with admin rights because Windows Setup and Secure Boot Check
  need them. Each tool keeps its own rules: Secure Boot Check, Crash Explainer and
  Connection Doctor only read or measure. They never change anything.
- Links (like "Search online" in Crash Explainer) open your browser as a normal user, without admin rights.
- The toolkit itself saves nothing: no settings, logs or temp files. Windows Setup saves its
  log on the desktop only once you confirm Start setup.
- On small screens (like 1366×768 laptops), a page that doesn't fit scrolls.
- It can be started from a network share or mapped drive.

## Folders

A release (see below) is one folder with everything inside:

```
KrimzToolkit\
    Krimz's Toolkit.cmd
    tools\WindowsSetup\
    tools\CrashExplainer\
    tools\ConnectionDoctor\
    tools\SecureBootCheck\
```

While developing, the tools are found next to the toolkit folder instead
(`..\WindowsSetup` and so on). Each tool still works on its own with its own launcher,
in both places.

## Building a release

```powershell
powershell -ExecutionPolicy Bypass -File Build-Release.ps1
```

This puts the toolkit and the four tools into `release\KrimzToolkit\` and
`release\KrimzToolkit-<version>.zip`. Every project is taken from its **last commit**,
so commit first. Projects with uncommitted changes are listed as a warning.
`ui\Theme.xaml` here is the main copy of the shared look. The release always uses it, and
tools whose own copy differs are listed so you can copy it over there too.

## For testing

`Toolkit.ps1 -DryRun` starts Windows Setup in dry-run mode: it shows what it would do
without changing anything.

See [PLAN.md](PLAN.md) for how it was built.

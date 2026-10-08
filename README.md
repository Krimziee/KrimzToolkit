# Krimz's Toolkit

Four PC tools in one window, with a tab for each:

- **Windows Setup**: sets up a fresh Windows install
- **Secure Boot**: checks whether Secure Boot is on and ready (read-only)
- **Crash Explainer**: explains crashes and blue screens in plain words (read-only)
- **Connection Doctor**: watches your connection live and explains where lag comes from

## How to start

Double-click **Krimz's Toolkit.cmd** and click **Yes** on the admin prompt.

The tools are found in the `tools` folder inside the toolkit, or next to the
toolkit folder:

```
Krimz's Toolkit\    (this folder)
WindowsSetup\
SecureBootCheck\
CrashExplainer\
ConnectionDoctor\
```

Each tool still works on its own with its own launcher.

## Shortcuts

- **Ctrl+Tab / Ctrl+Shift+Tab**: next / previous tab
- **Ctrl+1 to Ctrl+4**: go to a tab

## Good to know

- The toolkit runs with admin rights because Windows Setup and Secure Boot Check
  need them. Each tool keeps its own rules: Secure Boot Check and Crash Explainer
  only read, they never change anything.
- The toolkit itself saves nothing: no settings, logs or temp files.
- Don't start it from a mapped network drive. Copy the folders to the PC first.

See [PLAN.md](PLAN.md) for what's built and what's next.

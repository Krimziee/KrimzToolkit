# Krimz's Toolkit - plan for v0.1

Agreed 2026-10-08. Each phase ends with a test run on a real PC and its own commit.

## Goal

Put the four tools in **one window, with a tab along the top for each tool**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Krimz's Toolkit   Windows Setup │ Crash Explainer │ Connection Doctor │ Secure Boot │
│               ━━━━━━━━━━━━━                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                     (the selected tool's page)                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

Each tool keeps its own `.cmd` launcher and still works on its own.

## Ground rules

- **Admin rights:** the toolkit asks for admin once, at launch. Windows Setup and
  Secure Boot need it. The other tools only run with admin because they are in the same process.
- **Each tool keeps its own rules inside the toolkit:**
  - Secure Boot Check: strictly read-only (`mbr2gpt /validate` is allowed).
  - Crash Explainer: read-only, event logs only, its own `PLAN.md` checklist applies.
    Its "never asks for admin" rule still holds: Crash Explainer itself never
    asks. It only runs with admin when it's inside the toolkit, and the standalone version stays non-admin.
  - Connection Doctor: the agreed scope stays the same (live monitor, 3 regions,
    test buttons, no export or warnings).
- **The toolkit itself writes nothing.** It saves no settings, logs or remembered tab. It
  always opens on the first tab.
- **One look:** the shared colors that Windows Setup and Connection Doctor already use
  (`#1C1C1C` background, `#272727` / `#2F2F2F` surfaces, `#3A3A3A` lines,
  `#A6A6A6` muted text, `#4CA6FF` accent).

## Layout

- **Tab bar:** tool names as text tabs. The active tab is white with a blue underline and the others are muted.
  A tool that is working in the background shows a small blue dot on its tab.
- **Window size:** one size for all tabs so the window never jumps. It's based on the
  largest tool (Connection Doctor, 1180×880, min 980×740) plus the tab bar.
  Test on a 1366×768 laptop. If it doesn't fit, lower the minimum size and let pages scroll.
- **Windows Setup, Secure Boot and Crash Explainer** use the Windows Setup style:
  a title and subtitle, a two-column body (info and options on the left, a "what will happen" or
  results panel on the right), rounded cards, the same buttons, badges, checkboxes and progress bar.
- **Connection Doctor** keeps its own layout (graph, regions, tests and events), using
  the shared colors and controls.

## Tab behaviour

- **Connection Doctor:** the live monitor runs **only while its tab is selected**. It
  stops when you leave the tab and starts again when you come back.
- **Windows Setup:** pressing **Start setup** first shows a confirmation dialog in the
  toolkit's style that summarizes what will happen (preset or custom, number of
  changes, download size). There are two buttons: "Start" (accent) and "Cancel". This also goes into the
  standalone Windows Setup.
  While setup runs, you can still switch tabs and the Windows Setup tab shows the
  working dot. Closing the window while setup is running asks for confirmation first.
- **Crash Explainer:** reading in the background works as it does today. Leaving the tab doesn't stop it.
- **Secure Boot:** runs its check the first time the tab is opened, and has a Refresh button.

## How the code fits together

- Each tool stays in its own folder and repo. Each one gets a **page** (`ui\Page.xaml`,
  a `UserControl`) plus its page code. Its standalone window becomes a thin wrapper
  around that same page, so there is only one copy of each UI.
- The toolkit loads the pages from the sibling folders and owns only the window,
  the tab bar and the shared theme (`ui\Theme.xaml`).
- **Name clashes:** three tools each have a `Ui.ps1` with overlapping function
  names. Each tool's functions get a prefix (for example `WS-`, `SB-`, `CE-`, `CD-`) or are
  loaded in their own module scope, so loading all four can't overwrite anything.
- A release step copies the four tools and the toolkit into one folder to share.

## Phase 0 - Shell (done)

- `Krimz's Toolkit.cmd` starts `Toolkit.ps1`, which asks Windows for admin rights
  and starts again with them. "No" on the prompt shows a message and exits.
- Window with the header tabs (`ui\MainWindow.xaml`) and the shared theme
  (`ui\Theme.xaml`). The theme is loaded once as the application's resources, so pages use
  `{StaticResource ...}` without loading it themselves.
- Tabs come from `tools.psd1`. Ctrl+Tab / Ctrl+Shift+Tab and Ctrl+1..4 switch tabs.
  The window shrinks to fit small screens.
- **Name clashes: module scope, not prefixes.** Each tool's page file is
  loaded into its own private module that exports nothing, so the four tools keep
  their function and `$script:` variable names. Tested: two pages setting the same
  `$script:` variable keep separate values, and nothing leaks into the toolkit.
- **Page contract.** Each tool gets `<tool>\modules\Page.ps1` with
  `New-ToolPage -Root -Shell` (required, returns the page) and the optional
  `Enter-ToolPage`, `Exit-ToolPage`, `Test-ToolPageCanClose` and `Close-ToolPage`.
  `-Shell` gives `Window`, `SetBusy` (the working dot) and `IsAdmin`.
  Until a tool has a `Page.ps1`, its tab shows a placeholder.
- Tools are found in `tools\<Folder>` (release copy) or next to the toolkit.
- Windows functions (sharp text, dark title bar) are declared in memory, as in Crash
  Explainer, so the toolkit writes nothing.
- To test: double-click the launcher, click "Yes", switch tabs, close.
- Known issue: if it's started from a mapped network drive, the admin copy can't see the drive
  letter (same as Windows Setup). The release step (Phase 5) will deal with that.

## Phase 1 - Windows Setup tab (done)

- Its window is now a page (`WindowsSetup\ui\Page.xaml`). The standalone window
  (`ui\MainWindow.xaml`) is an empty frame that shows the same page. In the toolkit,
  `WindowsSetup\modules\Page.ps1` loads it.
- **Theme:** Windows Setup has its own copy of `Theme.xaml`, so it doesn't need the
  toolkit. Its styles moved out of the window into that file. The toolkit's
  `ui\Theme.xaml` is the main copy, and the release step (Phase 5) will keep the copies the same.
- **Start setup confirmation** (toolkit and standalone): a dialog in the toolkit's style
  with the setup and install type, the steps that will run with item counts, the
  download size, whether the PC restarts, and the restore point note. "Cancel" has focus,
  so a stray Enter doesn't start anything.
- Working dot on the tab while setup runs and during the restart countdown. Closing
  the toolkit during a run asks first (the same question as the standalone window).
- In the toolkit, the log on the desktop only starts when Start setup is confirmed, so
  opening the toolkit leaves no log behind. The standalone window logs as before.
- One version number for both (`$script:SetupVersion` in `Common.ps1`), still 0.9.
- `Toolkit.ps1 -DryRun` passes dry run to the tools for testing.
- Tested in dry run: page in the tab, confirmation dialog, run, working dot on and off,
  Cancel, finish page, and the standalone window in Custom mode.

## Phase 2 - Secure Boot tab (done)

- **Checks split from the output.** Every check records what it found (`$script:Report`)
  and, in the text version, also prints it. `Invoke-SecureBootCheck` runs them all and
  returns the results, and both versions show those same results. The data-safety
  advice and BIOS tips are now data too (`Get-DataSafety`, `Get-BiosAccess`).
  `SecureBootCheck.ps1` still works on its own, so the online one-liner (`irm | iex`)
  keeps working and shows the text version.
- `-Window` opens the window and `-LoadOnly` only loads the checks.
  `Check Secure Boot.cmd` now opens the window.
- Page in the Windows Setup style (`ui\Page.xaml`, `modules\Ui.ps1`):
  - Left: your PC, then one card per check with a ✓ / ⚠ / ✗ icon on every line.
  - Right: verdict card (green ready / yellow ready with notes / red "N things to fix")
    with "Secure Boot on/off" and "TPM 2.0 ready/not ready" chips. When something
    is wrong, below it come "Before you change anything" (BitLocker, disk conversion),
    "How to open the BIOS/UEFI setup" for the detected brand, then numbered step cards and the notes.
  - Commands in the steps sit in code boxes the player can select and copy. **No button
    runs anything**. The only button is "Check again".
- The check runs in a background runspace (about 3.5 s on this PC), so the window never freezes.
  Working dot on the tab while it runs. In the toolkit it starts the first time the tab
  is opened.
- Still read-only, and it now writes even less: the firmware-type read uses an in-memory
  declaration instead of `Add-Type`, which wrote compiler temp files. Scanned the new code for
  writes. The only hits are loading WPF and the existing admin prompt.
- Tested: the real check in the standalone window and in the toolkit tab, a made-up "broken
  PC" result (Legacy, MBR, BitLocker without a recovery key, TPM off) to see the fix layout,
  and the text version.

## Phase 3 - Crash Explainer tab (done)

- Its window is now a page (`CrashExplainer\ui\Page.xaml`) with the shared theme, shown by
  its standalone window and by the tab (`CrashExplainer\modules\Page.ps1`).
- **Changed from this plan:** the layout stays as it is (period and sort on top, crash list
  left, explanation right) instead of moving period, sort and "your PC" to a left column.
  It already uses the same colors and cards as Windows Setup, Crash Explainer's
  own plan (its Phase 3) designs its next layout, and "your PC" data only comes with its
  Phase 2. Restyling it here would have meant doing it twice.
- Logs are read the first time the tab is opened, with a working dot while reading. Switching
  tabs doesn't re-read.
- Links ("Search online") now open through Explorer, so the browser never runs with the
  toolkit's admin rights.
- Its read-only checklist passed (scan of the new code; the only hits are allowed).
- Tested: tab in the toolkit, standalone window (90 days), text version.

## Phase 4 - Connection Doctor tab (done)

- Connection Doctor wasn't a git repository. It now is, with its original 0.1.0 as the first commit.
- Its window is now a page (`ConnectionDoctor\ui\Page.xaml`) with its own layout and styles,
  shown by its standalone window and by the tab (`ConnectionDoctor\modules\Page.ps1`).
- **Monitor only while the tab is selected:** it starts the first time the tab is opened, pauses
  when another tab is selected (no pings, region tests or Wi-Fi reads), and resumes when the
  tab is selected again. The verdict then starts over ("Measuring..." for 30 s) because the old
  numbers are stale. The background threads are kept but idle, so switching back is
  instant, and they all stop when the toolkit closes.
- The Pause button is separate: a manual pause stays paused across tab switches.
- A running test carries on in the background (working dot on the tab); its result is there when you
  come back.
- The standalone window is unchanged: the monitor starts straight away.
- Its plan's open question ("standalone or inside Windows Setup") is now answered: both standalone
  and a toolkit tab.
- Tested in the toolkit: no measuring before the tab is opened, none while away (sample count
  stays the same), resumes on return, a manual pause survives switching, DNS Test finishes while away
  with the dot on and off, all threads stop on close. Also the standalone window.

## Phase 5 - Polish and test (done)

- **Small screens:** each page sits in a scroll area that only scrolls when the window is
  shorter than the page's `MinHeight` (set in each `Page.xaml`: Windows Setup 560, Crash
  Explainer 520, Secure Boot 540, Connection Doctor 700). Otherwise the page gets exactly the
  visible height, so its own lists and graphs behave as before. Tested at 1366×728 (a
  1366×768 laptop's work area): only Connection Doctor scrolls (642 px visible, 700 needed).
  At 1000 px tall, nothing scrolls.
- **Network drives:** started from a mapped drive, `Toolkit.ps1` restarts with admin
  rights using the network path (`\\server\share\...`), which the admin copy can see.
- **Release step:** `Build-Release.ps1` puts the toolkit and the four tools into
  `release\KrimzToolkit\` (tools under `tools\`) plus a zip. Each project is taken from its
  last commit (`git archive`), and uncommitted changes are listed as a warning. The release
  gets the toolkit's `Theme.xaml`, and tools whose own copy differs are listed. `release\`
  is git-ignored. Tested: the release copy finds every tool in its own `tools\` folder.
- **Stress test:** Secure Boot check, Crash Explainer reading, Connection Doctor monitor and a
  Route Check all at once, 40 quick tab switches: no errors. Closing while the Route Check
  ran took 80 ms, and all threads were stopped and the process exited.
- README rewritten: tabs, working dot, admin and read-only rules, folders, release, dry run.
- Still to do on a real PC: all four standalone launchers and the toolkit launcher from
  the release folder, including the admin prompt (that can't be automated here).

## Open questions

- None right now. Tab order decided: Windows Setup, Crash Explainer, Connection Doctor,
  Secure Boot (last).

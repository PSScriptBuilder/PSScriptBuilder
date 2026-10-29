# Example 15 - Watcher

This example demonstrates `Watch-PSScriptBuilderProject` — a cmdlet that monitors source
directories for file changes and reacts automatically. It shows both operating modes:
**Build mode** (triggers a full rebuild on every change) and **Script mode** (invokes a custom
script block with the changed file paths).

## New in this example

- `Watch-PSScriptBuilderProject` — watches source directories and reacts to file changes in
  real time
- **Build mode** (`Watch-Build.ps1`) — rebuilds automatically on every `.ps1` change; optional
  `-OnSuccess` runs a script block after each successful build; optional `-OnError` runs a script
  block after each failed build
- **Script mode** (`Watch-Script.ps1`) — invokes a custom script block with the list of changed
  file paths; no build is performed

## Key concepts

**The watcher blocks the current thread** and runs until stopped with Ctrl+C. Build failures
and script block errors do not stop the watcher — it continues after every error.

**Debouncing** collapses multiple rapid changes into a single execution. The default debounce
window is 500 ms. Changes that arrive during a running build are queued and trigger exactly one
additional execution after the current one completes.

**Build mode** is the primary use case: every time a source file changes, PSScriptBuilder runs a
full build and writes the output file. The optional `-OnSuccess` parameter receives the
`PSScriptBuilderBuildResult` after each successful build — useful for running tests, sending
notifications, or printing a summary. The optional `-OnError` parameter receives a
`PSScriptBuilderWatchBuildErrorResult` after each failed build — useful for alerting, logging,
or sending notifications on failure.

**Script mode** skips the build entirely and passes the changed file paths as a `string[]`
directly to the script block. This is useful for running a custom build tool, invoking an
external pipeline, or simply observing which files are changing.

## How to run

### Build mode — automatic rebuild on change

```powershell
cd examples\15-watcher
.\Watch-Build.ps1
```

Edit any `.ps1` file in `src\` and save it. The watcher rebuilds automatically and prints the
output path via the `-OnSuccess` script block. To test the `-OnError` path, introduce a syntax
error in any source file — the error message and triggering file are printed in red.

### Script mode — custom action on change

```powershell
cd examples\15-watcher
.\Watch-Script.ps1
```

Edit any `.ps1` file in `src\` and save it. The watcher prints the changed file paths without
performing a build.

Press **Ctrl+C** to stop either watcher.

## Project structure

```
15-watcher/
├── psscriptbuilder.config.json
├── Watch-Build.ps1             <- Build mode: rebuilds on every change
├── Watch-Script.ps1            <- Script mode: prints changed file paths
├── src/
│   ├── Classes/
│   │   ├── AppConfig.ps1
│   │   └── ConfigEntry.ps1
│   └── Functions/
│       ├── Get-ConfigValue.ps1
│       ├── New-AppConfig.ps1
│       └── New-ConfigEntry.ps1
└── build/
    ├── Output/                 <- Generated output (created on first build)
    └── Templates/
        └── AppConfig.ps1.template
```

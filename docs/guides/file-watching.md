# File Watching

During active development, editing a source file and then switching back to manually
re-running a build just to see the result is a slow, repetitive loop. A file watcher removes
that step: it observes your source and template files and reacts automatically the moment
something changes, without you having to trigger anything by hand.

PSScriptBuilder provides this via
[`Watch-PSScriptBuilderProject`](../cmdlets/Watch-PSScriptBuilderProject.md), which supports
two modes:

- **Build mode** — triggers a full build on every detected change
- **Script mode** — invokes a custom script block instead of building, giving you full
  control over what happens when files change

In both modes, multiple changes arriving in quick succession are collapsed into a single
execution. A change that arrives during a running build or script triggers exactly one
additional execution after the current one completes, rather than queuing up separately.

Build failures and script errors do not stop the watcher — it keeps watching and reacts to the
next change. Press **Ctrl+C** to stop it.

The watcher does **not** trigger an initial build on startup — it waits for the first file
change. Run a manual build first if you need a current output before the watcher starts.

---

## What is Monitored

The watcher derives its watch paths from the content collector and the template:

- **Collector directories** — every `-IncludePath` registered on a collector is watched recursively
- **Template directory** — when `-TemplatePath` is provided, its parent directory is watched as well; template changes always trigger a rebuild, regardless of the extension filter
- **Output file** — automatically excluded from the watch to prevent rebuild loops

By default, only `.ps1` files trigger a build or script execution. `-IncludeExtension`
**replaces** this default list rather than adding to it, so include `.ps1` again if you still
want it to trigger changes:

```powershell
# Rebuild on both .ps1 and JSON config file changes
Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1' `
                             -IncludeExtension '.ps1', '.json'
```

Pass an empty array to react to a change in any file, regardless of extension:

```powershell
# Rebuild on any file change, not just .ps1
Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1' `
                             -IncludeExtension @()
```

With the watch scope and trigger extensions defined, the next step is choosing how the watcher
reacts to a change — Build mode or Script mode.

---

## Build Mode

Build mode reruns a full build — the same one you'd trigger manually — every time a watched
file changes, keeping your output continuously up to date while you work. Setting it up takes
the same parameters as a manual build: content collector, template path, and output path.

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1'
```

This watches every file under `src\Classes` and `src\Public`, plus the template's own
directory, and rebuilds `MyScript.ps1` each time one of them changes.

### Reacting to Build Results

A rebuild's outcome often needs to trigger something else — running tests after a successful
build, or logging a failure for later review. Two optional script blocks handle this:
`-OnSuccess` and `-OnError`.

`-OnSuccess` runs after each successful build. The build result is passed as the first argument
via `param`:

```powershell
$onSuccess = {
    param($buildResult)
    Write-Host "Built $($buildResult.TotalComponents) components in $($buildResult.ExecutionTime.TotalMilliseconds) ms"
    Invoke-Pester -Path 'tests' -Output Minimal
}

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1' `
                             -OnSuccess        $onSuccess
```

`-OnError` runs after a failed build instead. The script block receives a
`PSScriptBuilderWatchBuildErrorResult` with `Exception`, `ChangedFiles`, and `Timestamp`
properties:

```powershell
$onError = {
    param($result)
    $logEntry = "[{0}] Build failed. Triggered by: {1}" -f $result.Timestamp.ToString('HH:mm:ss'), ($result.ChangedFiles -join ', ')
    Add-Content -Path 'build\build-errors.log' -Value $logEntry
}

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1' `
                             -OnError          $onError
```

Both callbacks can be combined in the same call:

```powershell
Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1' `
                             -OnSuccess        $onSuccess `
                             -OnError          $onError
```

---

## Script Mode

For complete control over what happens on change, use `-ScriptBlock` instead of building. No
build is triggered — PSScriptBuilder only handles the file watching and debouncing.

The script block receives the changed file paths as a `string[]`:

```powershell
$lintScript = {
    param([string[]] $changedFiles)
    Invoke-ScriptAnalyzer -Path $changedFiles -Severity Warning, Error
}

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -ScriptBlock $lintScript
```

`-TemplatePath` is optional in Script mode. Provide it only if you want template changes to
trigger the script block as well.

See the [Cmdlet Reference](../cmdlets/Watch-PSScriptBuilderProject.md) for the full parameter reference.

---

## Adjusting the Debounce Window

A single save can trigger several file-change events in quick succession — a formatter
rewriting multiple files, or an editor that writes a file in more than one step, for example.
Debouncing waits for a short quiet period after the last detected change before triggering a
build or script, so a burst of changes still results in exactly one execution instead of
several.

The default debounce window is 500 ms. Use `-Debounce` to tune it: lower values make the
watcher more responsive, higher values further reduce unnecessary rebuilds during rapid edits.

```powershell
# Rebuild 200 ms after the last change — useful for fast feedback cycles
Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1' `
                             -Debounce         200
```

---

## See Also

- [Build Pipeline Guide](build-pipeline.md) — the build process this watcher triggers in Build mode
- [Type Reference: File Watching](../reference/types.md#file-watching) — full `PSScriptBuilderWatchBuildErrorResult` property table
- [Example 15 — Watcher](../examples.md#15-watcher) — full walkthrough of both Build mode and Script mode
- [Cmdlet Reference: Watch-PSScriptBuilderProject](../cmdlets/Watch-PSScriptBuilderProject.md)

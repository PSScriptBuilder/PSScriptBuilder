# Watch-PSScriptBuilderProject

Watches project source files and triggers a build or custom script block on every change.

## Description

Monitors every registered collector's `-IncludePath` directories, and optionally the template
file's directory, for changes. On a change, either reruns a full build (**Build mode**) or invokes
a custom script block (**Script mode**) — never both.

Multiple changes within the debounce window are collapsed into a single execution; a change that
arrives while a build or script is still running triggers exactly one more execution afterward,
without waiting through another debounce period.

The watcher runs until stopped with `Ctrl+C`. It does not build once on startup — only on the
first detected change. Build failures and script errors are reported but never stop the watcher.

## Parameters

### Common to Both Modes

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** Determines which directories are watched, via its collectors' `-IncludePath` values. |
| `-TemplatePath` | string | Path to the template file. **Required in Build mode**; optional in Script mode (only needed if a template change should also trigger the script block). When provided, its directory is watched too, and a change there always triggers a run regardless of `-IncludeExtension`. |
| `-Debounce` | int | Milliseconds to wait after a change before triggering a run. Default: `500`. |
| `-IncludeExtension` | string[] | File extensions that trigger a run. **Replaces** the default list rather than adding to it — include `".ps1"` again if still wanted. Default: `@(".ps1")`. Pass `@()` to react to a change in any file. |

### Build Mode

| Name | Type | Description |
|---|---|---|
| `-OutputPath` | string | **Required.** Path to the output file. Automatically excluded from the watch to prevent rebuild loops. |
| `-BackupPath` | string | Backup directory, used only when `-EnableBackup` is specified. |
| `-OrderedComponentsKey` | string | The combined-components placeholder key. Default: `"ORDERED_COMPONENTS"`. |
| `-EnableBackup` | switch | Back up an existing output file before each rebuild overwrites it. |
| `-SkipSyntaxValidation` | switch | Skip the post-write syntax check. |
| `-WriteSourceMap` | switch | Write a `.sourcemap.json` sidecar after each build. |
| `-OnSuccess` | scriptblock | Runs after each successful build, receiving the [`PSScriptBuilderBuildResult`](../reference/types.md#psscriptbuilderbuildresult) as its first argument. |
| `-OnError` | scriptblock | Runs after each failed build, receiving a [`PSScriptBuilderWatchBuildErrorResult`](../reference/types.md#psscriptbuilderwatchbuilderrorresult) as its first argument. |

### Script Mode

| Name | Type | Description |
|---|---|---|
| `-ScriptBlock` | scriptblock | **Required.** Runs instead of a build on every change, receiving the changed file paths as a `string[]`. |

## Examples

### Rebuild on every source change (Build mode)

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\MyProject.ps1.template' `
                             -OutputPath       'build\Output\MyProject.ps1'
```

### Run tests after every successful rebuild

```powershell
Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\MyProject.ps1.template' `
                             -OutputPath       'build\Output\MyProject.ps1' `
                             -OnSuccess        { Invoke-Pester -Path 'tests' -Output Minimal }
```

### Run a custom script block instead of building (Script mode)

```powershell
Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -ScriptBlock      {
                                 param([string[]] $changedFiles)
                                 Write-Host "Changed: $($changedFiles -join ', ')"
                                 & '.\my-build.ps1'
                             }
```

## Output

None. Blocks the current thread until stopped with `Ctrl+C`; the `ContentCollector` cannot be
modified while the watcher is running.

## See Also

- [File Watching Guide](../guides/file-watching.md)
- [Build Pipeline Guide](../guides/build-pipeline.md)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md)

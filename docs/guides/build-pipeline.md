# Build Pipeline

The build pipeline takes your source files, collectors, and a template and produces a single
deployable PowerShell script. This guide covers running a build, interpreting the result,
protecting existing output with backups, post-processing the script for deployment, and
understanding build errors.

---

## Running a Build

[`Invoke-PSScriptBuilderBuild`](../cmdlets/Invoke-PSScriptBuilderBuild.md) orchestrates the
complete build pipeline in a single call:

1. Loads the template file
2. Runs all registered collectors
3. Builds and analyzes the dependency graph
4. Detects circular dependencies (fails with a detailed error message)
5. Performs topological sorting
6. Replaces template placeholders with collected and dependency-resolved components
7. Optionally backs up the existing output file
8. Writes the final output script

The examples below use the same `MyProject` project from the
[Quick Start](../getting-started/quick-start.md) — if you haven't read it yet, start there.
All paths are relative to the project root (`$Global:PSScriptBuilderProjectRoot`), see
[Configuration](configuration.md) for setup.

PSScriptBuilder supports multiple styles for setting up a build — choose based on how much
control and readability you need:

- **Explicit** — each collector and parameter is a named variable; easy to follow, easy to extend
- **Pipeline** — collectors are chained inline; build parameters are passed as a variable
- **Fluent** — the entire build is a single pipeline expression; most concise, best for stable scripts

### Explicit

Each collector and build parameter is a named variable. This makes it easy to follow what
happens at each step and to add conditional logic if needed:

```powershell
$classCollector    = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
$functionCollector = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'

$collectors = $classCollector, $functionCollector
$contentCollector = New-PSScriptBuilderContentCollector -Collector $collectors

$result = Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath     'build\Templates\MyProject.ps1.template' `
    -OutputPath       'build\Output\MyProject.ps1'
```

The explicit style also makes it straightforward to register multiple collectors of the same
type — for example, Domain and Utils classes that should be ordered separately, each with a
unique `-CollectionKey`. See [Example 10](../examples.md#10-multiple-collectors) for a
complete walkthrough.

### Pipeline

[`Add-PSScriptBuilderCollector`](../cmdlets/Add-PSScriptBuilderCollector.md) is an alternative
to `New-PSScriptBuilderCollector` that creates and registers a collector in one step. Instead
of creating collectors separately and passing them via `-Collector`, you chain
`Add-PSScriptBuilderCollector` directly onto `New-PSScriptBuilderContentCollector` in a
pipeline. Use this form when each collector has a straightforward configuration and you don't
need to reference them individually afterward:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'

$result = Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath     'build\Templates\MyProject.ps1.template' `
    -OutputPath       'build\Output\MyProject.ps1'
```

### Fluent

The most concise form — all steps in a single pipeline expression. Best suited for simple,
stable build scripts where no intermediate variables are needed and parameters don't change:

```powershell
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'  |
    Invoke-PSScriptBuilderBuild `
        -TemplatePath 'build\Templates\MyProject.ps1.template' `
        -OutputPath   'build\Output\MyProject.ps1'
```

### Using a Configuration File

The previous examples hardcode paths like `'build\Templates\MyProject.ps1.template'` directly
in the build script. That works for simple projects, but as soon as you use the same build
script in multiple environments — or want to change paths without touching the script — it
becomes a maintenance problem.

[`Get-PSScriptBuilderConfiguration`](../cmdlets/Get-PSScriptBuilderConfiguration.md) reads
`psscriptbuilder.config.json` from the project root and exposes all build settings as typed
properties. Paths, backup settings, and output locations are defined once in the configuration
file and referenced in code via `$config.Build.*`. Splatting keeps the
`Invoke-PSScriptBuilderBuild` call clean — no long backtick-continuation lines:

```powershell
$config = Get-PSScriptBuilderConfiguration

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'

$buildParams = @{
    ContentCollector = $contentCollector
    TemplatePath     = Join-Path $config.Build.TemplatePath 'MyProject.ps1.template'
    OutputPath       = Join-Path $config.Build.OutputPath   'MyProject.ps1'
    BackupPath       = $config.Build.BackupPath
    EnableBackup     = $config.Build.BackupEnabled
}

$result = Invoke-PSScriptBuilderBuild @buildParams
```

---

## The Scaffolded Build Script

[`New-PSScriptBuilderProject`](../cmdlets/New-PSScriptBuilderProject.md) generates a ready-to-run
build script (`Build-<Name>.ps1`) in the project root. The script wires up collectors, template
path, and output path, and calls `Invoke-PSScriptBuilderBuild` in one place. You can run it
directly or use it as a starting point to customize.

---

## Interpreting the Build Result

`Invoke-PSScriptBuilderBuild` returns a `PSScriptBuilderBuildResult` object that summarizes
what was collected, how long the build took, and where the output was written. Use
[`Format-PSScriptBuilderBuildResult`](../cmdlets/Format-PSScriptBuilderBuildResult.md) for a
quick human-readable summary, or access the properties directly when integrating into scripts
or CI pipelines:

```powershell
$result | Format-PSScriptBuilderBuildResult
```

Output:

```text
Build Summary
  Output : C:\MyProject\build\Output\MyProject.ps1
  Size   : 42.3 KB
  Time   : 312 ms

Components
  Classes   : 12
  Functions :  8
  Total     : 20
```

Add `-Detailed` to include all processed source files and component dependencies:

```powershell
$result | Format-PSScriptBuilderBuildResult -Detailed
```

For direct property access — for example in CI scripts or custom reporting — the result
object exposes all details as typed properties:

```powershell
Write-Host "Built $($result.TotalComponents) components in $($result.ExecutionTime.TotalMilliseconds) ms"
Write-Host "Output: $($result.OutputPath) ($($result.OutputFileSize) bytes)"
```

For a complete property reference see the [Reference](#reference) section at the end of this guide.

---

## Exporting the Build Report

To persist the build result as a structured JSON file — for auditing, artifact attachment, or
tracking changes between builds — pass `$result` to
[`Export-PSScriptBuilderBuildResult`](../cmdlets/Export-PSScriptBuilderBuildResult.md). The
cmdlet returns the exported file path as a string, which can be used directly in CI artifact
upload steps:

```powershell
$exportedPath = $result | Export-PSScriptBuilderBuildResult -Path 'build\reports\build.json' -Force
```

The compact output includes the build summary and component counts. Add `-Detailed` to also
include the full list of processed source files and per-component details — type, name, source
file, and dependencies:

```powershell
$result | Export-PSScriptBuilderBuildResult -Path 'build\reports\build.json' -Detailed -Force
```

---

## Backup

By default no backup is created before overwriting the output file — Git is the recommended
version control mechanism. A file-based backup can be useful as a local safety net — for
example, before a risky change you want to undo instantly without a checkout, or in
environments where the workspace is not a Git repository. Use `-EnableBackup` together with
`-BackupPath` to enable it:

```powershell
Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath     'build\Templates\MyProject.ps1.template' `
    -OutputPath       'build\Output\MyProject.ps1' `
    -BackupPath       'build\Backup' `
    -EnableBackup
```

Backup files are named with a timestamp:

```text
build\Backup\MyProject.ps1.20260422_103045.bak
```

The backup path is included in the build result (`$result.BackupPath`) and shown by
`Format-PSScriptBuilderBuildResult`.

---

## Post-Processing

A PSScriptBuilder build output is readable, well-structured PowerShell source — comments
intact, blank lines preserved, verbose logging included. That is ideal during development,
but when deploying to production you may want to reduce file size, strip diagnostic output,
or produce a leaner script that loads faster.

[`Compress-PSScriptBuilderScript`](../cmdlets/Compress-PSScriptBuilderScript.md) handles
this post-processing step. It operates on an already-built script file and selectively
removes comments, blank lines, and isolated output statements — independently or in any
combination. The original build output is never modified unless you explicitly point
`-DestinationPath` at the same file; typically you write to a separate deploy location.

`Compress-PSScriptBuilderScript` accepts pipeline input from `Invoke-PSScriptBuilderBuild`
via the `OutputPath` property, so build and compress can be chained in a single expression:

```powershell
New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'  |
    Invoke-PSScriptBuilderBuild `
        -TemplatePath 'build\Templates\MyProject.ps1.template' `
        -OutputPath   'build\Output\MyProject.ps1' |
    Compress-PSScriptBuilderScript `
        -RemoveComments `
        -RemoveBlankLines `
        -DestinationPath 'deploy\MyProject.ps1' `
        -Force
```

### Available Operations

| Parameter | Effect |
|---|---|
| `-RemoveComments` | Removes all comments, including `#region` / `#endregion`; preserves `#Requires` |
| `-RemoveBlankLines` | Removes all blank lines |
| `-RemoveOutputStatements` | Removes isolated `Write-Verbose`, `Write-Debug`, `Write-Host`, `Write-Warning`, or `Write-Information` calls |

Operations are applied in the order: **RemoveComments → RemoveOutputStatements → RemoveBlankLines**,
regardless of the parameter order you specify. This ensures that removing comments or output
statements does not leave behind unexpected blank lines.

!!! note "Isolated calls only"
    `-RemoveOutputStatements` only removes calls that stand alone on their line and are not part
    of a pipeline or control flow expression. Non-isolated calls are skipped silently; use
    `-Verbose` to see which calls were skipped and why.

Omit `-DestinationPath` to get the processed content as a string instead of writing to a file —
useful for inspecting the result, calculating size reductions, or piping into further
transformations:

```powershell
$compressed = Compress-PSScriptBuilderScript `
    -Path 'build\Output\MyProject.ps1' `
    -RemoveComments

$compressed | Measure-Object -Line
```

---

## Watch Mode

[`Watch-PSScriptBuilderProject`](../cmdlets/Watch-PSScriptBuilderProject.md) monitors the
source directories defined by the registered collectors for file changes. When `-TemplatePath`
is provided, the directory containing the template file is monitored as well. It reacts
automatically — no manual re-run needed. It supports two modes:

- **Build mode** — triggers a full build on every detected change
- **Script mode** — invokes a custom script block instead of building, giving you full
  control over what happens when files change

In both modes, multiple changes within the debounce window (default: 500 ms) are collapsed
into a single execution. A change that arrives during a running build or script triggers
exactly one additional execution after the current one completes — without waiting for the
debounce period again. Build failures and script errors do not stop the watcher. Press
**Ctrl+C** to stop it.

The most common setup is Build mode: set up the content collector once, then pass it to
`Watch-PSScriptBuilderProject` with the same template and output paths you use for a
manual build:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1'
```

Use `-OnSuccess` to run a script block after each successful build. The build result is passed
as the first argument via `param`:

```powershell
$postBuildAction = {
    param($buildResult)
    Write-Host "Built $($buildResult.TotalComponents) components in $($buildResult.ExecutionTime.TotalMilliseconds) ms"
    Invoke-Pester -Path 'tests' -Output Minimal
}

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1' `
                             -OnSuccess        $postBuildAction
```

Use `-OnError` to react to build failures. The script block receives a
`PSScriptBuilderWatchBuildErrorResult` with `Exception`, `ChangedFiles`, and `Timestamp`
properties:

```powershell
$onBuildError = {
    param($result)
    $logEntry = "[{0}] Build failed. Triggered by: {1}" -f $result.Timestamp.ToString('HH:mm:ss'), ($result.ChangedFiles -join ', ')
    Add-Content -Path 'build\build-errors.log' -Value $logEntry
}

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -TemplatePath     'build\Templates\MyScript.ps1.template' `
                             -OutputPath       'build\Output\MyScript.ps1' `
                             -OnError          $onBuildError
```

For complete control over what happens on change, use `-ScriptBlock` instead of building.
No build is triggered — PSScriptBuilder only handles the file watching and debouncing. The
script block receives the changed file paths as a `string[]`:

```powershell
$lintScript = {
    param([string[]] $changedFiles)
    Invoke-ScriptAnalyzer -Path $changedFiles -Severity Warning, Error
}

Watch-PSScriptBuilderProject -ContentCollector $contentCollector `
                             -ScriptBlock $lintScript
```

See the [Cmdlet Reference](../cmdlets/Watch-PSScriptBuilderProject.md) for the full parameter reference.

---

## Error Handling

`Invoke-PSScriptBuilderBuild` uses a fail-fast strategy — it throws on the first error
encountered and does not produce partial output. This is intentional: a build that succeeds
halfway would leave you with a broken output file that is harder to diagnose than a clear
exception.

All errors are thrown as typed exceptions with detailed messages that include the affected
component names and file paths. The sections below describe the five error conditions you
are most likely to encounter, what causes them, and how to resolve them.

### Missing Template File

When the specified template file does not exist:

```text
FileNotFoundException: Template file not found: 'build\Templates\MyProject.ps1.template'
```

Verify the path is correct and relative to the project root.

### Path Not Found

A collector accepts any path at creation time — path validation only happens at runtime,
when `Invoke-PSScriptBuilderBuild` triggers collection. If an `-IncludePath` directory does
not exist, the build fails with:

```text
IOException: Path not found: C:\MyProject\src\Classes (original: src\Classes)
```

The message shows both the resolved absolute path and the original value you passed, which
makes it easy to spot a typo or a missing directory. Verify that the path exists relative
to the project root and that `Set-PSScriptBuilderProjectRoot` was called before the build.

### Component Name Conflict

A class and a function with the same name within the same project are explicitly forbidden.
PSScriptBuilder uses component names as graph node keys — a collision would cause silent
incorrect ordering in the build output:

```text
InvalidOperationException: Component name conflict: 'Employee' is defined as both a Class
(in 'src\Classes\Employee.ps1') and a Function (in 'src\Public\Employee.ps1').
Classes and Functions must have unique names within a PSScriptBuilder project.
```

Rename one of the conflicting components to resolve the conflict.

### Circular Dependency

When a circular dependency is detected, the build fails immediately with a detailed error
message that includes the full cycle path:

```text
InvalidOperationException: Circular dependency detected: Employee -> Manager -> Employee
```

Resolve the cycle by removing or redirecting one of the dependencies. The
[Dependency Analysis Guide](dependency-analysis.md) explains how to query the dependency
graph to locate the cycle before running a build.

### Syntax Validation Failure

After writing the output file, PSScriptBuilder parses it to verify syntactic correctness.
If the parse fails, the build throws:

```text
InvalidOperationException: Output syntax validation failed: <parser error message>
```

`TypeNotFound` errors caused by external assemblies not loaded at build time are automatically
filtered and do not fail validation. Use `-SkipSyntaxValidation` only when the output contains
syntax that cannot be parsed at all by the PowerShell parser.

---

## Reference

### PSScriptBuilderBuildResult

| Property | Type | Description |
|---|---|---|
| `OutputPath` | `string` | Absolute path of the generated output file |
| `OutputFileSize` | `long` | Output file size in bytes |
| `ExecutionTime` | `TimeSpan` | Total build duration |
| `BackupPath` | `string` | Path of the backup file; `$null` if no backup was created |
| `TotalComponents` | `int` | Sum of all collected components across all collector types |
| `ComponentCounts` | `PSScriptBuilderBuildComponentCounts` | Per-type component counts |
| `ProcessedFiles` | `string[]` | Absolute paths of all source files processed during collection |
| `ComponentDetails` | `PSScriptBuilderBuildComponentDetail[]` | Detailed info per component; shown by `-Detailed` |
| `SyntaxValid` | `bool` | `$true` if the output file passed the syntax parse check |

### PSScriptBuilderBuildComponentCounts

| Property | Type | Description |
|---|---|---|
| `UsingStatements` | `int` | Number of `using` statements collected |
| `EnumDefinitions` | `int` | Number of enum definitions collected |
| `ClassDefinitions` | `int` | Number of class definitions collected |
| `FunctionDefinitions` | `int` | Number of function definitions collected |
| `FileContents` | `int` | Number of raw file contents collected |

### PSScriptBuilderBuildComponentDetail

| Property | Type | Description |
|---|---|---|
| `Type` | `PSScriptBuilderCollectorType` | Collector type (`Enum`, `Class`, `Function`, etc.) |
| `Name` | `string` | Component name as defined in source code |
| `SourceFile` | `string` | Absolute path to the file containing the component |
| `Dependencies` | `string[]` | Names of components this component depends on |

---

## See Also

- [Quick Start](../getting-started/quick-start.md) — end-to-end walkthrough of a first build
- [Code Analysis Guide](code-analysis.md) — inspect templates and dependencies without building
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](../cmdlets/Invoke-PSScriptBuilderBuild.md)
- [Cmdlet Reference: Format-PSScriptBuilderBuildResult](../cmdlets/Format-PSScriptBuilderBuildResult.md)
- [Cmdlet Reference: Export-PSScriptBuilderBuildResult](../cmdlets/Export-PSScriptBuilderBuildResult.md)
- [Cmdlet Reference: Watch-PSScriptBuilderProject](../cmdlets/Watch-PSScriptBuilderProject.md)
- [Cmdlet Reference: Compress-PSScriptBuilderScript](../cmdlets/Compress-PSScriptBuilderScript.md)

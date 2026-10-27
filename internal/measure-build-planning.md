# Planning: Build Phase Timing via Verbose

> **Decision (2026-08-10):** No separate `Measure-PSScriptBuilderBuild` cmdlet.
> Phase timing is surfaced as `Write-Verbose` output inside `Invoke-PSScriptBuilderBuild`.
> No new cmdlet, no new type, no new parameter, no change to `PSScriptBuilderBuildResult`.

## Background

For large projects with many source files, the build can take several seconds. The existing
`BuildResult.ExecutionTime` provides the total duration, but no per-phase breakdown.
`Measure-Command { Invoke-PSScriptBuilderBuild ... }` covers total time only.

A separate `Measure-PSScriptBuilderBuild` cmdlet was considered but rejected:
- A dedicated cmdlet is hard to justify when it is functionally identical to `Invoke-PSScriptBuilderBuild`
- Adding `-Measure` to `Invoke-PSScriptBuilderBuild` would require a new return type or optional nullable properties on `BuildResult` — both are undesirable
- PowerShell best practice: append timing to existing phase Verbose messages, not a separate output stream

Phase durations are emitted via `Write-Verbose` directly in `PSScriptBuilderBuildOrchestrator.ExecuteBuild()`,
activated automatically when the caller specifies `-Verbose`.

## Usage Examples

```powershell
# Phase timing is automatically included in Verbose output
Invoke-PSScriptBuilderBuild `
    -ContentCollector $cc `
    -TemplatePath "build/Templates/MyModule.psm1.template" `
    -OutputPath "build/Output/MyModule.psm1" `
    -Verbose
```

**Verbose output:**

```
VERBOSE: Starting script build...
VERBOSE: Loading template...
VERBOSE: Template loaded in 3 ms
VERBOSE: Starting collection...
  ...
VERBOSE: Collection completed in 245 ms
VERBOSE: Analyzing dependencies...
VERBOSE: Dependency analysis completed in 89 ms
VERBOSE: Processing template...
VERBOSE: Template processing completed in 22 ms
VERBOSE: Writing output...
VERBOSE: Output written in 11 ms
VERBOSE: Script build complete in 402 ms
```

## Design Decisions

- **No new cmdlet, no new parameter, no new type.** Phase timing is emitted via `Write-Verbose`
  inside `PSScriptBuilderBuildOrchestrator.ExecuteBuild()`, activated when the caller uses `-Verbose`.
- **Always measured, conditionally displayed.** A single phase `Stopwatch` runs unconditionally
  and is reset via `Restart()` after each phase. The overhead is negligible.
- **Timing appended to existing phase messages.** Each measured phase has a "completed in X ms"
  message that follows naturally from the existing "Starting..." Verbose messages.
- **4 measured phases**: Collection, DependencyAnalysis, TemplateProcessing, OutputWriting.
  Template loading and overhead steps (encoding check, syntax validation, stats) are not measured
  individually — they are fast and not bottlenecks.
- **`BuildResult.ExecutionTime`** continues to carry the total duration for programmatic access.
  No new properties are added to `BuildResult`.

## Files

| # | File | Directory | Change |
|---|---|---|---|
| 1 | `PSScriptBuilderBuildOrchestrator.ps1` | `src\Classes\ScriptBuilder\Orchestrators\` | Modified |

## 1. PSScriptBuilderBuildOrchestrator — Change

A single `[Stopwatch] $phaseWatch` is declared at the top of `ExecuteBuild()` alongside
the existing `$stopwatch`. It is restarted before each measured phase and read immediately
after. `Write-Verbose` emits the elapsed milliseconds.

```powershell
$phaseWatch = [Stopwatch]::StartNew()
$this.ContentCollector.Execute()
Write-Verbose "Collection completed in $($phaseWatch.ElapsedMilliseconds) ms"

$phaseWatch.Restart()
$analysisResult = $analyzer.Analyze()
Write-Verbose "Dependency analysis completed in $($phaseWatch.ElapsedMilliseconds) ms"

$phaseWatch.Restart()
$finalScript = $this.ProcessTemplate($analysisResult.OrderedComponents, $useOrderedMode)
Write-Verbose "Template processing completed in $($phaseWatch.ElapsedMilliseconds) ms"

$phaseWatch.Restart()
$this.WriteOutput($finalScript)
Write-Verbose "Output written in $($phaseWatch.ElapsedMilliseconds) ms"
```

The existing `$stopwatch` (total duration) is unchanged.

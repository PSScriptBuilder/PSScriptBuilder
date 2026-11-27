# Planning: Get-PSScriptBuilderSourceCoverage

> **Status:** Implemented (2026-08-21). All four files exist as designed
> (`PSScriptBuilderSourceCoverageResult`, `PSScriptBuilderCodeCoverageTranslator`,
> `Get-PSScriptBuilderSourceCoverage`, `Format-PSScriptBuilderSourceCoverage`), each with a
> corresponding Unit test file. Built into `build\Output\PSScriptBuilder.psm1` and verified
> against a real Pester 5.7.1 run producing a correctly translated, aligned coverage table.
> `tests\Invoke-Tests.ps1` gained a `-CodeCoverage` switch wiring this up end-to-end. Four bugs
> found and fixed during verification, all still tracked in this document where relevant:
> Pester's actual property names are `CommandsExecuted`/`CommandsMissed`, not
> `HitCommands`/`MissedCommands` as an earlier unverified web search assumed;
> `GetProjectRootedPath()` does not canonicalize already-rooted paths, so the Translator
> normalizes both sides via `[Path]::GetFullPath()` before comparing; the Translator's own
> consolidated-warning design initially double-warned for every unresolved line, because
> `PSScriptBuilderSourceLocationResolver.Resolve()` already emits a per-call warning on
> failure — fixed by extracting a silent `TryResolve()`/`FindLocation()` pair on the resolver
> (not by mutating `$global:WarningPreference`, which was rejected as bad design) so the
> Translator can aggregate failures itself; and `-Detailed` initially listed the same source
> line once per missed *command* rather than once per missed *line* (Pester tracks coverage
> per AST command, so one line can hold several), fixed by deduplicating in
> `Format-PSScriptBuilderSourceCoverage` via `Sort-Object -Unique`, confirmed against real
> project output (`Get-PSScriptBuilderCollector.ps1` line 124). Documented in `CHANGELOG.md`;
> `docs/cmdlets/` pages are pending the next `-Docs` build (PlatyPS-generated from the
> comment-based help already written, no manual doc authoring needed there).

## Background

Pester's `CodeCoverage` feature instruments a configured set of files (`CodeCoverage.Path`)
and reports which of their commands were executed during a test run. For PSScriptBuilder
projects that use classes, this configuration has no real choice: it must point at the
**built output**, not at the original per-class source files.

This is not a preference, it is a technical consequence of how PowerShell class loading and
Pester's coverage tracing both work. When `using module` loads the built module, every class
method body is a `ScriptBlock` whose origin metadata (`ScriptExtent`) points at the file that
was actually parsed — the built `.psm1`. The original source files under `src\Classes\...`
were never loaded into the session at all; they only existed at build time, read by
`PSScriptBuilderAstEngine` and then discarded. Pester's coverage tracking follows execution
provenance: if `CodeCoverage.Path` pointed at the original source files, it would report 0%
coverage, because PowerShell has no record of executing code whose origin is those files —
only the built file. This is confirmed by PSScriptBuilder's own test suite:
[tests/Invoke-Tests.ps1:1](../tests/Invoke-Tests.ps1#L1) loads
`using module '..\build\Output\PSScriptBuilder.psd1'` — the built module, not the source tree.

The consequence: coverage results are reported in terms of built-output line numbers, which
are meaningless to a developer working across dozens of per-class source files. This is
exactly the same class of problem `Resolve-PSScriptBuilderSourceLocation` solves for runtime
errors — here it needs solving for coverage data instead.

**Scope note:** this problem is concentrated on class-heavy, multi-file projects — the exact
audience PSScriptBuilder exists for. Function-only projects can dot-source/import source files
directly during testing and never hit this problem at all.

**Prerequisite (not yet true today):** PSScriptBuilder's own CI does not currently enable
Pester code coverage at all (`.gitlab-ci.yml` has no `CodeCoverage` configuration). Adopting
this feature for the project's own pipeline is a separate, follow-up step from building the
translation cmdlet itself.

## Usage Scenario

```powershell
# 1. Build with source maps
$buildResult = $contentCollector |
    Invoke-PSScriptBuilderBuild -TemplatePath $templatePath -OutputPath $outputPath -WriteSourceMap

# 2. Run Pester with CodeCoverage pointed at the BUILT output (not the source tree)
$config = [PesterConfiguration]::Default
$config.Run.Path              = 'tests'
$config.Run.PassThru          = $true
$config.CodeCoverage.Enabled  = $true
$config.CodeCoverage.Path     = $buildResult.OutputPath

$pesterResult = Invoke-Pester -Configuration $config

# 3. Translate coverage back to source files
$buildResult |
    Get-PSScriptBuilderSourceCoverage -CodeCoverage $pesterResult.CodeCoverage |
    Format-PSScriptBuilderSourceCoverage
```

**Expected output (Format-PSScriptBuilderSourceCoverage):**

```
SourceFile                                              Coverage   Hit/Total
-------------------------------------------------------  --------   ---------
src\Classes\ScriptBuilder\Orchestrators\...Orchestrator.ps1   87 %      41/47
src\Classes\ScriptBuilder\Collectors\...ClassCollector.ps1    62 %      18/29
src\Classes\Enums\...BumpType.ps1                              0 %       0/3
```

## Design Decisions

- **`Get-`, not `Resolve-` or `ConvertTo-`.** `Resolve-PSScriptBuilderSourceLocation` performs
  identity resolution — one reference in, one resolved location out, no new information
  (mirrors `Resolve-Path`). This feature is not that: it cross-references two independent
  inputs (the source map, Pester's raw per-command coverage) and computes a genuinely new,
  derived fact (per-file coverage percentages) that existed in neither input. `ConvertTo-`
  was considered but doesn't fit either — the project's own `ConvertTo-PSScriptBuilderComponentDependencyTree`
  takes an *already-computed* result (`Get-PSScriptBuilderComponentDependency`'s output) and
  purely re-encodes it into a different display shape, with no new computation and no second
  data source. That's a lighter, later step than what this cmdlet does. The closer precedent
  is `Get-PSScriptBuilderDependencyAnalysis` — it also takes already-collected input and
  *derives* a new analysis result through real computation (graph building, cycle detection).
  `Get-PSScriptBuilderSourceCoverage` follows that same pattern: derive a new report from
  existing inputs, not identity-resolve a reference or re-encode an already-finished result.
- **Aggregated by `SourceFile`, not by component.** Developers think in files, not in
  Enum/Class/Function components; a single source file commonly contains one component today,
  but the aggregation is written to naturally support files with multiple components without
  change.
- **No new resolution logic.** Per-entry line resolution reuses the existing
  `PSScriptBuilderSourceLocationResolver.Resolve([int])` unchanged. The only new logic is
  iteration over Pester's coverage entries and aggregation of the results.
- **Same preconditions as `Resolve-PSScriptBuilderSourceLocation`, verified against its actual
  implementation (not just its own pre-implementation planning doc).** Requires a prior build
  with `-WriteSourceMap`. Uses `BuildResult.SourceMapPath` directly in the `ByBuildResult`
  parameter set (throwing early if it's empty) exactly as the existing cmdlet does, reads the
  sidecar once via `PSScriptBuilderSourceMapFileManager.ReadSourceMapData()` (which already
  carries `OutputHash` — no separate `ReadOutputHash()` call needed), and performs the same
  staleness check.

### Verified Against Real Pester Output

An earlier draft of this document assumed Pester's `CodeCoverage` result exposes
`HitCommands`/`MissedCommands` collections, based on an unverified web search. This was
**wrong** and only surfaced once the implementation was actually run against real Pester
output: `tests\Invoke-Tests.ps1 -CodeCoverage` printed "No coverage results to display." for
every run, because those properties silently evaluate to `$null` on the real object rather
than throwing.

Confirmed directly against Pester 5.7.1 (`$result.CodeCoverage | Get-Member`, plus inspecting
one `CommandsExecuted`/`CommandsMissed` entry): the real top-level properties are
`CommandsAnalyzedCount`, `CommandsExecuted`, `CommandsExecutedCount`, `CommandsMissed`,
`CommandsMissedCount`, `CoveragePercent`, `CoverageReport`, `FilesAnalyzed`,
`FilesAnalyzedCount` — there is no `HitCommands`/`MissedCommands` at all. The per-entry shape
(`File`, `Line`, `StartLine`, `EndLine`, `StartColumn`, `EndColumn`, `Class`, `Function`,
`Command`, `HitCount`) was correct, only the container property names were not.

All references in this document and in the implementation
(`Get-PSScriptBuilderSourceCoverage.ps1`, `PSScriptBuilderCodeCoverageTranslator.ps1`) have
been corrected to `CommandsExecuted`/`CommandsMissed`. **Lesson**: for an external library's
object shape, verify directly against installed output before implementing against it — a
web search summary is not a reliable substitute, as this incident demonstrated concretely.

## Files

| # | File | Directory | Change |
|---|---|---|---|
| 1 | `PSScriptBuilderSourceCoverageResult.ps1` | `src\Classes\ScriptBuilder\Results\` | New |
| 2 | `PSScriptBuilderCodeCoverageTranslator.ps1` | `src\Classes\ScriptBuilder\Helper\` | New |
| 3 | `Get-PSScriptBuilderSourceCoverage.ps1` | `src\Public\` | New |
| 4 | `Format-PSScriptBuilderSourceCoverage.ps1` | `src\Public\` | New |

## 1. PSScriptBuilderSourceCoverageResult — New

Result class, one instance per source file. Properties:

| Property | Type | Description |
|---|---|---|
| `SourceFile` | `string` | Absolute path to the source file |
| `TotalCommands` | `int` | Number of coverage-analyzed commands attributed to this source file |
| `HitCommands` | `int` | Number of those commands that were executed at least once |
| `MissedCommands` | `int` | `TotalCommands - HitCommands` |
| `CoveragePercent` | `double` | `HitCommands / TotalCommands * 100`, `0` if `TotalCommands` is `0` |
| `MissedLocations` | `PSScriptBuilderSourceLocation[]` | Resolved locations of every missed command, for drill-down |

Constructor: all 6 properties as parameters, matching the existing convention for Result
classes in this project (e.g. `PSScriptBuilderSourceLocation`).

## 2. PSScriptBuilderCodeCoverageTranslator — New

Instance class. Constructed with an already-built resolver, so it never touches file I/O
itself:

```powershell
PSScriptBuilderCodeCoverageTranslator([PSScriptBuilderSourceLocationResolver] $resolver)

[PSScriptBuilderSourceCoverageResult[]] Translate([string] $outputPath, [object[]] $hitCommands, [object[]] $missedCommands)
```

**`Translate()` logic:**

1. Combine `$hitCommands` and `$missedCommands` into one sequence, tagging each with whether
   it was a hit or a miss.
2. **Validate origin file.** For each entry, compare `$command.File` against `$outputPath`
   (case-insensitive). If they don't match, skip the entry and increment an
   `unexpectedFileCount` counter — this guards against a misconfigured `CodeCoverage.Path`
   (pointed at something other than the build output) producing silently misleading results.
3. For each remaining entry, call `$resolver.Resolve($command.Line)` (existing method,
   unchanged). If it returns `$null` (line falls before the first component — e.g. template
   boilerplate around `{{ORDERED_COMPONENTS}}`), skip the entry and increment an
   `unresolvedCount` counter.
4. Group resolved entries by `SourceFile`, tally hit/miss counts per group, compute
   `CoveragePercent`, collect `MissedLocations` from the missed subset.
5. If `unexpectedFileCount` or `unresolvedCount` is greater than zero, emit **one** summary
   `Write-Warning` for each (not per-entry) — consistent with the project's established
   pattern of consolidated warnings instead of per-item spam (e.g.
   `WarnCrossCollectorDependencies()` in `PSScriptBuilderBuildOrchestrator`). Per-entry detail
   goes to `Write-Verbose`.
6. Return the array of `PSScriptBuilderSourceCoverageResult`, one per distinct `SourceFile`.

## 3. Get-PSScriptBuilderSourceCoverage — New

Same two-parameter-set shape as `Resolve-PSScriptBuilderSourceLocation`:

```powershell
[Parameter(ParameterSetName = 'ByBuildResult', Mandatory, ValueFromPipeline)]
[PSScriptBuilderBuildResult] $BuildResult

[Parameter(ParameterSetName = 'ByOutputPath', Mandatory)]
[string] $OutputPath

[Parameter(Mandatory)]
[object] $CodeCoverage   # $pesterResult.CodeCoverage — must expose CommandsExecuted/CommandsMissed
                          # (verified against Pester 5.7.1; an earlier draft of this document
                          # incorrectly assumed HitCommands/MissedCommands from an unverified
                          # web search - always confirm Pester's object shape directly, see
                          # "Verified Against Real Pester Output" note below)
```

**Body logic — verified against the actual implementation of
`Resolve-PSScriptBuilderSourceLocation`, not just its pre-implementation planning doc:**

```
if ParameterSetName -eq 'ByBuildResult':
    if [string]::IsNullOrWhiteSpace($BuildResult.SourceMapPath):
        throw [InvalidOperationException] "No source map was written for this build. Re-run Invoke-PSScriptBuilderBuild with -WriteSourceMap."
    outputPath  = $BuildResult.OutputPath
    sidecarPath = $BuildResult.SourceMapPath
else:
    outputPath  = GetProjectRootedPath($OutputPath)
    sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath(outputPath)

# Single read - sourceMapData already carries OutputHash, no separate ReadOutputHash() call
sourceMapData = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData(sidecarPath)   # FileNotFoundException if missing

currentHash = (Get-FileHash -LiteralPath outputPath -Algorithm SHA256).Hash
if currentHash -ne $sourceMapData.OutputHash:
    Write-Warning "Source map may be stale - output script has changed since the source map was created."

resolver    = [PSScriptBuilderSourceLocationResolver]::new($sourceMapData)   # takes the whole data object, not a bare array
translator  = [PSScriptBuilderCodeCoverageTranslator]::new($resolver)

return $translator.Translate($outputPath, $CodeCoverage.CommandsExecuted, $CodeCoverage.CommandsMissed)
```

Wrapped in the same top-level try/catch as `Resolve-PSScriptBuilderSourceLocation` (rethrows as
`InvalidOperationException` with a formatted message), for consistency.

## 4. Format-PSScriptBuilderSourceCoverage — New

Console formatter, following the existing Format-cmdlet convention (compact by default,
`-Detailed` adds drill-down). Compact mode: one row per `PSScriptBuilderSourceCoverageResult`
— `SourceFile`, `Coverage %`, `Hit/Total`. `-Detailed` additionally lists each entry in
`MissedLocations` (source file + line) beneath its row.

## Edge Cases

| Case | Behavior |
|---|---|
| `-BuildResult` was produced without `-WriteSourceMap` (`SourceMapPath` is empty) | `InvalidOperationException`, same message as `Resolve-PSScriptBuilderSourceLocation` — checked before any file I/O |
| Coverage entry's `File` doesn't match the build output path | Skipped; counted; single summary `Write-Warning` (possible `CodeCoverage.Path` misconfiguration) |
| Coverage line falls before the first component (template boilerplate) | Skipped; counted; single summary `Write-Warning` — `Resolve([int])` already emits its own per-call warning here; the translator suppresses that per-entry noise and reports one summary instead |
| Coverage line exceeds the output file's total line count | Same handling as above — `Resolve([int])` treats this identically to "not covered by any component" |
| Sidecar missing (`ByOutputPath` only) | `FileNotFoundException`, hint to use `-WriteSourceMap` (same as `Resolve-PSScriptBuilderSourceLocation`) |
| Output script changed since the build that produced the sidecar | `Write-Warning` — same staleness check as `Resolve-PSScriptBuilderSourceLocation`, single hash read reused (no separate `ReadOutputHash` call) |
| Multiple components collected from the same source file | Aggregated under one `SourceFile` entry |
| `$CodeCoverage.CommandsExecuted`/`CommandsMissed` both empty | Returns `@()` |

## Prerequisites

Requires the Source Maps feature (`-WriteSourceMap`, `PSScriptBuilderSourceLocationResolver`,
`PSScriptBuilderSourceMapFileManager`, `Resolve-PSScriptBuilderSourceLocation`). This is
**already implemented** in the `development` branch today (verified directly against
`src/Classes/ScriptBuilder/Helper/PSScriptBuilderSourceLocationResolver.ps1`,
`src/Classes/ScriptBuilder/Managers/PSScriptBuilderSourceMapFileManager.ps1`, and
`src/Public/Resolve-PSScriptBuilderSourceLocation.ps1`), just not yet in a tagged release —
see `resolve-source-location-planning.md` for its original design. No changes to that feature
are needed; this is a pure consumer of its existing public surface, and every method call in
this document's design (`ReadSourceMapData()`, `Resolve()`, `BuildResult.SourceMapPath`) has
been checked against that real, already-implemented code rather than against its
pre-implementation plan.

## Follow-up

- **Dogfooding is a two-line change, not a new setup.** `Build-Module.ps1:115` already sets
  `WriteSourceMap = $true` when PSScriptBuilder builds itself — the sidecar
  `build\Output\PSScriptBuilder.psm1.sourcemap.json` already exists after every self-build
  (see `.gitignore`, which already anticipates it as a generated artifact). The only missing
  piece is enabling coverage in the test runner itself:
  `tests\Invoke-Tests.ps1` would need `$config.CodeCoverage.Enabled = $true` and
  `$config.CodeCoverage.Path = "$PSScriptRoot\..\build\Output\PSScriptBuilder.psm1"` added to
  its existing `$config` block — the output path is already fixed and known
  (`Build-Module.ps1:72`). Once `Get-PSScriptBuilderSourceCoverage` exists, piping
  `$result.CodeCoverage` (from that same `Invoke-Pester` call) through it against the
  `-WriteSourceMap`-produced sidecar requires no further plumbing.
- Aggregating by component instead of (or in addition to) source file was considered and
  deferred — not needed while the common case is one component per file.
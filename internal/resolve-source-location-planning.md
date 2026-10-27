# Planning: Resolve-PSScriptBuilderSourceLocation

## Background

PSScriptBuilder merges multiple source files into a single output script. When the output
script throws a runtime error, the error message contains a line number in the output file —
not in any source file. There is currently no tooling to bridge this gap.

This feature solves that problem: given a line number or an ErrorRecord, it identifies the
component at that position and returns the source file it came from, along with the line
offset within that component.

A sidecar file (`.sourcemap.json`) is the source of truth for all resolution scenarios.
It is created at build time by passing `-WriteSourceMap` to `Invoke-PSScriptBuilderBuild`.

## Debugging Scenarios

**Scenario A — Error during dot-source (ErrorRecord available):**

```powershell
$result = New-PSScriptBuilderContentCollector | ... | Invoke-PSScriptBuilderBuild ... -WriteSourceMap

try {
    . $result.OutputPath
}
catch {
    $result | Resolve-PSScriptBuilderSourceLocation -ErrorRecord $_
}
```

**Scenario B — Error after build (line number from console, no BuildResult):**

```
At C:\build\Output\MyProject.ps1:1000 char:5
```

```powershell
# Requires prior build with -WriteSourceMap
Resolve-PSScriptBuilderSourceLocation -OutputPath 'build\Output\MyProject.ps1' -LineNumber 1000
```

**Scenario C — Full source map to verify component order:**

```powershell
$result | Resolve-PSScriptBuilderSourceLocation | Format-Table
```

## Design Decision

Line numbers are computed **once at build time**, only when `-WriteSourceMap` is requested.
`PSScriptBuilderSourceMapGenerator.CreateSourceMap()` receives the in-memory rendered string
and the `PSScriptBuilderContentCollector`, iterates all collectors, and searches for each
component's source code verbatim in the output string.

**Key design principles:**

- **No regex** — `IndexOf(SourceCode, [StringComparison]::Ordinal)` for all types (Enum,
  Class, Function, File). The `SourceCode`/`Content` from Data classes is the exact verbatim
  source, as it appears in the final script.
- **Unique by construction** — guard clauses enforce globally unique names. Identical
  `SourceCode` for different components is therefore impossible.
- **Not found = no placeholder** — if `IndexOf` returns -1, the component's collector had
  no placeholder in the template. The entry is silently omitted from the source map.
- **Sidecar as single source of truth** — `SourceMap` is never stored in `BuildResult` or
  on `ComponentDetails`. `ByBuildResult` derives the sidecar path from `BuildResult.OutputPath`.
- **Minimal changes to existing classes** — `PSScriptBuilderTemplateProcessor`,
  `PSScriptBuilderBuildComponentDetail`, `PSScriptBuilderBuildDataAggregator`,
  `PSScriptBuilderCollectorBase`, and all Data classes remain unchanged.
  `PSScriptBuilderEnumCollector`, `PSScriptBuilderClassCollector`,
  `PSScriptBuilderFunctionCollector`, and `PSScriptBuilderFileCollector` each gain a single
  `hidden` property (`$SourceRanges`).

## Files

| # | File | Directory | Change |
|---|---|---|---|
| 1 | `PSScriptBuilderBuildOrchestrator.ps1` | `src\Classes\ScriptBuilder\Orchestrators\` | Modified |
| 2 | `Invoke-PSScriptBuilderBuild.ps1` | `src\Public\` | Modified |
| 3 | `PSScriptBuilderBuildOptions.ps1` | `src\Classes\Configuration\Options\` | ✅ Done |
| 4 | `PSScriptBuilderConfigValidator.ps1` | `src\Classes\Configuration\` | ✅ Done |
| 5 | `PSScriptBuilderSourceLocation.ps1` | `src\Classes\ScriptBuilder\Results\` | New |
| 6 | `PSScriptBuilderSourceMapGenerator.ps1` | `src\Classes\ScriptBuilder\Helper\` | New |
| 7 | `PSScriptBuilderSourceMapFileManager.ps1` | `src\Classes\ScriptBuilder\Managers\` | New |
| 8 | `PSScriptBuilderSourceLocationResolver.ps1` | `src\Classes\ScriptBuilder\Helper\` | New |
| 9 | `Resolve-PSScriptBuilderSourceLocation.ps1` | `src\Public\` | New |
| 10 | `PSScriptBuilderSourceRange.ps1` | `src\Classes\ScriptBuilder\Data\` | New (intern) |
| 11 | `PSScriptBuilderEnumCollector.ps1` | `src\Classes\ScriptBuilder\Collectors\` | Modified |
| 12 | `PSScriptBuilderClassCollector.ps1` | `src\Classes\ScriptBuilder\Collectors\` | Modified |
| 13 | `PSScriptBuilderFunctionCollector.ps1` | `src\Classes\ScriptBuilder\Collectors\` | Modified |
| 14 | `PSScriptBuilderFileCollector.ps1` | `src\Classes\ScriptBuilder\Collectors\` | Modified |

## Prerequisites

The optional-config-fields refactoring (`optional-config-fields-planning.md`) must be applied
before this feature. It makes `backupEnabled`, `syntaxValidationEnabled`, and
`orderedComponentsKey` optional in the config schema, and corrects `SetOptions` to handle
absent optional fields properly. This is required so that `writeSourceMap` can be added as
another optional field without a breaking change.

## 1. PSScriptBuilderBuildOrchestrator — Change

New 8th constructor parameter (consistent with `backupEnabled` and `syntaxValidationEnabled`):

```powershell
[bool] $writeSourceMap
```

Stored as:

```powershell
hidden [bool] $WriteSourceMap
```

In `ExecuteBuild()`, immediately after `$this.WriteOutput($finalScript)`:

```powershell
if ($this.WriteSourceMap) {
    $sourceMap = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $this.ContentCollector)
    [PSScriptBuilderSourceMapFileManager]::WriteSourceMap($this.OutputPath, $sourceMap)
}
```

`$finalScript` is already a local variable at this point.

## 2. Invoke-PSScriptBuilderBuild — Change

New optional switch:

```powershell
[Parameter()]
[switch] $WriteSourceMap
```

Passed as 8th argument when constructing the orchestrator:

```powershell
$orchestrator = [PSScriptBuilderBuildOrchestrator]::new(
    $ContentCollector,
    $resolvedTemplatePath,
    $resolvedOutputPath,
    $resolvedBackupPath,
    $OrderedComponentsKey,
    $EnableBackup.IsPresent,
    (-not $SkipSyntaxValidation.IsPresent),
    $WriteSourceMap.IsPresent
)
```

## 3. PSScriptBuilderBuildOptions — Modified

New property (optional, default `$false`):

```powershell
[bool] $WriteSourceMap = $false
```

In `SetOptions()` — `[bool] $null = $false`, so unconditional assignment is safe:

```powershell
$this.WriteSourceMap = [bool] $this.GetPropertyValue($config, "writeSourceMap")
```

## 4. PSScriptBuilderConfigValidator — Modified

In `InitializeSchema()`, add to the `build` section (requires the optional-config-fields
refactoring to be applied first so that `required = $false` fields are already in use):

```powershell
writeSourceMap = @{ required = $false; type = "boolean" }
```

## 5. PSScriptBuilderSourceLocation — New

Result class. Properties:

| Property | Type | Description |
|---|---|---|
| `ComponentName` | `string` | Name of the component (class name, function name, file name) |
| `ComponentType` | `string` | Enum, Class, Function, or File — produced by `[PSScriptBuilderTextHelper]::FormatCollectorType()` |
| `OutputLineNumber` | `int` | First line (1-based) of the component in the output script |
| `Offset` | `int` | Target line minus `OutputLineNumber`. 0 for full source map entries |
| `SourceFile` | `string` | Absolute path to the source file |
| `ComponentLineNumber` | `int` | First line (1-based) of the component in the source file. Always 1 for File components |
| `SourceLineNumber` | `int` | Exact line in the source file (`ComponentLineNumber + Offset`). Set by `Resolve()`. Equals `ComponentLineNumber` in source map entries (where `Offset = 0`) |

Constructor: all 7 properties as parameters.

## 6. PSScriptBuilderSourceMapGenerator — New

Static class. Requires `using namespace System.Collections.Generic` (for internal `[List[PSScriptBuilderSourceLocation]]` accumulator). Single public method:

```powershell
static [PSScriptBuilderSourceLocation[]] CreateSourceMap([string] $finalScript, [PSScriptBuilderContentCollector] $contentCollector)
```

Iterates `$contentCollector.GetCollectors()`. Per collector type:

| Type | Data source | Search | ComponentLineNumber |
|---|---|---|---|
| UsingCollector | — | Skipped | — |
| EnumCollector | `$collector.EnumData.Values` | `$finalScript.IndexOf($data.SourceCode, [StringComparison]::Ordinal)` | `$collector.SourceRanges[$data.Name].StartLineNumber` |
| ClassCollector | `$collector.ClassData.Values` | `$finalScript.IndexOf($data.SourceCode, [StringComparison]::Ordinal)` | `$collector.SourceRanges[$data.Name].StartLineNumber` |
| FunctionCollector | `$collector.FunctionData.Values` | `$finalScript.IndexOf($data.SourceCode, [StringComparison]::Ordinal)` | `$collector.SourceRanges[$data.Name].StartLineNumber` |
| FileCollector | `$collector.FileData.Values` | `$finalScript.IndexOf($data.Content, [StringComparison]::Ordinal)` | `$collector.SourceRanges[$data.FileName].StartLineNumber` |

For each match (`$matchIndex >= 0`):
`$OutputLineNumber = ($finalScript.Substring(0, $matchIndex) -split '\r?\n').Count`

`ComponentLineNumber` is read from `$collector.SourceRanges[$data.Name].StartLineNumber` for
Enum/Class/Function components and from `$collector.SourceRanges[$data.FileName].StartLineNumber`
for File components. `SourceLineNumber` is set equal to `ComponentLineNumber` (all source map entries
have `Offset = 0`). `ComponentType` (string) is set via
`[PSScriptBuilderTextHelper]::FormatCollectorType($collector.CollectorType)`.

**`SourceFile` in the result:** Enum/Class/Function components use `$data.SourceFile`.
File components use `$data.FullPath` — `PSScriptBuilderFileData` names this property `FullPath`,
not `SourceFile`.

Returns `PSScriptBuilderSourceLocation[]` with `Offset = 0`. Not sorted — the Resolver
sorts on construction.

Private static helper: `FindLine([string] $script, [string] $content)` encapsulates the
`IndexOf` + line count logic; returns 0 if not found.

## 7. PSScriptBuilderSourceMapFileManager — New

Static class (no instance state, like `PSScriptBuilderOutputFileManager`).

```powershell
static [string]                          GetSidecarPath([string] $outputPath)
static [void]                            WriteSourceMap([string] $outputPath, [PSScriptBuilderSourceLocation[]] $sourceMap)
static [PSScriptBuilderSourceLocation[]] ReadSourceMap([string] $sidecarPath)
static [string]                          ReadOutputHash([string] $sidecarPath)
static [bool]                            SourceMapExists([string] $sidecarPath)
```

**`GetSidecarPath`:** Appends the private suffix `".sourcemap.json"` to `$outputPath`. The
suffix is defined as `hidden static [string] $SourceMapSuffix = ".sourcemap.json"` within
the class itself — it does not belong in `PSScriptBuilderWellKnownFileNames` because it is
a suffix, not a file name.

**`WriteSourceMap`:** Derives `$sidecarPath` via `GetSidecarPath($outputPath)` and computes
`$outputHash` via `Get-FileHash $outputPath -Algorithm SHA256` — both are internal details.
Wraps the data in a `PSCustomObject` with PascalCase keys and serializes via
`ConvertTo-Json -Depth 5`. `ComponentType` is a plain string (`"Enum"`, `"Class"`,
`"Function"`, `"File"`), serialized as-is. Written with UTF-8 without BOM via
`[PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithoutBOM`.

**`ReadSourceMap`:** Guard clause → `FileNotFoundException` if sidecar missing, message hints
to use `-WriteSourceMap`. Parses JSON (`ConvertFrom-Json` → `PSCustomObject`), reconstructs
`PSScriptBuilderSourceLocation[]`. Fields are read by PascalCase property name (matching the
serialised format). `SourceLineNumber` is set equal to `ComponentLineNumber` (all persisted entries
have `Offset = 0`).

**`ReadOutputHash`:** Reads only the `OutputHash` field from the sidecar JSON. Guard clause →
`FileNotFoundException` if sidecar missing.

**`SourceMapExists`:** Returns `$true` if the sidecar file exists at `$sidecarPath`.

**Sidecar format** (PascalCase property names match `PSScriptBuilderSourceLocation` class):

```json
{
  "OutputPath": "C:\\Project\\build\\Output\\MyProject.ps1",
  "OutputHash": "3A7B2C1D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0C1D2E3F4A5B6C7D8E9F0A1B",
  "Components": [
    { "ComponentName": "Config.ps1",  "ComponentType": "File",     "OutputLineNumber": 1,    "Offset": 0, "SourceFile": "C:\\...\\Config.ps1",      "ComponentLineNumber": 1,  "SourceLineNumber": 1  },
    { "ComponentName": "StatusCode",  "ComponentType": "Enum",     "OutputLineNumber": 45,   "Offset": 0, "SourceFile": "C:\\...\\StatusCode.ps1",  "ComponentLineNumber": 1,  "SourceLineNumber": 1  },
    { "ComponentName": "BaseService", "ComponentType": "Class",    "OutputLineNumber": 58,   "Offset": 0, "SourceFile": "C:\\...\\BaseService.ps1", "ComponentLineNumber": 14, "SourceLineNumber": 14 },
    { "ComponentName": "Get-MyData",  "ComponentType": "Function", "OutputLineNumber": 1024, "Offset": 0, "SourceFile": "C:\\...\\Get-MyData.ps1",  "ComponentLineNumber": 1,  "SourceLineNumber": 1  }
  ]
}
```

## 8. PSScriptBuilderSourceLocationResolver — New

Instance class. No file I/O. Requires `using namespace System.Management.Automation` for the `ErrorRecord` parameter type.

```powershell
PSScriptBuilderSourceLocationResolver([PSScriptBuilderSourceLocation[]] $sourceMap)

[PSScriptBuilderSourceLocation[]] GetSourceMap()
[PSScriptBuilderSourceLocation]   Resolve([int] $lineNumber)
[PSScriptBuilderSourceLocation]   Resolve([ErrorRecord] $errorRecord)
```

**Constructor:** Sorts `$sourceMap` by `OutputLineNumber` ascending and caches as `$this.SourceMap`.
No filtering required — `CreateSourceMap()` never adds entries with `OutputLineNumber = 0`.
`Sort-Object` returns `object[]` — cast explicitly:

```powershell
$this.SourceMap = [PSScriptBuilderSourceLocation[]]($sourceMap | Sort-Object -Property OutputLineNumber)
```

**`GetSourceMap()`:** Returns `$this.SourceMap` (all `Offset` values are already 0).

**`Resolve([int])`:** Iterates the sorted map and tracks the last entry where
`OutputLineNumber <= $lineNumber`. Breaks early when `OutputLineNumber > $lineNumber`. Returns
`$null` + `Write-Warning` if no entry qualifies:

```powershell
$found = $null
foreach ($entry in $this.SourceMap) {
    if ($entry.OutputLineNumber -le $lineNumber) { $found = $entry }
    else { break }
}
```

Creates a **new** `PSScriptBuilderSourceLocation` from `$found` with
`Offset = $lineNumber - $found.OutputLineNumber` and
`SourceLineNumber = $found.ComponentLineNumber + $Offset`.

**`Resolve([ErrorRecord])`:** Guard clause — throws `ArgumentException` if `$errorRecord` is
`$null` or if `$errorRecord.InvocationInfo` is `$null`. Extracts `InvocationInfo.ScriptLineNumber`,
delegates to `Resolve([int])`.

## 9. Resolve-PSScriptBuilderSourceLocation — New

**2 parameter sets** (`ByBuildResult`, `ByOutputPath`). Both require the sidecar file to exist.
`ByBuildResult` derives the sidecar path from `$BuildResult.OutputPath`.
Requires `using namespace System.Management.Automation` for the `ErrorRecord` parameter type.

```powershell
[Parameter(ParameterSetName = 'ByBuildResult', Mandatory, ValueFromPipeline)]
[PSScriptBuilderBuildResult] $BuildResult

[Parameter(ParameterSetName = 'ByOutputPath', Mandatory)]
[string] $OutputPath

[Parameter()]
[int] $LineNumber

[Parameter()]
[ErrorRecord] $ErrorRecord
```

**Body logic:**

```
# [int] defaults to 0 — value comparison cannot distinguish "not provided" from "0".
# Use $PSBoundParameters.ContainsKey() for reliable presence detection.
Mutual exclusion: $PSBoundParameters.ContainsKey('LineNumber') -and
                  $PSBoundParameters.ContainsKey('ErrorRecord') → ArgumentException

ByBuildResult:
    outputPath  = $BuildResult.OutputPath
    sidecarPath = GetSidecarPath(outputPath)

ByOutputPath:
    outputPath  = GetProjectRootedPath($OutputPath)
    sidecarPath = GetSidecarPath(outputPath)

sourceMap    = ReadSourceMap(sidecarPath) # FileNotFoundException if missing
currentHash  = (Get-FileHash outputPath -Algorithm SHA256).Hash
storedHash   = ReadOutputHash(sidecarPath)
if currentHash ≠ storedHash → Write-Warning "Source map may be stale — output script has changed since the source map was created."
$resolver = new Resolver(sourceMap)

-LineNumber   → $resolver.Resolve($LineNumber)
-ErrorRecord  → $resolver.Resolve($ErrorRecord)
(neither)     → $resolver.GetSourceMap()
```

## 10. PSScriptBuilderSourceRange — New (intern)

Minimale Value-Klasse im `Data/`-Ordner. Wird ausschließlich von EnumCollector, ClassCollector,
FunctionCollector und FileCollector als Typ für das `$SourceRanges`-Dictionary verwendet.
Nicht Teil der öffentlichen API.

| Property | Type | Description |
|---|---|---|
| `StartLineNumber` | `int` | First line (1-based) of the component in the source file |
| `EndLineNumber` | `int` | Last line (1-based) of the component in the source file |

Constructor: `PSScriptBuilderSourceRange([int] $StartLineNumber, [int] $EndLineNumber)`

## 11. PSScriptBuilderEnumCollector / PSScriptBuilderClassCollector / PSScriptBuilderFunctionCollector / PSScriptBuilderFileCollector — Change

Each collector gains one new `hidden` property (declared without inline initializer, consistent
with all existing data dictionaries in this project):

```powershell
hidden [Dictionary[string, PSScriptBuilderSourceRange]] $SourceRanges
```

Initialized in **both** constructors alongside the existing data dictionary:

```powershell
$this.SourceRanges = [Dictionary[string, PSScriptBuilderSourceRange]]::new([StringComparer]::OrdinalIgnoreCase)
```

`Reset()` clears `$SourceRanges` alongside the existing data dictionary. In `CollectFromFiles()`,
immediately after the guard clause check, a `PSScriptBuilderSourceRange` is created and stored
alongside the data object.

For Enum/Class/Function collectors, both values come from the AST node. The variable names differ per collector — use the names that already exist in each file:

```powershell
# EnumCollector:    $enumDefinition / $enumName
# ClassCollector:   $classDefinition / $className
# FunctionCollector: $functionDefinition / $functionName
$sourceRange = [PSScriptBuilderSourceRange]::new(
    $<type>Definition.Extent.StartLineNumber,
    $<type>Definition.Extent.EndLineNumber
)
$this.SourceRanges[$<type>Name] = $sourceRange
```

For `PSScriptBuilderFileCollector`, `StartLineNumber` is always 1 and `EndLineNumber` is computed from
the file content at read time. `Get-Content -Raw` is used (preserves original line endings for
verbatim `IndexOf` matching). Line count is determined by counting `\n` characters — covers
both CRLF (Windows) and LF (Linux/macOS), which are the only relevant variants for
PowerShell files:

```powershell
# Get-Content -Raw returns $null for empty files
if ([string]::IsNullOrEmpty($content)) {
    $lineCount = 0
}
else {
    $newlineCount = [regex]::Matches($content, '\n').Count
    $lineCount    = if ($content.EndsWith("`n")) { $newlineCount } else { $newlineCount + 1 }
}
$sourceRange  = [PSScriptBuilderSourceRange]::new(1, $lineCount)
$this.SourceRanges[$fileName] = $sourceRange
```

## Edge Cases

| Case | Behavior |
|---|---|
| Line before first component | `$null` + `Write-Warning` |
| Sidecar missing | `FileNotFoundException` with hint to use `-WriteSourceMap` |
| Output script changed after build | `Write-Warning` — resolution continues with potentially incorrect results |
| `-LineNumber` and `-ErrorRecord` both provided | `ArgumentException` |
| `ErrorRecord.InvocationInfo` is `$null` | `ArgumentException` |
| Source map empty | `GetSourceMap()` returns `@()` |
| Component not in template | Not in sidecar — silently omitted by `CreateSourceMap()` |

## Usage Examples

```powershell
# Scenario A: Build with sidecar, then resolve error during dot-source
$result = ... | Invoke-PSScriptBuilderBuild ... -WriteSourceMap
try { . $result.OutputPath }
catch { $result | Resolve-PSScriptBuilderSourceLocation -ErrorRecord $_ }

# Scenario B: Line number, offline
Resolve-PSScriptBuilderSourceLocation -OutputPath 'build\Output\MyProject.ps1' -LineNumber 1000

# Scenario C: Full source map
$result | Resolve-PSScriptBuilderSourceLocation | Format-Table
```

## Expected Output (single resolution)

```
ComponentName   : PSScriptBuilderBuildOrchestrator
ComponentType   : Class
OutputLineNumber  : 4510
Offset      : 10
ComponentLineNumber : 14
SourceLineNumber      : 24
SourceFile      : C:\Project\src\Classes\PSScriptBuilderBuildOrchestrator.ps1
```

## Follow-up: Format-PSScriptBuilderSourceLocation (optional)

`PSScriptBuilderSourceLocation` provides all location data needed to navigate to the source
(file path + line number). If a richer display showing the actual code line is desired in the
future, `Format-PSScriptBuilderSourceLocation` can be added as a dedicated Format cmdlet
that reads the source line via `Get-Content` at display time. This is a convenience
enhancement and not part of the core feature.

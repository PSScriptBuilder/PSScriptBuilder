# Planning: Resolve-PSScriptBuilderSourceLocation

## Background

PSScriptBuilder merges multiple source files into a single output script. When the output
script throws a runtime error, the error message contains a line number in the output file —
not in any source file. There is currently no tooling to bridge this gap.

This cmdlet solves that problem directly: given a line number or an ErrorRecord, it identifies
the component at that position and returns the source file it came from, along with the line
offset within that component.

## Cmdlet Design

**Name:** `Resolve-PSScriptBuilderSourceLocation`

**Verb rationale:** `Resolve-` follows the PowerShell convention for "turn an ambiguous
reference into a concrete result" (cf. `Resolve-Path`).

## Parameters

| Parameter | Type | Mandatory | Pipeline | Description |
|---|---|---|---|---|
| `BuildResult` | `PSScriptBuilderBuildResult` | Yes | Yes (ByValue) | The result returned by `Invoke-PSScriptBuilderBuild` |
| `LineNumber` | `int` | No | No | Line number in the output script to resolve |
| `ErrorRecord` | `ErrorRecord` | No | No | Error record from the failed script; line number is extracted automatically |

`LineNumber` and `ErrorRecord` are mutually exclusive (parameter sets). When neither is
provided, the cmdlet returns the full source map — all components with their output line
numbers and source files.

## Return Type: PSScriptBuilderSourceLocation

| Property | Type | Description |
|---|---|---|
| `ComponentName` | `string` | Name of the component at the resolved line |
| `ComponentType` | `PSScriptBuilderCollectorType` | Enum, Class, or Function |
| `ComponentStart` | `int` | First line of the component in the output script |
| `LineOffset` | `int` | Target line minus ComponentStart — the line within the component block |
| `SourceFile` | `string` | Absolute path to the source file the component was collected from |

When returning the full source map (no line number provided), `LineOffset` is always 0 and
`ComponentStart` is the actual start line of each component.

## Resolution Algorithm

1. Parse the output file line by line using `Get-Content`
2. For each component in `BuildResult.ComponentDetails`, find its start line using
   `Select-String` with a definition-pattern match:
   - Class: `^class\s+<name>\b`
   - Function: `^function\s+<name>\b`
   - Enum: `^enum\s+<name>\b`
   - Using/File: excluded (no named definition pattern)
3. Sort resolved components by `ComponentStart` ascending
4. For a given target line: find the component whose `ComponentStart` is ≤ target and closest
   (last entry in the sorted list where `ComponentStart <= targetLine`)
5. Calculate `LineOffset = targetLine - ComponentStart`

## Usage Examples

```powershell
# Resolve via line number
$result | Resolve-PSScriptBuilderSourceLocation -LineNumber 4520

# Resolve via error record
try {
    . $result.OutputPath
}
catch {
    $result | Resolve-PSScriptBuilderSourceLocation -ErrorRecord $_
}

# Full source map
$result | Resolve-PSScriptBuilderSourceLocation
```

## Expected Output (single resolution)

```
ComponentName  : PSScriptBuilderBuildOrchestrator
ComponentType  : Class
ComponentStart : 4510
LineOffset     : 10
SourceFile     : C:\Project\src\Classes\PSScriptBuilderBuildOrchestrator.ps1
```

## File Locations

| File | Path |
|---|---|
| Result class | `src\Classes\ScriptBuilder\Results\PSScriptBuilderSourceLocation.ps1` |
| Cmdlet | `src\Public\Resolve-PSScriptBuilderSourceLocation.ps1` |

## Open Questions

- Should `ErrorRecord` parameter support pipeline input separately, or always require
  `BuildResult` piped in first?
- Should the full source map output be sorted by `ComponentStart` (natural output order)
  or by `ComponentName` (alphabetical)?
- Should `Using` and `File` entries appear in the full source map with `ComponentStart = 0`
  as a placeholder, or be silently excluded?

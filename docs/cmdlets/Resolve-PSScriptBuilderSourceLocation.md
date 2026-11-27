# Resolve-PSScriptBuilderSourceLocation

Resolves an output script line number or ErrorRecord back to its source file location.

## Description

Reads the `.sourcemap.json` sidecar written by
[`Invoke-PSScriptBuilderBuild`](Invoke-PSScriptBuilderBuild.md)'s `-WriteSourceMap` (or
[`Watch-PSScriptBuilderProject`](Watch-PSScriptBuilderProject.md)'s Build mode with the same
switch) and resolves a specific output line, or the line from a caught `ErrorRecord`, back to the
original source file and line. Omit both `-LineNumber` and `-ErrorRecord` to retrieve every entry
in the source map at once.

Accepts either the build result directly (`-BuildResult`, sidecar path derived from its
`SourceMapPath`) or an explicit `-OutputPath` (sidecar path derived by appending
`.sourcemap.json`).

A SHA-256 hash comparison against the output file detects a stale source map — one written before
the output was rebuilt without `-WriteSourceMap` again — and emits a warning, but resolution still
proceeds using the (possibly outdated) data. If the output file cannot be read (missing, locked or
no access), a warning says that staleness cannot be checked; resolution still proceeds, since it
only needs the source map.

An `ErrorRecord` is only resolved if the error originated in the output script or in an unmodified
copy of it. For an error raised elsewhere — e.g. in the calling build or test script, interactively,
or in code loaded via `Invoke-Expression` — a warning is emitted and `$null` is returned, since its
line number does not refer to the output script.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-BuildResult` | `PSScriptBuilderBuildResult` | The build result to resolve against. Accepts pipeline input. Requires a build run with `-WriteSourceMap`. |
| `-OutputPath` | string | Path to the output script to resolve against, as an alternative to `-BuildResult`. |
| `-LineNumber` | int | The 1-based output line to resolve. Cannot be combined with `-ErrorRecord`. |
| `-ErrorRecord` | `ErrorRecord` | An error whose `InvocationInfo.ScriptLineNumber` is resolved. The error must originate in the output script or an unmodified copy of it. Cannot be combined with `-LineNumber`. |

Exactly one of `-BuildResult` or `-OutputPath` is required. `-LineNumber` and `-ErrorRecord` are
optional and mutually exclusive; passing both throws an `ArgumentException`.

## Examples

### Resolve a caught error back to its source

```powershell
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'  |
    Invoke-PSScriptBuilderBuild -TemplatePath 'template.psm1' -OutputPath 'output.psm1' -WriteSourceMap

try {
    . $result.OutputPath
}
catch {
    $result | Resolve-PSScriptBuilderSourceLocation -ErrorRecord $_
}
```

### Resolve a specific output line number

```powershell
Resolve-PSScriptBuilderSourceLocation -OutputPath 'build\Output\MyProject.ps1' -LineNumber 1000
```

### Inspect the full source map

```powershell
$result | Resolve-PSScriptBuilderSourceLocation | Format-Table
```

## Output

- A single [`PSScriptBuilderSourceLocation`](../reference/types.md#psscriptbuildersourcelocation) (or `$null` if no component covers that line, or the error did not originate in the output script) when `-LineNumber` or `-ErrorRecord` is passed
- Every entry in the source map, as `PSScriptBuilderSourceLocation[]`, when neither is passed

## See Also

- [Source Maps Guide](../guides/source-maps.md)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md)
- [Cmdlet Reference: Get-PSScriptBuilderSourceCoverage](Get-PSScriptBuilderSourceCoverage.md)

# Get-PSScriptBuilderSourceCoverage

Translates Pester code coverage data back to the original source files.

## Description

Reads the `.sourcemap.json` sidecar written by [`Invoke-PSScriptBuilderBuild`](Invoke-PSScriptBuilderBuild.md)'s
`-WriteSourceMap` and translates a Pester `CodeCoverage` result — reported in terms of the built
output script — back to per-source-file coverage aggregates.

This translation is necessary whenever tests load the built output as a single unit (for example
via `using module` for a class-based project) rather than the original per-file sources —
`CodeCoverage.Path` must then point at the build output, since that's the only file PowerShell
has any execution record of, and its line numbers are otherwise meaningless against a multi-file
source tree. See [Translating Pester Code Coverage](../guides/source-maps.md#translating-pester-code-coverage)
for the full setup, including why pointing `CodeCoverage.Path` at the source tree fails silently.

Accepts either the build result directly (`-BuildResult`, sidecar path derived from its
`SourceMapPath`) or an explicit `-OutputPath` (sidecar path derived by appending
`.sourcemap.json`) — mirroring [`Resolve-PSScriptBuilderSourceLocation`](Resolve-PSScriptBuilderSourceLocation.md).

A SHA-256 hash comparison against the output file detects a stale source map and emits a warning.
Coverage entries referencing a file other than the build output, or falling outside any tracked
component, are skipped and reported as one consolidated warning each.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-BuildResult` | `PSScriptBuilderBuildResult` | The build result to translate coverage against. Accepts pipeline input. Requires a build run with `-WriteSourceMap`. |
| `-OutputPath` | string | Path to the output script to translate coverage against, as an alternative to `-BuildResult`. |
| `-CodeCoverage` | object | **Required.** The `CodeCoverage` property of a Pester result (e.g. `$pesterResult.CodeCoverage`), exposing `CommandsExecuted` and `CommandsMissed`. |

Exactly one of `-BuildResult` or `-OutputPath` is required.

## Examples

### Translate coverage from a Pester run against the build output

```powershell
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions' |
    Invoke-PSScriptBuilderBuild -TemplatePath 'build\Templates\HRTools.ps1.template' `
                                -OutputPath   'build\Output\HRTools.ps1' `
                                -WriteSourceMap

$config = [PesterConfiguration]::Default
$config.Run.Path             = 'tests'
$config.Run.PassThru         = $true
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path    = $result.OutputPath

$pesterResult = Invoke-Pester -Configuration $config

$result | Get-PSScriptBuilderSourceCoverage -CodeCoverage $pesterResult.CodeCoverage |
    Format-PSScriptBuilderSourceCoverage
```

```text title="Output"
SourceFile                                    Coverage  Hit/Total
--------------------------------------------  --------  ---------
src\Classes\Person.ps1                         100.0 %        2/2
src\Classes\Employee.ps1                       100.0 %        2/2
src\Functions\Get-EmployeeById.ps1              71.4 %        5/7
src\Functions\New-Employee.ps1                 100.0 %        1/1
src\Functions\Get-EmployeesByDepartment.ps1      0.0 %        0/4
```

## Output

Returns an array of [`PSScriptBuilderSourceCoverageResult`](../reference/types.md#psscriptbuildersourcecoverageresult),
one per distinct source file referenced by the resolved coverage entries.

## See Also

- [Source Maps Guide](../guides/source-maps.md#translating-pester-code-coverage)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md)
- [Cmdlet Reference: Format-PSScriptBuilderSourceCoverage](Format-PSScriptBuilderSourceCoverage.md)
- [Cmdlet Reference: Resolve-PSScriptBuilderSourceLocation](Resolve-PSScriptBuilderSourceLocation.md)

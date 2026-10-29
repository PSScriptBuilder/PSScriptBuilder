# Get-PSScriptBuilderDependencyAnalysis

Analyzes dependencies between components without performing a build.

## Description

Runs the same analysis pipeline a build performs internally — collecting components, building
the dependency graph, detecting cycles, and topologically sorting — but produces no output file.
Useful for validating a project's dependency structure, planning a refactor's impact, or checking
for problems before committing to a full build.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-ContentCollector` | `PSScriptBuilderContentCollector` | **Required.** The collector set to analyze. Accepts pipeline input, enabling fluent chaining from `Add-PSScriptBuilderCollector`. |

## Examples

### Run an analysis and check its summary properties

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath "src\Enums"     |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes"   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Functions"

$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $contentCollector

Write-Host "Total components: $($analysis.TotalComponents)"
Write-Host "Cross-dependencies: $($analysis.HasCrossDependencies)"
```

### Check for cycles before building

```powershell
$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $contentCollector

if ($analysis.HasCycles) {
    Write-Error "Circular dependency detected: $($analysis.CyclePath -join ' -> ')"
    return
}
```

## Output

Returns a
[`PSScriptBuilderDependencyAnalysisResult`](../reference/types.md#psscriptbuilderdependencyanalysisresult)
object. See the [Dependency Analysis Guide](../guides/dependency-analysis.md#walkthrough) for how
to read every property, and the
[Pre-Build Validation Pattern](../guides/dependency-analysis.md#8-pre-build-validation-pattern)
for combining this with a build.

## See Also

- [Dependency Analysis Guide](../guides/dependency-analysis.md)
- [Cmdlet Reference: Format-PSScriptBuilderDependencyAnalysis](Format-PSScriptBuilderDependencyAnalysis.md)
- [Cmdlet Reference: Get-PSScriptBuilderComponentDependency](Get-PSScriptBuilderComponentDependency.md)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md)

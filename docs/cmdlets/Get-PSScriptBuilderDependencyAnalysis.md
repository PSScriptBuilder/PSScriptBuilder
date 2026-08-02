---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Get-PSScriptBuilderDependencyAnalysis

## SYNOPSIS
Analyzes dependencies between components without performing a build.

## SYNTAX

```
Get-PSScriptBuilderDependencyAnalysis [-ContentCollector] <PSScriptBuilderContentCollector>
 [<CommonParameters>]
```

## DESCRIPTION
The Get-PSScriptBuilderDependencyAnalysis cmdlet performs comprehensive dependency analysis on the
components registered in a ContentCollector.
It delegates all analysis logic to PSScriptBuilderDependencyAnalyzer
and returns a strongly-typed PSScriptBuilderDependencyAnalysisResult object.

The analysis includes:

- Executing all collectors to gather components
- Building a dependency graph
- Detecting circular dependencies
- Performing topological sorting (if no cycles)
- Identifying cross-dependencies between component types
- Gathering component statistics

This cmdlet is useful for:

- Validating dependencies before building
- Understanding component relationships
- Detecting potential circular dependencies early
- Analyzing the dependency structure of your codebase
- Planning refactoring with impact analysis

## EXAMPLES

### EXAMPLE 1
```
$analysis = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src" |
    Get-PSScriptBuilderDependencyAnalysis
Write-Host "Total components: $($analysis.TotalComponents)"
Write-Host "Classes: $($analysis.ComponentCounts.ClassDefinitions)"
Write-Host "Cross-dependencies: $($analysis.HasCrossDependencies)"
```

Fluent pipeline analysis with component statistics.

### EXAMPLE 2
```
$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
# Impact analysis: Which components would be affected by changing "BaseClass"?
$dependents = $analysis.DependencyGraph.GetDependents("BaseClass")
Write-Warning "Changing BaseClass affects $($dependents.Count) components:"
$dependents | ForEach-Object { Write-Host "  - $_" }
```

Advanced analysis with impact assessment using the dependency graph.

## PARAMETERS

### -ContentCollector
The ContentCollector instance containing all registered component collectors.
Accepts pipeline
input to enable fluent chaining from Add-PSScriptBuilderCollector.

```yaml
Type: PSScriptBuilderContentCollector
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSScriptBuilderDependencyAnalysisResult
## NOTES
This cmdlet delegates all analysis to PSScriptBuilderDependencyAnalyzer, which executes all registered
collectors via ContentCollector.Execute().
For large codebases, this may take some time.

If an Inheritance or StaticInitializer cycle is detected, the OrderedComponents array will be empty and the build will fail.
Inheritance and StaticInitializer cycles must be resolved in the source code before building.
Type reference cycles (classes referencing each other in method bodies or property type annotations)
are resolved automatically and do not affect HasCycles.

Cross-dependencies occur when component types are intermixed in the sorted order (e.g., a class
depends on a function that depends on another class).
While not necessarily an error, this may
indicate architectural issues.

The result is a strongly-typed PSScriptBuilderDependencyAnalysisResult object that provides
IntelliSense support and can be used with future format cmdlets.

## RELATED LINKS

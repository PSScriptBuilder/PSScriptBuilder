---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Find-PSScriptBuilderUnusedComponent

## SYNOPSIS
Finds unused components in a PSScriptBuilder content collector configuration.

## SYNTAX

```
Find-PSScriptBuilderUnusedComponent [-ContentCollector] <PSScriptBuilderContentCollector>
 [[-EntryPoint] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
The Find-PSScriptBuilderUnusedComponent cmdlet analyzes the dependency graph of the
provided ContentCollector to identify Enum, Class, and Function components that are
not referenced by any other component.

Two analysis modes are available:

Without -EntryPoint: Reports all components that have no incoming dependency edges.
A component is considered unused when nothing else in the graph depends on it.
Because public cmdlets are called externally (not from within the graph), they will
always appear in results in this mode.

With -EntryPoint: Performs a transitive reachability analysis starting from all
components whose names match any of the specified glob patterns.
Components not
reachable (directly or transitively) from any matched entry point are returned
as unused.
Use this mode to identify dead code relative to a known set of
public API functions.

If dependency cycles are detected, a warning is emitted and components involved
in the cycle may not be reported as unused (they reference each other, giving
each an incoming edge).

## EXAMPLES

### EXAMPLE 1
```
$results = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath "src/Enums"   |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src/Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src/Public"  |
    Find-PSScriptBuilderUnusedComponent -EntryPoint "*-MyModule*"
```

Finds all components not reachable from public cmdlets matching the "*-MyModule*" pattern.

### EXAMPLE 2
```
$results = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src/Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src/Functions" |
    Find-PSScriptBuilderUnusedComponent
```

Finds all components with no incoming dependencies.
Useful for class-only projects
without public cmdlets.

## PARAMETERS

### -ContentCollector
The ContentCollector instance containing all registered component collectors.
Accepts
pipeline input to enable fluent chaining from Add-PSScriptBuilderCollector.

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

### -EntryPoint
One or more glob patterns identifying the entry point components.
When specified, only
components not reachable from the matched entry points are reported as unused.
Wildcards (* and ?) are supported.
Patterns are matched case-insensitively.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSScriptBuilderUnusedComponentEntry
## NOTES
Public cmdlets collected by FunctionCollectors will always appear as unused when
-EntryPoint is omitted, because they have no callers within the dependency graph.
Use -EntryPoint with a wildcard pattern matching your cmdlet names to exclude them.

Components involved in dependency cycles may not be reported as unused even if they
are not reachable from any entry point, because they reference each other.

## RELATED LINKS

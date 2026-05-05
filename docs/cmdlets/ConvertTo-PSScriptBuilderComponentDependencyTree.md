---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# ConvertTo-PSScriptBuilderComponentDependencyTree

## SYNOPSIS
Converts component dependency entries to a hierarchical tree string.

## SYNTAX

```
ConvertTo-PSScriptBuilderComponentDependencyTree [-InputObject] <PSScriptBuilderComponentDependencyEntry>
 [<CommonParameters>]
```

## DESCRIPTION
The ConvertTo-PSScriptBuilderComponentDependencyTree cmdlet converts an array of
PSScriptBuilderComponentDependencyEntry objects (as returned by
Get-PSScriptBuilderComponentDependency) to a hierarchical tree diagram using
Unicode box-drawing characters.

The result is returned as a string to the pipeline, making it suitable for display,
file output, or further processing.

## EXAMPLES

### EXAMPLE 1
```
$analysis = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath '.\src\Classes' |
    Get-PSScriptBuilderDependencyAnalysis
```

$analysis | Get-PSScriptBuilderComponentDependency -Name 'ClassA' |
    ConvertTo-PSScriptBuilderComponentDependencyTree

Returns the dependencies of ClassA as a hierarchical tree string.

### EXAMPLE 2
```
$analysis | Get-PSScriptBuilderComponentDependency -Name 'BaseClass' -Direction Dependents |
    ConvertTo-PSScriptBuilderComponentDependencyTree |
    Set-Content -Path '.\dependents.txt'
```

Converts dependents of BaseClass to a tree and writes it to a file.

### EXAMPLE 3
```
$tree = $analysis | Get-PSScriptBuilderComponentDependency -Name 'CheckoutOrchestrator' |
    ConvertTo-PSScriptBuilderComponentDependencyTree
```

$lines = '## Dependencies', '\`\`\`text', $tree, '\`\`\`'
Set-Content -Path '.\docs\dependencies.md' -Value ($lines -join \[System.Environment\]::NewLine)

Embeds the dependency tree in a Markdown documentation file.

## PARAMETERS

### -InputObject
One or more PSScriptBuilderComponentDependencyEntry objects to convert.
Accepts pipeline input.

```yaml
Type: PSScriptBuilderComponentDependencyEntry
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

### System.String
## NOTES
Rendering is delegated to PSScriptBuilderComponentDependencyRenderer.

## RELATED LINKS

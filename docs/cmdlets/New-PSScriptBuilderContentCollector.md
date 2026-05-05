---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# New-PSScriptBuilderContentCollector

## SYNOPSIS
Creates a new content collector for managing multiple component collectors.

## SYNTAX

```
New-PSScriptBuilderContentCollector [[-Collector] <PSScriptBuilderCollectorBase[]>]
 [<CommonParameters>]
```

## DESCRIPTION
The New-PSScriptBuilderContentCollector cmdlet creates a ContentCollector instance that manages
a collection of component collectors (Using, Enum, Class, Function, File collectors).

The ContentCollector orchestrates the execution of all registered collectors and provides
centralized access to collected components.
It can be created empty and populated later via
Add-PSScriptBuilderCollector, or initialized with pre-created collectors via the -Collector parameter.

Duplicate CollectionKeys are automatically detected and will throw an error during creation.

## EXAMPLES

### EXAMPLE 1
```
$cc = New-PSScriptBuilderContentCollector
$cc.AddCollector((New-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES"))
```

Creates empty ContentCollector and adds a collector using the direct method.

### EXAMPLE 2
```
$collectors = @(
    New-PSScriptBuilderCollector -Type Using -CollectionKey "USINGS" -IncludePath "src"
    New-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src/Classes"
    New-PSScriptBuilderCollector -Type Function -CollectionKey "FUNCTIONS" -IncludePath "src/Public"
)
$cc = New-PSScriptBuilderContentCollector -Collector $collectors
```

Creates ContentCollector pre-populated with three collectors.

### EXAMPLE 3
```
New-PSScriptBuilderContentCollector -Collector @(
    New-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN" -IncludePath "src/Domain"
    New-PSScriptBuilderCollector -Type Class -CollectionKey "UTILS" -IncludePath "src/Utils"
)
```

Creates ContentCollector with multiple collectors of the same type but different keys.

## PARAMETERS

### -Collector
An optional array of pre-created collector instances to initialize the ContentCollector with.
All collectors must have unique CollectionKeys.
Duplicates will cause an error.

Collectors can be created using New-PSScriptBuilderCollector.

```yaml
Type: PSScriptBuilderCollectorBase[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSScriptBuilderContentCollector
## NOTES
The ContentCollector uses PSScriptBuilderCollectorCollection internally, which automatically:

- Validates unique CollectionKeys (throws InvalidOperationException for duplicates)
- Sorts collectors by CollectorType (Using, Enum, Class, Function, File)
- Manages collector lifecycle

Configuration is loaded automatically from the static PSScriptBuilderConfiguration instance.

## RELATED LINKS

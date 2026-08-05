---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Add-PSScriptBuilderCollector

## SYNOPSIS
Adds a collector to a ContentCollector for fluent pipeline configuration.

## SYNTAX

```
Add-PSScriptBuilderCollector [-ContentCollector] <PSScriptBuilderContentCollector> [-Type] <String>
 [[-CollectionKey] <String>] [[-IncludePath] <String[]>] [[-IncludeFile] <String[]>]
 [[-ExcludePath] <String[]>] [[-ExcludeFile] <String[]>] [[-FileExtension] <String[]>] [-NoRecurse]
 [<CommonParameters>]
```

## DESCRIPTION
The Add-PSScriptBuilderCollector cmdlet creates and adds a component collector to a ContentCollector
instance in one operation.
Specify the collector type and configuration parameters to create the
collector on-the-fly.

The cmdlet returns the ContentCollector to enable fluent chaining via pipeline, allowing
multiple collectors to be added in a single pipeline expression.

For initialization with pre-created collectors, use the -Collector parameter on
New-PSScriptBuilderContentCollector instead.

Duplicate CollectionKeys will cause an error during addition.

## EXAMPLES

### EXAMPLE 1
```
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src/Classes" |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey "FUNCTIONS" -IncludePath "src/Public"
```

Creates ContentCollector and adds two collectors with custom keys using fluent chaining.

### EXAMPLE 2
```
$cc = New-PSScriptBuilderContentCollector
$cc | Add-PSScriptBuilderCollector -Type Using -IncludePath "src"
```

Creates ContentCollector and adds a collector with default key using pipeline.

### EXAMPLE 3
```
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN" `
        -IncludePath "src/Classes/Domain" -ExcludeFile "*.Internal.ps1" |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "UTILS" `
        -IncludePath "src/Classes/Utils"
```

Adds multiple collectors of the same type with different configurations and keys.

## PARAMETERS

### -ContentCollector
The ContentCollector instance to add the collector to.
Accepts pipeline input to enable
fluent chaining.

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

### -Type
The type of collector to create and add.
Valid values:

- Using: Collects using statements
- Enum: Collects enumeration definitions
- Class: Collects class definitions
- Function: Collects function definitions
- File: Collects entire file contents

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionKey
An optional unique identifier for the collector being created.
If not specified, the collector uses
its default key.
Must be unique within the ContentCollector.

Examples: "CLASSES_DOMAIN", "FUNCTIONS_PUBLIC", "ENUMS"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludePath
One or more directory paths to scan for components.
Paths are relative to the project root
or can be absolute.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeFile
One or more specific files to include.
Supports glob patterns.
Takes precedence over ExcludeFile.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludePath
One or more directory paths to exclude from processing.
Overrides IncludePath if a path matches both.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeFile
One or more file patterns to exclude.
Supports glob patterns.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FileExtension
One or more file extensions to include during scanning.
Defaults to @(".ps1").
Use this to scan additional file types, for example @(".ps1", ".psm1") or @(".txt").

Example: ".psm1", ".txt"

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoRecurse
When specified, only the top-level directory of each IncludePath is scanned.
By default, all subdirectories are scanned recursively.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSScriptBuilderContentCollector
## NOTES
The cmdlet uses New-PSScriptBuilderCollector internally, ensuring consistent collector
creation logic across the module.

Path validation warnings from New-PSScriptBuilderCollector will be visible during execution.

To initialize a ContentCollector with pre-created collectors, use the -Collector parameter
on New-PSScriptBuilderContentCollector instead.

Duplicate CollectionKeys are detected by PSScriptBuilderCollectorCollection and will throw
an InvalidOperationException.

## RELATED LINKS

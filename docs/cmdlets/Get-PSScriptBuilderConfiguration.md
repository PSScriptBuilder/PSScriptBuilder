---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Get-PSScriptBuilderConfiguration

## SYNOPSIS
Retrieves the global PSScriptBuilder configuration.

## SYNTAX

```
Get-PSScriptBuilderConfiguration [-Flat] [<CommonParameters>]
```

## DESCRIPTION
The Get-PSScriptBuilderConfiguration function loads the psscriptbuilder.config.json file 
and returns the configuration object.
This includes release and build configuration 
settings.

By default, returns hierarchical data with Release and Build sections.
With -Flat parameter, returns a single flat structure with all properties on one level.

## EXAMPLES

### EXAMPLE 1
```
$config = Get-PSScriptBuilderConfiguration
$config.Build.OutputPath
```

Access specific configuration values.

### EXAMPLE 2
```
Get-PSScriptBuilderConfiguration -Flat | Format-Table
```

Returns flat configuration and formats as table.

## PARAMETERS

### -Flat
If specified, returns configuration in a flat single-level structure with all properties 
prefixed by category (Release*, Build*).
Useful for tabular display or when flat 
structure is preferred.

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

### System.Collections.Specialized.OrderedDictionary or PSScriptBuilderConfiguration object
## NOTES
The configuration is loaded from psscriptbuilder.config.json in the project root.

## RELATED LINKS

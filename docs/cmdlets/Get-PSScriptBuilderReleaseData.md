---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Get-PSScriptBuilderReleaseData

## SYNOPSIS
Retrieves the current release data configuration.

## SYNTAX

```
Get-PSScriptBuilderReleaseData [-Flat] [<CommonParameters>]
```

## DESCRIPTION
The Get-PSScriptBuilderReleaseData cmdlet loads and displays the current release data,
including version information, build metadata, and git information.
This cmdlet is useful
for inspecting the current state of release management without making any changes.

By default, returns hierarchical data with Version, Build, and Git sections using PascalCase property names.
With -Flat parameter, returns a single flat structure with all properties on one level.

Both formats return OrderedDictionary objects that maintain categorical order for consistent presentation.
Both can be sorted using: GetEnumerator() | Sort-Object -Property Key

## EXAMPLES

### EXAMPLE 1
```
$releaseData = Get-PSScriptBuilderReleaseData
$releaseData.Version
Retrieves release data and accesses version information.
```

### EXAMPLE 2
```
Get-PSScriptBuilderReleaseData -Flat | Format-Table
Retrieves flat release data and formats as table.
```

### EXAMPLE 3
```
$releaseData = Get-PSScriptBuilderReleaseData -Flat
$releaseData.GetEnumerator() | Sort-Object -Property Key
Retrieves flat release data sorted alphabetically by key.
```

## PARAMETERS

### -Flat
If specified, returns release data in a flat single-level structure with all properties prefixed
by category (Version*, Build*, Git*).
Useful for tabular display or when flat structure is preferred.

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

### System.Collections.Specialized.OrderedDictionary
## NOTES
This cmdlet requires a valid PSScriptBuilder configuration with Release management enabled.
The release data file must be properly configured and accessible.

## RELATED LINKS

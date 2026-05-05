---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Get-PSScriptBuilderReleaseDataTokens

## SYNOPSIS
Retrieves available release data tokens for substitution in bump files.

## SYNTAX

```
Get-PSScriptBuilderReleaseDataTokens [<CommonParameters>]
```

## DESCRIPTION
The Get-PSScriptBuilderReleaseDataTokens cmdlet loads and displays all available tokens
that can be used for variable substitution in bump files.
These tokens are generated from
the current release data and include version information, build metadata, and git context.

The tokens are returned sorted alphabetically by category (Build, Git, Version) for easy reference.

## EXAMPLES

### EXAMPLE 1
```
$tokens = Get-PSScriptBuilderReleaseDataTokens
$tokens.GetEnumerator() | Format-Table -AutoSize
Retrieves tokens and formats them as a table.
```

### EXAMPLE 2
```
$tokens = Get-PSScriptBuilderReleaseDataTokens
$tokens['VERSION_FULL']
Retrieves a specific token value.
```

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Collections.Specialized.OrderedDictionary
## NOTES
This cmdlet requires a valid PSScriptBuilder configuration with Release management enabled.
The release data file must be properly configured and accessible.
Tokens are used in bump file patterns and configuration.

## RELATED LINKS

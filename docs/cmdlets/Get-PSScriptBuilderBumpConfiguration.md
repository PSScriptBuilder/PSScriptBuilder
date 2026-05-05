---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Get-PSScriptBuilderBumpConfiguration

## SYNOPSIS
Retrieves the bump configuration.

## SYNTAX

```
Get-PSScriptBuilderBumpConfiguration [<CommonParameters>]
```

## DESCRIPTION
The Get-PSScriptBuilderBumpConfiguration cmdlet loads and displays the current bump configuration,
showing which files are configured to receive version token updates.
This cmdlet is useful for inspecting and validating bump configuration without making any changes.

## EXAMPLES

### EXAMPLE 1
```
Get-PSScriptBuilderBumpConfiguration | ForEach-Object { $_.path }
Retrieves all bump file paths and displays them.
```

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### Array of PSCustomObject
## NOTES
This cmdlet requires a valid PSScriptBuilder configuration with Release management enabled.
The bump files configuration file must be properly configured and accessible.
To view available tokens, use Get-PSScriptBuilderReleaseDataTokens.

## RELATED LINKS

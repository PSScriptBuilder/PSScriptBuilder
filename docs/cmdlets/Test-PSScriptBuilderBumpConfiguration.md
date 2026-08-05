---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Test-PSScriptBuilderBumpConfiguration

## SYNOPSIS
Tests the bump configuration file for validity.

## SYNTAX

```
Test-PSScriptBuilderBumpConfiguration [<CommonParameters>]
```

## DESCRIPTION
The Test-PSScriptBuilderBumpConfiguration cmdlet validates the bump configuration file from disk
against the configured data structure.
Returns $true if the file is valid, $false otherwise.

Validation errors are reported via Write-Error.
This is useful when external tools have 
modified the bump configuration file and you want to verify its integrity before proceeding 
with bump file operations.

## EXAMPLES

### EXAMPLE 1
```
if (Test-PSScriptBuilderBumpConfiguration) {
    Write-Host "Bump configuration is valid, proceeding with update..."
    Update-PSScriptBuilderBumpFiles
} else {
    Write-Host "Bump configuration has errors, fix them first"
}
```

Validates bump configuration and conditionally updates bump files.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Boolean
## NOTES

- Requires configuration to be loaded (PSScriptBuilderConfiguration.GetCurrent())
- Requires bump configuration file to exist
- Validation errors are displayed via Write-Error

## RELATED LINKS

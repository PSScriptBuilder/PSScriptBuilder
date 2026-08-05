---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Test-PSScriptBuilderReleaseData

## SYNOPSIS
Tests the release data file for validity.

## SYNTAX

```
Test-PSScriptBuilderReleaseData [<CommonParameters>]
```

## DESCRIPTION
The Test-PSScriptBuilderReleaseData cmdlet validates the release data file from disk
against the configured data structure.
Returns $true if the file is valid, $false otherwise.

Validation errors are reported via Write-Error.
This is useful when external tools have 
modified the release data file and you want to verify its integrity before proceeding 
with release operations.

## EXAMPLES

### EXAMPLE 1
```
if (Test-PSScriptBuilderReleaseData) {
    Write-Host "Release data is valid, proceeding with update..."
    Update-PSScriptBuilderReleaseData -Patch
} else {
    Write-Host "Release data has errors, fix them first"
}
```

Validates release data and conditionally updates it.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Boolean
## NOTES

- Requires configuration to be loaded (PSScriptBuilderConfiguration.GetCurrent())
- Requires release data file to exist
- Validation errors are displayed via Write-Error

## RELATED LINKS

---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Set-PSScriptBuilderProjectRoot

## SYNOPSIS
Sets the PSScriptBuilder project root directory.

## SYNTAX

```
Set-PSScriptBuilderProjectRoot [-Path] <String> [<CommonParameters>]
```

## DESCRIPTION
The Set-PSScriptBuilderProjectRoot cmdlet explicitly sets the project root directory and caches it
in $Global:PSScriptBuilderProjectRoot for all subsequent PSScriptBuilder operations.

Calling this cmdlet is optional.
If it is not called, Get-PSScriptBuilderProjectRoot performs
auto-discovery by walking up the directory tree from the current working directory, searching for
a psscriptbuilder.config.json file.

This cmdlet is useful for:

- Explicitly overriding the auto-discovered project root
- CI/CD pipelines that need to work with a specific project path
- Testing and debugging scenarios where the working directory differs from the project root

## EXAMPLES

### EXAMPLE 1
```
Set-PSScriptBuilderProjectRoot -Path "C:\MyProject"
Sets the project root to C:\MyProject
```

### EXAMPLE 2
```
Set-PSScriptBuilderProjectRoot -Path (Get-Location).Path
Sets the project root to the current working directory
```

## PARAMETERS

### -Path
The path to set as the new project root.
Must be an existing directory.

```yaml
Type: String
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

## NOTES
The global variable $Global:PSScriptBuilderProjectRoot is updated.
This affects all subsequent PSScriptBuilder operations.

In most cases, this cmdlet is not needed.
PSScriptBuilder automatically discovers
the project root by searching for psscriptbuilder.config.json in the current directory
and its parents.
Only call this cmdlet to override that behavior.

## RELATED LINKS

---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# New-PSScriptBuilderConfiguration

## SYNOPSIS
Creates a new PSScriptBuilder configuration file with default values.

## SYNTAX

```
New-PSScriptBuilderConfiguration [[-Path] <String>] [-Force] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The New-PSScriptBuilderConfiguration cmdlet creates a new psscriptbuilder.config.json file
with default values in the specified or currently set project root directory.

If no -ProjectRoot is specified, the cmdlet uses the project root set via
Set-PSScriptBuilderProjectRoot.
If neither is set, the current working directory is used.

If the configuration file already exists, the cmdlet fails with an error.
Use -Force to
overwrite an existing file.

The cmdlet supports PowerShell's -WhatIf and -Confirm parameters for safe preview and
confirmation.

## EXAMPLES

### EXAMPLE 1
```
New-PSScriptBuilderConfiguration
```

Creates a new psscriptbuilder.config.json with default values in the current
working directory or the project root set via Set-PSScriptBuilderProjectRoot.

### EXAMPLE 2
```
New-PSScriptBuilderConfiguration -Path "C:\MyProject"
```

Creates a new configuration file in the specified directory.

### EXAMPLE 3
```
New-PSScriptBuilderConfiguration -Force
```

Creates or overwrites an existing configuration file in the current working
directory.
Useful for resetting the configuration to its default values.

## PARAMETERS

### -Path
The directory in which to create the configuration file.
If not specified, the currently
set project root or the current working directory is used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Overwrites the configuration file if it already exists.

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

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### None
## NOTES

## RELATED LINKS

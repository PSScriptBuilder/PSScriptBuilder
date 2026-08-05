---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Update-PSScriptBuilderBumpFiles

## SYNOPSIS
Updates configured project files with current version information.

## SYNTAX

```
Update-PSScriptBuilderBumpFiles [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Update-PSScriptBuilderBumpFiles cmdlet synchronizes project files with the current version 
information from the release data.
It applies version tokens to all configured files according to 
the bump files configuration, supporting preview mode (-WhatIf) and interactive confirmation (-Confirm).

The operation:
1.
Loads the bump files configuration from the configured file
2.
Validates the configuration structure
3.
Applies version tokens to all configured files
4.
Persists changes based on -WhatIf and -Confirm parameters

## EXAMPLES

### EXAMPLE 1
```
Update-PSScriptBuilderBumpFiles -WhatIf
Shows which files would be updated without making changes.
```

### EXAMPLE 2
```
Update-PSScriptBuilderBumpFiles -Confirm
Prompts for confirmation before updating files.
```

## PARAMETERS

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

### PSScriptBuilderBumpFilesResult
## NOTES
This cmdlet requires a valid PSScriptBuilder configuration with Release management enabled.
The bump files configuration must be properly defined in the project configuration.

## RELATED LINKS

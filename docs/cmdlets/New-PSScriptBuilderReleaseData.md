---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# New-PSScriptBuilderReleaseData

## SYNOPSIS
Creates a new release data file with default values.

## SYNTAX

```
New-PSScriptBuilderReleaseData [-Force] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
The New-PSScriptBuilderReleaseData cmdlet creates and initializes a new release data file with default values:

- Version: 0.1.0
- Build Number: 0
- All timestamps and git information are set to $null

If the release data file already exists, the cmdlet fails with an error.
Use -Force to overwrite an existing file.

The cmdlet supports PowerShell's -WhatIf and -Confirm parameters for safe preview and confirmation.

## EXAMPLES

### EXAMPLE 1
```
# Preview what would be created (with -WhatIf)
New-PSScriptBuilderReleaseData -WhatIf
```

### EXAMPLE 2
```
# Overwrite existing release data file
New-PSScriptBuilderReleaseData -Force
```

## PARAMETERS

### -Force
Overwrites the release data file if it already exists.
Use with caution as this will replace existing data.

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

### PSCustomObject
## NOTES
Requires PSScriptBuilder configuration to be loaded.
The release data file path is specified in the PSScriptBuilder configuration.

## RELATED LINKS

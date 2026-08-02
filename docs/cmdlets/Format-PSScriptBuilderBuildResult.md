---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Format-PSScriptBuilderBuildResult

## SYNOPSIS
Formats and displays the result of a build operation.

## SYNTAX

```
Format-PSScriptBuilderBuildResult [-BuildResult] <PSScriptBuilderBuildResult> [-Detailed]
 [<CommonParameters>]
```

## DESCRIPTION
The Format-PSScriptBuilderBuildResult cmdlet takes a PSScriptBuilderBuildResult object and displays
its information in a clear, structured format.
The output includes build summary, component counts,
and dependency information.

By default, displays a compact summary.
Use -Detailed for comprehensive information including
all processed files and component details.

## EXAMPLES

### EXAMPLE 1
```
$result = Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath "template.psm1" -OutputPath "output.psm1"
Format-PSScriptBuilderBuildResult -BuildResult $result
```

Displays a compact build summary with component counts and execution time.

### EXAMPLE 2
```
$result | Format-PSScriptBuilderBuildResult -Detailed
```

Pipes an existing build result and displays detailed information including all processed
source files and component dependencies.

## PARAMETERS

### -BuildResult
The PSScriptBuilderBuildResult object returned from Invoke-PSScriptBuilderBuild.

```yaml
Type: PSScriptBuilderBuildResult
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Detailed
When specified, displays additional information including:

- Complete list of all processed source files
- Full backup file path (if backup was created)
- Component details with dependencies

Without this switch, only the build summary, component counts, and total execution time are shown.

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

### None
## NOTES
This cmdlet displays build results using Write-Host.
It does not return any values.
File sizes are displayed in human-readable format (KB/MB).

## RELATED LINKS

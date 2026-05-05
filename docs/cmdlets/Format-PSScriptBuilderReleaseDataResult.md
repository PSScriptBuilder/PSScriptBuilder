---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Format-PSScriptBuilderReleaseDataResult

## SYNOPSIS
Formats and displays the result of a release data update operation.

## SYNTAX

```
Format-PSScriptBuilderReleaseDataResult [-ReleaseDataResult] <PSScriptBuilderReleaseDataResult>
 [<CommonParameters>]
```

## DESCRIPTION
The Format-PSScriptBuilderReleaseDataResult function takes a PSScriptBuilderReleaseDataResult 
object and displays its changes in a clear, structured format organized by category (Version, Build, Git). 
For each change, the property name, old value, and new value are displayed.

## EXAMPLES

### EXAMPLE 1
```
Update-PSScriptBuilderReleaseData -Major | Format-PSScriptBuilderReleaseDataResult
```

Pipes the result directly to the formatting function.

## PARAMETERS

### -ReleaseDataResult
The PSScriptBuilderReleaseDataResult object returned from Update-PSScriptBuilderReleaseData 
or other release data operation cmdlets.

```yaml
Type: PSScriptBuilderReleaseDataResult
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

### None
## NOTES
This function displays the results of release data operations in a structured, easy-to-read format.
If no changes were made, a message indicating this is displayed.

## RELATED LINKS

---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Format-PSScriptBuilderBumpResult

## SYNOPSIS
Formats and displays the result of a bump operation.

## SYNTAX

```
Format-PSScriptBuilderBumpResult [-BumpResult] <PSScriptBuilderBumpFilesResult>
 [<CommonParameters>]
```

## DESCRIPTION
The Format-PSScriptBuilderBumpResult function takes a PSScriptBuilderBumpFilesResult 
object and displays its BumpDetails in a clear, structured format.
For each modified file, 
all changes are displayed with their pattern, token, old value, and new value.

## EXAMPLES

### EXAMPLE 1
```
Update-PSScriptBuilderBumpFiles | Format-PSScriptBuilderBumpResult
```

Pipes the result directly to the formatting function.

## PARAMETERS

### -BumpResult
The PSScriptBuilderBumpFilesResult object returned from Update-PSScriptBuilderBumpFiles 
or other bump operation cmdlets.

```yaml
Type: PSScriptBuilderBumpFilesResult
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
This function displays the results of bump operations in a structured, easy-to-read format.
If no changes were made, a message indicating this is displayed.

## RELATED LINKS

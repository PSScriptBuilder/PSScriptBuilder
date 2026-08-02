---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Compress-PSScriptBuilderScript

## SYNOPSIS
Post-processes a built PowerShell script by removing comments, blank lines, or output statements.

## SYNTAX

```
Compress-PSScriptBuilderScript [-Path] <String> [-RemoveComments] [-RemoveBlankLines]
 [[-RemoveOutputStatements] <String[]>] [[-DestinationPath] <String>] [-Force]
 [<CommonParameters>]
```

## DESCRIPTION
The Compress-PSScriptBuilderScript cmdlet transforms a PowerShell script file by applying one
or more post-processing operations.
Each operation is independent and can be combined freely.

Supported operations:

- RemoveComments:          removes all comment tokens; #Requires statements are preserved
- RemoveBlankLines:        removes all blank lines
- RemoveOutputStatements:  removes isolated calls to specified output cmdlets

The cmdlet accepts pipeline input from Invoke-PSScriptBuilderBuild via the OutputPath property,
enabling direct chaining of build and post-processing in a single pipeline.

When -DestinationPath is specified, the result is written to that file.
Otherwise, the processed
script string is returned to the pipeline.

## EXAMPLES

### EXAMPLE 1
```
Compress-PSScriptBuilderScript -Path '.\build\Output\MyScript.ps1' -RemoveComments -RemoveBlankLines -DestinationPath '.\deploy\MyScript.ps1' -Force
```

Removes all comments and blank lines from the built script and writes the result to a
deploy folder, overwriting any existing file.

### EXAMPLE 2
```
Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath '.\template.ps1' -OutputPath '.\output\MyScript.ps1' |
    Compress-PSScriptBuilderScript -RemoveComments -RemoveBlankLines -DestinationPath '.\deploy\MyScript.ps1' -Force
```

Chains build and post-processing in a single pipeline.
The OutputPath from the build result
is passed automatically to the -Path parameter via its OutputPath alias.

### EXAMPLE 3
```
Compress-PSScriptBuilderScript -Path '.\output\MyScript.ps1' -RemoveOutputStatements 'Write-Verbose', 'Write-Debug' -DestinationPath '.\deploy\MyScript.ps1' -Force
```

Removes all isolated Write-Verbose and Write-Debug calls from the script before deployment.

### EXAMPLE 4
```
$compressed = Compress-PSScriptBuilderScript -Path '.\output\MyScript.ps1' -RemoveComments
```

Returns the processed script as a string without writing to a file.
Useful for inspecting the result or piping into further processing.

## PARAMETERS

### -Path
The path to the PowerShell script file to process.
Accepts pipeline input by property name
via the OutputPath property, enabling direct piping from Invoke-PSScriptBuilderBuild.

```yaml
Type: String
Parameter Sets: (All)
Aliases: OutputPath

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -RemoveComments
When specified, removes all comments from the script including single-line comments,
block comments, and region markers (#region / #endregion).
#Requires statements are preserved.

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

### -RemoveBlankLines
When specified, removes all blank lines from the script.

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

### -RemoveOutputStatements
When specified, removes isolated calls to the specified output cmdlets.
Valid values are:
Write-Verbose, Write-Debug, Write-Host, Write-Warning, Write-Information.

A call is considered isolated when it stands alone on its line and is not part of a pipeline
or a control flow expression (if, foreach, etc.).
Non-isolated calls are skipped silently
and reported via Write-Verbose.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DestinationPath
The file path to write the processed script to.
If omitted, the processed script string
is returned to the pipeline instead.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
When specified, overwrites an existing output file without prompting.
When omitted and the target file already exists, the cmdlet throws an IOException.

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

### System.String
## NOTES
Operations are applied in the following order regardless of parameter order:
1.
RemoveComments
2.
RemoveOutputStatements
3.
RemoveBlankLines

This order ensures that removing comments or output statements does not leave behind
unexpected blank lines that RemoveBlankLines then cleans up.

When -DestinationPath is specified and the file already exists, the cmdlet throws an
IOException unless -Force is present.

Non-isolated output statement calls are silently skipped.
Use -Verbose to see which
calls were skipped and why.

## RELATED LINKS

---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Export-PSScriptBuilderBuildResult

## SYNOPSIS
Exports a build result to a JSON file.

## SYNTAX

```
Export-PSScriptBuilderBuildResult [-BuildResult] <PSScriptBuilderBuildResult> [-Path] <String> [-Detailed]
 [-Force] [<CommonParameters>]
```

## DESCRIPTION
The Export-PSScriptBuilderBuildResult cmdlet serializes a PSScriptBuilderBuildResult to a
structured JSON file suitable for use as a CI artifact for debugging, auditing, and
tracking changes between builds.

The output always includes build summary data: output path, file size, syntax validation
status, execution time, total component count, and component counts by type.
A UTC
generation timestamp is added automatically.

Use -Detailed to include the full list of processed source files and per-component details
(type, name, source file, and dependencies) in the output.

Relative paths are resolved using the project root ($Global:PSScriptBuilderProjectRoot).
If the project root has not been set explicitly, it is auto-discovered from the current
working directory.
The output directory is created automatically if it does not exist.

## EXAMPLES

### EXAMPLE 1
```
$result | Export-PSScriptBuilderBuildResult -Path ".\build\reports\build.json"
```

Exports a compact build summary to a JSON file.

### EXAMPLE 2
```
$result | Export-PSScriptBuilderBuildResult -Path ".\build\reports\build.json" -Detailed -Force
```

Exports a detailed report including all processed files and component details.
Overwrites the file if it already exists.

### EXAMPLE 3
```
$result = Invoke-PSScriptBuilderBuild @buildParams
$result | Format-PSScriptBuilderBuildResult
$result | Export-PSScriptBuilderBuildResult -Path ".\build\reports\build.json" -Force
```

Builds the script, displays the result to the console, and exports the report as a CI artifact.

## PARAMETERS

### -BuildResult
The build result to export.
Accepts pipeline input.

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

### -Path
The file path to write the JSON report to.
Relative paths are resolved using the project
root.
The output directory is created automatically if it does not exist.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Detailed
When specified, includes the full list of processed source files and per-component details
(type, name, source file, dependencies) in the JSON output.

Without this switch, only the build summary and component counts are included.

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

### -Force
When specified, overwrites an existing file without error.
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

## RELATED LINKS

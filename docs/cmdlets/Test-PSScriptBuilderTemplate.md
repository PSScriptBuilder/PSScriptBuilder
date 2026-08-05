---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Test-PSScriptBuilderTemplate

## SYNOPSIS
Validates a PSScriptBuilder template file without performing a build.

## SYNTAX

```
Test-PSScriptBuilderTemplate [-ContentCollector] <PSScriptBuilderContentCollector> [-TemplatePath] <String>
 [[-OrderedComponentsKey] <String>] [<CommonParameters>]
```

## DESCRIPTION
The Test-PSScriptBuilderTemplate cmdlet validates template content against the current 
collector configuration.
It checks:

- Placeholder format (no whitespace in placeholders)
- Placeholder existence (all collectors have placeholders in template)
- Unknown placeholders (no placeholders that don't map to collectors)
- Duplicate placeholders (no duplicate placeholder keys)
- Placeholder ordering (Using first, then Enum before Class/Function)

In Ordered and Hybrid mode (when the ordered components placeholder is used):

- Only the ordered components placeholder allowed
- Individual collector placeholders forbidden (Enum, Class, Function)

In Free Mode (when no cross-dependencies and no ordered components placeholder in template):

- Individual collector placeholders allowed
- Ordered components placeholder optional (triggers Hybrid mode when present)

This cmdlet is useful for:

- Validating template changes before building
- CI/CD pipeline template checks
- Development workflow validation
- Template troubleshooting

## EXAMPLES

### EXAMPLE 1
```
$isValid = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
    Test-PSScriptBuilderTemplate -TemplatePath "template.psm1"
if ($isValid) {
    Write-Host "Template is valid" -ForegroundColor Green
}
```

Fluent pipeline validation with conditional output.

### EXAMPLE 2
```
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"
if (Test-PSScriptBuilderTemplate -ContentCollector $cc -TemplatePath "template.psm1" -Verbose) {
    Invoke-PSScriptBuilderBuild -ContentCollector $cc `
        -TemplatePath "template.psm1" `
        -OutputPath "build\output\MyModule.psm1"
} else {
    Write-Warning "Template validation failed. Build skipped."
}
```

Pre-flight validation before build.
Use -Verbose to see detailed validation steps.

### EXAMPLE 3
```
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Using -IncludePath "src" |
    Add-PSScriptBuilderCollector -Type Enum -IncludePath "src\Enums" |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"
Test-PSScriptBuilderTemplate -ContentCollector $cc `
    -TemplatePath "template.psm1" `
    -OrderedComponentsKey "ALL_COMPONENTS"
```

Validates template with custom placeholder key for ordered components.

## PARAMETERS

### -ContentCollector
The PSScriptBuilderContentCollector instance containing all configured collectors.
Can be passed via pipeline from New-PSScriptBuilderContentCollector or 
Add-PSScriptBuilderCollector.

```yaml
Type: PSScriptBuilderContentCollector
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -TemplatePath
Path to the template file to validate.
Supports both absolute paths and paths relative 
to the project root (as set via Set-PSScriptBuilderProjectRoot).

The path is resolved using FileSystemHelper.GetProjectRootedPath(), which means:

- Absolute paths are used as-is
- Relative paths are resolved from the project root

Example paths:

- "build\templates\module.template"
- "C:\Projects\MyModule\templates\script.template"

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

### -OrderedComponentsKey
The placeholder key used in the template for dependency-ordered components.
Default is "ORDERED_COMPONENTS" (resulting in {{ORDERED_COMPONENTS}} in template).

This is used in Ordered and Hybrid mode where all components must be merged in 
dependency order.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: ORDERED_COMPONENTS
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Boolean
## NOTES
The cmdlet performs dependency analysis to determine the validation mode:

- Ordered Mode: Class \<-\> Function dependencies detected automatically
- Hybrid Mode: Ordered components placeholder present, no cross-dependencies
- Free Mode: No cross-dependencies and no ordered components placeholder

Validation is comprehensive and catches common template issues early:

- Missing placeholders for configured collectors
- Extra placeholders that don't map to collectors
- Incorrect placeholder ordering (e.g., Class before Using)
- Mode violations (e.g., individual placeholders in Ordered/Hybrid mode)

Template validation failures return $false (not an error):

- Validation failures are expected outcomes and logged via Write-Verbose
- Use -Verbose to see detailed validation failure messages
- Only unexpected errors (file not found, parameter errors) are terminating errors

This is a lightweight validation-only operation.
No files are modified and no 
output is generated.
For detailed analysis results, use Get-PSScriptBuilderTemplateAnalysis.

All validation details are logged by the worker classes when -Verbose is specified:

- TemplateFileManager logs template loading
- ContentCollector logs collection execution
- DependencyAnalyzer logs dependency analysis
- TemplateValidator logs validation steps

## RELATED LINKS

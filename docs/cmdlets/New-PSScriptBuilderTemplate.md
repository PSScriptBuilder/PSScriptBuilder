---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# New-PSScriptBuilderTemplate

## SYNOPSIS
Generates a PSScriptBuilder template file from a content collector configuration.

## SYNTAX

```
New-PSScriptBuilderTemplate [-ContentCollector] <PSScriptBuilderContentCollector> [-OutputPath] <String>
 [[-OrderedComponentsKey] <String>] [-OrderedMode] [-Force] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The New-PSScriptBuilderTemplate cmdlet analyzes the registered collectors and their
dependencies to generate a ready-to-use template file with the correct placeholders.

The cmdlet automatically determines the appropriate template mode:

- Free:    No cross-dependencies detected.
Individual {{CollectionKey}} placeholders
           are generated for each registered collector.

- Ordered: Cross-dependencies detected between component types.
An {{ORDERED_COMPONENTS}}
           placeholder is generated, along with {{USING_STATEMENTS}} and {{FILE_CONTENTS}}
           if those collectors are registered.

- Hybrid:  No cross-dependencies detected, but -OrderedMode was specified.
           Same placeholders as Ordered mode.

Use -Force to overwrite an existing template file.

The cmdlet supports PowerShell's -WhatIf and -Confirm parameters for safe preview and
confirmation.

## EXAMPLES

### EXAMPLE 1
```
# Generate a template for a project with class and function collectors
$result = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
    New-PSScriptBuilderTemplate -OutputPath "build\Templates\MyModule.psm1.template"
Write-Host "Generated template: $($result.OutputPath)"
Write-Host "Mode: $($result.Mode)"
Write-Host "Placeholders: $($result.Placeholders -join ', ')"
```

Fluent pipeline generation with automatic mode detection.

### EXAMPLE 2
```
# Force ordered mode (useful when cross-dependencies are expected)
$result = New-PSScriptBuilderTemplate `
    -ContentCollector $contentCollector `
    -OutputPath "build\Templates\MyScript.ps1.template" `
    -OrderedMode
Write-Host "Mode: $($result.Mode)"  # Hybrid
```

Force ordered mode for a future-proof template structure.

### EXAMPLE 3
```
# Overwrite an existing template
New-PSScriptBuilderTemplate `
    -ContentCollector $contentCollector `
    -OutputPath "build\Templates\MyScript.ps1.template" `
    -Force
```

Overwrite an existing template file.

### EXAMPLE 4
```
# Preview what would be created (with -WhatIf)
New-PSScriptBuilderTemplate `
    -ContentCollector $contentCollector `
    -OutputPath "build\Templates\MyScript.ps1.template" `
    -WhatIf
```

Preview the template generation without writing any files.

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

### -OutputPath
Path to the template file to generate.
Supports both absolute paths and paths relative
to the project root (as set via Set-PSScriptBuilderProjectRoot).

The path is resolved using FileSystemHelper.GetProjectRootedPath(), which means:

- Absolute paths are used as-is
- Relative paths are resolved from the project root

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
The placeholder key used for dependency-ordered components.
Default is "ORDERED_COMPONENTS" (resulting in {{ORDERED_COMPONENTS}} in template).

Must match the OrderedComponentsKey used in Get-PSScriptBuilderTemplateAnalysis and
Invoke-PSScriptBuilderBuild to ensure consistent placeholder resolution.

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

### -OrderedMode
Forces Hybrid mode even when no cross-dependencies are detected.
The generated template
will use {{ORDERED_COMPONENTS}} instead of individual collector placeholders for
Enum, Class, and Function collectors.

Use this when you anticipate future cross-dependencies and want to start with an
Ordered-compatible template structure.

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
Overwrites the template file if it already exists.
Use with caution as this will
replace existing template content.

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

### PSScriptBuilderTemplateGenerationResult
## NOTES
The cmdlet delegates all generation logic to PSScriptBuilderTemplateGenerator, which:

- Runs PSScriptBuilderDependencyAnalyzer to detect cross-dependencies
- Determines mode (Free, Ordered, Hybrid)
- Builds placeholder tokens based on mode and collectors
- Writes the template file using UTF8 with BOM encoding

The generated template is a minimal starting point.
Add surrounding PowerShell code
(module header, footer, etc.) to the template as needed before using it in a build.

To validate an existing template, use Get-PSScriptBuilderTemplateAnalysis.
To run a build using the template, use Invoke-PSScriptBuilderBuild.

## RELATED LINKS

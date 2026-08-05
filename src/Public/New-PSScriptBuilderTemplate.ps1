#region Cmdlet New-PSScriptBuilderTemplate
function New-PSScriptBuilderTemplate {
    <#
    .SYNOPSIS
        Generates a PSScriptBuilder template file from a content collector configuration.
    .DESCRIPTION
        The New-PSScriptBuilderTemplate cmdlet analyzes the registered collectors and their
        dependencies to generate a ready-to-use template file with the correct placeholders.

        The cmdlet automatically determines the appropriate template mode:
        - Free:    No cross-dependencies detected. Individual {{CollectionKey}} placeholders
                   are generated for each registered collector.
        - Ordered: Cross-dependencies detected between component types. An {{ORDERED_COMPONENTS}}
                   placeholder is generated, along with {{USING_STATEMENTS}} and {{FILE_CONTENTS}}
                   if those collectors are registered.
        - Hybrid:  No cross-dependencies detected, but -OrderedMode was specified.
                   Same placeholders as Ordered mode.

        Use -Force to overwrite an existing template file.

        The cmdlet supports PowerShell's -WhatIf and -Confirm parameters for safe preview and
        confirmation.
    .PARAMETER ContentCollector
        The PSScriptBuilderContentCollector instance containing all configured collectors.
        Can be passed via pipeline from New-PSScriptBuilderContentCollector or
        Add-PSScriptBuilderCollector.
    .PARAMETER OutputPath
        Path to the template file to generate. Supports both absolute paths and paths relative
        to the project root (as set via Set-PSScriptBuilderProjectRoot).

        The path is resolved using FileSystemHelper.GetProjectRootedPath(), which means:
        - Absolute paths are used as-is
        - Relative paths are resolved from the project root
    .PARAMETER OrderedComponentsKey
        The placeholder key used for dependency-ordered components.
        Default is "ORDERED_COMPONENTS" (resulting in {{ORDERED_COMPONENTS}} in template).

        Must match the OrderedComponentsKey used in Get-PSScriptBuilderTemplateAnalysis and
        Invoke-PSScriptBuilderBuild to ensure consistent placeholder resolution.
    .PARAMETER OrderedMode
        Forces Hybrid mode even when no cross-dependencies are detected. The generated template
        will use {{ORDERED_COMPONENTS}} instead of individual collector placeholders for
        Enum, Class, and Function collectors.

        Use this when you anticipate future cross-dependencies and want to start with an
        Ordered-compatible template structure.
    .PARAMETER Force
        Overwrites the template file if it already exists. Use with caution as this will
        replace existing template content.
    .OUTPUTS
        PSScriptBuilderTemplateGenerationResult
    .EXAMPLE
        # Generate a template for a project with class and function collectors
        $result = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
            Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
            New-PSScriptBuilderTemplate -OutputPath "build\Templates\MyModule.psm1.template"
        Write-Host "Generated template: $($result.OutputPath)"
        Write-Host "Mode: $($result.Mode)"
        Write-Host "Placeholders: $($result.Placeholders -join ', ')"

        Fluent pipeline generation with automatic mode detection.
    .EXAMPLE
        # Force ordered mode (useful when cross-dependencies are expected)
        $result = New-PSScriptBuilderTemplate `
            -ContentCollector $contentCollector `
            -OutputPath "build\Templates\MyScript.ps1.template" `
            -OrderedMode
        Write-Host "Mode: $($result.Mode)"  # Hybrid

        Force ordered mode for a future-proof template structure.
    .EXAMPLE
        # Overwrite an existing template
        New-PSScriptBuilderTemplate `
            -ContentCollector $contentCollector `
            -OutputPath "build\Templates\MyScript.ps1.template" `
            -Force

        Overwrite an existing template file.
    .EXAMPLE
        # Preview what would be created (with -WhatIf)
        New-PSScriptBuilderTemplate `
            -ContentCollector $contentCollector `
            -OutputPath "build\Templates\MyScript.ps1.template" `
            -WhatIf

        Preview the template generation without writing any files.
    .NOTES
        The cmdlet delegates all generation logic to PSScriptBuilderTemplateGenerator, which:
        - Runs PSScriptBuilderDependencyAnalyzer to detect cross-dependencies
        - Determines mode (Free, Ordered, Hybrid)
        - Builds placeholder tokens based on mode and collectors
        - Writes the template file using UTF8 with BOM encoding

        The generated template is a minimal starting point. Add surrounding PowerShell code
        (module header, footer, etc.) to the template as needed before using it in a build.

        To validate an existing template, use Get-PSScriptBuilderTemplateAnalysis.
        To run a build using the template, use Invoke-PSScriptBuilderBuild.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSScriptBuilderTemplateGenerationResult])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderContentCollector] $ContentCollector,

        [Parameter(Mandatory)]
        [string] $OutputPath,

        [Parameter()]
        [string] $OrderedComponentsKey = "ORDERED_COMPONENTS",

        [Parameter()]
        [switch] $OrderedMode,

        [Parameter()]
        [switch] $Force
    )

    process {
        try {
            # Resolve output path relative to project root if needed
            $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($OutputPath)

            if ($PSCmdlet.ShouldProcess($resolvedPath, "Generate template")) {
                # Execute content collection
                $ContentCollector.Execute()

                $generator = [PSScriptBuilderTemplateGenerator]::new(
                    $ContentCollector,
                    $resolvedPath,
                    $OrderedComponentsKey,
                    $OrderedMode.IsPresent,
                    $Force.IsPresent
                )

                return $generator.Generate()
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet New-PSScriptBuilderTemplate

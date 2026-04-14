#region Cmdlet Get-PSScriptBuilderTemplateAnalysis
function Get-PSScriptBuilderTemplateAnalysis {
    <#
    .SYNOPSIS
        Analyzes a PSScriptBuilder template file and returns comprehensive analysis information.
    .DESCRIPTION
        The Get-PSScriptBuilderTemplateAnalysis cmdlet performs comprehensive template analysis including
        validation, placeholder analysis, and validation mode detection. Unlike Test-PSScriptBuilderTemplate which
        returns a simple boolean, this cmdlet returns a detailed result object focused on template-specific information.

        The analysis includes:
        - Template validation status and detailed error messages
        - Template information (path, size, validation mode)
        - Cross-dependency detection (determines validation mode)
        - Placeholder analysis (found, expected, missing, unknown placeholders)

        For detailed dependency analysis (topological order, component counts, dependency graph),
        use Get-PSScriptBuilderDependencyAnalysis separately.

        This cmdlet is useful for:
        - Detailed template debugging and troubleshooting
        - CI/CD pipeline reporting with focused template metrics
        - Template validation and placeholder analysis
        - Understanding template structure and requirements
    .PARAMETER ContentCollector
        The PSScriptBuilderContentCollector instance containing all configured collectors.
        Can be passed via pipeline from New-PSScriptBuilderContentCollector or 
        Add-PSScriptBuilderCollector.
    .PARAMETER TemplatePath
        Path to the template file to analyze. Supports both absolute paths and paths relative 
        to the project root (as set via Set-PSScriptBuilderProjectRoot).

        The path is resolved using FileSystemHelper.GetProjectRootedPath(), which means:
        - Absolute paths are used as-is
        - Relative paths are resolved from the project root

        Example paths:
        - "build\templates\module.template"
        - "C:\Projects\MyModule\templates\script.template"
    .PARAMETER OrderedComponentsKey
        The placeholder key used in the template for dependency-ordered components.
        Default is "ORDERED_COMPONENTS" (resulting in {{ORDERED_COMPONENTS}} in template).

        This is used in Ordered and Hybrid mode where all components must be merged in 
        dependency order.
    .OUTPUTS
        PSScriptBuilderTemplateAnalysisResult
    .EXAMPLE
        $result = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
            Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
            Get-PSScriptBuilderTemplateAnalysis -TemplatePath "template.psm1"
        if ($result.IsValid) {
            Write-Host "Template is valid - Mode: $($result.ValidationMode)" -ForegroundColor Green
            Write-Host "  Cross-dependencies: $($result.HasCrossDependencies)"
            Write-Host "  Placeholders found: $($result.PlaceholdersFound.Count)"
        }
        else {
            Write-Warning "Template validation failed:"
            $result.ValidationErrors | ForEach-Object { Write-Warning "  $_" }
        }

        Fluent pipeline analysis with conditional output based on validation status.
    .EXAMPLE
        $result = Get-PSScriptBuilderTemplateAnalysis -ContentCollector $cc -TemplatePath "template.psm1"
        # Analyze placeholder issues
        if ($result.MissingPlaceholders.Count -gt 0) {
            Write-Host "Missing placeholders: $($result.MissingPlaceholders -join ', ')"
        }
        if ($result.UnknownPlaceholders.Count -gt 0) {
            Write-Host "Unknown placeholders: $($result.UnknownPlaceholders -join ', ')"
        }
        # Check dependency status
        if ($result.HasCrossDependencies) {
            Write-Host "Cross-dependencies detected - using Ordered mode"
            Write-Host "  ValidationMode: $($result.ValidationMode)"
        }

        Detailed placeholder and cross-dependency analysis.
    .EXAMPLE
        $result = Get-PSScriptBuilderTemplateAnalysis -ContentCollector $cc -TemplatePath "template.psm1" -Verbose
        # Display validation details
        Write-Host "Template Analysis Results:"
        Write-Host "  IsValid: $($result.IsValid)"
        Write-Host "  ValidationMode: $($result.ValidationMode)"
        Write-Host "  HasCrossDependencies: $($result.HasCrossDependencies)"
        Write-Host "  Template Size: $($result.TemplateSize) characters"
        # For detailed dependency information, use separate cmdlet
        $depAnalysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
        Write-Host "Component Breakdown:"
        Write-Host "  Classes: $($depAnalysis.ComponentCounts.ClassDefinitions)"
        Write-Host "  Functions: $($depAnalysis.ComponentCounts.FunctionDefinitions)"
        Write-Host "  Total: $($depAnalysis.TotalComponents)"

        Template analysis with separate dependency analysis for complete information.
    .NOTES
        The cmdlet delegates all analysis to PSScriptBuilderTemplateAnalyzer, which orchestrates:
        - Template loading and validation
        - Content collection from all registered collectors
        - Cross-dependency detection (via PSScriptBuilderDependencyAnalyzer)
        - Placeholder extraction and analysis
        - Validation mode detection (Free, Hybrid, or Ordered)

        The result is focused on template-specific information. For detailed dependency analysis
        (topological order, component counts, dependency graph), use Get-PSScriptBuilderDependencyAnalysis.

        All worker classes log their operations when -Verbose is specified.

        For simple boolean validation (is template valid?), use Test-PSScriptBuilderTemplate instead.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderTemplateAnalysisResult])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderContentCollector] $ContentCollector,

        [Parameter(Mandatory)]
        [string] $TemplatePath,

        [Parameter()]
        [string] $OrderedComponentsKey = "ORDERED_COMPONENTS"
    )

    process {
        try {
            # Delegate to analyzer
            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new(
                $ContentCollector,
                $TemplatePath,
                $OrderedComponentsKey
            )

            $result = $analyzer.Analyze()

            return $result
        }
        catch {
            # Unexpected errors - rethrow as terminating
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderTemplateAnalysis

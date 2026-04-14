#region Cmdlet Test-PSScriptBuilderTemplate
function Test-PSScriptBuilderTemplate {
    <#
    .SYNOPSIS
        Validates a PSScriptBuilder template file without performing a build.
    .DESCRIPTION
        The Test-PSScriptBuilderTemplate cmdlet validates template content against the current 
        collector configuration. It checks:

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
    .PARAMETER ContentCollector
        The PSScriptBuilderContentCollector instance containing all configured collectors.
        Can be passed via pipeline from New-PSScriptBuilderContentCollector or 
        Add-PSScriptBuilderCollector.
    .PARAMETER TemplatePath
        Path to the template file to validate. Supports both absolute paths and paths relative 
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
        System.Boolean
    .EXAMPLE
        $isValid = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
            Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public" |
            Test-PSScriptBuilderTemplate -TemplatePath "template.psm1"
        if ($isValid) {
            Write-Host "Template is valid" -ForegroundColor Green
        }

        Fluent pipeline validation with conditional output.
    .EXAMPLE
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

        Pre-flight validation before build. Use -Verbose to see detailed validation steps.
    .EXAMPLE
        $cc = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Using -IncludePath "src" |
            Add-PSScriptBuilderCollector -Type Enum -IncludePath "src\Enums" |
            Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" |
            Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"
        Test-PSScriptBuilderTemplate -ContentCollector $cc `
            -TemplatePath "template.psm1" `
            -OrderedComponentsKey "ALL_COMPONENTS"

        Validates template with custom placeholder key for ordered components.
    .NOTES
        The cmdlet performs dependency analysis to determine the validation mode:
        - Ordered Mode: Class <-> Function dependencies detected automatically
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

        This is a lightweight validation-only operation. No files are modified and no 
        output is generated. For detailed analysis results, use Get-PSScriptBuilderTemplateAnalysis.

        All validation details are logged by the worker classes when -Verbose is specified:
        - TemplateFileManager logs template loading
        - ContentCollector logs collection execution
        - DependencyAnalyzer logs dependency analysis
        - TemplateValidator logs validation steps
    #>
    [CmdletBinding()]
    [OutputType([bool])]
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
            # Resolve template path (FileSystemHelper logs internally)
            $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($TemplatePath)

            # Load template (TemplateFileManager logs)
            $templateContent = [PSScriptBuilderTemplateFileManager]::LoadTemplate($resolvedPath)

            # Get collectors for validation
            $collectors = $ContentCollector.GetCollectors()

            # Analyze dependencies (DependencyAnalyzer logs and executes collection)
            $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($ContentCollector)
            $analysisResult = $analyzer.Analyze()

            # Validate template - TemplateValidator throws InvalidOperationException on validation failure
            try {
                $orderedPlaceholderToken = "{{{{{0}}}}}" -f $OrderedComponentsKey
                $useOrderedMode = $analysisResult.HasCrossDependencies -or ($templateContent -match [Regex]::Escape($orderedPlaceholderToken))

                [PSScriptBuilderTemplateValidator]::Validate(
                    $templateContent,
                    $OrderedComponentsKey,
                    $useOrderedMode,
                    $collectors
                )

                return $true
            }
            catch [System.InvalidOperationException] {
                # Template validation failed - this is an expected outcome, not an error
                Write-Verbose "Template validation failed: $($_.Exception.Message)"
                return $false
            }
        }
        catch [System.ArgumentException], [System.ArgumentNullException] {
            # Parameter validation errors - these are unexpected errors
            $message = "Parameter validation failed: {0}" -f $_.Exception.Message
            Write-Error -Message $message -Category InvalidArgument -ErrorAction Stop
        }
        catch [System.IO.FileNotFoundException] {
            # Template file not found - this is an unexpected error
            $message = "Template file not found: {0}" -f $TemplatePath
            Write-Error -Message $message -Category ObjectNotFound -ErrorAction Stop
        }
        catch {
            # Unexpected errors - rethrow as terminating
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Test-PSScriptBuilderTemplate

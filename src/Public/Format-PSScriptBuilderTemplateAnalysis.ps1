#region Cmdlet Format-PSScriptBuilderTemplateAnalysis
function Format-PSScriptBuilderTemplateAnalysis {
    <#
    .SYNOPSIS
        Formats and displays the result of a template analysis operation.
    .DESCRIPTION
        The Format-PSScriptBuilderTemplateAnalysis cmdlet takes a PSScriptBuilderTemplateAnalysisResult
        object and displays its information in a clear, structured format. The output includes a template
        summary, placeholder analysis, and conditional sections for validation errors, missing placeholders,
        and unknown placeholders.

        The Key line is only shown when the validation mode is Hybrid or Ordered.
        The Validation Errors, Missing Placeholders, and Unknown Placeholders sections are
        only shown when they contain entries.
    .PARAMETER AnalysisResult
        The PSScriptBuilderTemplateAnalysisResult object returned from Get-PSScriptBuilderTemplateAnalysis.
    .OUTPUTS
        None
    .EXAMPLE
        $analysis = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Enum     -IncludePath "src\Enums"  |
            Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes" |
            Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"  |
            Get-PSScriptBuilderTemplateAnalysis -TemplatePath "build\Templates\MyProject.ps1.template"
        $analysis | Format-PSScriptBuilderTemplateAnalysis

        Displays the template analysis summary including validation status and placeholder analysis.
    .NOTES
        This cmdlet displays results using Write-Host. It does not return any values.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderTemplateAnalysisResult] $AnalysisResult
    )

    process {
        $crossDeps = if ($AnalysisResult.HasCrossDependencies) { 'Detected' } else { 'None' }
        $status    = if ($AnalysisResult.IsValid) { 'Valid' } else { 'Invalid' }

        Write-Host ""
        Write-Host "Template Analysis"
        Write-Host "  Template   : $($AnalysisResult.TemplatePath)"
        Write-Host "  Size       : $($AnalysisResult.TemplateSize) characters"
        Write-Host "  Mode       : $($AnalysisResult.ValidationMode)"

        if ($AnalysisResult.ValidationMode -ne [PSScriptBuilderTemplateValidationMode]::Free) {
            Write-Host "  Key        : $($AnalysisResult.OrderedComponentsKey)"
        }

        Write-Host "  Cross-Deps : $crossDeps"
        Write-Host "  Status     : $status"

        if ((-not $AnalysisResult.IsValid) -and $AnalysisResult.ValidationErrors.Count -gt 0) {
            Write-Host ""
            Write-Host "Validation Errors"

            foreach ($validationError in $AnalysisResult.ValidationErrors) {
                Write-Host "  $validationError"
            }
        }

        $expected = if ($AnalysisResult.PlaceholdersExpected.Count -gt 0) { $AnalysisResult.PlaceholdersExpected -join ', ' } else { '<none>' }
        $found    = if ($AnalysisResult.PlaceholdersFound.Count -gt 0) { $AnalysisResult.PlaceholdersFound -join ', ' } else { '<none>' }

        Write-Host ""
        Write-Host "Placeholders"
        Write-Host "  Expected : $expected"
        Write-Host "  Found    : $found"

        if ($AnalysisResult.MissingPlaceholders.Count -gt 0) {
            Write-Host ""
            Write-Host "Missing Placeholders"

            foreach ($placeholder in $AnalysisResult.MissingPlaceholders) {
                Write-Host "  $placeholder"
            }
        }

        if ($AnalysisResult.UnknownPlaceholders.Count -gt 0) {
            Write-Host ""
            Write-Host "Unknown Placeholders"

            foreach ($placeholder in $AnalysisResult.UnknownPlaceholders) {
                Write-Host "  $placeholder"
            }
        }

        Write-Host ""
    }
}
#endregion Cmdlet Format-PSScriptBuilderTemplateAnalysis

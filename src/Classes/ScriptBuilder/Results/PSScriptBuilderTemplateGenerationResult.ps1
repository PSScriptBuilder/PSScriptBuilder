using namespace System

#region Class PSScriptBuilderTemplateGenerationResult
<#
.SYNOPSIS
    Represents the result of a template generation operation.
.DESCRIPTION
    The PSScriptBuilderTemplateGenerationResult class encapsulates all information produced
    by the New-PSScriptBuilderTemplate cmdlet, including the output path, validation mode,
    generated placeholders, and whether ordered mode was forced by the caller.
#>
class PSScriptBuilderTemplateGenerationResult {
    #region Properties
    <#
    .SYNOPSIS
        The absolute path to the generated template file.
    .DESCRIPTION
        The OutputPath property holds the absolute path to the template file that was created
        by the generation operation.
    #>
    [string] $OutputPath

    <#
    .SYNOPSIS
        The validation mode of the generated template.
    .DESCRIPTION
        The Mode property indicates which template validation mode was applied during generation:
        - Free:    Individual collector placeholders; no cross-dependencies detected.
        - Ordered: Cross-dependencies detected; {{ORDERED_COMPONENTS}} placeholder used.
        - Hybrid:  No cross-dependencies, but ordered mode was forced via -OrderedMode.
    #>
    [PSScriptBuilderTemplateValidationMode] $Mode

    <#
    .SYNOPSIS
        The list of placeholders inserted into the generated template.
    .DESCRIPTION
        The Placeholders property contains all placeholder tokens written into the template file,
        in the order they appear (e.g. {{USING_STATEMENTS}}, {{ORDERED_COMPONENTS}}, {{FILE_CONTENTS}}).
    #>
    [string[]] $Placeholders

    <#
    .SYNOPSIS
        Indicates whether ordered mode was forced by the caller.
    .DESCRIPTION
        The OrderedMode property is true when the -OrderedMode switch was specified,
        causing Hybrid mode even if no cross-dependencies were detected.
        Is false when ordered mode was triggered automatically by cross-dependency detection.
    #>
    [bool] $OrderedMode
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderTemplateGenerationResult.
    .DESCRIPTION
        Creates a new result object representing a completed template generation operation.
    .PARAMETER outputPath
        The absolute path to the generated template file.
    .PARAMETER mode
        The validation mode of the generated template (Free, Ordered, or Hybrid).
    .PARAMETER placeholders
        The placeholder tokens written into the template file.
    .PARAMETER orderedMode
        True if ordered mode was forced by the caller via -OrderedMode.
    #>
    PSScriptBuilderTemplateGenerationResult(
        [string]                                $outputPath,
        [PSScriptBuilderTemplateValidationMode] $mode,
        [string[]]                              $placeholders,
        [bool]                                  $orderedMode
    ) {
        $this.OutputPath   = $outputPath
        $this.Mode         = $mode
        $this.Placeholders = $placeholders
        $this.OrderedMode  = $orderedMode
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderTemplateGenerationResult

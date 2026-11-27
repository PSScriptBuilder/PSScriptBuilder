using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderTemplateAnalysisResult
<#
.SYNOPSIS
    Represents the result of a template analysis operation.
.DESCRIPTION
    The PSScriptBuilderTemplateAnalysisResult class encapsulates comprehensive information about
    a template validation and analysis operation, focusing on template-specific validation and
    placeholder analysis.

    This class provides a strongly-typed result object for template analysis operations,
    enabling pipeline compatibility and format cmdlet support (Format-PSScriptBuilderTemplateAnalysisResult).

    The result includes:
    - Validation status and errors
    - Template information (path, size, validation mode)
    - Cross-dependency detection (determines validation mode)
    - Placeholder analysis (found, expected, missing, unknown)

    For detailed dependency analysis (topological order, component counts, dependency graph),
    use Get-PSScriptBuilderDependencyAnalysis instead.
#>
class PSScriptBuilderTemplateAnalysisResult {
    #region Properties
    <#
    .SYNOPSIS
        Indicates if the template is valid.
    .DESCRIPTION
        The IsValid property is true if the template passed all validation checks, false otherwise.
        If false, check the ValidationErrors property for detailed information.
    #>
    [bool] $IsValid

    <#
    .SYNOPSIS
        Validation error messages.
    .DESCRIPTION
        The ValidationErrors property contains an array of validation error messages.
        Empty if the template is valid.
    #>
    [string[]] $ValidationErrors

    <#
    .SYNOPSIS
        Path to the validated template file.
    .DESCRIPTION
        The TemplatePath property contains the resolved absolute path to the template file
        that was analyzed.
    #>
    [string] $TemplatePath

    <#
    .SYNOPSIS
        Template file size in characters.
    .DESCRIPTION
        The TemplateSize property contains the number of characters in the template content.
    #>
    [int] $TemplateSize

    <#
    .SYNOPSIS
        Template validation mode.
    .DESCRIPTION
        The ValidationMode property indicates which validation mode was used:
        - Free: No cross-dependencies and no {{ORDERED_COMPONENTS}} in template. Individual collector
          placeholders required.
        - Hybrid: No cross-dependencies (HasCrossDependencies = false), but {{ORDERED_COMPONENTS}} is
          explicitly present in the template. Validates and renders identically to Ordered mode.
        - Ordered: Cross-dependencies detected (HasCrossDependencies = true). {{ORDERED_COMPONENTS}}
          placeholder required; individual Enum/Class/Function placeholders forbidden.
    #>
    [PSScriptBuilderTemplateValidationMode] $ValidationMode

    <#
    .SYNOPSIS
        The placeholder key for ordered components.
    .DESCRIPTION
        The OrderedComponentsKey property contains the placeholder key used for dependency-ordered
        components (e.g., "ORDERED_COMPONENTS" results in {{ORDERED_COMPONENTS}} in template).
    #>
    [string] $OrderedComponentsKey

    <#
    .SYNOPSIS
        Indicates if cross-dependencies between component types exist.
    .DESCRIPTION
        The HasCrossDependencies property is true if Class <-> Function dependencies exist,
        requiring all components to be merged in dependency order.
    #>
    [bool] $HasCrossDependencies

    <#
    .SYNOPSIS
        Placeholders found in the template.
    .DESCRIPTION
        The PlaceholdersFound property contains an array of all placeholder keys found in the template
        (e.g., "USING", "CLASS", "FUNCTION", "ORDERED_COMPONENTS").
    #>
    [string[]] $PlaceholdersFound

    <#
    .SYNOPSIS
        Placeholders expected based on collectors.
    .DESCRIPTION
        The PlaceholdersExpected property contains an array of placeholder keys expected based on
        the configured collectors and validation mode.
    #>
    [string[]] $PlaceholdersExpected

    <#
    .SYNOPSIS
        Placeholders missing in the template.
    .DESCRIPTION
        The MissingPlaceholders property contains an array of placeholder keys that were expected
        but not found in the template.
    #>
    [string[]] $MissingPlaceholders

    <#
    .SYNOPSIS
        Unknown placeholders found in the template.
    .DESCRIPTION
        The UnknownPlaceholders property contains an array of placeholder keys found in the template
        but not recognized or expected.
    #>
    [string[]] $UnknownPlaceholders
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new template analysis result.
    .DESCRIPTION
        Creates a new PSScriptBuilderTemplateAnalysisResult with the specified analysis information.
        This result focuses on template-specific validation and placeholder analysis.
    .PARAMETER isValid
        Whether the template passed validation.
    .PARAMETER validationErrors
        Array of validation error messages (empty if valid).
    .PARAMETER templatePath
        Resolved absolute path to the template file.
    .PARAMETER templateSize
        Template file size in characters.
    .PARAMETER validationMode
        The validation mode used (Free, Hybrid, or Ordered).
    .PARAMETER orderedComponentsKey
        The placeholder key for ordered components.
    .PARAMETER hasCrossDependencies
        Whether cross-dependencies exist between component types.
    .PARAMETER placeholdersFound
        Placeholders found in the template.
    .PARAMETER placeholdersExpected
        Placeholders expected based on collectors and mode.
    .PARAMETER missingPlaceholders
        Placeholders expected but not found in template.
    .PARAMETER unknownPlaceholders
        Placeholders found but not recognized.
    #>
    PSScriptBuilderTemplateAnalysisResult(
        [bool]                                  $isValid,
        [string[]]                              $validationErrors,
        [string]                                $templatePath,
        [int]                                   $templateSize,
        [PSScriptBuilderTemplateValidationMode] $validationMode,
        [string]                                $orderedComponentsKey,
        [bool]                                  $hasCrossDependencies,
        [string[]]                              $placeholdersFound,
        [string[]]                              $placeholdersExpected,
        [string[]]                              $missingPlaceholders,
        [string[]]                              $unknownPlaceholders
    ) {
        $this.IsValid              = $isValid
        $this.ValidationErrors     = $validationErrors
        $this.TemplatePath         = $templatePath
        $this.TemplateSize         = $templateSize
        $this.ValidationMode       = $validationMode
        $this.OrderedComponentsKey = $orderedComponentsKey
        $this.HasCrossDependencies = $hasCrossDependencies
        $this.PlaceholdersFound    = $placeholdersFound
        $this.PlaceholdersExpected = $placeholdersExpected
        $this.MissingPlaceholders  = $missingPlaceholders
        $this.UnknownPlaceholders  = $unknownPlaceholders
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderTemplateAnalysisResult

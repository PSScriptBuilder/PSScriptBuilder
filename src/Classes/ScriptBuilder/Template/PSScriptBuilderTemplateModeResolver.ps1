using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderTemplateModeResolver
<#
.SYNOPSIS
    Static utility class for template placeholder extraction and rendering-mode detection.
.DESCRIPTION
    The PSScriptBuilderTemplateModeResolver class extracts {{PLACEHOLDER}} tokens from template
    content and determines whether Free Mode or Ordered/Hybrid Mode applies. Centralizing this
    logic in one place means any future change to how a placeholder is recognized only needs to
    change here.
#>
class PSScriptBuilderTemplateModeResolver {
    #region Methods
    <#
    .SYNOPSIS
        Extracts all unique {{PLACEHOLDER}} tokens from template content.
    .DESCRIPTION
        The ExtractPlaceholders method scans the given template content for every occurrence of
        the {{...}} placeholder syntax and returns the unique set found, sorted alphabetically.
    .PARAMETER templateContent
        The raw template content to scan.
    .OUTPUTS
        A sorted array of unique {{PLACEHOLDER}} token strings (including the braces).
    #>
    static [string[]] ExtractPlaceholders([string] $templateContent) {
        $placeholderPattern = '\{\{([^}]+)\}\}'
        $regexMatches       = [regex]::Matches($templateContent, $placeholderPattern)
        $placeholderValues  = @($regexMatches | ForEach-Object { $_.Value })

        $result = $placeholderValues | Sort-Object -Unique
        return $result
    }

    <#
    .SYNOPSIS
        Determines whether template content contains the ordered-components placeholder.
    .DESCRIPTION
        The HasOrderedPlaceholder method checks whether the template's extracted placeholders
        include the ordered-components token built from the given key (e.g. {{ORDERED_COMPONENTS}}).
    .PARAMETER templateContent
        The raw template content to check.
    .PARAMETER orderedComponentsKey
        The active ordered-components key for this build/validation call (e.g. "ORDERED_COMPONENTS").
    .OUTPUTS
        $true if the ordered-components placeholder is present, otherwise $false.
    #>
    static [bool] HasOrderedPlaceholder([string] $templateContent, [string] $orderedComponentsKey) {
        $orderedPlaceholderToken = "{{{{{0}}}}}" -f $orderedComponentsKey
        $placeholders            = [PSScriptBuilderTemplateModeResolver]::ExtractPlaceholders($templateContent)

        $result = $placeholders -contains $orderedPlaceholderToken
        return $result
    }

    <#
    .SYNOPSIS
        Determines whether Ordered/Hybrid Mode is required for a build/validation call.
    .DESCRIPTION
        The IsOrderedModeRequired method combines real cross-collector dependencies with the
        presence of the ordered-components placeholder: either one alone is sufficient to require
        Ordered/Hybrid Mode.
    .PARAMETER hasCrossDependencies
        Whether the dependency analysis found real cross-collector dependencies.
    .PARAMETER templateContent
        The raw template content to check for the ordered-components placeholder.
    .PARAMETER orderedComponentsKey
        The active ordered-components key for this build/validation call.
    .OUTPUTS
        $true if Ordered/Hybrid Mode is required, otherwise $false (Free Mode).
    #>
    static [bool] IsOrderedModeRequired([bool] $hasCrossDependencies, [string] $templateContent, [string] $orderedComponentsKey) {
        $hasOrderedPlaceholder = [PSScriptBuilderTemplateModeResolver]::HasOrderedPlaceholder($templateContent, $orderedComponentsKey)

        $result = $hasCrossDependencies -or $hasOrderedPlaceholder
        return $result
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderTemplateModeResolver

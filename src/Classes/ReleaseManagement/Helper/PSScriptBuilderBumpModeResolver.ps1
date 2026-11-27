using namespace System

#region Class PSScriptBuilderBumpModeResolver
<#
.SYNOPSIS
    Static utility class for Release Management bump-mode detection.
.DESCRIPTION
    The PSScriptBuilderBumpModeResolver class determines which of Release Management's bump
    replacement mechanisms applies to a given pattern string or bump file config entry.
    Centralizing this logic in one place means any future change to how a bump mode is recognized
    only needs to change here, and consumers do not need to know about each other.
#>
class PSScriptBuilderBumpModeResolver {
    #region Methods
    <#
    .SYNOPSIS
        Determines whether a bump config item's pattern is Placeholder- or Regex-shaped.
    .DESCRIPTION
        The DetermineBumpPatternMode method inspects a pattern string for well-formed {{TOKEN}}
        placeholders (a complete {{...}} pair) and well-formed capture groups (a complete,
        non-escaped (...) pair) to decide which of PSScriptBuilderBumpReplacementHelper's two
        items-mode replacement mechanisms applies. A dangling, unclosed {{ or ( - never a valid
        placeholder or capture group on its own - does not count as either signal.
    .PARAMETER pattern
        The pattern string to inspect (an item's 'pattern' property).
    .OUTPUTS
        Placeholder if the pattern contains one or more well-formed {{TOKEN}} placeholders and no
        capture group; Regex if it contains one or more well-formed capture groups. Throws if the
        pattern contains both, or neither.
    #>
    static [PSScriptBuilderBumpPatternMode] DetermineBumpPatternMode([string] $pattern) {
        $hasPlaceholders = $pattern -match '\{\{[^}]+\}\}'
        $hasCaptures     = $pattern -match '(?<!\\)\([^)]*\)'  # Only non-escaped, closed capture groups

        if ($hasPlaceholders -and $hasCaptures) {
            $message = "Pattern cannot mix {{TOKEN}} placeholder syntax with regex capture group syntax: $pattern. " +
                       "If a parenthesis here is meant to be literal text rather than a capture group, escape it with \( and \)."
            throw [ArgumentException]::new($message)
        }

        if ($hasPlaceholders) {
            return [PSScriptBuilderBumpPatternMode]::Placeholder
        }

        if ($hasCaptures) {
            return [PSScriptBuilderBumpPatternMode]::Regex
        }

        $message = "Pattern must contain either {{TOKEN}} placeholders or capture groups: $pattern"
        throw [ArgumentException]::new($message)
    }

    <#
    .SYNOPSIS
        Determines whether a bump file config entry uses Simple Mode.
    .DESCRIPTION
        The IsSimpleMode method checks whether the given file config entry has a non-empty
        'tokens' property, PSScriptBuilder's direct {{TOKEN}} replacement mode.
    .PARAMETER fileConfig
        The bumpFiles entry to inspect.
    .OUTPUTS
        $true if 'tokens' is present and non-empty, otherwise $false.
    #>
    static [bool] IsSimpleMode([PSCustomObject] $fileConfig) {
        $result = $null -ne $fileConfig.tokens -and @($fileConfig.tokens).Count -gt 0
        return $result
    }

    <#
    .SYNOPSIS
        Determines whether a bump file config entry uses Items Mode.
    .DESCRIPTION
        The IsItemsMode method checks whether the given file config entry has a non-empty 'items'
        property, PSScriptBuilder's pattern-based (Placeholder or Regex) replacement mode.
    .PARAMETER fileConfig
        The bumpFiles entry to inspect.
    .OUTPUTS
        $true if 'items' is present and non-empty, otherwise $false.
    #>
    static [bool] IsItemsMode([PSCustomObject] $fileConfig) {
        $result = $null -ne $fileConfig.items -and @($fileConfig.items).Count -gt 0
        return $result
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderBumpModeResolver

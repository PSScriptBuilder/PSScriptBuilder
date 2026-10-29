#region Enum PSScriptBuilderBumpPatternMode
<#
.SYNOPSIS
    Defines the pattern shapes Release Management's items-mode replacement recognizes.
.DESCRIPTION
    The PSScriptBuilderBumpPatternMode enum represents the two ways a bump config item's 'pattern'
    property can be shaped, determined from the pattern text itself:

    - Placeholder: the pattern contains {{TOKEN}} placeholders and no capture groups. The pattern's
      own placeholders are resolved, then the whole resolved pattern is located and replaced within
      file content.

    - Regex: the pattern contains one or more non-escaped capture groups (typically built from
      {REGEX_TOKEN} placeholders). The pattern is matched against file content via regex, and only
      the matched capture group values are replaced, preserving surrounding formatting.
#>
enum PSScriptBuilderBumpPatternMode {
    <#
    .SYNOPSIS
        Placeholder mode - {{TOKEN}} placeholders within a custom pattern.
    .DESCRIPTION
        Placeholder mode resolves {{TOKEN}} placeholders within a custom pattern string, then
        replaces the pattern's occurrence in the file content with the resolved value.
    #>
    Placeholder = 0

    <#
    .SYNOPSIS
        Regex mode - capture groups (typically from {REGEX_TOKEN}) within a custom pattern.
    .DESCRIPTION
        Regex mode resolves {REGEX_TOKEN} placeholders to their configured regex patterns, matches
        the result against file content, and replaces only the matched capture group values.
    #>
    Regex = 1
}
#endregion Enum PSScriptBuilderBumpPatternMode

using namespace System
using namespace System.Collections.Generic
using namespace System.Text.RegularExpressions

#region Class PSScriptBuilderTemplateEscapeHelper
<#
.SYNOPSIS
    Static utility class for escaping literal {{KEY}}-shaped text in template content.
.DESCRIPTION
    The PSScriptBuilderTemplateEscapeHelper class implements the `{{{{KEY}}}}` (quadruple-brace)
    escape syntax: a template author writes four braces on each side to have the text render as
    literal, two-brace `{{KEY}}` text in the output, instead of being treated as a real,
    functioning placeholder.

    Mask() replaces every valid escape sequence with a unique, invisible sentinel before any
    placeholder-matching consumer (mode detection, validation, rendering) sees the content;
    Unmask() reverses that after all such processing has finished, producing the literal,
    un-escaped two-brace text in its place. Applied once, by the caller, immediately after loading
    raw template content, not patched into every individual placeholder-matching method.
#>
class PSScriptBuilderTemplateEscapeHelper {
    #region Methods
    <#
    .SYNOPSIS
        Masks every valid four-brace escape sequence in template content.
    .DESCRIPTION
        The Mask() method replaces every match of the boundary-aware escape pattern
        `(?<!\{)\{\{\{\{([^{}]+)\}\}\}\}(?!\})` with a unique sentinel built from a NUL character
        (``0``) as the delimiter, e.g. ``0ESC_3`0``. NUL bytes practically never appear in real
        PowerShell source, and the sentinel doesn't look like `{{...}}` at all, so it's invisible
        to every existing `{{...}}`-matching check or replacement without touching any of them
        individually.

        The pattern matches only exactly four braces on each side: a negative lookbehind/lookahead
        (no extra `{` immediately before, no extra `}` immediately after) combined with a
        character class that excludes both brace kinds from the captured key (`[^{}]+`, not just
        `[^}]+`) ensures five or more consecutive braces on either side are rejected outright
        rather than partially, malformedly matched. An empty escape (`{{{{}}}}`) also does not
        match, since the key requires at least one character, and falls through to normal
        two-brace handling.
    .PARAMETER content
        The raw template content to mask.
    .OUTPUTS
        A PSCustomObject with two properties:
        - MaskedContent [string]    - the content with every valid escape sequence replaced by its sentinel
        - EscapeMap     [hashtable] - maps each sentinel to the original, already-un-escaped two-brace text
    .EXAMPLE
        $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($templateContent)
        $result.MaskedContent
        $result.EscapeMap
    #>
    static [PSCustomObject] Mask([string] $content) {
        $pattern     = '(?<!\{)\{\{\{\{([^{}]+)\}\}\}\}(?!\})'
        $escapeMap   = [Hashtable]::new()
        $matchNumber = [ref] 0

        $matchEvaluator = {
            param($match)

            $matchNumber.Value = $matchNumber.Value + 1
            $sentinel          = "`0ESC_$($matchNumber.Value)`0"
            $originalText      = "{{" + $match.Groups[1].Value + "}}"

            $escapeMap[$sentinel] = $originalText

            return $sentinel
        }

        $maskedContent = [Regex]::Replace($content, $pattern, $matchEvaluator)

        if ($escapeMap.Count -gt 0) {
            Write-Verbose "  Masked $($escapeMap.Count) escaped placeholder sequence(s)"
            foreach ($originalText in $escapeMap.Values) {
                Write-Verbose "    Escaped: $originalText"
            }
        }

        $result = [PSCustomObject] @{
            MaskedContent = $maskedContent
            EscapeMap     = $escapeMap
        }
        return $result
    }

    <#
    .SYNOPSIS
        Reverses masking, restoring escaped sequences as literal, un-escaped two-brace text.
    .DESCRIPTION
        The Unmask() method replaces every sentinel produced by Mask() with its corresponding
        original, already-un-escaped two-brace text (e.g. a masked `{{{{ORDERED_COMPONENTS}}}}`
        becomes literal `{{ORDERED_COMPONENTS}}` text in the output). Must be called after all
        placeholder-matching processing (mode detection, validation, rendering) has finished,
        since a sentinel is invisible to every `{{...}}`-matching check by design.
    .PARAMETER content
        The masked content to restore, as produced by Mask()'s MaskedContent property (after any
        further processing, e.g. rendering, has been applied to it).
    .PARAMETER escapeMap
        The sentinel-to-original-text map produced by Mask()'s EscapeMap property.
    .OUTPUTS
        The content with every sentinel replaced by its original, un-escaped two-brace text.
    .EXAMPLE
        $finalOutput = [PSScriptBuilderTemplateEscapeHelper]::Unmask($renderedContent, $escapeMap)
    #>
    static [string] Unmask([string] $content, [hashtable] $escapeMap) {
        $result = $content

        foreach ($sentinel in $escapeMap.Keys) {
            $result = $result.Replace($sentinel, $escapeMap[$sentinel])
        }

        if ($escapeMap.Count -gt 0) {
            Write-Verbose "  Restored $($escapeMap.Count) escaped placeholder sequence(s)"
            foreach ($originalText in $escapeMap.Values) {
                Write-Verbose "    Restored: $originalText"
            }
        }

        return $result
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderTemplateEscapeHelper

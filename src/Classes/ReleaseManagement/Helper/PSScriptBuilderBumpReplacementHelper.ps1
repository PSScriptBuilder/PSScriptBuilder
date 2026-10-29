using namespace System
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.Text
using namespace System.Text.RegularExpressions

#region Class PSScriptBuilderBumpReplacementHelper
<#
.SYNOPSIS
    Helper class for token and pattern replacement operations in bump files.
.DESCRIPTION
    The PSScriptBuilderBumpReplacementHelper class handles all replacement operations for bump file processing.
    It supports three modes of operation:
    - Simple Mode: Direct token replacements ({{TOKEN}})
    - Pattern Mode: Placeholder-based replacements within patterns ({{TOKEN}})
    - Regex Mode: Regex-based replacements with capture groups ({REGEX_TOKEN})
    The class provides methods for validating tokens and patterns, replacing placeholders with token values,
    and applying regex matches while preserving original formatting. It also includes a set of default regex
    patterns for common tokens related to build metadata, git metadata, and versioning.
    This class is designed to be flexible and extensible, allowing for custom regex patterns and dynamic token
    replacement in various file formats. It is a core component of the bump file processing logic in the
    PSScriptBuilder release management system.
#>
class PSScriptBuilderBumpReplacementHelper {
    #region Properties
    <#
    .SYNOPSIS
        Map of token names to their values.
    .DESCRIPTION
        The TokenMap property is an OrderedDictionary that holds token names (e.g., "VERSION", "BUILD_DATE") and 
        their corresponding values to be used in replacements.
    #>
    hidden [OrderedDictionary] $TokenMap

    <#
    .SYNOPSIS
        Map of token names to their regex patterns.
    .DESCRIPTION
        The RegexPatterns property is a hashtable that maps token names to their corresponding regex patterns.
        This allows dynamic replacement of {REGEX_TOKEN} placeholders with actual regex patterns during processing.
    #>
    hidden [hashtable] $RegexPatterns

    <#
    .SYNOPSIS
        Default regex patterns (static).
    .DESCRIPTION
        The DefaultRegexPatterns static property provides a predefined set of regex patterns for common tokens 
        related to build metadata, git metadata, and versioning. These patterns are compliant with standards 
        like ISO 8601 for dates and Semantic Versioning (SemVer) for versions.
    #>
    static [hashtable] $DefaultRegexPatterns = @{
        # Build Metadata Patterns (ISO 8601 compliant)
        'BUILD_DATE'            = '\d{4}-\d{2}-\d{2}'                                         # ISO 8601: YYYY-MM-DD
        'BUILD_TIME'            = '\d{2}:\d{2}:\d{2}'                                         # ISO 8601: HH:MM:SS
        'BUILD_DAY'             = '\d{2}'                                                     # 01-31
        'BUILD_MONTH'           = '\d{2}'                                                     # 01-12
        'BUILD_YEAR'            = '\d{4}'                                                     # Four-digit year
        'BUILD_HOUR'            = '\d{2}'                                                     # 00-23
        'BUILD_MINUTE'          = '\d{2}'                                                     # 00-59
        'BUILD_SECOND'          = '\d{2}'                                                     # 00-59
        'BUILD_TIMESTAMP'       = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z'                      # ISO 8601: YYYY-MM-DDTHH:MM:SSZ
        'BUILD_NUMBER'          = '\d+'                                                       # Arbitrary number

        # Git Metadata Patterns (Git naming conventions, RFC standards)
        'GIT_COMMIT'            = '[a-f0-9]{40}'                                              # SHA1 hash: exactly 40 hexadecimal chars
        'GIT_COMMIT_SHORT'      = '[a-f0-9]{7,40}'                                            # Short SHA: 7-40 hexadecimal chars
        'GIT_BRANCH'            = '[a-zA-Z0-9._\-/]+'                                         # Git branch naming (no spaces, no .lock suffix)
        'GIT_TAG'               = '[a-zA-Z0-9._\-]+'                                          # Flexible tag naming (alphanumeric, dots, dashes, underscores)

        # Version Patterns (Semantic Versioning RFC 6391)
        'VERSION'               = '\d+\.\d+\.\d+'                                             # MAJOR.MINOR.PATCH (e.g., 1.0.0)
        'VERSION_MAJOR'         = '\d+'                                                       # Major version number
        'VERSION_MINOR'         = '\d+'                                                       # Minor version number
        'VERSION_PATCH'         = '\d+'                                                       # Patch version number
        'VERSION_FULL'          = '\d+\.\d+\.\d+(?:-[a-zA-Z0-9.\-]+)?(?:\+[a-zA-Z0-9.\-]+)?'  # SemVer: MAJ.MIN.PATCH[-prerelease][+build]
        'VERSION_PRERELEASE'    = '[a-zA-Z0-9.\-]+'                                           # Prerelease: alpha, beta, rc, etc. (RFC 6391)
        'VERSION_BUILDMETADATA' = '[a-zA-Z0-9._\-]+'                                          # Build metadata (alphanumeric + . _ -)
    }
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes PSScriptBuilderBumpReplacementHelper with TokenMap only.
    .DESCRIPTION
        Creates a new PSScriptBuilderBumpReplacementHelper with the provided TokenMap.
        Uses the default regex patterns from DefaultRegexPatterns.
    .PARAMETER tokenMap
        OrderedDictionary mapping token names to their values.
    #>
    PSScriptBuilderBumpReplacementHelper([OrderedDictionary] $tokenMap) {
        if ($null -eq $tokenMap) {
            throw [ArgumentNullException]::new("TokenMap", "TokenMap cannot be null.")
        }

        $this.TokenMap = $tokenMap
        $this.RegexPatterns = [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns
    }

    <#
    .SYNOPSIS
        Initializes PSScriptBuilderBumpReplacementHelper with TokenMap and custom RegexPatterns.
    .DESCRIPTION
        Creates a new PSScriptBuilderBumpReplacementHelper with the provided TokenMap and custom regex patterns.
        This allows injection of custom patterns for testing or specialized use cases.
    .PARAMETER tokenMap
        OrderedDictionary mapping token names to their values.
    .PARAMETER regexPatterns
        Hashtable of custom regex patterns. If null, uses DefaultRegexPatterns.
    #>
    PSScriptBuilderBumpReplacementHelper([OrderedDictionary] $tokenMap, [hashtable] $regexPatterns) {
        if ($null -eq $tokenMap) {
            throw [ArgumentNullException]::new("TokenMap", "TokenMap cannot be null.")
        }

        $this.TokenMap = $tokenMap

        if ($null -eq $regexPatterns) {
            $this.RegexPatterns = [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns
        }
        else {
            $this.RegexPatterns = $regexPatterns
        }
    }
    #endregion Constructors

    #region Methods
    #region Public Methods
    <#
    .SYNOPSIS
        Applies simple token replacements directly in content.
    .DESCRIPTION
        The ApplySimpleReplacements method performs direct {{TOKEN}} replacements in the content without any
        pattern matching. This is the simplest mode of operation, ideal for straightforward token substitution
        where each {{TOKEN}} placeholder in the content is replaced with its corresponding value from the TokenMap.
        This method validates that token values are not empty before replacement and tracks all changes.
    .PARAMETER content
        The file content to search and replace in.
    .PARAMETER tokens
        Array of token names to replace.
    .OUTPUTS
        Returns hashtable with Content (modified) and Changes (array of modifications).
    #>
    [hashtable] ApplySimpleReplacements([string] $content, [object[]] $tokens) {
        $result = $this.ApplySimpleReplacements($content, $tokens, [List[PSCustomObject]]::new())
        return @{
            Content = $result.Content
            Changes = $result.Changes
        }
    }

    <#
    .SYNOPSIS
        Applies simple token replacements directly in content, honoring protected spans from prior tokens.
    .DESCRIPTION
        Same behavior as the two-parameter overload, extended to accept and return a protected-span
        ledger (RFC 0009): a candidate occurrence overlapping a span belonging to a different token
        (already inserted by an earlier, separate call - e.g. a prior bumpFiles entry or items entry
        for the same file) is skipped, so this token's substitution never corrupts a previous one's
        already-inserted value. A match inside a span belonging to this same token is still accepted,
        preserving the documented same-token multi-phase idiom.
    .PARAMETER content
        The file content to search and replace in.
    .PARAMETER tokens
        Array of token names to replace.
    .PARAMETER protectedSpans
        Spans of content already produced by prior tokens' substitutions, carried forward from an
        earlier call. Pass an empty list for the first call in a sequence.
    .OUTPUTS
        Returns hashtable with Content (modified), Changes (array of modifications), and
        ProtectedSpans (the updated ledger, to pass into the next call in the sequence).
    #>
    [hashtable] ApplySimpleReplacements([string] $content, [object[]] $tokens, [List[PSCustomObject]] $protectedSpans) {
        if ($null -eq $tokens -or $tokens.Count -eq 0) {
            throw [ArgumentException]::new("Tokens array cannot be null or empty")
        }

        $replacements = [List[PSCustomObject]]::new()
        $changes = @()

        foreach ($token in $tokens) {
            $placeholder = "{{$token}}"
            $tokenValue = $this.TokenMap[$token]
            $tokenValueString = [PSScriptBuilderTextHelper]::GetStringOrEmpty($tokenValue)

            $occurrences = $this.DiscoverOccurrences($content, $placeholder, $tokenValueString, $token, $protectedSpans, [StringComparison]::OrdinalIgnoreCase)

            if ($occurrences.Count -gt 0) {
                $replacements.AddRange($occurrences)

                # Track change
                $change = [ordered] @{
                    Pattern  = $placeholder
                    Token    = $token
                    OldValue = $placeholder
                    NewValue = $tokenValueString
                }
                $changes += $change
            }
        }

        $assembled = $this.AssembleFromReplacements($content, $replacements.ToArray(), $protectedSpans)

        return @{
            Content        = $assembled.Content
            Changes        = $changes
            ProtectedSpans = $assembled.ProtectedSpans
        }
    }

    <#
    .SYNOPSIS
        Routes pattern replacement to appropriate mode (placeholder vs regex).
    .DESCRIPTION
        The ApplyPatternReplacements method determines whether the provided pattern contains {{TOKEN}}
        placeholders or {REGEX_TOKEN} capture groups and routes the replacement operation to the corresponding
        handler method (ApplyPlaceholderReplacements or ApplyRegexReplacements).

        This is a convenience overload with no protected-span ledger - equivalent to calling the
        four-parameter overload with an empty ledger. Use the four-parameter overload when a prior,
        separate call's inserted values must not be re-matched (RFC 0009).
    .PARAMETER content
        The file content to search and replace in.
    .PARAMETER pattern
        The pattern string (either {{TOKEN}} or {REGEX_TOKEN} based).
    .PARAMETER tokens
        Array of token names corresponding to placeholders/patterns.
    .OUTPUTS
        Returns hashtable with Content (modified) and Changes (array of modifications).
    #>
    [hashtable] ApplyPatternReplacements([string] $content, [string] $pattern, [object[]] $tokens) {
        $result = $this.ApplyPatternReplacements($content, $pattern, $tokens, [List[PSCustomObject]]::new())
        return @{
            Content = $result.Content
            Changes = $result.Changes
        }
    }

    <#
    .SYNOPSIS
        Routes pattern replacement to appropriate mode (placeholder vs regex), honoring protected
        spans from prior tokens.
    .DESCRIPTION
        Same behavior as the three-parameter overload, extended to accept and return a protected-span
        ledger (RFC 0009), threaded through to whichever handler method (ApplyPlaceholderReplacements
        or ApplyRegexReplacements) the pattern routes to.
    .PARAMETER content
        The file content to search and replace in.
    .PARAMETER pattern
        The pattern string (either {{TOKEN}} or {REGEX_TOKEN} based).
    .PARAMETER tokens
        Array of token names corresponding to placeholders/patterns.
    .PARAMETER protectedSpans
        Spans of content already produced by prior tokens' substitutions, carried forward from an
        earlier call. Pass an empty list for the first call in a sequence.
    .OUTPUTS
        Returns hashtable with Content (modified), Changes (array), and ProtectedSpans (the updated
        ledger, to pass into the next call in the sequence).
    #>
    [hashtable] ApplyPatternReplacements(
        [string]               $content,
        [string]               $pattern,
        [object[]]             $tokens,
        [List[PSCustomObject]] $protectedSpans
    ) {
        if ([string]::IsNullOrEmpty($pattern)) {
            throw [ArgumentException]::new("Pattern cannot be null or empty")
        }

        if ($null -eq $tokens -or $tokens.Count -eq 0) {
            throw [ArgumentException]::new("Tokens array cannot be null or empty")
        }

        $mode = [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode($pattern)

        switch ($mode) {
            ([PSScriptBuilderBumpPatternMode]::Placeholder) {
                return $this.ApplyPlaceholderReplacements($content, $pattern, $tokens, $protectedSpans)
            }
            ([PSScriptBuilderBumpPatternMode]::Regex) {
                return $this.ApplyRegexReplacements($content, $pattern, $tokens, $protectedSpans)
            }
        }

        throw [ArgumentException]::new("Unhandled bump pattern mode: $mode")
    }

    <#
    .SYNOPSIS
        Checks if content has replaceable matches for the given pattern.
    .DESCRIPTION
        The HasContentToReplace method determines whether the provided pattern has any matches in the content
        without performing actual replacements or validation. This allows for content-aware validation where
        tokens are only validated if they are actually used in the content.

        For placeholder patterns ({{TOKEN}}), it performs a simple Contains check.
        For regex patterns with capture groups, it builds the regex and checks for matches.

        This method is exception-safe and returns false if any errors occur (e.g., missing regex patterns).
    .PARAMETER content
        The file content to check.
    .PARAMETER pattern
        The pattern to search for (either {{TOKEN}} or {REGEX_TOKEN} based).
    .PARAMETER tokens
        Array of token names corresponding to the pattern.
    .OUTPUTS
        Returns true if the pattern has matches in content, false otherwise.
    #>
    [bool] HasContentToReplace([string] $content, [string] $pattern, [object[]] $tokens) {
        try {
            $mode = [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode($pattern)

            switch ($mode) {
                ([PSScriptBuilderBumpPatternMode]::Placeholder) {
                    $unescapedPattern = $this.UnescapeLiteralBracesInPattern($this.UnescapeLiteralParenthesesInPattern($pattern))
                    return $content.Contains($unescapedPattern)
                }
                ([PSScriptBuilderBumpPatternMode]::Regex) {
                    $regexPattern = $this.ReplaceRegexPatterns($pattern, $tokens)
                    $regexMatches = $this.FindRegexMatches($content, $regexPattern)
                    return $regexMatches.Count -gt 0
                }
            }
        }
        catch {
            # Exception-safe: If error occurs (e.g., missing regex pattern, or pattern matches
            # neither shape), assume no content
            return $false
        }

        return $false
    }
    #endregion Public Methods

    #region Helper Methods: Discover/Assemble
    <#
    .SYNOPSIS
        Finds every occurrence of a placeholder in content.
    .DESCRIPTION
        The DiscoverOccurrences method scans the given content for every occurrence of the specified
        placeholder and records each one's position, without modifying the content. Always searches
        the original, unmodified content passed to it, so that discovering one token's occurrences
        is never affected by a previously-discovered token's replacement value.

        This is a convenience overload with no protected-span ledger - equivalent to calling the
        six-parameter overload with an empty ledger and OrdinalIgnoreCase, so every occurrence found
        is accepted unconditionally and token-name casing is tolerated (RFC 0008). Use the
        six-parameter overload directly when a prior, separate call's inserted values must not be
        re-matched (RFC 0009), or when the comparison mode itself must differ (e.g. Pattern Mode's
        content-level search, which must stay case-sensitive - see ApplyPlaceholderReplacements).
    .PARAMETER content
        The content to search. Must be the original, unmodified content - never a partially-replaced
        intermediate result - so that inserted values are never mistaken for further occurrences.
    .PARAMETER placeholder
        The exact placeholder text to search for (e.g. "{{VERSION}}").
    .PARAMETER replacementValue
        The value that should replace this placeholder at each discovered position.
    .OUTPUTS
        A list of PSCustomObject entries, one per occurrence found, each with Start, Length, and
        Replacement properties.
    #>
    hidden [List[PSCustomObject]] DiscoverOccurrences([string] $content, [string] $placeholder, [string] $replacementValue) {
        return $this.DiscoverOccurrences($content, $placeholder, $replacementValue, $null, [List[PSCustomObject]]::new(), [StringComparison]::OrdinalIgnoreCase)
    }

    <#
    .SYNOPSIS
        Finds every occurrence of a placeholder in content, honoring protected spans from prior
        tokens and an explicit comparison mode.
    .DESCRIPTION
        Same behavior as the three-parameter overload, extended with a protected-span ledger (RFC
        0009) and an explicit comparison mode: a candidate match is skipped if it overlaps a
        protected span belonging to a *different* token - this prevents this call from re-matching
        text that an earlier, separate call already inserted for another token. A match inside a
        span belonging to the *same* token is still accepted, preserving the documented same-token
        multi-phase idiom (e.g. a placeholder replaced once, then re-matched by a regex pattern
        against its own already-substituted value).

        The comparison mode is explicit, not always OrdinalIgnoreCase, because not every caller
        searches for a token *name*: ApplySimpleReplacements and the token-name resolution step in
        ApplyPlaceholderReplacements both search for "{{TOKEN}}" text and want RFC 0008's
        case-insensitive token-name matching, but ApplyPlaceholderReplacements' content-level search
        looks for the pattern's entire, author-written literal text (not a token name) and must stay
        case-sensitive - RFC 0008 never extended case-insensitivity to arbitrary literal text.
    .PARAMETER content
        The content to search. Must be the original, unmodified content - never a partially-replaced
        intermediate result - so that inserted values are never mistaken for further occurrences.
    .PARAMETER placeholder
        The exact text to search for (e.g. "{{VERSION}}", or an entire pattern string).
    .PARAMETER replacementValue
        The value that should replace this placeholder at each discovered position.
    .PARAMETER token
        The name of the token (or comma-joined compound identity) this occurrence belongs to.
    .PARAMETER protectedSpans
        Spans of content already produced by prior tokens' substitutions. A candidate match
        overlapping a span belonging to a different token is skipped.
    .PARAMETER comparisonMode
        The StringComparison to use when searching for placeholder.
    .OUTPUTS
        A list of PSCustomObject entries, one per occurrence found, each with Start, Length,
        Replacement, and Token properties.
    #>
    hidden [List[PSCustomObject]] DiscoverOccurrences(
        [string]               $content,
        [string]               $placeholder,
        [string]               $replacementValue,
        [string]               $token,
        [List[PSCustomObject]] $protectedSpans,
        [StringComparison]     $comparisonMode
    ) {
        $occurrences = [List[PSCustomObject]]::new()
        $searchStart = 0

        while ($true) {
            $index = $content.IndexOf($placeholder, $searchStart, $comparisonMode)
            if ($index -lt 0) {
                break
            }

            $matchEnd = $index + $placeholder.Length
            $blockedByOtherToken = $false

            foreach ($span in $protectedSpans) {
                if ($span.Token -ne $token -and $index -lt ($span.Start + $span.Length) -and $matchEnd -gt $span.Start) {
                    $blockedByOtherToken = $true
                    break
                }
            }

            if (-not $blockedByOtherToken) {
                $occurrences.Add([PSCustomObject] @{
                    Start       = $index
                    Length      = $placeholder.Length
                    Replacement = $replacementValue
                    Token       = $token
                })
            }

            $searchStart = $matchEnd
        }

        return $occurrences
    }

    <#
    .SYNOPSIS
        Builds the final content from a set of discovered replacement positions.
    .DESCRIPTION
        The AssembleFromReplacements method sorts all replacement entries by their Start position and
        walks the original content once, copying literal segments and inserting each replacement
        value in a single pass. Because every position was discovered against the original,
        unmodified content, an inserted replacement value is never re-scanned or mistaken for a
        further occurrence of any other placeholder.

        This is a convenience overload with no protected-span ledger - equivalent to calling the
        three-parameter overload with an empty existing-spans list and returning only its Content.
        Use the three-parameter overload when the updated ledger must be carried forward to a
        subsequent call (RFC 0009).
    .PARAMETER content
        The original, unmodified content the replacement positions were discovered against.
    .PARAMETER replacements
        The replacement entries to apply, each with Start, Length, and Replacement properties.
    .OUTPUTS
        The assembled content with every replacement applied.
    #>
    hidden [string] AssembleFromReplacements([string] $content, [PSCustomObject[]] $replacements) {
        $result = $this.AssembleFromReplacements($content, $replacements, [List[PSCustomObject]]::new())
        return $result.Content
    }

    <#
    .SYNOPSIS
        Builds the final content from a set of discovered replacement positions, and updates a
        protected-span ledger to reflect both the newly-inserted values and any existing spans
        shifted by the length change.
    .DESCRIPTION
        Same behavior as the two-parameter overload, extended with a protected-span ledger (RFC
        0009). After inserting each replacement, the Start position of every existing protected span
        that lies after that replacement's original position is shifted by the replacement's length
        delta (new length minus old length), and a new protected span is added for the
        freshly-inserted value, tagged with its own token. The returned ProtectedSpans list
        therefore correctly describes every tracked token's position in the assembled content,
        ready to be passed into the next call in the sequence.
    .PARAMETER content
        The original, unmodified content the replacement positions were discovered against.
    .PARAMETER replacements
        The replacement entries to apply, each with Start, Length, Replacement, and Token properties.
    .PARAMETER existingSpans
        Protected spans from prior tokens, with positions relative to this same, original content.
    .OUTPUTS
        A hashtable with Content (the assembled string) and ProtectedSpans (the updated list of
        tracked spans, including both the shifted existing ones and the newly-inserted ones).
    #>
    hidden [hashtable] AssembleFromReplacements(
        [string]               $content,
        [PSCustomObject[]]     $replacements,
        [List[PSCustomObject]] $existingSpans
    ) {
        if ($replacements.Count -eq 0) {
            return @{
                Content        = $content
                ProtectedSpans = $existingSpans
            }
        }

        $sorted          = $replacements | Sort-Object -Property Start
        $builder         = [StringBuilder]::new()
        $position        = 0
        $newSpans        = [List[PSCustomObject]]::new()
        $workingExisting = [List[PSCustomObject]]::new()

        foreach ($span in $existingSpans) {
            $workingExisting.Add([PSCustomObject] @{
                Start  = $span.Start
                Length = $span.Length
                Token  = $span.Token
            })
        }

        foreach ($replacement in $sorted) {
            [void] $builder.Append($content.Substring($position, $replacement.Start - $position))
            $insertPosition = $builder.Length
            [void] $builder.Append($replacement.Replacement)
            $delta = $replacement.Replacement.Length - $replacement.Length

            $newSpans.Add([PSCustomObject] @{
                Start  = $insertPosition
                Length = $replacement.Replacement.Length
                Token  = $replacement.Token
            })

            foreach ($span in $workingExisting) {
                if ($span.Start -ge ($replacement.Start + $replacement.Length)) {
                    $span.Start += $delta
                }
            }

            $position = $replacement.Start + $replacement.Length
        }

        [void] $builder.Append($content.Substring($position))

        $allSpans = [List[PSCustomObject]]::new()
        $allSpans.AddRange($newSpans)
        $allSpans.AddRange($workingExisting)

        return @{
            Content        = $builder.ToString()
            ProtectedSpans = $allSpans
        }
    }
    #endregion Helper Methods: Discover/Assemble

    #region Pattern Mode: Placeholder Replacements
    <#
    .SYNOPSIS
        Applies placeholder-based replacements within patterns.
    .DESCRIPTION
        The ApplyPlaceholderReplacements method processes patterns that contain {{TOKEN}} placeholders, which
        are replaced with actual token values from the TokenMap. This method validates that all tokens have
        corresponding placeholders in the pattern and that token values are present. It then performs a simple
        string replacement for each placeholder, allowing for straightforward token substitution without regex
        complexity.
        This mode is ideal for patterns that do not require complex matching and can be directly replaced with
        token values.

        This is a convenience overload with no protected-span ledger - equivalent to calling the four-parameter
        overload with an empty ledger. Use the four-parameter overload when a prior, separate call's inserted
        values must not be re-matched (RFC 0009).
    .PARAMETER content
        File content as string.
    .PARAMETER pattern
        Pattern containing {{TOKEN}} placeholders only.
    .PARAMETER tokens
        Array of token names.
    .OUTPUTS
        Hashtable with Content (modified) and Changes (array).
    #>
    hidden [hashtable] ApplyPlaceholderReplacements([string] $content, [string] $pattern, [object[]] $tokens) {
        $result = $this.ApplyPlaceholderReplacements($content, $pattern, $tokens, [List[PSCustomObject]]::new())
        return @{
            Content = $result.Content
            Changes = $result.Changes
        }
    }

    <#
    .SYNOPSIS
        Applies placeholder-based replacements within patterns, honoring protected spans from prior tokens.
    .DESCRIPTION
        Same behavior as the three-parameter overload, extended to accept and return a protected-span
        ledger (RFC 0009), applied to the content-level search: a candidate match of the pattern's
        entire resolved text overlapping a span belonging to a different token is skipped, so this
        pattern's substitution never corrupts a previous one's already-inserted value. A match inside
        a span belonging to this same compound token is still accepted, preserving the documented
        same-token multi-phase idiom.

        The pattern's own {{TOKEN}} placeholders are still resolved against the pattern text itself
        (case-insensitive token-name matching per RFC 0008, unaffected by the ledger - that step never
        touches file content). Locating the resolved pattern within content is case-sensitive
        (Ordinal): this searches for the pattern's entire, author-written literal text, not a token
        name, so RFC 0008's case-insensitivity does not apply here.
    .PARAMETER content
        File content as string.
    .PARAMETER pattern
        Pattern containing {{TOKEN}} placeholders only.
    .PARAMETER tokens
        Array of token names.
    .PARAMETER protectedSpans
        Spans of content already produced by prior tokens' substitutions, carried forward from an
        earlier call. Pass an empty list for the first call in a sequence.
    .OUTPUTS
        Hashtable with Content (modified), Changes (array), and ProtectedSpans (the updated ledger,
        to pass into the next call in the sequence).
    #>
    hidden [hashtable] ApplyPlaceholderReplacements(
        [string]               $content,
        [string]               $pattern,
        [object[]]             $tokens,
        [List[PSCustomObject]] $protectedSpans
    ) {
        $changes = @()

        # Unescape the literal-parenthesis convention Regex Mode already relies on natively -
        # Placeholder Mode does no regex matching, so this must be applied explicitly here (RFC 0012)
        $pattern = $this.UnescapeLiteralParenthesesInPattern($pattern)

        # Validate each token has corresponding placeholder
        foreach ($token in $tokens) {
            $placeholder = "{{$token}}"

            if ($pattern -notmatch [regex]::Escape($placeholder)) {
                $message = "Token '$token' has no corresponding placeholder '{{$token}}' in pattern"
                throw [InvalidOperationException]::new($message)
            }
        }

        # Resolve the pattern's own {{TOKEN}} placeholders against itself - pattern-internal,
        # unaffected by the cross-call ledger; token-name matching stays case-insensitive per RFC 0008
        $patternReplacements = [List[PSCustomObject]]::new()

        foreach ($token in $tokens) {
            $placeholder = "{{$token}}"
            $tokenValue  = $this.TokenMap[$token].ToString()

            $occurrences = $this.DiscoverOccurrences($pattern, $placeholder, $tokenValue)
            $patternReplacements.AddRange($occurrences)
        }

        $searchString = $this.AssembleFromReplacements($pattern, $patternReplacements.ToArray())

        # Unescape any remaining literal-brace text now - by construction, only ever foreign,
        # non-declared-token {{...}} text survives to this point, since a declared token's own
        # occurrence was already required to be unescaped to pass validation above (RFC 0016)
        $contentSearchKey = $this.UnescapeLiteralBracesInPattern($pattern)
        $searchString     = $this.UnescapeLiteralBracesInPattern($searchString)

        # Locate the resolved pattern in content. Ordinal (case-sensitive) is deliberate here: this
        # searches for the pattern's entire literal text, not a token name, so RFC 0008's
        # token-name case-insensitivity does not apply.
        $compoundToken      = $tokens -join ', '
        $contentOccurrences = $this.DiscoverOccurrences($content, $contentSearchKey, $searchString, $compoundToken, $protectedSpans, [StringComparison]::Ordinal)

        if ($contentOccurrences.Count -gt 0) {
            $assembled = $this.AssembleFromReplacements($content, $contentOccurrences.ToArray(), $protectedSpans)

            $changes += [ordered] @{
                Pattern  = $contentSearchKey
                Token    = $compoundToken
                OldValue = $contentSearchKey
                NewValue = $searchString
            }

            Write-Verbose "Placeholder pattern replaced: $contentSearchKey -> $searchString"

            return @{
                Content        = $assembled.Content
                Changes        = $changes
                ProtectedSpans = $assembled.ProtectedSpans
            }
        }

        return @{
            Content        = $content
            Changes        = $changes
            ProtectedSpans = $protectedSpans
        }
    }
    #endregion Pattern Mode: Placeholder Replacements

    #region Regex Mode: Regex Replacements
    <#
    .SYNOPSIS
        Applies regex-based replacements with capture groups.
    .DESCRIPTION
        The ApplyRegexReplacements method processes patterns that contain {REGEX_TOKEN} placeholders, which are
        replaced with actual regex patterns to find matches in the content. It then applies replacements based
        on the matches while preserving the original formatting of the file.
        This method allows for complex pattern matching and dynamic token replacement, enabling powerful and
        flexible bump file processing capabilities.

        This is a convenience overload with no protected-span ledger - equivalent to calling the four-parameter
        overload with an empty ledger. Use the four-parameter overload when a prior, separate call's inserted
        values must not be re-matched (RFC 0009).
    .PARAMETER content
        File content as string.
    .PARAMETER pattern
        Pattern with {REGEX_TOKEN} placeholders and/or capture groups.
    .PARAMETER tokens
        Array of token names.
    .OUTPUTS
        Hashtable with Content (modified) and Changes (array).
    #>
    hidden [hashtable] ApplyRegexReplacements([string] $content, [string] $pattern, [object[]] $tokens) {
        $result = $this.ApplyRegexReplacements($content, $pattern, $tokens, [List[PSCustomObject]]::new())
        return @{
            Content = $result.Content
            Changes = $result.Changes
        }
    }

    <#
    .SYNOPSIS
        Applies regex-based replacements with capture groups, honoring protected spans from prior tokens.
    .DESCRIPTION
        Same behavior as the three-parameter overload, extended to accept and return a protected-span
        ledger (RFC 0009): a capture group whose position overlaps a span belonging to a different
        token is left untouched, so this pattern's substitution never corrupts a previous one's
        already-inserted value. A capture group inside a span belonging to the same token is still
        replaced, preserving the documented same-token multi-phase idiom (e.g. a placeholder replaced
        once by Simple Mode, then re-matched here against its own already-substituted value).
    .PARAMETER content
        File content as string.
    .PARAMETER pattern
        Pattern with {REGEX_TOKEN} placeholders and/or capture groups.
    .PARAMETER tokens
        Array of token names.
    .PARAMETER protectedSpans
        Spans of content already produced by prior tokens' substitutions, carried forward from an
        earlier call. Pass an empty list for the first call in a sequence.
    .OUTPUTS
        Hashtable with Content (modified), Changes (array), and ProtectedSpans (the updated ledger,
        to pass into the next call in the sequence).
    #>
    hidden [hashtable] ApplyRegexReplacements(
        [string]               $content,
        [string]               $pattern,
        [object[]]             $tokens,
        [List[PSCustomObject]] $protectedSpans
    ) {
        # Validate regex patterns (pattern-specific validation)
        $this.ValidateRegexPatterns($tokens)

        $changes = @()

        # Step 1: Replace {REGEX_*} with actual regex patterns
        $regexPattern = $this.ReplaceRegexPatterns($pattern, $tokens)

        # Step 2: Find matches
        $regexMatches = $this.FindRegexMatches($content, $regexPattern)

        # If no matches found, return original content with empty changes
        if ($regexMatches.Count -eq 0) {
            return @{ Content = $content; Changes = $changes; ProtectedSpans = $protectedSpans }
        }

        # Step 3: Apply matches using position-based capture group replacement
        # This preserves original formatting (spaces, tabs, newlines) while replacing only token values
        $result = $this.ApplyMatchesWithCaptureGroups($content, $regexMatches, $tokens, $pattern, $protectedSpans)

        return $result
    }
    #endregion Regex Mode: Regex Replacements

    #region Helper Methods: Validation
    <#
    .SYNOPSIS
        Validates that all tokens exist in TokenMap and have non-empty values.
    .DESCRIPTION
        The ValidateTokenValues method checks that each token in the provided array exists in the TokenMap and
        has a non-null, non-empty value. It also checks for duplicate tokens in the array. If any token is
        missing, has an empty value, or if there are duplicates, an appropriate exception is thrown to prevent
        invalid replacements.
    .PARAMETER tokens
        Array of token names to validate.
    #>
    hidden [void] ValidateTokenValues([object[]] $tokens) {
        if ($null -eq $tokens -or $tokens.Count -eq 0) {
            throw [ArgumentException]::new("Tokens array is null or empty")
        }

        # Check for duplicates
        $uniqueTokens = $tokens | Select-Object -Unique
        if ($uniqueTokens.Count -ne $tokens.Count) {
            throw [ArgumentException]::new("Tokens array contains duplicates")
        }

        foreach ($token in $tokens) {
            if ([string]::IsNullOrWhiteSpace($token)) {
                $tokenIndex = [Array]::IndexOf($tokens, $token)
                $message = "Token at index $tokenIndex is null or empty"
                throw [ArgumentException]::new($message)
            }

            if (-not $this.TokenMap.Contains($token)) {
                $message = "Token '$token' not found in TokenMap"
                throw [KeyNotFoundException]::new($message)
            }

            $value = $this.TokenMap[$token]
            if ([string]::IsNullOrWhiteSpace($value)) {
                $message = "Token '$token' has no value (null or empty)"
                throw [InvalidOperationException]::new($message)
            }
        }
    }

    <#
    .SYNOPSIS
        Validates that all tokens have corresponding regex patterns defined.
    .DESCRIPTION
        The ValidateRegexPatterns method checks that for each token in the provided array, there is a
        corresponding regex pattern defined in the RegexPatterns hashtable. If any token does not have a
        defined regex pattern, an exception is thrown indicating which token is missing a pattern.
        This validation ensures that all necessary patterns are available for regex-based replacements,
        preventing runtime errors during pattern processing.
    .PARAMETER tokens
        Array of token names to validate.
    #>
    hidden [void] ValidateRegexPatterns([object[]] $tokens) {
        foreach ($token in $tokens) {
            if (-not $this.RegexPatterns.Contains($token)) {
                $message = "No regex pattern defined for token '$token'"
                throw [InvalidOperationException]::new($message)
            }
        }
    }
    #endregion Helper Methods: Validation

    #region Helper Methods: Pattern Processing
    <#
    .SYNOPSIS
        Replaces {REGEX_TOKEN} placeholders with actual regex patterns.
    .DESCRIPTION
        The ReplaceRegexPatterns method takes a pattern containing {REGEX_TOKEN} placeholders and replaces them
        with the corresponding regex patterns from the RegexPatterns hashtable. This allows for dynamic
        construction of regex patterns based on token names, enabling flexible and powerful matching capabilities
        while keeping the original pattern syntax clean and maintainable.
    .PARAMETER pattern
        Pattern containing {REGEX_*} placeholders.
    .PARAMETER tokens
        Array of token names to replace.
    .OUTPUTS
        Pattern with {REGEX_*} replaced by actual regex values.
    #>
    hidden [string] ReplaceRegexPatterns([string] $pattern, [object[]] $tokens) {
        $result = $pattern

        foreach ($token in $tokens) {
            $regexPlaceholder = "{REGEX_$token}"
            $regexValue       = $this.RegexPatterns[$token]

            $matchEvaluator = {
                param($match)
                return $regexValue
            }

            $result = [Regex]::Replace($result, [regex]::Escape($regexPlaceholder), $matchEvaluator, [RegexOptions]::IgnoreCase)
        }

        return $result
    }

    <#
    .SYNOPSIS
        Unescapes literal parentheses in a Placeholder Mode pattern.
    .DESCRIPTION
        The UnescapeLiteralParenthesesInPattern method replaces \( with ( and \) with ) in a pattern
        already confirmed to be Placeholder Mode. The escape convention lets an author include a
        literal parenthesis in a pattern without it being mistaken for a Regex Mode capture group
        during mode detection; Placeholder Mode itself does no regex matching, so the escape must be
        removed explicitly here before the pattern's text is used any further.
    .PARAMETER pattern
        A pattern already confirmed to be Placeholder Mode.
    .OUTPUTS
        The pattern with \( and \) replaced by ( and ).
    #>
    hidden [string] UnescapeLiteralParenthesesInPattern([string] $pattern) {
        $result = $pattern.Replace('\(', '(').Replace('\)', ')')
        return $result
    }

    <#
    .SYNOPSIS
        Unescapes literal braces in text derived from an already-resolved Placeholder Mode pattern.
    .DESCRIPTION
        The UnescapeLiteralBracesInPattern method replaces \{ with { and \} with } in text derived
        from a pattern already confirmed to be Placeholder Mode. Unlike the parenthesis escape, this
        must be applied only after the pattern's own {{TOKEN}} placeholders have already been located
        and resolved (RFC 0016) - braces are the placeholder delimiter syntax itself, so applying
        this any earlier would erase the distinction between an escaped, literal {{...}} occurrence
        and a declared token's own unescaped {{TOKEN}} occurrence before validation and
        token-resolution can tell them apart.
    .PARAMETER text
        Text derived from a Placeholder Mode pattern, after its own {{TOKEN}} placeholders have
        already been resolved.
    .OUTPUTS
        The text with \{ and \} replaced by { and }.
    #>
    hidden [string] UnescapeLiteralBracesInPattern([string] $text) {
        $result = $text.Replace('\{', '{').Replace('\}', '}')
        return $result
    }

    <#
    .SYNOPSIS
        Converts {REGEX_TOKEN} placeholders to {{TOKEN}} format.
    .DESCRIPTION
        The ConvertRegexPlaceholdersToTokens method takes a pattern with {REGEX_TOKEN} placeholders and
        converts them to {{TOKEN}} format. This allows the same pattern to be used for both regex matching
        and token replacement, enabling a unified processing flow while preserving the original formatting
        of the file content.
        This method is used in the regex replacement mode to facilitate the final token value replacement
        after regex matches have been applied.
    .PARAMETER pattern
        Denormalized pattern containing {REGEX_*} placeholders.
    .PARAMETER tokens
        Array of token names.
    .OUTPUTS
        Pattern with {REGEX_*} replaced by {{TOKEN}}.
    #>
    hidden [string] ConvertRegexPlaceholdersToTokens([string] $pattern, [object[]] $tokens) {
        $result = $pattern

        foreach ($token in $tokens) {
            $regexPlaceholder = "{REGEX_$token}"
            $tokenPlaceholder = "{{$token}}"

            $result = $result.Replace($regexPlaceholder, $tokenPlaceholder)
        }

        return $result
    }

    <#
    .SYNOPSIS
        Replaces {{TOKEN}} placeholders with actual token values.
    .DESCRIPTION
        The BuildReplacementStringFromTokens method takes a pattern with {{TOKEN}} placeholders and replaces
        them with the corresponding token values from the TokenMap. This method is used after converting regex
        patterns to token placeholders, allowing for a unified replacement process that preserves formatting
        while applying the final token values.
    .PARAMETER pattern
        Pattern containing {{TOKEN}} placeholders.
    .PARAMETER tokens
        Array of token names.
    .OUTPUTS
        Pattern with {{TOKEN}} replaced by token values.
    #>
    hidden [string] BuildReplacementStringFromTokens([string] $pattern, [object[]] $tokens) {
        $result = $pattern

        foreach ($token in $tokens) {
            $placeholder = "{{$token}}"
            $tokenValue  = $this.TokenMap[$token].ToString()

            $result = $result.Replace($placeholder, $tokenValue)
        }

        return $result
    }
    #endregion Helper Methods: Pattern Processing

    #region Helper Methods: Matching
    <#
    .SYNOPSIS
        Finds all regex matches in content.
    .DESCRIPTION
        The FindRegexMatches method uses the .NET Regex class to find all matches of the provided regex pattern
        in the content.
        It returns a MatchCollection that can be processed to apply replacements while preserving formatting.
    .PARAMETER content
        Content to search in.
    .PARAMETER pattern
        Regex pattern to search for.
    .OUTPUTS
        MatchCollection of all matches.
    #>
    hidden [MatchCollection] FindRegexMatches([string] $content, [string] $pattern) {
        return [regex]::Matches($content, $pattern, 'Multiline')
    }

    <#
    .SYNOPSIS
        Applies matches using position-based capture group replacement (preserves formatting).
    .DESCRIPTION
        The ApplyMatchesWithCaptureGroups method processes each regex match's capture groups, replacing only
        the capture group values at their exact positions and delegating the actual assembly to
        AssembleFromReplacements - preserving all surrounding formatting (spaces, tabs, newlines) exactly as
        before, while also respecting the protected-span ledger (RFC 0009): a capture group overlapping a span
        belonging to a different token is skipped, leaving its text untouched.

        IMPORTANT:
        - This method expects that each token has exactly ONE corresponding capture group in the pattern,
          in the same order as the tokens array.
        - Matches may be processed in any order - AssembleFromReplacements handles cross-match position safety.
        - Within each match, capture groups are still processed from BACK TO FRONT, to correctly reconstruct
          that match's own text for change-detection (a purely local operation, unrelated to the ledger).
    .PARAMETER content
        Original file content.
    .PARAMETER matchCollection
        MatchCollection from regex matching.
    .PARAMETER tokens
        Array of token names (must match order of capture groups).
    .PARAMETER pattern
        Original pattern (for change recording).
    .PARAMETER protectedSpans
        Spans of content already produced by prior tokens' substitutions. A capture group overlapping a
        span belonging to a different token is left untouched.
    .OUTPUTS
        Hashtable with Content (modified), Changes (array), and ProtectedSpans (the updated ledger).
    #>
    hidden [hashtable] ApplyMatchesWithCaptureGroups(
        [string]               $content,
        [MatchCollection]      $matchCollection,
        [object[]]             $tokens,
        [string]               $pattern,
        [List[PSCustomObject]] $protectedSpans
    ) {
        $changes = @()
        $allReplacements = [List[PSCustomObject]]::new()

        for ($matchIndex = 0; $matchIndex -lt $matchCollection.Count; $matchIndex++) {
            $regexMatch = $matchCollection[$matchIndex]
            $oldValue = $regexMatch.Value
            $newMatch = $oldValue

            # Process capture groups from BACK TO FRONT to preserve string positions within match
            # (this match's own local reconstruction, independent of the cross-call ledger)
            # Groups[0] is the entire match, Groups[1..N] are the capture groups
            for ($i = $tokens.Count - 1; $i -ge 0; $i--) {
                $token = $tokens[$i]
                $groupIndex = $i + 1  # Groups[0] = entire match, Groups[1] = first capture group

                if ($regexMatch.Groups.Count -le $groupIndex) {
                    $message = "Pattern has fewer capture groups than tokens. Expected $($tokens.Count) groups for tokens: $($tokens -join ', ')"
                    throw [InvalidOperationException]::new($message)
                }

                $captureGroup  = $regexMatch.Groups[$groupIndex]
                $newTokenValue = $this.TokenMap[$token].ToString()

                $blockedByOtherToken = $false
                foreach ($span in $protectedSpans) {
                    if ($span.Token -ne $token -and $captureGroup.Index -lt ($span.Start + $span.Length) -and ($captureGroup.Index + $captureGroup.Length) -gt $span.Start) {
                        $blockedByOtherToken = $true
                        break
                    }
                }

                if ($blockedByOtherToken) {
                    continue
                }

                $allReplacements.Add([PSCustomObject] @{
                    Start       = $captureGroup.Index
                    Length      = $captureGroup.Length
                    Replacement = $newTokenValue
                    Token       = $token
                })

                # Calculate position RELATIVE to the match start
                $relativeIndex = $captureGroup.Index - $regexMatch.Index

                # Replace only this capture group's value at its exact position within the match
                $before   = $newMatch.Substring(0, $relativeIndex)
                $after    = $newMatch.Substring($relativeIndex + $captureGroup.Length)
                $newMatch = $before + $newTokenValue + $after
            }

            # Only record a change if content actually changed
            if ($oldValue -ne $newMatch) {
                $changes += [ordered] @{
                    Pattern  = $pattern
                    Token    = ($tokens -join ', ')
                    OldValue = $oldValue
                    NewValue = $newMatch
                }

                $formattedOld = $this.FormatStringForVerboseOutput($oldValue)
                $formattedNew = $this.FormatStringForVerboseOutput($newMatch)
                Write-Verbose "Regex match replaced: $formattedOld -> $formattedNew"
            }
        }

        $assembled = $this.AssembleFromReplacements($content, $allReplacements.ToArray(), $protectedSpans)

        return @{
            Content        = $assembled.Content
            Changes        = $changes
            ProtectedSpans = $assembled.ProtectedSpans
        }
    }
    #endregion Helper Methods: Matching

    #region Helper Methods: Formatting
    <#
    .SYNOPSIS
        Formats a string for readable verbose output by replacing special characters with placeholders.
    .DESCRIPTION
        The FormatStringForVerboseOutput method replaces special whitespace characters and line breaks
        with readable placeholders to improve verbose output clarity, especially for multiline replacements.
    .PARAMETER text
        Text to format.
    .OUTPUTS
        Formatted string with placeholders: [CRLF], [LF], [CR], [TAB], [space:n].
    #>
    hidden [string] FormatStringForVerboseOutput([string] $text) {
        if ([string]::IsNullOrEmpty($text)) {
            return $text
        }

        # Replace line breaks (CRLF must be before LF to avoid double replacement)
        $formatted = $text.Replace("`r`n", '[CRLF]')
        $formatted = $formatted.Replace("`r", '[CR]')
        $formatted = $formatted.Replace("`n", '[LF]')

        # Replace tabs
        $formatted = $formatted.Replace("`t", '[TAB]')

        # Replace consecutive spaces (2 or more) with [space:n]
        $spacePattern = ' {2,}'

        $evaluator = {
            param($match)
            $count = $match.Value.Length
            return "[space:$count]"
        }

        $formatted = [regex]::Replace($formatted, $spacePattern, $evaluator)
        return $formatted
    }
    #endregion Helper Methods: Formatting
    #endregion Methods
}
#endregion Class PSScriptBuilderBumpReplacementHelper

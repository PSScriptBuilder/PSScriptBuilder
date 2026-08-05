using namespace System
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
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
        if ($null -eq $tokens -or $tokens.Count -eq 0) {
            throw [ArgumentException]::new("Tokens array cannot be null or empty")
        }

        $newContent = $content
        $changes = @()

        foreach ($token in $tokens) {
            $placeholder = "{{$token}}"
            $tokenValue = $this.TokenMap[$token]
            $tokenValueString = [PSScriptBuilderTextHelper]::GetStringOrEmpty($tokenValue)

            # Only process if placeholder exists in content
            if ($newContent.Contains($placeholder)) {
                # Track change
                $change = [ordered] @{
                    Pattern  = $placeholder
                    Token    = $token
                    OldValue = $placeholder
                    NewValue = $tokenValueString
                }
                $changes += $change

                # Apply replacement
                $newContent = $newContent.Replace($placeholder, $tokenValueString)
            }
        }

        return @{
            Content = $newContent
            Changes = $changes
        }
    }

    <#
    .SYNOPSIS
        Routes pattern replacement to appropriate mode (placeholder vs regex).
    .DESCRIPTION
        The ApplyPatternReplacements method determines whether the provided pattern contains {{TOKEN}} 
        placeholders or {REGEX_TOKEN} capture groups and routes the replacement operation to the corresponding 
        handler method (ApplyPlaceholderReplacements or ApplyRegexReplacements).
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
        if ([string]::IsNullOrEmpty($pattern)) {
            throw [ArgumentException]::new("Pattern cannot be null or empty")
        }

        if ($null -eq $tokens -or $tokens.Count -eq 0) {
            throw [ArgumentException]::new("Tokens array cannot be null or empty")
        }

        # Determine mode based on pattern type
        $hasPlaceholders = $pattern -match '\{\{'
        $hasCaptures     = $pattern -match '(?<!\\)\('  # Only non-escaped parentheses

        if ($hasPlaceholders -and -not $hasCaptures) {
            # Pattern Mode: Placeholder-only ({{TOKEN}})
            return $this.ApplyPlaceholderReplacements($content, $pattern, $tokens)
        }
        elseif ($hasCaptures) {
            # Regex Mode: Regex with capture groups ({REGEX_TOKEN})
            return $this.ApplyRegexReplacements($content, $pattern, $tokens)
        }
        else {
            $message = "Pattern must contain either {{TOKEN}} placeholders or capture groups: $pattern"
            throw [ArgumentException]::new($message)
        }
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
            # Determine mode based on pattern type
            $hasPlaceholders = $pattern -match '\{\{'
            $hasCaptures     = $pattern -match '(?<!\\)\('  # Only non-escaped parentheses

            if ($hasPlaceholders -and -not $hasCaptures) {
                # Pattern Mode: Simple placeholder check
                return $content.Contains($pattern)
            }
            elseif ($hasCaptures) {
                # Regex Mode: Check for matches using hidden helper methods
                $regexPattern = $this.ReplaceRegexPatterns($pattern, $tokens)
                $regexMatches = $this.FindRegexMatches($content, $regexPattern)
                return $regexMatches.Count -gt 0
            }
            else {
                # Unknown pattern format
                return $false
            }
        }
        catch {
            # Exception-safe: If error occurs (e.g., missing regex pattern), assume no content
            return $false
        }
    }
    #endregion Public Methods

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
        $changes = @()

        # Validate each token has corresponding placeholder
        foreach ($token in $tokens) {
            $placeholder = "{{$token}}"

            if ($pattern -notmatch [regex]::Escape($placeholder)) {
                $message = "Token '$token' has no corresponding placeholder '{{$token}}' in pattern"
                throw [InvalidOperationException]::new($message)
            }
        }

        # Build replacement string
        $searchString = $pattern

        foreach ($token in $tokens) {
            $placeholder = "{{$token}}"
            $tokenValue  = $this.TokenMap[$token].ToString()

            $searchString = $searchString.Replace($placeholder, $tokenValue)
        }

        # Replace in content (graceful if not found)
        if ($content.Contains($pattern)) {
            $content = $content.Replace($pattern, $searchString)

            $changes += [ordered] @{
                Pattern  = $pattern
                Token    = ($tokens -join ', ')
                OldValue = $pattern
                NewValue = $searchString
            }

            Write-Verbose "Placeholder pattern replaced: $pattern -> $searchString"
        }

        return @{
            Content = $content
            Changes = $changes
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
        # Validate regex patterns (pattern-specific validation)
        $this.ValidateRegexPatterns($tokens)

        $changes = @()

        # Step 1: Replace {REGEX_*} with actual regex patterns
        $regexPattern = $this.ReplaceRegexPatterns($pattern, $tokens)

        # Step 2: Find matches
        $regexMatches = $this.FindRegexMatches($content, $regexPattern)

        # If no matches found, return original content with empty changes
        if ($regexMatches.Count -eq 0) {
            return @{ Content = $content; Changes = $changes }
        }

        # Step 3: Apply matches using position-based capture group replacement
        # This preserves original formatting (spaces, tabs, newlines) while replacing only token values
        $result = $this.ApplyMatchesWithCaptureGroups($content, $regexMatches, $tokens, $pattern)

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

            if ($result -match [regex]::Escape($regexPlaceholder)) {
                $regexValue = $this.RegexPatterns[$token]
                $result = $result.Replace($regexPlaceholder, $regexValue)
            }
        }

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
        This method is used in the regex replacement mode to facilitate the final token value 
        replacement after regex matches have been applied.
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
        The FindRegexMatches method uses the .NET Regex class to find all matches of the provided regex pattern in the content.
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
        The ApplyMatchesWithCaptureGroups method processes each regex match by replacing only the capture group 
        values at their exact positions, preserving all surrounding formatting (spaces, tabs, newlines).
        This approach ensures that the original file formatting is maintained while updating token values.

        IMPORTANT:
        - This method expects that each token has exactly ONE corresponding capture group in the pattern,
          in the same order as the tokens array.
        - Matches are processed from BACK TO FRONT in the content to avoid index shifting.
        - Within each match, capture groups are processed from BACK TO FRONT for the same reason.
    .PARAMETER content
        Original file content.
    .PARAMETER matchCollection
        MatchCollection from regex matching.
    .PARAMETER tokens
        Array of token names (must match order of capture groups).
    .PARAMETER pattern
        Original pattern (for change recording).
    .OUTPUTS
        Hashtable with modified Content and Changes array.
    #>
    hidden [hashtable] ApplyMatchesWithCaptureGroups(
        [string]          $content,
        [MatchCollection] $matchCollection,
        [object[]]        $tokens,
        [string]          $pattern
    ) {
        $changes = @()
        $newContent = $content

        # Process matches from BACK TO FRONT to avoid index shifting in content
        for ($matchIndex = $matchCollection.Count - 1; $matchIndex -ge 0; $matchIndex--) {
            $regexMatch = $matchCollection[$matchIndex]
            $oldValue = $regexMatch.Value
            $newMatch = $oldValue

            # Process capture groups from BACK TO FRONT to preserve string positions within match
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

                # Calculate position RELATIVE to the match start
                $relativeIndex = $captureGroup.Index - $regexMatch.Index

                # Replace only this capture group's value at its exact position within the match
                $before   = $newMatch.Substring(0, $relativeIndex)
                $after    = $newMatch.Substring($relativeIndex + $captureGroup.Length)
                $newMatch = $before + $newTokenValue + $after
            }

            # Only replace if content actually changed
            if ($oldValue -ne $newMatch) {
                # Replace at exact position in content (not global replace!)
                $matchStart  = $regexMatch.Index
                $beforeMatch = $newContent.Substring(0, $matchStart)
                $afterMatch  = $newContent.Substring($matchStart + $oldValue.Length)
                $newContent  = $beforeMatch + $newMatch + $afterMatch

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

        return @{
            Content = $newContent
            Changes = $changes
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

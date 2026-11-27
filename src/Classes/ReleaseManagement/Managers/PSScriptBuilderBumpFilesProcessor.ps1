using namespace System
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderBumpFilesProcessor
<#
.SYNOPSIS
    Processes file updates for version bumping.
.DESCRIPTION
    The PSScriptBuilderBumpFilesProcessor class handles updating version information in project files based on a 
    bump configuration and token map. It applies token replacements to files according to specified patterns.
#>
class PSScriptBuilderBumpFilesProcessor {
    #region Properties
    <#
    .SYNOPSIS
        Holds the bump files configuration.
    .DESCRIPTION
        The BumpFilesConfig property contains the configuration specifying which files should be updated
        and which patterns/tokens should be replaced.
    #>
    hidden [PSCustomObject] $BumpFilesConfig

    <#
    .SYNOPSIS
        Holds the token mapping.
    .DESCRIPTION
        The TokenMap property contains the token name to value mappings used for replacing patterns in files.
    #>
    hidden [OrderedDictionary] $TokenMap

    <#
    .SYNOPSIS
        Helper for token and pattern replacements.
    .DESCRIPTION
        The ReplacementHelper property contains an instance of PSScriptBuilderBumpReplacementHelper
        which handles all token-based and regex-based replacement operations.
    #>
    hidden [PSScriptBuilderBumpReplacementHelper] $ReplacementHelper
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderBumpFilesProcessor.
    .DESCRIPTION
        Creates a new PSScriptBuilderBumpFilesProcessor with the provided bump files configuration and token map.
    .PARAMETER bumpFilesConfig
        A PSCustomObject containing the bump files configuration.
    .PARAMETER tokenMap
        An ordered dictionary mapping token names to their values.
    #>
    PSScriptBuilderBumpFilesProcessor([PSCustomObject] $bumpFilesConfig, [OrderedDictionary] $tokenMap) {
        $this.BumpFilesConfig = $bumpFilesConfig
        $this.TokenMap = $tokenMap
        $this.ReplacementHelper = [PSScriptBuilderBumpReplacementHelper]::new($tokenMap)
    }
    #endregion Constructors

    #region Methods
    #region Public Methods
    <#
    .SYNOPSIS
        Prepares bump file updates in memory without writing to disk.
    .DESCRIPTION
        The UpdateBumpFilesInMemory method iterates through all configured files and calculates 
        the token replacements in-memory, returning only files with actual changes. This separation allows
        for preview/WhatIf scenarios without immediate disk writes.
        Additionally returns the total count of processed files (including unchanged ones) to provide visibility
        into both TotalFilesProcessed and TotalFilesModified.

        Entries for the same file are grouped by full path with the platform's path comparer and
        processed in the configured order - Group-Object would sort the groups in PowerShell 7 but
        keep the input order in 5.1. Each file is read once as bytes, kept for the change check of
        the transaction that writes it, and decoded exactly as before (see
        PSScriptBuilderFileIOHelper.DecodeUTF8WithBOM).
    .OUTPUTS
        Returns a hashtable with:
        - TotalProcessed: Total number of files processed (including unchanged)
        - Changes: List[PSScriptBuilderBumpFileChange] containing only files with actual changes
    #>
    [hashtable] UpdateBumpFilesInMemory() {
        if ($null -eq $this.BumpFilesConfig -or $null -eq $this.BumpFilesConfig.bumpFiles) {
            $message = "BumpFilesConfig is null or does not contain bumpFiles array"
            throw [InvalidOperationException]::new($message)
        }

        $totalProcessed = 0
        $changes = [List[PSScriptBuilderBumpFileChange]]::new()

        # Group by full path to handle multiple entries for the same file (Phase 1, Phase 2, etc.),
        # in the configured order and with the platform's path comparison
        $groups = [OrderedDictionary]::new([PSScriptBuilderFileSystemHelper]::GetPathComparer())
        foreach ($fileConfig in $this.BumpFilesConfig.bumpFiles) {
            try {
                $rootedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($fileConfig.path)
                $fullPath   = [Path]::GetFullPath($rootedPath)
            }
            catch {
                $message = "Failed to process bump file '$($fileConfig.path)': $($_.Exception.Message)"
                throw [InvalidOperationException]::new($message, $_.Exception)
            }

            if (-not $groups.Contains($fullPath)) {
                $groups[$fullPath] = [List[object]]::new()
            }
            $groups[$fullPath].Add($fileConfig)
        }

        foreach ($filePath in $groups.Keys) {
            $fileConfigs = $groups[$filePath]  # All entries for this file

            try {
                Write-Verbose "Processing bump file: $filePath"

                # Check if file exists
                if (-not (Test-Path -Path $filePath -PathType Leaf)) {
                    $message = "Failed to process bump file '$filePath' because it does not exist"
                    throw [FileNotFoundException]::new($message, $filePath)
                }

                # Read the bytes once: kept for the change check, decoded exactly as before
                $originalBytes   = [PSScriptBuilderFileIOHelper]::ReadAllBytes($filePath)
                $originalContent = [PSScriptBuilderFileIOHelper]::DecodeUTF8WithBOM($originalBytes)

                # Initialize new content with original content
                $newContent = $originalContent

                # Protected-span ledger (RFC 0009), reset per file-path group - tracks which token
                # produced which region of $newContent, so a later entry/item cannot re-scan and
                # corrupt an earlier entry/item's own inserted value for a different token.
                $protectedSpans = [List[PSCustomObject]]::new()

                # Track changes for this file (used for items-based replacements)
                $fileChanges = @()

                # Process all configurations for this file (handles multiple entries like Phase 1, Phase 2)
                foreach ($fileConfig in $fileConfigs) {
                    # Output item-level description if available
                    if ($null -ne $fileConfig.description) {
                        Write-Verbose "  Applying: $($fileConfig.description)"
                    }

                    # Simple Mode: Direct token replacement (if tokens property exists)
                    if ([PSScriptBuilderBumpModeResolver]::IsSimpleMode($fileConfig)) {
                        # Validate exactly the tokens the replacement is about to replace: the same
                        # search, without regard to letter case and with the protected spans (RFC 0027)
                        foreach ($configToken in $fileConfig.tokens) {
                            $spellings = $this.ReplacementHelper.FindPlaceholderSpellings($newContent, $configToken, $protectedSpans)

                            if ($spellings.Count -gt 0) {
                                $this.ValidateSimpleModeToken($configToken, $spellings)
                            }
                        }

                        try {
                            $result = $this.ReplacementHelper.ApplySimpleReplacements($newContent, $fileConfig.tokens, $protectedSpans)
                            $newContent     = $result.Content
                            $protectedSpans = $result.ProtectedSpans
                            $fileChanges += $result.Changes
                        }
                        catch {
                            $message = "Failed to apply simple token replacement in file '$filePath': $($_.Exception.Message)"
                            throw [InvalidOperationException]::new($message, $_.Exception)
                        }
                    }
                    # Pattern/Regex Mode: Pattern-based or regex-based replacement (if items property exists)
                    elseif ([PSScriptBuilderBumpModeResolver]::IsItemsMode($fileConfig)) {
                        foreach ($item in $fileConfig.items) {
                            # Always validate token values - an empty token is always a configuration error,
                            # regardless of whether the pattern currently matches the file content.
                            # Unlike Simple Mode, items-mode entries are explicit per-file configurations
                            # that are always expected to have valid token values.
                            $this.ValidateTokensForFile($item.tokens, $filePath)

                            try {
                                $result = $this.ReplacementHelper.ApplyPatternReplacements($newContent, $item.pattern, $item.tokens, $protectedSpans)
                                $newContent     = $result.Content
                                $protectedSpans = $result.ProtectedSpans
                                $fileChanges += $result.Changes
                            }
                            catch {
                                $message = "Failed to apply pattern replacement in file '$filePath': $($_.Exception.Message)"
                                throw [InvalidOperationException]::new($message, $_.Exception)
                            }
                        }
                    }
                    else {
                        $message = "BumpFile '$($fileConfig.path)' must have either 'tokens' or 'items' property"
                        throw [InvalidOperationException]::new($message)
                    }
                }

                # Increment total processed count
                $totalProcessed++

                # Only add to changes if content was modified
                if (-not [string]::Equals($originalContent, $newContent, [StringComparison]::Ordinal)) {
                    $change = [PSScriptBuilderBumpFileChange]::new($filePath, $originalBytes, $originalContent, $newContent, $fileChanges)
                    $changes.Add($change)
                }
                else {
                    # None of this file's configured entries matched anything in its current
                    # content. In a working Mixed Bump Mode setup (multiple entries per file)
                    # this is never true - at least one entry always matches on any given run -
                    # so this only fires when every configured entry failed to match: a genuine
                    # reachable silent-failure case (e.g. a Simple/Placeholder-only entry with no
                    # Regex fallback, already consumed by a prior run).
                    #
                    # Deliberately no attempted count of "how many patterns/tokens were tried" in
                    # the message: a single $fileConfig entry can itself hold several tokens
                    # (Simple Mode) or several items (Items/Regex Mode), so a naive
                    # $fileConfigs.Count would undercount - verified against this project's own
                    # bumpconfig.json, where a 2-entry group represents 13 individual
                    # tokens/patterns, not 2. Restating that count correctly would duplicate the
                    # Simple/Items mode-detection logic that already lives in
                    # PSScriptBuilderBumpModeResolver, for a number the message doesn't need to be
                    # actionable.
                    $format  =
                        "Bump file '{0}' is configured for release data substitution, but none of " +
                        "its patterns matched the current content - nothing was updated. If this " +
                        "file was already bumped by a prior run, add a Regex-mode fallback entry " +
                        "(Mixed Bump Mode) so subsequent runs keep matching."
                    $message = $format -f $filePath
                    Write-Warning $message
                }
            }
            catch [DecoderFallbackException] {
                # PowerShell matches a typed catch against the inner exception of the
                # MethodInvocationException the decoding call is wrapped in, too
                $decoderException = $_.Exception
                if ($decoderException -isnot [DecoderFallbackException]) {
                    $decoderException = $decoderException.InnerException
                }

                $message = "Failed to read bump file '$filePath' due to invalid UTF-8 encoding: $($decoderException.Message)"
                throw [IOException]::new($message, $decoderException)
            }
            catch {
                $message = "Failed to process bump file '$filePath': $($_.Exception.Message)"
                throw [InvalidOperationException]::new($message, $_.Exception)
            }
        }

        return @{
            TotalProcessed = $totalProcessed
            Changes        = $changes
        }
    }
    #endregion Public Methods

    #region Private Methods
    <#
    .SYNOPSIS
        Validates a single token that occurs in the file content.
    .DESCRIPTION
        The ValidateSimpleModeToken method validates one token of a Simple-mode entry and wraps a
        validation exception like ValidateTokensForFile does. The message names the token as
        written in the bump configuration; when the file spells the placeholder differently, it
        adds every spelling found, so the place in the file can be located (RFC 0027).

        The token is passed on as the object it is. A nested array in a tokens list must not be
        flattened into a valid token name on the way.
    .PARAMETER token
        The token as written in the bump configuration.
    .PARAMETER spellings
        The spellings of the token's placeholder found in the file content.
    #>
    hidden [void] ValidateSimpleModeToken([object] $token, [string[]] $spellings) {
        try {
            [object[]] $singleToken = , $token
            $this.ReplacementHelper.ValidateTokenValues($singleToken)
        }
        catch {
            $exception          = $_.Exception
            $message            = "Token validation failed - {0}" -f $exception.Message
            $configuredSpelling = "{{$token}}"
            $deviatingSpellings = @($spellings | Where-Object { -not [string]::Equals($_, $configuredSpelling, [StringComparison]::Ordinal) })

            if ($deviatingSpellings.Count -gt 0) {
                $quotedSpellings = @($spellings | ForEach-Object { "'$_'" }) -join ', '
                $message         = "{0}; written in the file as {1}" -f $message, $quotedSpellings
            }

            throw [InvalidOperationException]::new($message, $exception)
        }
    }

    <#
    .SYNOPSIS
        Validates tokens for a specific file.
    .DESCRIPTION
        The ValidateTokensForFile method validates that all tokens in the provided array exist in the TokenMap
        and have non-empty values. It wraps validation exceptions with file context for better error messages.
        It validates the tokens of an items entry before any file I/O, ensuring fail-fast behavior. The
        tokens of a Simple-mode entry are validated one by one by ValidateSimpleModeToken.
    .PARAMETER tokens
        Array of token names to validate.
    .PARAMETER filePath
        Path to the file being processed (for error context).
    #>
    hidden [void] ValidateTokensForFile([object[]] $tokens, [string] $filePath) {
        if ($null -eq $tokens -or $tokens.Count -eq 0) {
            return  # No tokens to validate
        }

        try {
            # Delegate to helper (reusable validation logic)
            $this.ReplacementHelper.ValidateTokenValues($tokens)
        }
        catch {
            # Wrap exception (file context added by outer catch)
            $message = "Token validation failed - $($_.Exception.Message)"
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
    #endregion Private Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderBumpFilesProcessor

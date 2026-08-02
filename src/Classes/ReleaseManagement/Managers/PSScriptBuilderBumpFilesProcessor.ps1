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
        the token replacements in-memory, returning only files with actual changes. This separation allows \
        for preview/WhatIf scenarios without immediate disk writes.
        Additionally returns the total count of processed files (including unchanged ones) to provide visibility 
        into both TotalFilesProcessed and TotalFilesModified.
    .OUTPUTS
        Returns a hashtable with:
        - TotalProcessed: Total number of files processed (including unchanged)
        - Changes: List[PSCustomObject] containing only files with actual changes (filePath, originalContent, newContent, changedItems)
    #>
    [hashtable] UpdateBumpFilesInMemory() {
        if ($null -eq $this.BumpFilesConfig -or $null -eq $this.BumpFilesConfig.bumpFiles) {
            $message = "BumpFilesConfig is null or does not contain bumpFiles array"
            throw [InvalidOperationException]::new($message)
        }

        $totalProcessed = 0
        $changes = [List[PSCustomObject]]::new()

        # Group by file path to handle multiple entries for the same file (Phase 1, Phase 2, etc.)
        $groupedByPath = $this.BumpFilesConfig.bumpFiles | Group-Object -Property path

        foreach ($group in $groupedByPath) {
            $filePath    = $group.Name
            $fileConfigs = $group.Group  # All entries for this file

            try {
                $filePath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($filePath)
                Write-Verbose "Processing bump file: $filePath"

                # Check if file exists
                if (-not (Test-Path -Path $filePath -PathType Leaf)) {
                    $message = "Failed to process bump file '$filePath' because it does not exist"
                    throw [FileNotFoundException]::new($message, $filePath)
                }

                # Read original file content using FileIOHelper
                $originalContent = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($filePath)

                # Initialize new content with original content
                $newContent = $originalContent

                # Track changes for this file (used for items-based replacements)
                $fileChanges = @()

                # Process all configurations for this file (handles multiple entries like Phase 1, Phase 2)
                foreach ($fileConfig in $fileConfigs) {
                    # Output item-level description if available
                    if ($null -ne $fileConfig.description) {
                        Write-Verbose "  Applying: $($fileConfig.description)"
                    }

                    # Simple Mode: Direct token replacement (if tokens property exists)
                    if ($null -ne $fileConfig.tokens -and @($fileConfig.tokens).Count -gt 0) {
                        # Filter: Only validate tokens that exist in content (content-aware validation)
                        $tokensInContent = @($fileConfig.tokens | Where-Object {
                            $newContent.Contains("{{$_}}")
                        })

                        if ($tokensInContent.Count -gt 0) {
                            $this.ValidateTokensForFile($tokensInContent, $filePath)
                        }

                        try {
                            $result = $this.ReplacementHelper.ApplySimpleReplacements($newContent, $fileConfig.tokens)
                            $newContent = $result.Content
                            $fileChanges += $result.Changes
                        }
                        catch {
                            $message = "Failed to apply simple token replacement in file '$filePath': $($_.Exception.Message)"
                            throw [InvalidOperationException]::new($message, $_.Exception)
                        }
                    }
                    # Pattern/Regex Mode: Pattern-based or regex-based replacement (if items property exists)
                    elseif ($null -ne $fileConfig.items -and @($fileConfig.items).Count -gt 0) {
                        foreach ($item in $fileConfig.items) {
                            # Always validate token values - an empty token is always a configuration error,
                            # regardless of whether the pattern currently matches the file content.
                            # Unlike Simple Mode, items-mode entries are explicit per-file configurations
                            # that are always expected to have valid token values.
                            $this.ValidateTokensForFile($item.tokens, $filePath)

                            try {
                                $result = $this.ReplacementHelper.ApplyPatternReplacements($newContent, $item.pattern, $item.tokens)
                                $newContent = $result.Content
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
                if ($originalContent -ne $newContent) {
                    $change = [PSCustomObject] @{
                        filePath        = $filePath
                        originalContent = $originalContent
                        newContent      = $newContent
                        changedItems    = $fileChanges
                    }

                    $changes.Add($change)
                }
            }
            catch {
                $inner = $_.Exception.InnerException

                if ($inner -is [DecoderFallbackException]) {
                    $message = "Failed to read bump file '$filePath' due to invalid UTF-8 encoding: $($inner.Message)"
                    throw [IOException]::new($message, $inner)
                }

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
        Validates tokens for a specific file.
    .DESCRIPTION
        The ValidateTokensForFile method validates that all tokens in the provided array exist in the TokenMap
        and have non-empty values. It wraps validation exceptions with file context for better error messages.
        This method provides a single point of validation at the orchestrator level, ensuring fail-fast behavior
        before file I/O operations.
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

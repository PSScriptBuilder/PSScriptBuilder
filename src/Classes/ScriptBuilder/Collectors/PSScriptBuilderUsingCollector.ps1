using namespace System.Collections.Generic
using namespace System.IO

#region Class PSScriptBuilderUsingCollector
<#
.SYNOPSIS
    Collector for using statements across PowerShell files.
.DESCRIPTION
    The PSScriptBuilderUsingCollector scans PowerShell files for using statements and aggregates them.
    Using statements are automatically deduplicated and sorted alphabetically for consistent output.
#>
class PSScriptBuilderUsingCollector : PSScriptBuilderCollectorBase {
    #region Properties
    <#
    .SYNOPSIS
        Collection of unique using statements with source file information.
    .DESCRIPTION
        The UsingData property holds a deduplicated collection of using statements found across all processed 
        files.
        Each entry is a PSScriptBuilderUsingData object that tracks the statement and all files where it appears.
        Uses case-insensitive comparison to ensure uniqueness.
    #>
    [Dictionary[string, PSScriptBuilderUsingData]] $UsingData
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderUsingCollector with default collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderUsingCollector with the default collection key "UsingData".
    #>
    PSScriptBuilderUsingCollector() : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::UsingCollector
        $this.CollectionKey = "USING_STATEMENTS"
        $this.UsingData     = [Dictionary[string, PSScriptBuilderUsingData]]::new([StringComparer]::OrdinalIgnoreCase)
    }

    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderUsingCollector with custom collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderUsingCollector with the specified collection key.
    .PARAMETER collectionKey
        The unique identifier for this collector instance.
    #>
    PSScriptBuilderUsingCollector([string] $collectionKey) : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::UsingCollector
        $this.CollectionKey = $collectionKey
        $this.UsingData     = [Dictionary[string, PSScriptBuilderUsingData]]::new([StringComparer]::OrdinalIgnoreCase)
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Resets the collector's state.
    .DESCRIPTION
        Clears all collected using statements to prepare for a new collection run.
    #>
    [void] Reset() {
        $this.UsingData.Clear()
    }

    <#
    .SYNOPSIS
        Collects using statements from the provided files.
    .DESCRIPTION
        Parses each file using the AstEngine, finds all using statements, and stores them
        in a deduplicated collection. Parse errors are logged but do not stop collection.
    .PARAMETER files
        The files to collect using statements from.
    #>
    hidden [void] CollectFromFiles([FileInfo[]] $files) {
        Write-Verbose "Collecting using statements from $($files.Count) file(s)..."

        $totalCollected = 0

        foreach ($file in $files) {
            try {
                Write-Verbose "  Parsing: $($file.Name)"

                $ast = [PSScriptBuilderAstEngine]::ParseFile($file.FullName)
                $usingStatements = [PSScriptBuilderAstEngine]::FindUsingStatements($ast)

                $beforeCount = $this.UsingData.Count

                foreach ($usingStatement in $usingStatements) {
                    $sourceCode = [PSScriptBuilderAstEngine]::ExtractSourceCode($usingStatement)

                    if ($this.UsingData.ContainsKey($sourceCode)) {
                        # Using statement exists - add source file to existing UsingInfo
                        $this.UsingData[$sourceCode].AddSourceFile($file.FullName)
                    }
                    else {
                        # New using statement - create UsingData object
                        $usingDataObject = [PSScriptBuilderUsingData]::new($sourceCode, $file.FullName)
                        $this.UsingData.Add($sourceCode, $usingDataObject)
                    }
                }

                $newCount = $this.UsingData.Count - $beforeCount

                if ($usingStatements.Count -gt 0) {
                    Write-Verbose "    Found $($usingStatements.Count) using statement(s), $newCount new"
                }

                $totalCollected += $newCount
            }
            catch {
                $format  = "Failed to collect using statements from file: {0}. Error: {1}"
                $message = $format -f $file.FullName, $_.Exception.Message
                throw [Exception]::new($message, $_.Exception)
            }
        }

        Write-Verbose "Collection complete: $($this.UsingData.Count) unique using statement(s), $totalCollected new"
    }

    <#
    .SYNOPSIS
        Gets detailed information for a specific component.
    .DESCRIPTION
        The TryGetComponentDetail method always returns null for UsingCollector because using statements
        are not included in component details.
    .PARAMETER componentName
        The name of the component (not used for using statements).
    .PARAMETER knownComponents
        A case-insensitive set of all known project component names (not used for using statements).
    .OUTPUTS
        Always returns null.
    #>
    [PSScriptBuilderBuildComponentDetail] TryGetComponentDetail([string] $componentName, [HashSet[string]] $knownComponents) {
        return $null
    }

    <#
    .SYNOPSIS
        Gets the count of collected using statements.
    .DESCRIPTION
        The GetCount method returns the total number of unique using statements collected by this collector.
    .OUTPUTS
        Returns the number of collected using statements as an integer.
    #>
    [int] GetCount() {
        return $this.UsingData.Count
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderUsingCollector

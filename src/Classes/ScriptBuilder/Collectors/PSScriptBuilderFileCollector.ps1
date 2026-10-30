using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderFileCollector
<#
.SYNOPSIS
    Collects file content from all kinds of text files.
.DESCRIPTION
    The PSScriptBuilderFileCollector extracts raw file content from text files without any parsing or analysis.
    It stores the content using the file name as key.
#>
class PSScriptBuilderFileCollector : PSScriptBuilderCollectorBase {
    #region Properties
    <#
    .SYNOPSIS
        Collection of file contents.
    .DESCRIPTION
        The FileData property holds the raw content of all processed files and uses the file name as key to 
        ensure uniqueness. 
        It stores PSScriptBuilderFileData objects containing file name, full path, and content.
    #>
    [Dictionary[string, PSScriptBuilderFileData]] $FileData

    <#
    .SYNOPSIS
        Source line ranges of collected files, keyed by file name.
    .DESCRIPTION
        The SourceRanges property maps each collected file name to its PSScriptBuilderSourceRange.
        StartLineNumber is always 1; EndLineNumber is the total line count of the file.
        Used by PSScriptBuilderSourceMapGenerator to populate ComponentLineNumber entries.
    #>
    hidden [Dictionary[string, PSScriptBuilderSourceRange]] $SourceRanges
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderFileCollector with default collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderFileCollector with the default collection key "FileData".
    #>
    PSScriptBuilderFileCollector() : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::FileCollector
        $this.CollectionKey = "FILE_CONTENTS"
        $this.FileData      = [Dictionary[string, PSScriptBuilderFileData]]::new([StringComparer]::OrdinalIgnoreCase)
        $this.SourceRanges  = [Dictionary[string, PSScriptBuilderSourceRange]]::new([StringComparer]::OrdinalIgnoreCase)
    }

    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderFileCollector with custom collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderFileCollector with the specified collection key.
    .PARAMETER collectionKey
        The unique identifier for this collector instance.
    #>
    PSScriptBuilderFileCollector([string] $collectionKey) : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::FileCollector
        $this.CollectionKey = $collectionKey
        $this.FileData      = [Dictionary[string, PSScriptBuilderFileData]]::new([StringComparer]::OrdinalIgnoreCase)
        $this.SourceRanges  = [Dictionary[string, PSScriptBuilderSourceRange]]::new([StringComparer]::OrdinalIgnoreCase)
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Resets the collector's state.
    .DESCRIPTION
        Clears all collected file contents and source ranges to prepare for a new collection run.
    #>
    [void] ResetData() {
        $this.FileData.Clear()
        $this.SourceRanges.Clear()
    }

    <#
    .SYNOPSIS
        Collects file contents from the provided files.
    .DESCRIPTION
        Reads the raw content of each file and stores it using the file name as key.
        Duplicate file names will overwrite previous content with a warning.

        Content is read explicitly as UTF-8 rather than via Get-Content, since Get-Content falls
        back to the system's default codepage for a BOM-less file, silently corrupting non-ASCII
        characters (e.g. umlauts) on any system whose default codepage isn't UTF-8. Reading
        explicitly avoids this regardless of whether the file has a BOM.
    .PARAMETER files
        The files to collect content from.
    #>
    hidden [void] CollectFromFiles([FileInfo[]] $files) {
        Write-Verbose "Collecting file contents from $($files.Count) file(s)..."
        $totalCollected = 0

        foreach ($file in $files) {
            try {
                Write-Verbose "  Reading: $($file.Name)"

                # Guard clause: Check for duplicates before processing
                if ($this.FileData.ContainsKey($file.Name)) {
                    $format  = "Duplicate file name '{0}' found in path: {1}. A file with this name was already collected from another path."
                    $message = $format -f $file.Name, $file.FullName
                    throw [InvalidOperationException]::new($message)
                }

                $content = [PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($file.FullName)

                if ([string]::IsNullOrEmpty($content)) {
                    $lineCount = 0
                }
                else {
                    $newlineCount = [regex]::Matches($content, '\n').Count
                    $lineCount    = if ($content.EndsWith("`n")) { $newlineCount } else { $newlineCount + 1 }
                }
                $this.SourceRanges[$file.Name] = [PSScriptBuilderSourceRange]::new(1, $lineCount)

                # Create file data object
                $fileDataObject = [PSScriptBuilderFileData]::new(
                    $file.Name,
                    $file.FullName,
                    $content
                )

                $this.FileData[$file.Name] = $fileDataObject
                $totalCollected++

                $contentLength = if ($content) { $content.Length } else { 0 }
                Write-Verbose "    Content length: $contentLength character(s)"
            }
            catch {
                $inner = $_.Exception.InnerException

                if ($inner -is [DecoderFallbackException]) {
                    $format  = "Failed to read file content from '{0}' due to invalid UTF-8 encoding: {1}"
                    $message = $format -f $file.FullName, $inner.Message
                    throw [Exception]::new($message, $inner)
                }

                $format  = "Failed to read file content from: {0}. Error: {1}"
                $message = $format -f $file.FullName, $_.Exception.Message
                throw [Exception]::new($message, $_.Exception)
            }
        }

        Write-Verbose "Collection complete: $($this.FileData.Count) unique file(s), $totalCollected new"
    }

    <#
    .SYNOPSIS
        Gets detailed information for a specific component.
    .DESCRIPTION
        The TryGetComponentDetail method always returns null for FileCollector because files
        are not included in component details.
    .PARAMETER componentName
        The name of the component (not used for files).
    .PARAMETER knownComponents
        A case-insensitive set of all known project component names (not used for files).
    .OUTPUTS
        Always returns null.
    #>
    [PSScriptBuilderBuildComponentDetail] TryGetComponentDetail([string] $componentName, [HashSet[string]] $knownComponents) {
        return $null
    }

    <#
    .SYNOPSIS
        Gets the count of collected files.
    .DESCRIPTION
        The GetCount method returns the total number of files collected by this collector.
    .OUTPUTS
        Returns the number of collected files as an integer.
    #>
    [int] GetCount() {
        return $this.FileData.Count
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderFileCollector

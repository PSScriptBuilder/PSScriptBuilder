using namespace System.Collections.Generic

#region Class PSScriptBuilderUsingData
<#
.SYNOPSIS
    Represents collected using statement data with source file information.
.DESCRIPTION
    The PSScriptBuilderUsingData class encapsulates data about a using statement
    including its statement text and all source files where it appears. Since using statements
    can appear in multiple files, this class tracks all occurrences for complete traceability.
#>
class PSScriptBuilderUsingData {
    #region Properties
    <#
    .SYNOPSIS
        The using statement text.
    .DESCRIPTION
        The Statement property holds the complete using statement as it appears in source code
        (e.g., "using namespace System" or "using module MyModule").
    #>
    [string] $Statement

    <#
    .SYNOPSIS
        Collection of source files containing this using statement.
    .DESCRIPTION
        The SourceFiles property holds the absolute paths to all files where this using statement appears.
        Uses case-insensitive comparison to handle duplicate file references consistently.
    #>
    [HashSet[string]] $SourceFiles
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderUsingData.
    .DESCRIPTION
        Creates a new PSScriptBuilderUsingData with the specified using statement and initial source file.
    .PARAMETER statement
        The using statement text.
    .PARAMETER sourceFile
        The absolute path to the file containing this using statement.
    #>
    PSScriptBuilderUsingData([string] $statement, [string] $sourceFile) {
        if ([string]::IsNullOrWhiteSpace($statement)) {
            $message = "Statement cannot be null or empty."
            throw [ArgumentException]::new($message, "statement")
        }

        if ([string]::IsNullOrWhiteSpace($sourceFile)) {
            $message = "SourceFile cannot be null or empty."
            throw [ArgumentException]::new($message, "sourceFile")
        }

        $this.Statement   = $statement
        $this.SourceFiles = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        $this.SourceFiles.Add($sourceFile) | Out-Null
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Adds a source file to the collection.
    .DESCRIPTION
        The AddSourceFile method adds another source file path to the SourceFiles collection.
        If the file is already tracked, the operation is a no-op due to HashSet deduplication.
    .PARAMETER sourceFile
        The absolute path to the file containing this using statement.
    #>
    [void] AddSourceFile([string] $sourceFile) {
        if ([string]::IsNullOrWhiteSpace($sourceFile)) {
            $message = "SourceFile cannot be null or empty."
            throw [ArgumentException]::new($message, "sourceFile")
        }

        $this.SourceFiles.Add($sourceFile) | Out-Null
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderUsingData

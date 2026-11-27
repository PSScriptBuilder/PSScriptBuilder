using namespace System

#region Class PSScriptBuilderBumpFileChange
<#
.SYNOPSIS
    Represents the prepared change of one bump file.
.DESCRIPTION
    The PSScriptBuilderBumpFileChange class holds the change that PSScriptBuilderBumpFilesProcessor
    prepared in memory for one bump file: the file's path, its content before and after the token
    replacements and the bytes it was read from, and the individual replacements. It is passed from
    the processor through PSScriptBuilderReleaseManagementOrchestrator to the step that persists
    the change, and is created only for files whose content actually changes.
#>
class PSScriptBuilderBumpFileChange {
    #region Properties
    <#
    .SYNOPSIS
        The absolute path to the bump file.
    .DESCRIPTION
        The FilePath property holds the project-rooted path of the bump file the change applies to.
    #>
    [string] $FilePath

    <#
    .SYNOPSIS
        The bytes of the bump file before the change.
    .DESCRIPTION
        The OriginalBytes property holds the exact content read from the bump file when the change
        was prepared, from which OriginalContent was decoded. PSScriptBuilderFileTransaction
        compares the file with it before writing, so a file changed in the meantime is not
        overwritten.
    #>
    [byte[]] $OriginalBytes

    <#
    .SYNOPSIS
        The content of the bump file before the change.
    .DESCRIPTION
        The OriginalContent property holds the text read from the bump file when the change was
        prepared.
    #>
    [string] $OriginalContent

    <#
    .SYNOPSIS
        The content of the bump file after the change.
    .DESCRIPTION
        The NewContent property holds the text with all configured token replacements applied, as
        it is written when the change is persisted.
    #>
    [string] $NewContent

    <#
    .SYNOPSIS
        The individual replacements made in the bump file.
    .DESCRIPTION
        The ChangedItems property holds one entry per replacement reported by
        PSScriptBuilderBumpReplacementHelper, in the order they were applied, each with Pattern,
        Token, OldValue and NewValue. They are reported unchanged as ChangedItems in the
        BumpDetails of the Update-PSScriptBuilderBumpFiles result. Never $null; empty if the
        helper reported no individual replacements.
    #>
    [object[]] $ChangedItems
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderBumpFileChange.
    .DESCRIPTION
        Creates the change of one bump file. A missing list of replacements is stored as an empty
        array, so ChangedItems is never $null.
    .PARAMETER filePath
        The absolute path to the bump file.
    .PARAMETER originalBytes
        The bytes of the bump file before the change.
    .PARAMETER originalContent
        The content of the bump file before the change.
    .PARAMETER newContent
        The content of the bump file after the change.
    .PARAMETER changedItems
        The individual replacements made in the bump file.
    #>
    PSScriptBuilderBumpFileChange([string] $filePath, [byte[]] $originalBytes, [string] $originalContent, [string] $newContent, [object[]] $changedItems) {
        if ([string]::IsNullOrWhiteSpace($filePath)) {
            $message = "Parameter 'filePath' cannot be null or empty."
            throw [ArgumentException]::new($message, "filePath")
        }

        if ($null -eq $originalBytes) {
            $message = "Parameter 'originalBytes' cannot be null."
            throw [ArgumentNullException]::new("originalBytes", $message)
        }

        $this.FilePath        = $filePath
        $this.OriginalBytes   = $originalBytes
        $this.OriginalContent = $originalContent
        $this.NewContent      = $newContent
        $this.ChangedItems    = @()
        if ($null -ne $changedItems) {
            $this.ChangedItems = $changedItems
        }
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderBumpFileChange

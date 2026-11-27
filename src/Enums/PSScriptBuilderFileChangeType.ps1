#region Enum PSScriptBuilderFileChangeType
<#
.SYNOPSIS
    Defines the kind of change a file transaction applies to a file.
.DESCRIPTION
    The PSScriptBuilderFileChangeType enumeration defines the two kinds of change that
    PSScriptBuilderFileTransaction applies:
    - Replace: an existing file gets new content; it is backed up and restored on failure
    - Create:  a new file is written; it must not exist yet and is deleted on failure
    Replace has the value zero as the most common kind (Framework Design Guidelines: a None value
    would not be a valid change). Entries always set the kind through their constructor, so it is
    never left at this default by accident.
#>
enum PSScriptBuilderFileChangeType {
    <#
    .SYNOPSIS
        Replace the content of an existing file.
    .DESCRIPTION
        The file must exist and still have the content the change was prepared from. It is backed
        up next to itself before it is written and restored from that backup if the transaction
        fails.
    #>
    Replace = 0

    <#
    .SYNOPSIS
        Create a new file.
    .DESCRIPTION
        The file must not exist when the transaction is committed; it is created exclusively and
        deleted again if the transaction fails. Its directory is created if necessary.
    #>
    Create = 1
}
#endregion Enum PSScriptBuilderFileChangeType

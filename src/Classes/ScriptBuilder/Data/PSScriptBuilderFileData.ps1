#region Class PSScriptBuilderFileData
<#
.SYNOPSIS
    Represents collected file data with its content.
.DESCRIPTION
    The PSScriptBuilderFileData class encapsulates data about a file collected during the build process
    including its filename, full path, and content.
#>
class PSScriptBuilderFileData {
    #region Properties
    <#
    .SYNOPSIS
        The name of the file.
    .DESCRIPTION
        The FileName property holds the name of the file without directory information.
    #>
    [string] $FileName

    <#
    .SYNOPSIS
        The complete file path.
    .DESCRIPTION
        The FullPath property holds the absolute path to the file.
    #>
    [string] $FullPath

    <#
    .SYNOPSIS
        The content of the file.
    .DESCRIPTION
        The Content property contains the complete text content of the file.
    #>
    [string] $Content
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderFileData.
    .DESCRIPTION
        Creates a new PSScriptBuilderFileData with the specified file information.
    .PARAMETER fileName
        The name of the file without directory information.
    .PARAMETER fullPath
        The absolute path to the file.
    .PARAMETER content
        The complete text content of the file.
    #>
    PSScriptBuilderFileData([string] $fileName, [string] $fullPath, [string] $content) {
        $this.FileName = $fileName
        $this.FullPath = $fullPath
        $this.Content  = $content
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderFileData

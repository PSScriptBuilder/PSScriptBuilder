#region Class PSScriptBuilderScaffoldingResult
<#
.SYNOPSIS
    Encapsulates the result of a project scaffold operation.
.DESCRIPTION
    The PSScriptBuilderScaffoldingResult class provides a structured container for the outcome of a
    New-PSScriptBuilderProject operation, including the project name, paths, and lists of all
    created files and directories.
#>
class PSScriptBuilderScaffoldingResult {
    #region Properties
    <#
    .SYNOPSIS
        The name of the scaffolded project.
    .DESCRIPTION
        The ProjectName property holds the name that was used when scaffolding the project.
    #>
    [string] $ProjectName

    <#
    .SYNOPSIS
        The absolute path to the project root directory.
    .DESCRIPTION
        The ProjectPath property holds the absolute path to the root directory of the scaffolded
        project.
    #>
    [string] $ProjectPath

    <#
    .SYNOPSIS
        The absolute path to the generated build script.
    .DESCRIPTION
        The BuildScriptPath property holds the absolute path to the Build-<Name>.ps1 script
        created during scaffolding.
    #>
    [string] $BuildScriptPath

    <#
    .SYNOPSIS
        List of all files created during scaffolding.
    .DESCRIPTION
        The CreatedFiles property contains the absolute paths of all files created during the
        scaffold operation, in creation order.
    #>
    [string[]] $CreatedFiles

    <#
    .SYNOPSIS
        List of all directories created during scaffolding.
    .DESCRIPTION
        The CreatedDirectories property contains the absolute paths of all directories created
        during the scaffold operation, in creation order.
    #>
    [string[]] $CreatedDirectories
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderScaffoldingResult class.
    .PARAMETER projectName
        The name of the scaffolded project.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    .PARAMETER buildScriptPath
        The absolute path to the generated build script.
    .PARAMETER createdFiles
        The absolute paths of all files created during scaffolding.
    .PARAMETER createdDirectories
        The absolute paths of all directories created during scaffolding.
    #>
    PSScriptBuilderScaffoldingResult(
        [string]   $projectName,
        [string]   $projectPath,
        [string]   $buildScriptPath,
        [string[]] $createdFiles,
        [string[]] $createdDirectories
    ) {
        $this.ProjectName        = $projectName
        $this.ProjectPath        = $projectPath
        $this.BuildScriptPath    = $buildScriptPath
        $this.CreatedFiles       = $createdFiles
        $this.CreatedDirectories = $createdDirectories
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderScaffoldingResult

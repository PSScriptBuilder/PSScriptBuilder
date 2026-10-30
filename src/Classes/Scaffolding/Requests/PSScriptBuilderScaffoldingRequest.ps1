#region Class PSScriptBuilderScaffoldingRequest
<#
.SYNOPSIS
    Encapsulates parameters for a project scaffold operation.
.DESCRIPTION
    The PSScriptBuilderScaffoldingRequest class represents the input parameters for scaffolding a new
    PSScriptBuilder project, including the project name, target path, and optional feature flags.
#>
class PSScriptBuilderScaffoldingRequest {
    #region Properties
    <#
    .SYNOPSIS
        The name of the project to scaffold.
    .DESCRIPTION
        The Name property holds the project name used to derive file and directory names in the
        scaffolded structure.
    #>
    [string] $Name

    <#
    .SYNOPSIS
        The target directory in which to create the project.
    .DESCRIPTION
        The Path property holds the absolute path to the directory where the project folder will
        be created. The project folder itself will be named after the Name property.
    #>
    [string] $Path

    <#
    .SYNOPSIS
        Whether to include release management files.
    .DESCRIPTION
        If $true, the scaffold operation also creates release management files:
        psscriptbuilder.releasedata.json, psscriptbuilder.bumpconfig.json, and a
        Release script with -Major, -Minor, and -Patch switches.
    #>
    [bool] $IncludeReleaseManagement = $false

    <#
    .SYNOPSIS
        Whether to include sample source files.
    .DESCRIPTION
        If $true, the scaffold operation creates sample source files demonstrating enum, class,
        and function definitions with dependency relationships. Enabled by default.
    #>
    [bool] $IncludeSampleFiles = $true

    <#
    .SYNOPSIS
        Whether to overwrite existing files.
    .DESCRIPTION
        If $true, existing files in the target directory are overwritten without error.
    #>
    [bool] $Force = $false
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderScaffoldingRequest class.
    .PARAMETER name
        The project name.
    .PARAMETER path
        The target directory path.
    .PARAMETER includeReleaseManagement
        Whether to include release management files.
    .PARAMETER includeSampleFiles
        Whether to include sample source files.
    .PARAMETER force
        Whether to overwrite existing files.
    #>
    PSScriptBuilderScaffoldingRequest([string] $name, [string] $path, [bool] $includeReleaseManagement, [bool] $includeSampleFiles, [bool] $force) {
        $this.Name                     = $name
        $this.Path                     = $path
        $this.IncludeReleaseManagement = $includeReleaseManagement
        $this.IncludeSampleFiles       = $includeSampleFiles
        $this.Force                    = $force
    }
    #endregion Constructors
}
#endregion Class PSScriptBuilderScaffoldingRequest

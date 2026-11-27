#region Class PSScriptBuilderWellKnownFileNames
<#
.SYNOPSIS
    Well-known file names used by PSScriptBuilder projects.
.DESCRIPTION
    The PSScriptBuilderWellKnownFileNames class is the single source of truth for all file names
    that PSScriptBuilder expects to find in a project. These names are prescribed by the module
    and must not be changed by consumers.
#>
class PSScriptBuilderWellKnownFileNames {
    #region Static Properties
    <#
    .SYNOPSIS
        The well-known name of the PSScriptBuilder configuration file.
    #>
    static [string] $Configuration = "psscriptbuilder.config.json"

    <#
    .SYNOPSIS
        The well-known name of the release data file.
    #>
    static [string] $ReleaseData = "psscriptbuilder.releasedata.json"

    <#
    .SYNOPSIS
        The well-known name of the bump configuration file.
    #>
    static [string] $BumpConfig = "psscriptbuilder.bumpconfig.json"
    #endregion Static Properties
}
#endregion Class PSScriptBuilderWellKnownFileNames

using namespace System.IO

#region Class PSScriptBuilderReleaseOptions
<#
.SYNOPSIS
    Release options for PSScriptBuilder.
.DESCRIPTION
    The PSScriptBuilderReleaseOptions class encapsulates configuration options related to release management 
    within the PSScriptBuilder framework, including release data file path and bump configuration file path.
#>
class PSScriptBuilderReleaseOptions : PSScriptBuilderOptionsBase {
    #region Properties
    <#
    .SYNOPSIS
        Path to the release data file.
    .DESCRIPTION
        The DataFile property holds the file path to the release data file used for release management.
    #>
    [string] $DataFile

    <#
    .SYNOPSIS
        Path to the bump configuration file.
    .DESCRIPTION
        The BumpConfigFile property contains the file path to the configuration file that defines which 
        files should have their versions bumped during the release process.
    #>
    [string] $BumpConfigFile
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderReleaseOptions class.
    .DESCRIPTION
        The constructor takes a PSCustomObject containing configuration data and initializes the class instance.
    .PARAMETER config
        A PSCustomObject containing the release configuration data.
    #>
    PSScriptBuilderReleaseOptions([PSCustomObject] $config) : base($config) {
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Sets the release options from a configuration object.
    .DESCRIPTION
        The SetOptions method sets the corresponding properties of the PSScriptBuilderReleaseOptions instance
        from the provided configuration object.
    .PARAMETER config
        A PSCustomObject containing the release configuration data.
    #>
    [void] SetOptions([PSCustomObject] $config) {
        $this.DataFile       = [string] $this.GetPropertyValue($config, "datafile")
        $this.BumpConfigFile = [string] $this.GetPropertyValue($config, "bumpconfigfile")
    }

    <#
    .SYNOPSIS
        Validates the release options.
    .DESCRIPTION
        The ValidateOptions method performs option-specific validation including path normalization.
        Structural validation is handled by PSScriptBuilderConfigValidator.
    #>
    [void] ValidateOptions() {
        # Normalize paths to absolute paths rooted at the project root
        $this.DataFile       = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($this.DataFile)
        $this.BumpConfigFile = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($this.BumpConfigFile)
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderReleaseOptions

#region Class PSScriptBuilderReleaseDataOperationRequest
<#
.SYNOPSIS
    Encapsulates parameters for a release data operation.
.DESCRIPTION
    The PSScriptBuilderReleaseDataOperationRequest class represents the input parameters for a release data operation,
    including version bumping options, metadata updates, and custom version/metadata values.
#>
class PSScriptBuilderReleaseDataOperationRequest {
    #region Properties
    <#
    .SYNOPSIS
        The type of version bump to apply.
    .DESCRIPTION
        Specifies which component of the semantic version to increment. Use PSScriptBuilderBumpType.None
        when no version bump is requested.
    #>
    [PSScriptBuilderBumpType] $BumpType = [PSScriptBuilderBumpType]::None

    <#
    .SYNOPSIS
        Update build details.
    .DESCRIPTION
        If $true, auto-updates build details (date, time, timestamp, year, month, day, hour, minute, second)
        based on the current UTC time.
    #>
    [bool] $UpdateBuildDetails = $false

    <#
    .SYNOPSIS
        Update git details.
    .DESCRIPTION
        If $true, auto-updates git details (commit, commitShort, branch, tag) from the current git repository.
    #>
    [bool] $UpdateGitDetails = $false

    <#
    .SYNOPSIS
        Prerelease identifier.
    .DESCRIPTION
        Optional prerelease identifier to set (e.g., "alpha.1", "beta", "rc.1").
        Must match pattern: ^[0-9a-zA-Z\-\.]+$ if specified.
    #>
    [string] $Prerelease = $null

    <#
    .SYNOPSIS
        Build metadata value.
    .DESCRIPTION
        Optional build metadata string to set manually (NOT auto-generated).
        This is separate from automatic build metadata updates.
        Must match pattern: ^[0-9a-zA-Z\-\.]+$ if specified.
    #>
    [string] $BuildMetadata = $null

    <#
    .SYNOPSIS
        Clear prerelease identifier.
    .DESCRIPTION
        If $true, clears/removes the prerelease identifier (sets it to $null).
    #>
    [bool] $ClearPrerelease = $false

    <#
    .SYNOPSIS
        Clear build metadata.
    .DESCRIPTION
        If $true, clears/removes the build metadata (sets it to $null).
    #>
    [bool] $ClearBuildMetadata = $false

    <#
    .SYNOPSIS
        Explicit version string to set.
    .DESCRIPTION
        Optional full version string to set directly (e.g., "1.0.0", "2.1.0-beta"). 
        Mutually exclusive with BumpType (Major/Minor/Patch).
    #>
    [string] $Version = $null
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance with default values.
    .DESCRIPTION
        Creates a request with all operations set to false and no custom values.
        Use properties to configure the request.
    #>
    PSScriptBuilderReleaseDataOperationRequest() {
    }

    <#
    .SYNOPSIS
        Initializes a new instance with specified parameters.
    .DESCRIPTION
        Creates a request with the specified version bump and metadata update options.
    .PARAMETER bumpType
        The type of version bump to apply. Use PSScriptBuilderBumpType.None for no bump.
    .PARAMETER updateBuildDetails
        Whether to update build details.
    .PARAMETER updateGitDetails
        Whether to update git details.
    .PARAMETER prerelease
        Optional prerelease identifier as string.
    .PARAMETER buildMetadata
        Optional build metadata value as string.
    .PARAMETER clearPrerelease
        Whether to clear/remove the prerelease identifier.
    .PARAMETER clearBuildMetadata
        Whether to clear/remove the build metadata.
    .PARAMETER version
        Optional explicit version string to set directly (e.g., "1.0.0", "2.1.0-beta").
        Mutually exclusive with bumpType (Major/Minor/Patch).
    #>
    PSScriptBuilderReleaseDataOperationRequest(
        [PSScriptBuilderBumpType] $bumpType,
        [bool]   $updateBuildDetails, 
        [bool]   $updateGitDetails, 
        [string] $prerelease, 
        [string] $buildMetadata,
        [bool]   $clearPrerelease,
        [bool]   $clearBuildMetadata,
        [string] $version
    ) {
        $this.BumpType           = $bumpType
        $this.UpdateBuildDetails = $updateBuildDetails
        $this.UpdateGitDetails   = $updateGitDetails
        $this.Prerelease         = $prerelease
        $this.BuildMetadata      = $buildMetadata
        $this.ClearPrerelease    = $clearPrerelease
        $this.ClearBuildMetadata = $clearBuildMetadata
        $this.Version            = $version
    }

    #endregion Constructors
}
#endregion Class PSScriptBuilderReleaseDataOperationRequest

#region Cmdlet Update-PSScriptBuilderReleaseData
function Update-PSScriptBuilderReleaseData {
    <#
    .SYNOPSIS
        Updates release data including version and metadata.
    .DESCRIPTION
        The Update-PSScriptBuilderReleaseData cmdlet performs atomic release data management operations with 
        transactional semantics and automatic rollback capability. 

        It supports:
        - Semantic version bumping (Major/Minor/Patch)
        - Explicit version setting via -Version (e.g., "1.0.0", "2.1.0-beta")
        - Build metadata updates (automatic or manual)
        - Git metadata updates (automatic from repository)
        - Prerelease and build metadata management

        Operations are transactional with automatic rollback on failure.
    .PARAMETER Major
        Increment the major version (X.0.0). Resets minor and patch to 0.
        Cannot be combined with -Minor or -Patch switches.
    .PARAMETER Minor
        Increment the minor version (0.X.0). Resets patch to 0.
        Cannot be combined with -Major or -Patch switches.
    .PARAMETER Patch
        Increment the patch version (0.0.X).
        Cannot be combined with -Major or -Minor switches.
    .PARAMETER Prerelease
        Set prerelease identifier (e.g., "alpha.1", "beta", "rc.1").
        Must match pattern: ^[0-9a-zA-Z\-\.]+$
        Can be combined with any version type or -BuildMetadata (per SemVer: 1.2.3-alpha+build.123).
    .PARAMETER ClearPrerelease
        Clear/remove the prerelease identifier (set to $null).
        Cannot be combined with -Prerelease.
    .PARAMETER BuildMetadata
        Set build metadata string (NOT auto-update). Can be combined with -Prerelease (per SemVer: 1.2.3-alpha+build.123).
        Must match pattern: ^[0-9a-zA-Z\-\.]+$
        Different from -UpdateBuildDetails switch.
    .PARAMETER ClearBuildMetadata
        Clear/remove the build metadata (set to $null).
        Cannot be combined with -BuildMetadata.
    .PARAMETER UpdateBuildDetails
        Auto-update build details including:
        - Date, time, timestamp, year, month, day, hour, minute, second
        - Incrementing build number by 1
        Can be combined with version bumps or used standalone.
    .PARAMETER Version
        Set an explicit version string (e.g., "1.0.0", "2.1.0-beta", "v1.0.0").
        Supports SemVer formats including prerelease and build metadata.
        Cannot be combined with -Major, -Minor, or -Patch.
    .PARAMETER UpdateGitDetails
        Auto-update git details (commit hash, short commit, branch, latest tag) from repository.
        Requires git command availability.
        Can be combined with -Version or version bumps or used standalone.
    .OUTPUTS
        PSScriptBuilderReleaseDataResult
    .EXAMPLE
        # Bump major version and update build details (date, time, number)
        Update-PSScriptBuilderReleaseData -Major -UpdateBuildDetails
    .EXAMPLE
        # Bump minor version with prerelease and preview changes
        Update-PSScriptBuilderReleaseData -Minor -Prerelease "beta.1" -WhatIf
    .EXAMPLE
        # Set version directly to 1.0.0 and update build details
        Update-PSScriptBuilderReleaseData -Version "1.0.0" -UpdateBuildDetails
    .EXAMPLE
        # Update only git details from repository
        Update-PSScriptBuilderReleaseData -UpdateGitDetails
    .NOTES
        - Requires configuration to be loaded (PSScriptBuilderConfiguration.GetCurrent())
        - Requires release data file to exist
        - Supports PowerShell's ShouldProcess pattern (-Confirm, -WhatIf)
        - Automatic rollback on failure restores all modified files
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Bump')]
    [OutputType([PSScriptBuilderReleaseDataResult])]
    param(
        # Version Type Parameters (ParameterSet: Bump)
        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [switch] $Major,

        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [switch] $Minor,

        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [switch] $Patch,

        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [ValidatePattern('^[vV]?\d+(\.\d+){0,3}(-[0-9a-zA-Z\-\.]+)?(\+[0-9a-zA-Z\-\.]+)?$')]
        [string] $Version,

        # Details Parameters (can be combined with Bump or used in Details set)
        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Details')]
        [ValidatePattern('^[0-9a-zA-Z\-\.]+$')]
        [string] $Prerelease,

        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Details')]
        [switch] $ClearPrerelease,

        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Details')]
        [ValidatePattern('^[0-9a-zA-Z\-\.]+$')]
        [string] $BuildMetadata,

        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Details')]
        [switch] $ClearBuildMetadata,

        # Metadata Update Switches
        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Details')]
        [switch] $UpdateBuildDetails,

        [Parameter(Mandatory = $false, ParameterSetName = 'Bump')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Details')]
        [switch] $UpdateGitDetails
    )

    begin {
        # Step 1: 
        # Validate that only one of the version bump switches is specified (Major, Minor, Patch)
        $versionBumpCount = @($Major, $Minor, $Patch | Where-Object { $_ }).Count

        if ($versionBumpCount -gt 1) {
            $message = "Only one version type can be specified (Major, Minor, or Patch). Cannot combine multiple version bumps."
            throw [InvalidOperationException]::new($message)
        }

        # Validate that -Version cannot be combined with -Major/-Minor/-Patch
        $hasVersionParam = $PSBoundParameters.ContainsKey('Version') -and -not [string]::IsNullOrEmpty($Version)

        if ($hasVersionParam -and $versionBumpCount -gt 0) {
            $message = "Cannot combine -Version with -Major, -Minor, or -Patch. Use -Version to set an explicit version or use a bump switch."
            throw [InvalidOperationException]::new($message)
        }

        # Step 2: 
        # Validate that set parameters cannot be combined with their respective clear switches
        $hasPrereleaseParam         = $PSBoundParameters.ContainsKey('Prerelease')         -and -not [string]::IsNullOrEmpty($Prerelease)
        $hasBuildMetadataParam      = $PSBoundParameters.ContainsKey('BuildMetadata')      -and -not [string]::IsNullOrEmpty($BuildMetadata)
        $hasClearPrereleaseParam    = $PSBoundParameters.ContainsKey('ClearPrerelease')    -and $ClearPrerelease
        $hasClearBuildMetadataParam = $PSBoundParameters.ContainsKey('ClearBuildMetadata') -and $ClearBuildMetadata

        if ($hasPrereleaseParam -and $hasClearPrereleaseParam) {
            $message = "Cannot use both -Prerelease and -ClearPrerelease simultaneously. Use one or the other."
            throw [InvalidOperationException]::new($message)
        }

        if ($hasBuildMetadataParam -and $hasClearBuildMetadataParam) {
            $message = "Cannot use both -BuildMetadata and -ClearBuildMetadata simultaneously. Use one or the other."
            throw [InvalidOperationException]::new($message)
        }

        # Step 3: 
        # Validate that at least one operation is specified (version bump or details update)
        $hasVersionOperation = 
            $Major -or 
            $Minor -or 
            $Patch -or
            $hasVersionParam

        $hasDetailsOperation = 
            $UpdateBuildDetails                             -or 
            $UpdateGitDetails                               -or 
            $PSBoundParameters.ContainsKey('BuildMetadata') -or 
            $PSBoundParameters.ContainsKey('Prerelease')    -or
            $ClearPrerelease                                -or
            $ClearBuildMetadata

        if (-not $hasVersionOperation -and -not $hasDetailsOperation) {
            $message = 
                "Specify at least one version type (Major/Minor/Patch/Version) or at least one detail update " + 
                "(UpdateBuildDetails/UpdateGitDetails/BuildMetadata/Prerelease/ClearPrerelease/ClearBuildMetadata)"
            throw [InvalidOperationException]::new($message)
        }
    }

    process {
        try {
            # Step 1: Create orchestrator (loads configuration automatically)
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            # Step 2: Build operation request object
            $bumpType = [PSScriptBuilderBumpType]::None
            if ($Major) { $bumpType = [PSScriptBuilderBumpType]::Major }
            if ($Minor) { $bumpType = [PSScriptBuilderBumpType]::Minor }
            if ($Patch) { $bumpType = [PSScriptBuilderBumpType]::Patch }

            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                $bumpType,
                $UpdateBuildDetails,
                $UpdateGitDetails,
                $(if ($PSBoundParameters.ContainsKey('Prerelease'))    { $Prerelease }    else { $null }),
                $(if ($PSBoundParameters.ContainsKey('BuildMetadata')) { $BuildMetadata } else { $null }),
                $ClearPrerelease,
                $ClearBuildMetadata,
                $(if ($hasVersionParam) { $Version } else { $null })
            )

            # Step 3: Execute the operation (calculate changes)
            $result = $orchestrator.ExecuteReleaseDataUpdate($request)

            # Step 4: Persist changes only if ShouldProcess returns true
            if ($PSCmdlet.ShouldProcess("Release data", "Persist changes to release data file")) {
                $orchestrator.PersistReleaseDataChanges()
            }

            # Step 5: Return the result object
            return $result
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Update-PSScriptBuilderReleaseData

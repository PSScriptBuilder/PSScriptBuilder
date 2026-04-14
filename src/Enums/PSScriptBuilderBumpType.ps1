#region Enum PSScriptBuilderBumpType
<#
.SYNOPSIS
    Defines the types of version bumps for PSScriptBuilder release management.
.DESCRIPTION
    The PSScriptBuilderBumpType enumeration defines the different semantic versioning bump types that can be 
    applied to a release. Each type increments a specific component of the version number according to 
    semantic versioning standards:
    - None:  No version bump (default value)
    - Major: Increments X in X.Y.Z (Y and Z reset to 0)
    - Minor: Increments Y in X.Y.Z (Z resets to 0)
    - Patch: Increments Z in X.Y.Z
#>
enum PSScriptBuilderBumpType {
    <#
    .SYNOPSIS
        No version bump.
    .DESCRIPTION
        Default value. Indicates that no version bump is requested.
    #>
    None = 0

    <#
    .SYNOPSIS
        Major version bump
    .DESCRIPTION
        Increments the major version number and resets minor and patch to 0.
        Example: 1.2.3 -> 2.0.0
        Use when: Making incompatible API changes
    #>
    Major = 1

    <#
    .SYNOPSIS
        Minor version bump
    .DESCRIPTION
        Increments the minor version number and resets patch to 0.
        Example: 1.2.3 -> 1.3.0
        Use when: Adding functionality in a backward compatible manner
    #>
    Minor = 2

    <#
    .SYNOPSIS
        Patch version bump
    .DESCRIPTION
        Increments the patch version number.
        Example: 1.2.3 -> 1.2.4
        Use when: Making backward compatible bug fixes
    #>
    Patch = 3
}
#endregion Enum PSScriptBuilderBumpType

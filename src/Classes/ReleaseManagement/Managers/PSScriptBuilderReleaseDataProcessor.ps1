using namespace System
using namespace System.Collections.Generic
using namespace System.Collections.Specialized

#region Class PSScriptBuilderReleaseDataProcessor
<#
.SYNOPSIS
    Manages release data business logic.
.DESCRIPTION
    The PSScriptBuilderReleaseDataProcessor class handles release data processing operations including setting versions,
    bumping version numbers, and managing release metadata. It works with release data directly without I/O concerns.
#>
class PSScriptBuilderReleaseDataProcessor {
    #region Properties
    <#
    .SYNOPSIS
        Holds the release data.
    .DESCRIPTION
        The ReleaseData property is a PSCustomObject that contains the version information, build metadata, and 
        Git metadata.
    #>
    [PSCustomObject] $ReleaseData
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderReleaseDataProcessor class.
    .DESCRIPTION
        The constructor initializes the release data with default values or from a provided PSCustomObject.
    #>
    PSScriptBuilderReleaseDataProcessor() {
        $this.InitializeReleaseData()
    }

    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderReleaseDataProcessor class with provided release data.
    .DESCRIPTION
        The constructor takes a PSCustomObject containing release data and initializes the class instance.
    .PARAMETER releaseData
        A PSCustomObject containing the release data.
    #>
    PSScriptBuilderReleaseDataProcessor([PSCustomObject] $releaseData) {
        $this.ReleaseData = $this.CloneReleaseData($releaseData)
    }
    #endregion Constructors

    #region Methods
    #region Initialization
    <#
    .SYNOPSIS
        Initializes the release data with default values.
    .DESCRIPTION
        The InitializeReleaseData method sets up the ReleaseData property with default version numbers, 
        build metadata, and Git metadata.
    #>
    [void] InitializeReleaseData() {
        $this.ReleaseData = [PSCustomObject] @{
            version = [PSCustomObject] @{
                major         = 0
                minor         = 1
                patch         = 0
                prerelease    = $null
                buildmetadata = $null
                full          = '0.1.0'
            }
            build = [PSCustomObject] @{
                number        = 0
                date          = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
                time          = [DateTime]::UtcNow.ToString('HH:mm:ss')
                timestamp     = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssK')
                year          = [DateTime]::UtcNow.Year
                month         = [DateTime]::UtcNow.Month
                day           = [DateTime]::UtcNow.Day
                hour          = [DateTime]::UtcNow.Hour
                minute        = [DateTime]::UtcNow.Minute
                second        = [DateTime]::UtcNow.Second
            }
            git = [PSCustomObject] @{
                commit        = $null
                commitShort   = $null
                branch        = $null
                tag           = $null
            }
        }
    }
    #endregion Initialization

    #region Release Data Management
    <#
    .SYNOPSIS
        Sets the version numbers.
    .DESCRIPTION
        The SetVersion method sets the major, minor, and patch version numbers to the specified values. 
        It validates that the provided numbers are non-negative integers.
    .PARAMETER major
        The major version number as an integer.
    .PARAMETER minor
        The minor version number as an integer.
    .PARAMETER patch
        The patch version number as an integer.
    #>
    [void] SetVersion([int] $major, [int] $minor, [int] $patch) {
        $isValid = ($major -ge 0) -and ($minor -ge 0) -and ($patch -ge 0)

        if (-not $isValid) {
            $message = "Failed to set version. Major, minor, and patch must be non-negative integers. Provided: major=$major, minor=$minor, patch=$patch"
            throw [ArgumentException]::new($message)
        }

        $this.ReleaseData.version.major = $major
        $this.ReleaseData.version.minor = $minor
        $this.ReleaseData.version.patch = $patch

        # Since version numbers are part of the full version string, we need to update it whenever they change
        $this.UpdateFullVersion()
    }

    <#
    .SYNOPSIS
        Sets the version numbers from a flexible version string.
    .DESCRIPTION
        The SetVersion method parses a version string in various formats (e.g., "1.2.3", "1.2", "1", "1.2.3.4", 
        "1.2.3-beta"). It extracts the major, minor, patch, prerelease, and buildmetadata components and updates 
        the release data accordingly.
    .PARAMETER versionString
        The version string to parse and set.
    #>
    [void] SetVersion([string] $versionString) {
        if ([string]::IsNullOrEmpty($versionString)) {
            throw [ArgumentNullException]::new("versionString", "Version string cannot be null or empty")
        }

        $normalized = $versionString.Trim() -replace '^[vV]', ''

        $parsers = @(
            @{ 
                Pattern = '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:-(?<prerelease>[a-zA-Z0-9\-\.]+))?(?:\+(?<buildmetadata>[a-zA-Z0-9\-\.]+))?$'
                Extract = { 
                    param($m)
                    @{ 
                        major         = $m.Groups['major'].Value
                        minor         = $m.Groups['minor'].Value
                        patch         = $m.Groups['patch'].Value
                        prerelease    = $m.Groups['prerelease'].Value
                        buildmetadata = $m.Groups['buildmetadata'].Value
                    } 
                } 
            },
            @{ 
                Pattern = '^(?<major>\d+)\.(?<minor>\d+)(?:-(?<prerelease>[a-zA-Z0-9\-\.]+))?(?:\+(?<buildmetadata>[a-zA-Z0-9\-\.]+))?$'
                Extract = { 
                    param($m)
                    @{ 
                        major         = $m.Groups['major'].Value
                        minor         = $m.Groups['minor'].Value
                        patch         = 0
                        prerelease    = $m.Groups['prerelease'].Value
                        buildmetadata = $m.Groups['buildmetadata'].Value 
                    } 
                } 
            },
            @{ 
                Pattern = '^(?<major>\d+)(?:-(?<prerelease>[a-zA-Z0-9\-\.]+))?(?:\+(?<buildmetadata>[a-zA-Z0-9\-\.]+))?$'
                Extract = { 
                    param($m)
                    @{ 
                        major         = $m.Groups['major'].Value
                        minor         = 0
                        patch         = 0
                        prerelease    = $m.Groups['prerelease'].Value
                        buildmetadata = $m.Groups['buildmetadata'].Value 
                    } 
                } 
            },
            @{ 
                Pattern = '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)?(?:\+(?<buildmetadata>[a-zA-Z0-9\-\.]+))?$'
                Extract = { 
                    param($m)
                    @{ 
                        major         = $m.Groups['major'].Value
                        minor         = $m.Groups['minor'].Value
                        patch         = $m.Groups['patch'].Value
                        prerelease    = $null
                        buildmetadata = $m.Groups['buildmetadata'].Value 
                    } 
                } 
            }
        )

        foreach ($parser in $parsers) {
            $match = [regex]::Match($normalized, $parser.Pattern)

            if ($match.Success) {
                $result = & $parser.Extract $match

                $this.ReleaseData.version.major         = [int] $result.major
                $this.ReleaseData.version.minor         = [int] $result.minor
                $this.ReleaseData.version.patch         = [int] $result.patch
                $this.ReleaseData.version.prerelease    =       $result.prerelease
                $this.ReleaseData.version.buildmetadata =       $result.buildmetadata

                $this.UpdateFullVersion()
                return
            }
        }

        $message = 
            "Failed to set version. Invalid format: '$versionString'. " + 
            "Supported examples: '1.2.3', '1.2', '1', '1.2.3.4', '1.2.3-beta'."
        throw [FormatException]::new($message)
    }

    <#
    .SYNOPSIS
        Sets the prerelease identifier.
    .DESCRIPTION
        The SetPrerelease method sets the prerelease identifier to the specified value. It validates that the 
        provided string matches the allowed format.
    .PARAMETER prerelease
        The prerelease identifier as a string.
    #>
    [void] SetPrerelease([string] $prerelease) {
        if (-not [string]::IsNullOrWhiteSpace($prerelease)) {
            $pattern = '^[a-zA-Z0-9\-\.]+$'

            if (-not ($prerelease -match $pattern)) {
                throw [FormatException]::new("Failed to set prerelease. Invalid format: '$prerelease'.")
            }
        }

        $this.ReleaseData.version.prerelease = $prerelease

        # Prerelease is part of the full version string, so we need to update it whenever prerelease changes
        $this.UpdateFullVersion()
    }

    <#
    .SYNOPSIS
        Sets the build metadata.
    .DESCRIPTION
        The SetBuildMetadata method sets the build metadata to the specified value. It validates that the 
        provided string matches the allowed format.
    .PARAMETER buildMetadata
        The build metadata as a string.
    #>
    [void] SetBuildMetadata([string] $buildMetadata) {
        if (-not [string]::IsNullOrWhiteSpace($buildMetadata)) {
            $pattern = '^[a-zA-Z0-9\-\.]+$'

            if (-not ($buildMetadata -match $pattern)) {
                throw [FormatException]::new("Failed to set build metadata. Invalid format: '$buildMetadata'.")
            }
        }

        $this.ReleaseData.version.buildmetadata = $buildMetadata

        # Build metadata is part of the full version string, so we need to update it whenever build metadata changes
        $this.UpdateFullVersion()
    }

    <#
    .SYNOPSIS
        Sets the build number to a specific value.
    .DESCRIPTION
        The SetBuildNumber method sets the build number to the specified value. It validates that the provided 
        number is greater than zero.
    .PARAMETER buildNumber
        The build number as an integer.
    #>
    [void] SetBuildNumber([int] $buildNumber) {
        if ($buildNumber -lt 1) {
            throw [ArgumentException]::new("Failed to set build number. Build number must be greater than 0.")
        }

        $this.ReleaseData.build.number = $buildNumber
    }

    <#
    .SYNOPSIS
        Increments the major version number and resets minor and patch.
    .DESCRIPTION
        The BumpMajor method increments the major version number by one and resets the minor and patch 
        numbers to zero.
    #>
    [void] BumpMajor() {
        $this.ReleaseData.version.major++
        $this.ReleaseData.version.minor = 0
        $this.ReleaseData.version.patch = 0

        # Since major version is part of the full version string, we need to update it whenever major version changes
        $this.UpdateFullVersion()
    }

    <#
    .SYNOPSIS
        Increments the minor version number and resets patch.
    .DESCRIPTION
        The BumpMinor method increments the minor version number by one and resets the patch number to zero.
    #>
    [void] BumpMinor() {
        $this.ReleaseData.version.minor++
        $this.ReleaseData.version.patch = 0

        # Since minor version is part of the full version string, we need to update it whenever minor version changes
        $this.UpdateFullVersion()
    }

    <#
    .SYNOPSIS
        Increments the patch version number.
    .DESCRIPTION
        The BumpPatch method increments the patch version number by one.
    #>
    [void] BumpPatch() {
        $this.ReleaseData.version.patch++

        # Since patch version is part of the full version string, we need to update it whenever patch version changes
        $this.UpdateFullVersion()
    }

    <#
    .SYNOPSIS
        Increments the build number.
    .DESCRIPTION
        The BumpBuild method increments the build number by one.
    #>
    [void] BumpBuild() {
        $this.ReleaseData.build.number++
    }

    <#
    .SYNOPSIS
        Updates build details and increments build number.
    .DESCRIPTION
        The UpdateBuildDetails method increments the build number by 1 and sets the build detail fields such as 
        date, time, timestamp, year, month, day, hour, minute, and second based on the current UTC date and time.
    #>
    [void] UpdateBuildDetails() {
        $now = [DateTime]::UtcNow

        # Update build number
        $this.ReleaseData.build.number++

        # Update build date and time details
        $this.ReleaseData.build.date      = $now.ToString('yyyy-MM-dd')
        $this.ReleaseData.build.time      = $now.ToString('HH:mm:ss')
        $this.ReleaseData.build.day       = $now.Day
        $this.ReleaseData.build.month     = $now.Month
        $this.ReleaseData.build.year      = $now.Year
        $this.ReleaseData.build.hour      = $now.Hour
        $this.ReleaseData.build.minute    = $now.Minute
        $this.ReleaseData.build.second    = $now.Second
        $this.ReleaseData.build.timestamp = $now.ToString('yyyy-MM-ddTHH:mm:ssK')
    }

    <#
    .SYNOPSIS
        Updates Git details from the current Git repository.
    .DESCRIPTION
        The UpdateGitDetails method retrieves the current Git commit hash, short commit hash, branch name 
        and latest tag from the Git repository and updates the release data accordingly.
    #>
    [void] UpdateGitDetails() {
        if (-not (Get-Command -Name 'git' -ErrorAction SilentlyContinue)) {
            return
        }

        try {
            $commitResult      = git rev-parse HEAD 2>$null
            $commitShortResult = git rev-parse --short HEAD 2>$null
            $branchResult      = git rev-parse --abbrev-ref HEAD 2>$null
            $tagResult         = git describe --tags --abbrev=0 2>$null

            $this.ReleaseData.git.commit      = if ($null -ne $commitResult)      { $commitResult.Trim()      } else { $null }
            $this.ReleaseData.git.commitShort = if ($null -ne $commitShortResult) { $commitShortResult.Trim() } else { $null }
            $this.ReleaseData.git.branch      = if ($null -ne $branchResult)      { $branchResult.Trim()      } else { $null }
            $this.ReleaseData.git.tag         = if ($null -ne $tagResult)         { $tagResult.Trim()         } else { $null }
        }
        catch {
            Write-Verbose "Git metadata could not be retrieved: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Updates the full version string based on current version components.
    .DESCRIPTION
        The UpdateFullVersion method constructs the full version string from the major, minor, patch, 
        prerelease, and buildmetadata components and updates the ReleaseData property.
    #>
    [void] UpdateFullVersion() {
        $major         = $this.ReleaseData.version.major
        $minor         = $this.ReleaseData.version.minor
        $patch         = $this.ReleaseData.version.patch
        $prerelease    = $this.ReleaseData.version.prerelease
        $buildMetadata = $this.ReleaseData.version.buildmetadata

        $fullVersion = "{0}.{1}.{2}" -f $major, $minor, $patch

        if ($prerelease) {
            $fullVersion += "-{0}" -f $prerelease
        }

        if ($buildMetadata) {
            $fullVersion += "+{0}" -f $buildMetadata
        }

        $this.ReleaseData.version.full = $fullVersion
    }
    #endregion Release Data Management

    #region Getters
    <#
    .SYNOPSIS
        Gets the major version number.
    .DESCRIPTION
        The GetMajor method retrieves the major version number from the release data.
    .OUTPUTS
        Returns the major version number as an integer.
    #>
    [int] GetMajor() {
        return $this.ReleaseData.version.major
    }

    <#
    .SYNOPSIS
        Gets the minor version number.
    .DESCRIPTION
        The GetMinor method retrieves the minor version number from the release data.
    .OUTPUTS
        Returns the minor version number as an integer.
    #>
    [int] GetMinor() {
        return $this.ReleaseData.version.minor
    }

    <#
    .SYNOPSIS
        Gets the patch version number.
    .DESCRIPTION
        The GetPatch method retrieves the patch version number from the release data.
    .OUTPUTS
        Returns the patch version number as an integer.
    #>
    [int] GetPatch() {
        return $this.ReleaseData.version.patch
    }

    <#
    .SYNOPSIS
        Gets the prerelease identifier.
    .DESCRIPTION
        The GetPrerelease method retrieves the prerelease identifier from the release data.
    .OUTPUTS
        Returns the prerelease identifier as a string.
    #>
    [string] GetPrerelease() {
        return $this.ReleaseData.version.prerelease
    }

    <#
    .SYNOPSIS
        Gets the build metadata.
    .DESCRIPTION
        The GetBuildMetadata method retrieves the build metadata from the release data.
    .OUTPUTS
        Returns the build metadata as a string.
    #>
    [string] GetBuildMetadata() {
        return $this.ReleaseData.version.buildmetadata
    }

    <#
    .SYNOPSIS
        Gets the full version string.
    .DESCRIPTION
        The GetFullVersion method retrieves the full version string from the release data.
    .OUTPUTS
        Returns the full version string as a string.
    #>
    [string] GetFullVersion() {
        return $this.ReleaseData.version.full
    }

    <#
    .SYNOPSIS
        Gets the build number.
    .DESCRIPTION
        The GetBuildNumber method retrieves the build number from the release data.
    .OUTPUTS
        Returns the build number as an integer.
    #>
    [int] GetBuildNumber() {
        return $this.ReleaseData.build.number
    }

    <#
    .SYNOPSIS
        Gets a copy of the complete release data object.
    .DESCRIPTION
        The GetReleaseData method retrieves a PSCustomObject containing the complete release data, including 
        version components, build metadata, and Git metadata.
    .OUTPUTS
        Returns a PSCustomObject containing the release data.
    #>
    [PSCustomObject] GetReleaseData() {
        return $this.CloneReleaseData($this.ReleaseData)
    }
    #endregion Getters

    #region Data Formatting
    <#
    .SYNOPSIS
        Gets release data with formatted property names (PascalCase hierarchy).
    .DESCRIPTION
        The GetReleaseDataFormatted method returns a hierarchical PSCustomObject with PascalCase property names.
        The structure preserves the three-level hierarchy: Version, Build, and Git sections.
        This is useful for structured access to typed data.
    .OUTPUTS
        Returns a PSCustomObject with structure:
        - Version: { Major, Minor, Patch, Prerelease, Build, Full }
        - Build: { Number, Date, Time, Timestamp, Year, Month, Day, Hour, Minute, Second }
        - Git: { Commit, CommitShort, Branch, Tag }
    #>
    [PSCustomObject] GetReleaseDataFormatted() {
        return [PSCustomObject] @{
            Version = [PSCustomObject] @{
                Major         = $this.ReleaseData.version.major
                Minor         = $this.ReleaseData.version.minor
                Patch         = $this.ReleaseData.version.patch
                Full          = $this.ReleaseData.version.full
                Prerelease    = $this.ReleaseData.version.prerelease
                BuildMetadata = $this.ReleaseData.version.buildmetadata
            }
            Build = [PSCustomObject] @{
                Date          = $this.ReleaseData.build.date
                Time          = $this.ReleaseData.build.time
                Day           = $this.ReleaseData.build.day
                Month         = $this.ReleaseData.build.month
                Year          = $this.ReleaseData.build.year
                Hour          = $this.ReleaseData.build.hour
                Minute        = $this.ReleaseData.build.minute
                Second        = $this.ReleaseData.build.second
                Timestamp     = $this.ReleaseData.build.timestamp
                Number        = $this.ReleaseData.build.number
            }
            Git = [PSCustomObject] @{
                Commit        = $this.ReleaseData.git.commit
                CommitShort   = $this.ReleaseData.git.commitShort
                Branch        = $this.ReleaseData.git.branch
                Tag           = $this.ReleaseData.git.tag
            }
        }
    }

    <#
    .SYNOPSIS
        Gets release data as a flat single-level ordered dictionary.
    .DESCRIPTION
        The GetReleaseDataFlattened method returns a flat OrderedDictionary with all release data on a single level.
        All properties are prefixed with their category (Version*, Build*, Git*) to avoid naming conflicts.
        The OrderedDictionary maintains categorical ordering: Build, Git, Version.
        This format is useful for sorting, tabular display, or when a flat structure is preferred.
    .OUTPUTS
        Returns an OrderedDictionary with flat structure:
        VersionMajor, VersionMinor, VersionPatch, VersionPrerelease, VersionBuild, VersionFull,
        BuildNumber, BuildDate, BuildTime, BuildTimestamp, BuildYear, BuildMonth, BuildDay, BuildHour, BuildMinute, BuildSecond,
        GitCommit, GitCommitShort, GitBranch, GitTag
    #>
    [OrderedDictionary] GetReleaseDataFlattened() {
        return [ordered] @{
            VersionMajor         = $this.ReleaseData.version.major
            VersionMinor         = $this.ReleaseData.version.minor
            VersionPatch         = $this.ReleaseData.version.patch
            VersionFull          = $this.ReleaseData.version.full
            VersionPrerelease    = $this.ReleaseData.version.prerelease
            VersionBuildMetadata = $this.ReleaseData.version.buildmetadata
            BuildDate            = $this.ReleaseData.build.date
            BuildTime            = $this.ReleaseData.build.time
            BuildDay             = $this.ReleaseData.build.day
            BuildMonth           = $this.ReleaseData.build.month
            BuildYear            = $this.ReleaseData.build.year
            BuildHour            = $this.ReleaseData.build.hour
            BuildMinute          = $this.ReleaseData.build.minute
            BuildSecond          = $this.ReleaseData.build.second
            BuildTimestamp       = $this.ReleaseData.build.timestamp
            BuildNumber          = $this.ReleaseData.build.number
            GitCommit            = $this.ReleaseData.git.commit
            GitCommitShort       = $this.ReleaseData.git.commitShort
            GitBranch            = $this.ReleaseData.git.branch
            GitTag               = $this.ReleaseData.git.tag
        }
    }
    #endregion Data Formatting

    #region Cloning
    <#
    .SYNOPSIS
        Creates a deep clone of the release data object.
    .DESCRIPTION
        The CloneReleaseData method creates a new PSCustomObject with the same values as the provided
        release data. This avoids JSON roundtrip serialization, which in PowerShell 7 causes ISO 8601
        timestamp strings to be deserialized as DateTime objects.
    .PARAMETER data
        The release data to clone as a PSCustomObject.
    .OUTPUTS
        Returns a new PSCustomObject with the same values as the provided release data.
    #>
    hidden [PSCustomObject] CloneReleaseData([PSCustomObject] $data) {
        return [PSCustomObject] @{
            version = [PSCustomObject] @{
                major         = $data.version.major
                minor         = $data.version.minor
                patch         = $data.version.patch
                prerelease    = $data.version.prerelease
                buildmetadata = $data.version.buildmetadata
                full          = $data.version.full
            }
            build = [PSCustomObject] @{
                number        = $data.build.number
                date          = $data.build.date
                time          = $data.build.time
                timestamp     = $data.build.timestamp
                year          = $data.build.year
                month         = $data.build.month
                day           = $data.build.day
                hour          = $data.build.hour
                minute        = $data.build.minute
                second        = $data.build.second
            }
            git = [PSCustomObject] @{
                commit        = $data.git.commit
                commitShort   = $data.git.commitShort
                branch        = $data.git.branch
                tag           = $data.git.tag
            }
        }
    }
    #endregion Cloning
    #endregion Methods
}
#endregion Class PSScriptBuilderReleaseDataProcessor

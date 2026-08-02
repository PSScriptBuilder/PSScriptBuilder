using namespace System

Describe 'PSScriptBuilderReleaseDataProcessor' {

    BeforeAll {
        Function New-ReleaseData {
            param(
                [int]    $Major = 1,
                [int]    $Minor = 0,
                [int]    $Patch = 0,
                [int]    $BuildNumber = 0,
                [string] $Prerelease = $null,
                [string] $BuildMetadata = $null
            )
            return [PSCustomObject] @{
                version = [PSCustomObject] @{
                    major         = $Major
                    minor         = $Minor
                    patch         = $Patch
                    prerelease    = $Prerelease
                    buildmetadata = $BuildMetadata
                    full          = "$Major.$Minor.$Patch"
                }
                build = [PSCustomObject] @{
                    number    = $BuildNumber
                    date      = '2026-01-01'
                    time      = '00:00:00'
                    timestamp = '2026-01-01T00:00:00Z'
                    year      = 2026
                    month     = 1
                    day       = 1
                    hour      = 0
                    minute    = 0
                    second    = 0
                }
                git = [PSCustomObject] @{
                    commit      = $null
                    commitShort = $null
                    branch      = $null
                    tag         = $null
                }
            }
        }

        Function New-Proc {
            param(
                [int]    $Major = 1,
                [int]    $Minor = 0,
                [int]    $Patch = 0,
                [int]    $BuildNumber = 0,
                [string] $Prerelease = $null,
                [string] $BuildMetadata = $null
            )
            $data = New-ReleaseData @PSBoundParameters
            return [PSScriptBuilderReleaseDataProcessor]::new($data)
        }
    }

    Context 'Constructor - parameterless (default values)' {

        It 'Should initialise with default version 0.1.0' {
            $proc = [PSScriptBuilderReleaseDataProcessor]::new()

            $proc.ReleaseData.version.major | Should -Be 0
            $proc.ReleaseData.version.minor | Should -Be 1
            $proc.ReleaseData.version.patch | Should -Be 0
            $proc.ReleaseData.version.full  | Should -Be '0.1.0'
        }

        It 'Should initialise build number to 0' {
            $proc = [PSScriptBuilderReleaseDataProcessor]::new()

            $proc.ReleaseData.build.number | Should -Be 0
        }

        It 'Should initialise git fields to null' {
            $proc = [PSScriptBuilderReleaseDataProcessor]::new()

            $proc.ReleaseData.git.commit      | Should -BeNullOrEmpty
            $proc.ReleaseData.git.commitShort | Should -BeNullOrEmpty
            $proc.ReleaseData.git.branch      | Should -BeNullOrEmpty
            $proc.ReleaseData.git.tag         | Should -BeNullOrEmpty
        }
    }

    Context 'Constructor - with release data' {

        It 'Should copy the provided release data' {
            $data = New-ReleaseData -Major 2 -Minor 3 -Patch 4
            $proc = [PSScriptBuilderReleaseDataProcessor]::new($data)

            $proc.ReleaseData.version.major | Should -Be 2
            $proc.ReleaseData.version.minor | Should -Be 3
            $proc.ReleaseData.version.patch | Should -Be 4
        }

        It 'Should deep-copy the data so mutations do not affect the original' {
            $data = New-ReleaseData -Major 1 -Minor 0 -Patch 0
            $proc = [PSScriptBuilderReleaseDataProcessor]::new($data)

            $proc.BumpPatch()

            $data.version.patch | Should -Be 0
        }
    }

    Context 'SetVersion (integers)' {

        It 'Should set all three version components' {
            $proc = New-Proc

            $proc.SetVersion(3, 2, 1)

            $proc.ReleaseData.version.major | Should -Be 3
            $proc.ReleaseData.version.minor | Should -Be 2
            $proc.ReleaseData.version.patch | Should -Be 1
        }

        It 'Should update the full version string' {
            $proc = New-Proc

            $proc.SetVersion(3, 2, 1)

            $proc.ReleaseData.version.full | Should -Be '3.2.1'
        }

        It 'Should accept zero for all components' {
            $proc = New-Proc

            { $proc.SetVersion(0, 0, 0) } | Should -Not -Throw
        }

        It 'Should throw ArgumentException for negative version numbers' {
            $proc = New-Proc

            { $proc.SetVersion(-1, 0, 0) } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'SetVersion (string)' {

        It 'Should parse a standard MAJOR.MINOR.PATCH string' {
            $proc = New-Proc

            $proc.SetVersion('2.5.3')

            $proc.ReleaseData.version.major | Should -Be 2
            $proc.ReleaseData.version.minor | Should -Be 5
            $proc.ReleaseData.version.patch | Should -Be 3
            $proc.ReleaseData.version.full  | Should -Be '2.5.3'
        }

        It 'Should leave prerelease as null when version string has no prerelease' {
            $proc = New-Proc

            $proc.SetVersion('1.1.1')

            $proc.ReleaseData.version.prerelease | Should -BeNullOrEmpty
        }

        It 'Should leave buildmetadata as null when version string has no buildmetadata' {
            $proc = New-Proc

            $proc.SetVersion('1.1.1')

            $proc.ReleaseData.version.buildmetadata | Should -BeNullOrEmpty
        }

        It 'Should parse a version string with prerelease' {
            $proc = New-Proc

            $proc.SetVersion('1.0.0-beta.1')

            $proc.ReleaseData.version.prerelease | Should -Be 'beta.1'
            $proc.ReleaseData.version.full        | Should -Be '1.0.0-beta.1'
        }

        It 'Should strip a leading v prefix' {
            $proc = New-Proc

            $proc.SetVersion('v1.2.3')

            $proc.ReleaseData.version.full | Should -Be '1.2.3'
        }

        It 'Should parse a MAJOR.MINOR string and default patch to 0' {
            $proc = New-Proc

            $proc.SetVersion('4.2')

            $proc.ReleaseData.version.patch | Should -Be 0
            $proc.ReleaseData.version.full  | Should -Be '4.2.0'
        }

        It 'Should throw FormatException for an invalid version string' {
            $proc = New-Proc

            { $proc.SetVersion('not-a-version') } | Should -Throw -ExceptionType ([FormatException])
        }

        It 'Should throw for null or empty version string' {
            $proc = New-Proc

            { $proc.SetVersion('') } | Should -Throw
        }
    }

    Context 'BumpMajor' {

        It 'Should increment major and reset minor and patch to zero' {
            $proc = New-Proc -Major 1 -Minor 2 -Patch 3

            $proc.BumpMajor()

            $proc.ReleaseData.version.major | Should -Be 2
            $proc.ReleaseData.version.minor | Should -Be 0
            $proc.ReleaseData.version.patch | Should -Be 0
            $proc.ReleaseData.version.full  | Should -Be '2.0.0'
        }
    }

    Context 'BumpMinor' {

        It 'Should increment minor and reset patch to zero' {
            $proc = New-Proc -Major 1 -Minor 2 -Patch 3

            $proc.BumpMinor()

            $proc.ReleaseData.version.minor | Should -Be 3
            $proc.ReleaseData.version.patch | Should -Be 0
            $proc.ReleaseData.version.full  | Should -Be '1.3.0'
        }

        It 'Should not change major version' {
            $proc = New-Proc -Major 2 -Minor 0 -Patch 0

            $proc.BumpMinor()

            $proc.ReleaseData.version.major | Should -Be 2
        }
    }

    Context 'BumpPatch' {

        It 'Should increment patch by one' {
            $proc = New-Proc -Major 1 -Minor 0 -Patch 5

            $proc.BumpPatch()

            $proc.ReleaseData.version.patch | Should -Be 6
            $proc.ReleaseData.version.full  | Should -Be '1.0.6'
        }

        It 'Should not change major or minor' {
            $proc = New-Proc -Major 2 -Minor 3 -Patch 0

            $proc.BumpPatch()

            $proc.ReleaseData.version.major | Should -Be 2
            $proc.ReleaseData.version.minor | Should -Be 3
        }
    }

    Context 'BumpBuild' {

        It 'Should increment build number by one' {
            $proc = New-Proc -BuildNumber 4

            $proc.BumpBuild()

            $proc.ReleaseData.build.number | Should -Be 5
        }
    }

    Context 'UpdateBuildDetails' {

        It 'Should increment build number' {
            $proc = New-Proc -BuildNumber 2

            $proc.UpdateBuildDetails()

            $proc.ReleaseData.build.number | Should -Be 3
        }

        It 'Should set date to today in ISO 8601 format' {
            $proc = New-Proc

            $proc.UpdateBuildDetails()

            $proc.ReleaseData.build.date | Should -Match '^\d{4}-\d{2}-\d{2}$'
        }

        It 'Should set timestamp in ISO 8601 format' {
            $proc = New-Proc

            $proc.UpdateBuildDetails()

            $proc.ReleaseData.build.timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'
        }

        It 'Should set year, month, day fields' {
            $proc = New-Proc

            $proc.UpdateBuildDetails()

            $proc.ReleaseData.build.year  | Should -BeGreaterThan 2000
            $proc.ReleaseData.build.month | Should -BeGreaterOrEqual 1
            $proc.ReleaseData.build.day   | Should -BeGreaterOrEqual 1
        }
    }

    Context 'SetPrerelease' {

        It 'Should set a valid prerelease identifier' {
            $proc = New-Proc

            $proc.SetPrerelease('beta.1')

            $proc.ReleaseData.version.prerelease | Should -Be 'beta.1'
            $proc.ReleaseData.version.full        | Should -Be '1.0.0-beta.1'
        }

        It 'Should clear prerelease when null is passed' {
            $proc = New-Proc -Prerelease 'alpha'

            $proc.SetPrerelease($null)

            $proc.ReleaseData.version.prerelease | Should -BeNullOrEmpty
        }

        It 'Should throw FormatException for an invalid prerelease identifier' {
            $proc = New-Proc

            { $proc.SetPrerelease('invalid version!') } | Should -Throw -ExceptionType ([FormatException])
        }
    }

    Context 'UpdateFullVersion' {

        It 'Should produce MAJOR.MINOR.PATCH when no prerelease or buildmetadata' {
            $proc = New-Proc -Major 1 -Minor 2 -Patch 3

            $proc.UpdateFullVersion()

            $proc.ReleaseData.version.full | Should -Be '1.2.3'
        }

        It 'Should include prerelease in full version' {
            $proc = New-Proc -Prerelease 'rc.1'

            $proc.UpdateFullVersion()

            $proc.ReleaseData.version.full | Should -Be '1.0.0-rc.1'
        }

        It 'Should include build metadata in full version' {
            $proc = New-Proc -BuildMetadata 'build.42'

            $proc.UpdateFullVersion()

            $proc.ReleaseData.version.full | Should -Be '1.0.0+build.42'
        }

        It 'Should include both prerelease and build metadata' {
            $proc = New-Proc -Prerelease 'alpha' -BuildMetadata 'exp.sha.5114f85'

            $proc.UpdateFullVersion()

            $proc.ReleaseData.version.full | Should -Be '1.0.0-alpha+exp.sha.5114f85'
        }
    }

    Context 'Getters' {

        It 'Should return correct values from GetMajor, GetMinor, GetPatch' {
            $proc = New-Proc -Major 3 -Minor 2 -Patch 1

            $proc.GetMajor() | Should -Be 3
            $proc.GetMinor() | Should -Be 2
            $proc.GetPatch() | Should -Be 1
        }

        It 'Should return build number from GetBuildNumber' {
            $proc = New-Proc -BuildNumber 7

            $proc.GetBuildNumber() | Should -Be 7
        }
    }

    Context 'InitializeReleaseData' {

        It 'Should reset version to 0.1.0 after a bump' {
            $proc = [PSScriptBuilderReleaseDataProcessor]::new()
            $proc.BumpMinor()

            $proc.InitializeReleaseData()

            $proc.ReleaseData.version.major | Should -Be 0
            $proc.ReleaseData.version.minor | Should -Be 1
            $proc.ReleaseData.version.patch | Should -Be 0
            $proc.ReleaseData.version.full  | Should -Be '0.1.0'
        }

        It 'Should reset build number to 0 after a bump' {
            $proc = [PSScriptBuilderReleaseDataProcessor]::new()
            $proc.BumpBuild()

            $proc.InitializeReleaseData()

            $proc.ReleaseData.build.number | Should -Be 0
        }

        It 'Should reset all build fields to null' {
            $proc = [PSScriptBuilderReleaseDataProcessor]::new()
            $proc.UpdateBuildDetails()

            $proc.InitializeReleaseData()

            $proc.ReleaseData.build.date      | Should -BeNullOrEmpty
            $proc.ReleaseData.build.time      | Should -BeNullOrEmpty
            $proc.ReleaseData.build.timestamp | Should -BeNullOrEmpty
        }

        It 'Should reset all git fields to null' {
            $proc = [PSScriptBuilderReleaseDataProcessor]::new()

            $proc.InitializeReleaseData()

            $proc.ReleaseData.git.commit      | Should -BeNullOrEmpty
            $proc.ReleaseData.git.commitShort | Should -BeNullOrEmpty
            $proc.ReleaseData.git.branch      | Should -BeNullOrEmpty
            $proc.ReleaseData.git.tag         | Should -BeNullOrEmpty
        }
    }
}

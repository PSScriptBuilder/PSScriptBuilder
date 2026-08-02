using namespace System

Describe 'PSScriptBuilderReleaseDataValidator' {

    BeforeAll {
        Function New-ValidReleaseData {
            return [PSCustomObject] @{
                version = [PSCustomObject] @{
                    major         = 1
                    minor         = 0
                    patch         = 0
                    prerelease    = $null
                    buildmetadata = $null
                    full          = '1.0.0'
                }
                build = [PSCustomObject] @{
                    number    = 0
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
    }

    Context 'Constructor' {

        It 'Should initialise with an empty ValidationErrors list' {
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.ValidationErrors.Count | Should -Be 0
        }
    }

    Context 'Validate - valid data' {

        It 'Should return true for fully valid release data' {
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate((New-ValidReleaseData)) | Should -BeTrue
        }

        It 'Should return true when optional git fields are null' {
            $data = New-ValidReleaseData
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeTrue
        }

        It 'Should return true when optional prerelease is null' {
            $data = New-ValidReleaseData
            $data.version.prerelease = $null
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeTrue
        }

        It 'Should clear previous errors before each validation' {
            $validator = [PSScriptBuilderReleaseDataValidator]::new()
            $validator.Validate($null) | Out-Null

            $validator.Validate((New-ValidReleaseData)) | Should -BeTrue
            $validator.ValidationErrors.Count | Should -Be 0
        }
    }

    Context 'Validate - invalid data' {

        It 'Should return false when release data is null' {
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($null) | Should -BeFalse
        }

        It 'Should record an error when release data is null' {
            $validator = [PSScriptBuilderReleaseDataValidator]::new()
            $validator.Validate($null) | Out-Null

            $validator.ValidationErrors.Count | Should -BeGreaterThan 0
        }

        It 'Should return false when major version is missing' {
            $data = New-ValidReleaseData
            $data.version.PSObject.Properties.Remove('major')
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return false when an unknown field is present' {
            $data = New-ValidReleaseData
            $data.version | Add-Member -NotePropertyName 'unknownField' -NotePropertyValue 'x'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should record an error message for each invalid field' {
            $data = New-ValidReleaseData
            $data.version.PSObject.Properties.Remove('major')
            $data.version.PSObject.Properties.Remove('minor')
            $validator = [PSScriptBuilderReleaseDataValidator]::new()
            $validator.Validate($data) | Out-Null

            $validator.ValidationErrors.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Validate - git fields' {

        It 'Should return false when git.branch is an empty string' {
            $data = New-ValidReleaseData
            $data.git.branch = ''
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should record an error when git.branch is an empty string' {
            $data = New-ValidReleaseData
            $data.git.branch = ''
            $validator = [PSScriptBuilderReleaseDataValidator]::new()
            $validator.Validate($data) | Out-Null

            $validator.ValidationErrors.Count | Should -BeGreaterThan 0
        }

        It 'Should return false when git.tag is an empty string' {
            $data = New-ValidReleaseData
            $data.git.tag = ''
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should record an error when git.tag is an empty string' {
            $data = New-ValidReleaseData
            $data.git.tag = ''
            $validator = [PSScriptBuilderReleaseDataValidator]::new()
            $validator.Validate($data) | Out-Null

            $validator.ValidationErrors.Count | Should -BeGreaterThan 0
        }

        It 'Should return false when git.branch exceeds 100 characters' {
            $data = New-ValidReleaseData
            $data.git.branch = 'a' * 101
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return false when git.tag exceeds 100 characters' {
            $data = New-ValidReleaseData
            $data.git.tag = 'a' * 101
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return true when git.branch is a valid non-empty string' {
            $data = New-ValidReleaseData
            $data.git.branch = 'main'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeTrue
        }

        It 'Should return true when git.tag is a valid non-empty string' {
            $data = New-ValidReleaseData
            $data.git.tag = 'v1.0.0'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeTrue
        }

        It 'Should return false when git.commit does not match the 40-character SHA-1 pattern' {
            $data = New-ValidReleaseData
            $data.git.commit = 'not-a-sha'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return true when git.commit is a valid 40-character SHA-1 hash' {
            $data = New-ValidReleaseData
            $data.git.commit = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeTrue
        }

        It 'Should return false when git.commitShort does not match the 7-character SHA-1 pattern' {
            $data = New-ValidReleaseData
            $data.git.commitShort = 'xyz'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return true when git.commitShort is a valid 7-character short SHA-1 hash' {
            $data = New-ValidReleaseData
            $data.git.commitShort = 'a1b2c3d'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeTrue
        }
    }

    Context 'Validate - version fields' {

        It 'Should return false when version.patch is missing' {
            $data = New-ValidReleaseData
            $data.version.PSObject.Properties.Remove('patch')
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return false when version.patch is negative' {
            $data = New-ValidReleaseData
            $data.version.patch = -1
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return false when version.full does not match the SemVer pattern' {
            $data = New-ValidReleaseData
            $data.version.full = 'not-semver'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return true when version.full is a valid SemVer string' {
            $data = New-ValidReleaseData
            $data.version.full = '1.0.0'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeTrue
        }

        It 'Should return false when version.prerelease contains invalid characters' {
            $data = New-ValidReleaseData
            $data.version.prerelease = 'alpha/1'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }
    }

    Context 'Validate - build fields' {

        It 'Should return false when build.date does not match the yyyy-MM-dd pattern' {
            $data = New-ValidReleaseData
            $data.build.date = '25-03-2026'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return true when build.date matches the yyyy-MM-dd pattern' {
            $data = New-ValidReleaseData
            $data.build.date = '2026-03-25'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeTrue
        }

        It 'Should return false when build.timestamp does not match the ISO 8601 format' {
            $data = New-ValidReleaseData
            $data.build.timestamp = '2026-03-25 12:00:00'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return true when build.timestamp matches the ISO 8601 format' {
            $data = New-ValidReleaseData
            $data.build.timestamp = '2026-03-25T12:00:00Z'
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeTrue
        }

        It 'Should return false when build.year is below the minimum allowed value of 2000' {
            $data = New-ValidReleaseData
            $data.build.year = 1999
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }

        It 'Should return false when build.year exceeds the maximum allowed value of 2100' {
            $data = New-ValidReleaseData
            $data.build.year = 2101
            $validator = [PSScriptBuilderReleaseDataValidator]::new()

            $validator.Validate($data) | Should -BeFalse
        }
    }

    Context 'GetErrors' {

        It 'Should return an empty array when validation passes' {
            $validator = [PSScriptBuilderReleaseDataValidator]::new()
            $validator.Validate((New-ValidReleaseData)) | Out-Null

            $validator.GetErrors().Count | Should -Be 0
        }

        It 'Should return error messages when validation fails' {
            $validator = [PSScriptBuilderReleaseDataValidator]::new()
            $validator.Validate($null) | Out-Null

            $validator.GetErrors().Count | Should -BeGreaterThan 0
        }
    }

    Context 'ThrowIfInvalid' {

        It 'Should not throw when there are no validation errors' {
            $validator = [PSScriptBuilderReleaseDataValidator]::new()
            $validator.Validate((New-ValidReleaseData)) | Out-Null

            { $validator.ThrowIfInvalid() } | Should -Not -Throw
        }

        It 'Should throw InvalidOperationException when there are validation errors' {
            $validator = [PSScriptBuilderReleaseDataValidator]::new()
            $validator.Validate($null) | Out-Null

            { $validator.ThrowIfInvalid() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }
}

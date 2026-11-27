using namespace System

Describe 'PSScriptBuilderConfigValidator' {

    BeforeAll {
        Function New-ValidConfigObj {
            return [PSCustomObject] @{
                release = [PSCustomObject] @{
                    dataFile       = 'build\Release\releasedata.json'
                    bumpConfigFile = 'build\Release\bumpconfig.json'
                }
                build = [PSCustomObject] @{
                    outputPath              = 'build\Output'
                    backupPath              = 'build\Backup'
                    templatePath            = 'build\Templates'
                    orderedComponentsKey    = 'ORDERED_COMPONENTS'
                    backupEnabled           = $false
                    syntaxValidationEnabled = $true
                }
            }
        }
    }

    Context 'Constructor' {

        It 'Should instantiate without throwing' {
            { [PSScriptBuilderConfigValidator]::new() } | Should -Not -Throw
        }
    }

    Context 'Validate - valid config' {

        It 'Should not throw for a valid configuration' {
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate((New-ValidConfigObj)) } | Should -Not -Throw
        }
    }

    Context 'Validate - unknown options' {

        It 'Should throw InvalidOperationException for an unknown top-level option' {
            $config = New-ValidConfigObj
            $config | Add-Member -NotePropertyName 'unknownOption' -NotePropertyValue 'x'
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException for an unknown nested option in build' {
            $config = New-ValidConfigObj
            $config.build | Add-Member -NotePropertyName 'unknownBuildOption' -NotePropertyValue 'x'
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException for an unknown nested option in release' {
            $config = New-ValidConfigObj
            $config.release | Add-Member -NotePropertyName 'unknownReleaseOption' -NotePropertyValue 'x'
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should include the unknown option name in the error message' {
            $config = New-ValidConfigObj
            $config | Add-Member -NotePropertyName 'badOption' -NotePropertyValue 'x'
            $validator = [PSScriptBuilderConfigValidator]::new()
            $caughtError = $null

            try { $validator.Validate($config) } catch { $caughtError = $_ }

            $caughtError.Exception.Message | Should -Match 'badOption'
        }
    }

    Context 'Validate - missing required fields' {

        It 'Should throw InvalidOperationException when outputPath is missing from build' {
            $config = New-ValidConfigObj
            $config.build.PSObject.Properties.Remove('outputPath')
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException when dataFile is missing from release' {
            $config = New-ValidConfigObj
            $config.release.PSObject.Properties.Remove('dataFile')
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should include the missing field name in the error message' {
            $config = New-ValidConfigObj
            $config.build.PSObject.Properties.Remove('templatePath')
            $validator = [PSScriptBuilderConfigValidator]::new()
            $caughtError = $null

            try { $validator.Validate($config) } catch { $caughtError = $_ }

            $caughtError.Exception.Message | Should -Match 'templatePath'
        }
    }

    Context 'Validate - null input' {

        It 'Should throw ArgumentNullException when config is null' {
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($null) } | Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }

    Context 'Validate - missing required sections' {

        It 'Should throw InvalidOperationException when build section is missing' {
            $config = [PSCustomObject] @{
                release = [PSCustomObject] @{
                    dataFile       = 'build\Release\releasedata.json'
                    bumpConfigFile = 'build\Release\bumpconfig.json'
                }
            }
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException when release section is missing' {
            $config = [PSCustomObject] @{
                build = [PSCustomObject] @{
                    outputPath              = 'build\Output'
                    backupPath              = 'build\Backup'
                    templatePath            = 'build\Templates'
                    orderedComponentsKey    = 'ORDERED_COMPONENTS'
                    backupEnabled           = $false
                    syntaxValidationEnabled = $true
                }
            }
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should include the missing section name in the error message' {
            $config = [PSCustomObject] @{
                release = [PSCustomObject] @{
                    dataFile       = 'build\Release\releasedata.json'
                    bumpConfigFile = 'build\Release\bumpconfig.json'
                }
            }
            $validator = [PSScriptBuilderConfigValidator]::new()
            $caughtError = $null

            try { $validator.Validate($config) } catch { $caughtError = $_ }

            $caughtError.Exception.Message | Should -Match 'build'
        }
    }

    Context 'Validate - optional fields' {

        It 'Should not throw when optional build fields are absent' {
            $config = [PSCustomObject] @{
                release = [PSCustomObject] @{
                    dataFile       = 'build\Release\releasedata.json'
                    bumpConfigFile = 'build\Release\bumpconfig.json'
                }
                build = [PSCustomObject] @{
                    outputPath   = 'build\Output'
                    templatePath = 'build\Templates'
                }
            }
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Not -Throw
        }

        It 'Should throw InvalidOperationException when optional backupEnabled is present with wrong type' {
            $config = New-ValidConfigObj
            $config.build.PSObject.Properties.Remove('backupEnabled')
            $config.build | Add-Member -NotePropertyName 'backupEnabled' -NotePropertyValue 'yes'
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException when optional syntaxValidationEnabled is present with wrong type' {
            $config = New-ValidConfigObj
            $config.build.PSObject.Properties.Remove('syntaxValidationEnabled')
            $config.build | Add-Member -NotePropertyName 'syntaxValidationEnabled' -NotePropertyValue 'true'
            $validator = [PSScriptBuilderConfigValidator]::new()

            { $validator.Validate($config) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }
}

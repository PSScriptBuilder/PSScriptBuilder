using namespace System

Describe 'PSScriptBuilderBumpFilesValidator' {

    BeforeAll {
        Function New-ValidBumpConfig {
            param([string] $FilePath = 'build\Output\Module.psd1')
            return [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path        = $FilePath
                        description = 'Test entry'
                        items       = @(
                            [PSCustomObject] @{
                                pattern = "ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'"
                                tokens  = @('VERSION_FULL')
                            }
                        )
                    }
                )
            }
        }
    }

    Context 'Constructor' {

        It 'Should initialise with an empty ValidationErrors list' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.ValidationErrors.Count | Should -Be 0
        }
    }

    Context 'Validate - valid config' {

        It 'Should return true for a valid bump config with items' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate((New-ValidBumpConfig)) | Should -BeTrue
        }

        It 'Should return true for a valid bump config with tokens (simple mode)' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path   = 'build\Output\Module.psd1'
                        tokens = @('VERSION_FULL')
                    }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeTrue
        }

        It 'Should clear previous errors before each validation' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $validator.Validate($null) | Out-Null

            $validator.Validate((New-ValidBumpConfig)) | Should -BeTrue
            $validator.ValidationErrors.Count | Should -Be 0
        }
    }

    Context 'Validate - invalid config' {

        It 'Should return false when config is null' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($null) | Should -BeFalse
        }

        It 'Should return false when bumpFiles property is missing' {
            $config = [PSCustomObject] @{ something = 'else' }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeFalse
        }

        It 'Should return false when bumpFiles array is empty' {
            $config = [PSCustomObject] @{ bumpFiles = @() }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeFalse
        }

        It 'Should return false when a file entry has no path' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        tokens = @('VERSION_FULL')
                    }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeFalse
        }

        It 'Should return false when a file entry has neither tokens nor items' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path        = 'build\Output\Module.psd1'
                        description = 'Missing action'
                    }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeFalse
        }

        It 'Should return false when a file entry has both tokens and items' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path   = 'build\Output\Module.psd1'
                        tokens = @('VERSION_FULL')
                        items  = @(
                            [PSCustomObject] @{
                                pattern = "ModuleVersion\s*=\s*'(\S+)'"
                                tokens  = @('VERSION_FULL')
                            }
                        )
                    }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeFalse
        }

        It 'Should return false when an item is missing its tokens property' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path  = 'build\Output\Module.psd1'
                        items = @(
                            [PSCustomObject] @{
                                pattern = "ModuleVersion\s*=\s*'(\S+)'"
                            }
                        )
                    }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeFalse
        }

        It 'Should return false when a token contains invalid characters' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path  = 'build\Output\Module.psd1'
                        items = @(
                            [PSCustomObject] @{
                                pattern = "ModuleVersion\s*=\s*'(\S+)'"
                                tokens  = @('INVALID TOKEN!')
                            }
                        )
                    }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeFalse
        }

        It 'Should record an error message for each invalid entry' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $validator.Validate($null) | Out-Null

            $validator.ValidationErrors.Count | Should -BeGreaterThan 0
        }
    }

    Context 'ThrowIfInvalid' {

        It 'Should not throw when there are no validation errors' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $validator.Validate((New-ValidBumpConfig)) | Out-Null

            { $validator.ThrowIfInvalid() } | Should -Not -Throw
        }

        It 'Should throw InvalidOperationException when there are validation errors' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $validator.Validate($null) | Out-Null

            { $validator.ThrowIfInvalid() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }
}

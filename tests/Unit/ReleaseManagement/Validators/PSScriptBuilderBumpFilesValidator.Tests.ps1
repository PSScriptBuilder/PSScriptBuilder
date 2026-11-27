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

        Function New-SimpleBumpConfig {
            param([object[]] $Tokens)
            return [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path   = 'build\Output\Module.psd1'
                        tokens = $Tokens
                    }
                )
            }
        }

        Function New-ItemsBumpConfig {
            param([string] $Pattern, [object[]] $Tokens)
            return [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path  = 'build\Output\Module.psd1'
                        items = @(
                            [PSCustomObject] @{
                                pattern = $Pattern
                                tokens  = $Tokens
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

        It 'Should return false when an item pattern mixes {{TOKEN}} with an unescaped capture group' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path  = 'build\Output\Module.psd1'
                        items = @(
                            [PSCustomObject] @{
                                pattern = '{{GIT_BRANCH}} vs ({REGEX_GIT_BRANCH})'
                                tokens  = @('GIT_BRANCH')
                            }
                        )
                    }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeFalse
            $validator.ValidationErrors[0] | Should -Match 'cannot mix'
        }

        It 'Should record an error message for each invalid entry' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $validator.Validate($null) | Out-Null

            $validator.ValidationErrors.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Validate - empty tokens' {

        # The classes behind the validator rely on it to keep empty entries away (RFC 0027)
        It 'Should return false when a tokens list contains <Case> (simple mode)' -ForEach @(
            @{ Case = 'a null entry';   Tokens = @('VERSION_FULL', $null) }
            @{ Case = 'an empty entry'; Tokens = @('VERSION_FULL', '') }
            @{ Case = 'a blank entry';  Tokens = @('VERSION_FULL', ' ') }
        ) {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate((New-SimpleBumpConfig $Tokens)) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 1
            $validator.ValidationErrors[0] | Should -BeExactly '{bumpFiles[0]}: Token array contains null or empty values'
        }

        It 'Should return false when a tokens list contains <Case> (items mode)' -ForEach @(
            @{ Case = 'a null entry';   Tokens = @('VERSION_FULL', $null) }
            @{ Case = 'an empty entry'; Tokens = @('VERSION_FULL', '') }
            @{ Case = 'a blank entry';  Tokens = @('VERSION_FULL', ' ') }
        ) {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate((New-ItemsBumpConfig 'Version: {{VERSION_FULL}}' $Tokens)) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 1
            $validator.ValidationErrors[0] | Should -BeExactly '{bumpFiles[0].items[0]}: Token at index 1 is null or empty'
        }
    }

    Context 'Validate - duplicate tokens (RFC 0027)' {

        It 'Should return false when a token is listed in two spellings (simple mode)' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $expected  = "{bumpFiles[0]}: Token 'VERSION_FULL' is listed more than once ('VERSION_FULL' and 'version_full'). " +
                         'A token may appear only once in a tokens list'

            $validator.Validate((New-SimpleBumpConfig @('VERSION_FULL', 'version_full'))) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 1
            $validator.ValidationErrors[0] | Should -BeExactly $expected
        }

        It 'Should return false when a token is listed twice in the same spelling' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate((New-SimpleBumpConfig @('VERSION_FULL', 'VERSION_FULL'))) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 1
            $validator.ValidationErrors[0] | Should -BeExactly "{bumpFiles[0]}: Token 'VERSION_FULL' is listed more than once. A token may appear only once in a tokens list"
        }

        It 'Should find a duplicate that is not adjacent' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate((New-SimpleBumpConfig @('VERSION_FULL', 'VERSION_MAJOR', 'Version_Full'))) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 1
            $validator.ValidationErrors[0] | Should -BeLikeExactly "*('VERSION_FULL' and 'Version_Full')*"
        }

        It 'Should report every duplicated token of one tokens list' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $tokens    = @('VERSION_FULL', 'version_full', 'VERSION_MAJOR', 'Version_Major')

            $validator.Validate((New-SimpleBumpConfig $tokens)) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 2
            $validator.ValidationErrors[0] | Should -BeLikeExactly "*('VERSION_FULL' and 'version_full')*"
            $validator.ValidationErrors[1] | Should -BeLikeExactly "*('VERSION_MAJOR' and 'Version_Major')*"
        }

        It 'Should report a token that is listed three times only once' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate((New-SimpleBumpConfig @('VERSION_FULL', 'version_full', 'Version_Full'))) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 1
            $validator.ValidationErrors[0] | Should -BeLikeExactly "*('VERSION_FULL' and 'version_full')*"
        }

        It 'Should name the position of the item (items mode, placeholder pattern)' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $config    = New-ItemsBumpConfig 'Version: {{VERSION_FULL}}' @('VERSION_FULL', 'version_full')
            $expected  = "{bumpFiles[0].items[0]}: Token 'VERSION_FULL' is listed more than once ('VERSION_FULL' and 'version_full'). " +
                         'A token may appear only once in a tokens list'

            $validator.Validate($config) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 1
            $validator.ValidationErrors[0] | Should -BeExactly $expected
        }

        It 'Should add how to write a value into several capture groups (items mode, regex pattern)' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $config    = New-ItemsBumpConfig 'V=({REGEX_VERSION_FULL})-({REGEX_VERSION_FULL})' @('VERSION_FULL', 'version_full')
            $expected  = "{bumpFiles[0].items[0]}: Token 'VERSION_FULL' is listed more than once ('VERSION_FULL' and 'version_full'). " +
                         'A token may appear only once in a tokens list. ' +
                         'To write the same value into several capture groups, use one item per capture group'

            $validator.Validate($config) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 1
            $validator.ValidationErrors[0] | Should -BeExactly $expected
        }

        It 'Should report a duplicate in every tokens list with its own position' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = 'a.txt'; tokens = @('VERSION_FULL', 'version_full') }
                    [PSCustomObject] @{
                        path  = 'b.txt'
                        items = @(
                            [PSCustomObject] @{ pattern = 'Version: {{VERSION_FULL}}'; tokens = @('VERSION_FULL') }
                            [PSCustomObject] @{ pattern = 'Major: {{VERSION_MAJOR}}'; tokens = @('VERSION_MAJOR', 'version_major') }
                        )
                    }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 2
            $validator.ValidationErrors[0] | Should -MatchExactly ('^' + [regex]::Escape('{bumpFiles[0]}: '))
            $validator.ValidationErrors[1] | Should -MatchExactly ('^' + [regex]::Escape('{bumpFiles[1].items[1]}: '))
        }

        It 'Should report an empty entry and a duplicate in the same tokens list' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate((New-SimpleBumpConfig @('VERSION_FULL', '', 'version_full'))) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 2
            $validator.ValidationErrors[0] | Should -BeLikeExactly '*null or empty*'
            $validator.ValidationErrors[1] | Should -BeLikeExactly '*listed more than once*'
        }

        It 'Should not report two empty entries as a duplicate' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate((New-SimpleBumpConfig @('VERSION_FULL', '', ''))) | Should -BeFalse
            $validator.ValidationErrors.Count | Should -Be 1
            $validator.ValidationErrors[0] | Should -BeLikeExactly '*null or empty*'
        }

        It 'Should accept the same token in two entries for the same file' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = 'a.txt'; tokens = @('VERSION_FULL') }
                    [PSCustomObject] @{ path = 'a.txt'; tokens = @('version_full', 'VERSION_MAJOR') }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeTrue
        }

        It 'Should accept the same token in two items of one file' {
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path  = 'a.txt'
                        items = @(
                            [PSCustomObject] @{ pattern = 'V=({REGEX_VERSION_FULL})-'; tokens = @('VERSION_FULL') }
                            [PSCustomObject] @{ pattern = '-({REGEX_VERSION_FULL})$'; tokens = @('VERSION_FULL') }
                        )
                    }
                )
            }
            $validator = [PSScriptBuilderBumpFilesValidator]::new()

            $validator.Validate($config) | Should -BeTrue
        }

        It 'Should not report an entry that is not text as a duplicate of a different token' {
            $validator = [PSScriptBuilderBumpFilesValidator]::new()
            $validator.Validate((New-SimpleBumpConfig @('VERSION_FULL', $true))) | Out-Null

            $validator.ValidationErrors | Where-Object { $_ -clike '*listed more than once*' } | Should -BeNullOrEmpty
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

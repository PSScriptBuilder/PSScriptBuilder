using namespace System
using namespace System.IO

Describe 'PSScriptBuilderOutputFileManager' {

    #region WriteScript

    Context 'WriteScript - parameter validation' {

        It 'Should throw ArgumentException when filePath is null or empty' {
            { [PSScriptBuilderOutputFileManager]::WriteScript($null, 'content') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when filePath is whitespace' {
            { [PSScriptBuilderOutputFileManager]::WriteScript('   ', 'content') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should not throw when content is null (coerced to empty string by PowerShell)' {
            $filePath = Join-Path $TestDrive 'output-null.ps1'

            { [PSScriptBuilderOutputFileManager]::WriteScript($filePath, $null) } |
                Should -Not -Throw
        }
    }

    Context 'WriteScript - file creation' {

        It 'Should create the output file at the specified path' {
            $filePath = Join-Path $TestDrive 'created.ps1'

            [PSScriptBuilderOutputFileManager]::WriteScript($filePath, '# content')

            Test-Path $filePath | Should -BeTrue
        }

        It 'Should write the provided content to the file' {
            $expectedContent = '# script content'
            $filePath        = Join-Path $TestDrive 'with-content.ps1'

            [PSScriptBuilderOutputFileManager]::WriteScript($filePath, $expectedContent)
            $actual = Get-Content -Path $filePath -Raw

            $actual.Trim() | Should -Be $expectedContent.Trim()
        }

        It 'Should write an empty string without throwing' {
            $filePath = Join-Path $TestDrive 'empty-content.ps1'

            { [PSScriptBuilderOutputFileManager]::WriteScript($filePath, '') } |
                Should -Not -Throw
        }

        It 'Should create the output directory when it does not exist' {
            $dir      = Join-Path $TestDrive 'new-output-dir'
            $filePath = Join-Path $dir 'script.ps1'

            [PSScriptBuilderOutputFileManager]::WriteScript($filePath, '# dir test')

            Test-Path $dir | Should -BeTrue
        }

        It 'Should overwrite an existing file without throwing' {
            $filePath = Join-Path $TestDrive 'overwrite.ps1'
            [File]::WriteAllText($filePath, 'old content', [Text.Encoding]::UTF8)

            { [PSScriptBuilderOutputFileManager]::WriteScript($filePath, 'new content') } |
                Should -Not -Throw
        }

        It 'Should replace the content when overwriting an existing file' {
            $filePath = Join-Path $TestDrive 'overwrite-check.ps1'
            [File]::WriteAllText($filePath, 'old content', [Text.Encoding]::UTF8)

            [PSScriptBuilderOutputFileManager]::WriteScript($filePath, 'new content')
            $actual = Get-Content -Path $filePath -Raw

            $actual.Trim() | Should -Be 'new content'
        }
    }

    #endregion WriteScript

    #region ScriptExists

    Context 'ScriptExists' {

        It 'Should return false when filePath is null or empty' {
            [PSScriptBuilderOutputFileManager]::ScriptExists($null) | Should -BeFalse
            [PSScriptBuilderOutputFileManager]::ScriptExists('')   | Should -BeFalse
        }

        It 'Should return false when filePath is whitespace' {
            [PSScriptBuilderOutputFileManager]::ScriptExists('   ') | Should -BeFalse
        }

        It 'Should return false when the file does not exist' {
            $missing = Join-Path $TestDrive 'missing-script.ps1'

            [PSScriptBuilderOutputFileManager]::ScriptExists($missing) | Should -BeFalse
        }

        It 'Should return true when the file exists' {
            $existing = Join-Path $TestDrive 'existing-script.ps1'
            [File]::WriteAllText($existing, '# existing', [Text.Encoding]::UTF8)

            [PSScriptBuilderOutputFileManager]::ScriptExists($existing) | Should -BeTrue
        }
    }

    #endregion ScriptExists
}

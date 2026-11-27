using namespace System
using namespace System.IO

Describe 'PSScriptBuilderTemplateFileManager' {

    BeforeAll {
        Function New-TemplateFile {
            param([string] $Path, [string] $Content = '# template content')
            [File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
        }
    }

    #region LoadTemplate

    Context 'LoadTemplate - parameter validation' {

        It 'Should throw ArgumentException when templatePath is null or empty' {
            { [PSScriptBuilderTemplateFileManager]::LoadTemplate($null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when templatePath is whitespace' {
            { [PSScriptBuilderTemplateFileManager]::LoadTemplate('   ') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'LoadTemplate - file does not exist' {

        It 'Should throw FileNotFoundException when the template file does not exist' {
            $missing = Join-Path $TestDrive 'missing.template'

            { [PSScriptBuilderTemplateFileManager]::LoadTemplate($missing) } |
                Should -Throw -ExceptionType ([FileNotFoundException])
        }
    }

    Context 'LoadTemplate - empty file' {

        It 'Should throw InvalidOperationException when the template file is empty' {
            $emptyFile = Join-Path $TestDrive 'empty.template'
            New-TemplateFile -Path $emptyFile -Content ''

            { [PSScriptBuilderTemplateFileManager]::LoadTemplate($emptyFile) } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException when the template file contains only whitespace' {
            $wsFile = Join-Path $TestDrive 'whitespace.template'
            New-TemplateFile -Path $wsFile -Content '   '

            { [PSScriptBuilderTemplateFileManager]::LoadTemplate($wsFile) } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    Context 'LoadTemplate - successful load' {

        It 'Should return the template content as a string' {
            $expectedContent = '# valid template'
            $templateFile    = Join-Path $TestDrive 'valid.template'
            New-TemplateFile -Path $templateFile -Content $expectedContent

            $result = [PSScriptBuilderTemplateFileManager]::LoadTemplate($templateFile)

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return the exact content of the template file' {
            $expectedContent = '{{ENUMS}}' + [Environment]::NewLine + '{{CLASSES}}'
            $templateFile    = Join-Path $TestDrive 'exact.template'
            New-TemplateFile -Path $templateFile -Content $expectedContent

            $result = [PSScriptBuilderTemplateFileManager]::LoadTemplate($templateFile)

            $result | Should -Be $expectedContent
        }

        It 'Should not throw for a template with multi-line content' {
            $content      = "line1`nline2`nline3"
            $templateFile = Join-Path $TestDrive 'multiline.template'
            New-TemplateFile -Path $templateFile -Content $content

            { [PSScriptBuilderTemplateFileManager]::LoadTemplate($templateFile) } |
                Should -Not -Throw
        }
    }

    #endregion LoadTemplate

    #region TemplateExists

    Context 'TemplateExists' {

        It 'Should return false when templatePath is null or empty' {
            [PSScriptBuilderTemplateFileManager]::TemplateExists($null) | Should -BeFalse
            [PSScriptBuilderTemplateFileManager]::TemplateExists('')   | Should -BeFalse
        }

        It 'Should return false when templatePath is whitespace' {
            [PSScriptBuilderTemplateFileManager]::TemplateExists('   ') | Should -BeFalse
        }

        It 'Should return false when the template file does not exist' {
            $missing = Join-Path $TestDrive 'missing-check.template'

            [PSScriptBuilderTemplateFileManager]::TemplateExists($missing) | Should -BeFalse
        }

        It 'Should return true when the template file exists' {
            $existing = Join-Path $TestDrive 'existing.template'
            New-TemplateFile -Path $existing

            [PSScriptBuilderTemplateFileManager]::TemplateExists($existing) | Should -BeTrue
        }
    }

    #endregion TemplateExists
}

using namespace System
using namespace System.IO

Describe 'PSScriptBuilderEnumCollector' {

    BeforeAll {
        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-EnumCollector {
            param([string[]] $Files, [string] $Key = 'ENUM_DEFINITIONS')
            $collector = [PSScriptBuilderEnumCollector]::new($Key)
            $collector.IncludeFiles = $Files
            return $collector
        }
    }

    Context 'Constructor' {

        It 'Should initialise with default CollectionKey' {
            $collector = [PSScriptBuilderEnumCollector]::new()

            $collector.CollectionKey | Should -Be 'ENUM_DEFINITIONS'
        }

        It 'Should initialise with a custom CollectionKey' {
            $collector = [PSScriptBuilderEnumCollector]::new('MyEnums')

            $collector.CollectionKey | Should -Be 'MyEnums'
        }

        It 'Should start with an empty EnumData dictionary' {
            $collector = [PSScriptBuilderEnumCollector]::new()

            $collector.EnumData.Count | Should -Be 0
        }

        It 'Should have CollectorType set to EnumCollector' {
            $collector = [PSScriptBuilderEnumCollector]::new()

            $collector.CollectorType | Should -Be ([PSScriptBuilderCollectorType]::EnumCollector)
        }
    }

    Context 'Collection - basic' {

        It 'Should collect a single enum from a file' {
            $file = New-TestFile 'SingleEnum.ps1' @'
enum MyStatus {
    Active
    Inactive
}
'@
            $collector = New-EnumCollector @($file)
            $collector.Collect()

            $collector.EnumData.Count | Should -Be 1
            $collector.EnumData.ContainsKey('MyStatus') | Should -BeTrue
        }

        It 'Should collect multiple enums from a single file' {
            $file = New-TestFile 'MultiEnum.ps1' @'
enum ColorEnum {
    Red
    Blue
}

enum SizeEnum {
    Small
    Large
}
'@
            $collector = New-EnumCollector @($file)
            $collector.Collect()

            $collector.EnumData.Count | Should -Be 2
            $collector.EnumData.ContainsKey('ColorEnum') | Should -BeTrue
            $collector.EnumData.ContainsKey('SizeEnum') | Should -BeTrue
        }

        It 'Should collect enums from multiple files' {
            $fileA = New-TestFile 'EnumFileA.ps1' "enum EnumA { Val1 }"
            $fileB = New-TestFile 'EnumFileB.ps1' "enum EnumB { Val2 }"
            $collector = New-EnumCollector @($fileA, $fileB)
            $collector.Collect()

            $collector.EnumData.Count | Should -Be 2
        }

        It 'Should store the correct enum name in EnumData' {
            $file = New-TestFile 'NamedEnum.ps1' "enum ExactEnumName { Val }"
            $collector = New-EnumCollector @($file)
            $collector.Collect()

            $collector.EnumData['ExactEnumName'].Name | Should -Be 'ExactEnumName'
        }

        It 'Should return zero enums for a file with no enum definitions' {
            $file = New-TestFile 'NoEnums.ps1' '# just a comment'
            $collector = New-EnumCollector @($file)
            $collector.Collect()

            $collector.EnumData.Count | Should -Be 0
        }
    }

    Context 'Collection - Reset' {

        It 'Should clear EnumData when Collect is called a second time with different files' {
            $file1 = New-TestFile 'EnumReset1.ps1' "enum ResetEnumA { Val }"
            $collector = New-EnumCollector @($file1)
            $collector.Collect()

            $file2 = New-TestFile 'EnumReset2.ps1' "enum ResetEnumB { Val }"
            $collector.IncludeFiles = @($file2)
            $collector.Collect()

            $collector.EnumData.Count | Should -Be 1
            $collector.EnumData.ContainsKey('ResetEnumB') | Should -BeTrue
        }

        It 'Should start with empty EnumData after explicit Reset' {
            $file = New-TestFile 'EnumBeforeReset.ps1' "enum ToReset { Val }"
            $collector = New-EnumCollector @($file)
            $collector.Collect()

            $collector.Reset()

            $collector.EnumData.Count | Should -Be 0
        }
    }

    Context 'Duplicate Detection' {

        It 'Should throw when the same enum name appears in two files' {
            $fileA = New-TestFile 'EnumDupA.ps1' "enum DuplicateEnum { Val1 }"
            $fileB = New-TestFile 'EnumDupB.ps1' "enum DuplicateEnum { Val2 }"
            $collector = New-EnumCollector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExceptionType ([Exception])
        }

        It 'Should include the duplicate enum name in the exception message' {
            $fileA = New-TestFile 'EnumDupMsgA.ps1' "enum MyDuplicateEnum { Val }"
            $fileB = New-TestFile 'EnumDupMsgB.ps1' "enum MyDuplicateEnum { Val }"
            $collector = New-EnumCollector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*MyDuplicateEnum*'
        }

        It 'Should be case-insensitive when detecting duplicate enums' {
            $fileA = New-TestFile 'EnumDupCaseA.ps1' "enum CaseEnum { Val }"
            $fileB = New-TestFile 'EnumDupCaseB.ps1' "enum CASEENUM { Val }"
            $collector = New-EnumCollector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExceptionType ([Exception])
        }
    }

    Context 'Parse Error Detection' {

        It 'Should throw InvalidOperationException when a structural parse error prevents enum collection' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\ParseErrorNoDefinitions.ps1'
            $collector = New-EnumCollector @($file)

            { $collector.Collect() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should include the file name in the exception message' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\ParseErrorNoDefinitions.ps1'
            $collector = New-EnumCollector @($file)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*ParseErrorNoDefinitions.ps1*'
        }

        It 'Should include line and column info in the exception message' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\ParseErrorNoDefinitions.ps1'
            $collector = New-EnumCollector @($file)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*Line*Col*'
        }

        It 'Should not throw when file has no parse errors and no enum definitions' {
            $file = New-TestFile 'PE-Enum-NoEnums.ps1' '# No enum definitions in this file'
            $collector = New-EnumCollector @($file)

            { $collector.Collect() } | Should -Not -Throw
        }
    }
}

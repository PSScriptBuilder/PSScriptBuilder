using namespace System
using namespace System.IO

Describe 'PSScriptBuilderFileCollector' {

    BeforeAll {
        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-FileCollector {
            param([string[]] $Files, [string] $Key = 'FILE_CONTENTS')
            $collector = [PSScriptBuilderFileCollector]::new($Key)
            $collector.IncludeFiles = $Files
            return $collector
        }
    }

    Context 'Constructor' {

        It 'Should initialise with default CollectionKey' {
            $collector = [PSScriptBuilderFileCollector]::new()

            $collector.CollectionKey | Should -Be 'FILE_CONTENTS'
        }

        It 'Should initialise with a custom CollectionKey' {
            $collector = [PSScriptBuilderFileCollector]::new('MyFiles')

            $collector.CollectionKey | Should -Be 'MyFiles'
        }

        It 'Should start with an empty FileData dictionary' {
            $collector = [PSScriptBuilderFileCollector]::new()

            $collector.FileData.Count | Should -Be 0
        }

        It 'Should have CollectorType set to FileCollector' {
            $collector = [PSScriptBuilderFileCollector]::new()

            $collector.CollectorType | Should -Be ([PSScriptBuilderCollectorType]::FileCollector)
        }
    }

    Context 'Collection - basic' {

        It 'Should collect content from a single file' {
            $file = New-TestFile 'ContentA.txt' 'Hello World'
            $collector = New-FileCollector @($file)
            $collector.Collect()

            $collector.FileData.Count | Should -Be 1
        }

        It 'Should store the file name as key in FileData' {
            $file = New-TestFile 'KeyCheck.txt' 'content'
            $collector = New-FileCollector @($file)
            $collector.Collect()

            $collector.FileData.ContainsKey('KeyCheck.txt') | Should -BeTrue
        }

        It 'Should store the raw file content in FileData' {
            $file = New-TestFile 'RawContent.txt' 'raw content here'
            $collector = New-FileCollector @($file)
            $collector.Collect()

            $collector.FileData['RawContent.txt'].Content | Should -Match 'raw content here'
        }

        It 'Should collect content from multiple files' {
            $fileA = New-TestFile 'MultiFileA.txt' 'content A'
            $fileB = New-TestFile 'MultiFileB.txt' 'content B'
            $collector = New-FileCollector @($fileA, $fileB)
            $collector.Collect()

            $collector.FileData.Count | Should -Be 2
        }

        It 'GetCount should return the number of collected files' {
            $fileA = New-TestFile 'CountFileA.txt' 'a'
            $fileB = New-TestFile 'CountFileB.txt' 'b'
            $collector = New-FileCollector @($fileA, $fileB)
            $collector.Collect()

            $collector.GetCount() | Should -Be 2
        }
    }

    Context 'Collection - Reset' {

        It 'Should clear FileData when Collect is called a second time with different files' {
            $file1 = New-TestFile 'FileReset1.txt' 'first'
            $collector = New-FileCollector @($file1)
            $collector.Collect()

            $file2 = New-TestFile 'FileReset2.txt' 'second'
            $collector.IncludeFiles = @($file2)
            $collector.Collect()

            $collector.FileData.Count | Should -Be 1
            $collector.FileData.ContainsKey('FileReset2.txt') | Should -BeTrue
        }

        It 'Should start with empty FileData after explicit Reset' {
            $file = New-TestFile 'FileBeforeReset.txt' 'data'
            $collector = New-FileCollector @($file)
            $collector.Collect()

            $collector.Reset()

            $collector.FileData.Count | Should -Be 0
        }
    }

    Context 'Duplicate Detection' {

        It 'Should throw when two files with the same name are collected from different directories' {
            $subDir = Join-Path $TestDrive 'sub'
            New-Item -Path $subDir -ItemType Directory -Force | Out-Null

            $fileA = New-TestFile 'duplicate.txt' 'content A'
            $fileB = Join-Path $subDir 'duplicate.txt'
            Set-Content -Path $fileB -Value 'content B' -Encoding UTF8

            $collector = New-FileCollector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExceptionType ([Exception])
        }

        It 'Should include the duplicate file name in the exception message' {
            $subDir = Join-Path $TestDrive 'sub2'
            New-Item -Path $subDir -ItemType Directory -Force | Out-Null

            $fileA = New-TestFile 'samename.txt' 'a'
            $fileB = Join-Path $subDir 'samename.txt'
            Set-Content -Path $fileB -Value 'b' -Encoding UTF8

            $collector = New-FileCollector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*samename.txt*'
        }
    }
}

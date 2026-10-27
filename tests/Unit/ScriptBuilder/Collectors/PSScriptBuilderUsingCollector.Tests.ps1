using namespace System
using namespace System.IO

Describe 'PSScriptBuilderUsingCollector' {

    BeforeAll {
        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-UsingCollector {
            param([string[]] $Files, [string] $Key = 'USING_STATEMENTS')
            $collector = [PSScriptBuilderUsingCollector]::new($Key)
            $collector.IncludeFiles = $Files
            return $collector
        }
    }

    Context 'Constructor' {

        It 'Should initialise with default CollectionKey' {
            $collector = [PSScriptBuilderUsingCollector]::new()

            $collector.CollectionKey | Should -Be 'USING_STATEMENTS'
        }

        It 'Should initialise with a custom CollectionKey' {
            $collector = [PSScriptBuilderUsingCollector]::new('MyUsings')

            $collector.CollectionKey | Should -Be 'MyUsings'
        }

        It 'Should start with an empty UsingData dictionary' {
            $collector = [PSScriptBuilderUsingCollector]::new()

            $collector.UsingData.Count | Should -Be 0
        }

        It 'Should have CollectorType set to UsingCollector' {
            $collector = [PSScriptBuilderUsingCollector]::new()

            $collector.CollectorType | Should -Be ([PSScriptBuilderCollectorType]::UsingCollector)
        }
    }

    Context 'Collection - basic' {

        It 'Should collect a single using statement from a file' {
            $file = New-TestFile 'SingleUsing.ps1' "using namespace System"
            $collector = New-UsingCollector @($file)
            $collector.Collect()

            $collector.UsingData.Count | Should -Be 1
        }

        It 'Should collect multiple distinct using statements from one file' {
            $file = New-TestFile 'MultiUsing.ps1' @'
using namespace System
using namespace System.IO
'@
            $collector = New-UsingCollector @($file)
            $collector.Collect()

            $collector.UsingData.Count | Should -Be 2
        }

        It 'Should return zero using statements for a file with none' {
            $file = New-TestFile 'NoUsings.ps1' '# just a comment'
            $collector = New-UsingCollector @($file)
            $collector.Collect()

            $collector.UsingData.Count | Should -Be 0
        }

        It 'GetCount should return the number of collected using statements' {
            $file = New-TestFile 'UsingCount.ps1' @'
using namespace System
using namespace System.Collections
'@
            $collector = New-UsingCollector @($file)
            $collector.Collect()

            $collector.GetCount() | Should -Be 2
        }
    }

    Context 'Deduplication' {

        It 'Should deduplicate identical using statements across files' {
            $fileA = New-TestFile 'UsingDedupA.ps1' "using namespace System"
            $fileB = New-TestFile 'UsingDedupB.ps1' "using namespace System"
            $collector = New-UsingCollector @($fileA, $fileB)
            $collector.Collect()

            $collector.UsingData.Count | Should -Be 1
        }

        It 'Should merge source files for identical using statements' {
            $fileA = New-TestFile 'UsingMergeA.ps1' "using namespace System.IO"
            $fileB = New-TestFile 'UsingMergeB.ps1' "using namespace System.IO"
            $collector = New-UsingCollector @($fileA, $fileB)
            $collector.Collect()

            $collector.UsingData['using namespace System.IO'].SourceFiles.Count | Should -Be 2
        }

        It 'Should keep distinct using statements from different files' {
            $fileA = New-TestFile 'UsingDistinctA.ps1' "using namespace System"
            $fileB = New-TestFile 'UsingDistinctB.ps1' "using namespace System.IO"
            $collector = New-UsingCollector @($fileA, $fileB)
            $collector.Collect()

            $collector.UsingData.Count | Should -Be 2
        }
    }

    Context 'Collection - Reset' {

        It 'Should clear UsingData when Collect is called a second time with different files' {
            $file1 = New-TestFile 'UsingReset1.ps1' "using namespace System"
            $collector = New-UsingCollector @($file1)
            $collector.Collect()

            $file2 = New-TestFile 'UsingReset2.ps1' "using namespace System.IO"
            $collector.IncludeFiles = @($file2)
            $collector.Collect()

            $collector.UsingData.Count | Should -Be 1
        }

        It 'Should start with empty UsingData after explicit Reset' {
            $file = New-TestFile 'UsingBeforeReset.ps1' "using namespace System"
            $collector = New-UsingCollector @($file)
            $collector.Collect()

            $collector.Reset()

            $collector.UsingData.Count | Should -Be 0
        }
    }

    Context 'Parse Error Detection' {

        It 'Should throw InvalidOperationException when a structural parse error prevents using collection' {
            # Unclosed function body — structural parse error, zero using statements
            $file = New-TestFile 'PE-Using-Throw.ps1' 'Function Get-Broken {'
            $collector = New-UsingCollector @($file)

            { $collector.Collect() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should include the file name in the exception message' {
            $file = New-TestFile 'PE-Using-FileName.ps1' 'Function Get-Broken {'
            $collector = New-UsingCollector @($file)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*PE-Using-FileName.ps1*'
        }

        It 'Should not throw when file has a structural parse error but using statements are collected' {
            # Using statement at top is collected before the structural error below it
            $content = "using namespace System`nFunction Get-Broken {"
            $file = New-TestFile 'PE-Using-HasUsing.ps1' $content
            $collector = New-UsingCollector @($file)

            { $collector.Collect() } | Should -Not -Throw
        }

        It 'Should not throw when file has no parse errors and no using statements' {
            $file = New-TestFile 'PE-Using-NoUsing.ps1' '# No using statements in this file'
            $collector = New-UsingCollector @($file)

            { $collector.Collect() } | Should -Not -Throw
        }
    }
}

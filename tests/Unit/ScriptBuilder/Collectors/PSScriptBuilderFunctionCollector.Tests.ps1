using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Describe 'PSScriptBuilderFunctionCollector' {

    BeforeAll {
        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-FuncCollector {
            param([string[]] $Files, [string] $Key = 'FUNCTION_DEFINITIONS')
            $collector = [PSScriptBuilderFunctionCollector]::new($Key)
            $collector.IncludeFiles = $Files
            return $collector
        }
    }

    Context 'Constructor' {

        It 'Should initialise with default CollectionKey' {
            $collector = [PSScriptBuilderFunctionCollector]::new()

            $collector.CollectionKey | Should -Be 'FUNCTION_DEFINITIONS'
        }

        It 'Should initialise with a custom CollectionKey' {
            $collector = [PSScriptBuilderFunctionCollector]::new('MyFunctions')

            $collector.CollectionKey | Should -Be 'MyFunctions'
        }

        It 'Should start with an empty FunctionData dictionary' {
            $collector = [PSScriptBuilderFunctionCollector]::new()

            $collector.FunctionData.Count | Should -Be 0
        }

        It 'Should have CollectorType set to FunctionCollector' {
            $collector = [PSScriptBuilderFunctionCollector]::new()

            $collector.CollectorType | Should -Be ([PSScriptBuilderCollectorType]::FunctionCollector)
        }
    }

    Context 'Collection - basic' {

        It 'Should collect a single function from a file' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\Functions\FuncGetSample.ps1'
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $collector.FunctionData.Count | Should -Be 1
            $collector.FunctionData.ContainsKey('Get-Sample') | Should -BeTrue
        }

        It 'Should collect multiple functions from a single file' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\Functions\FuncAlphaBeta.ps1'
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $collector.FunctionData.Count | Should -Be 2
            $collector.FunctionData.ContainsKey('Get-Alpha') | Should -BeTrue
            $collector.FunctionData.ContainsKey('Set-Beta') | Should -BeTrue
        }

        It 'Should collect functions from multiple files' {
            $fileA = New-TestFile 'FuncFileA.ps1' "Function Get-FuncA { [CmdletBinding()] param() }"
            $fileB = New-TestFile 'FuncFileB.ps1' "Function Get-FuncB { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($fileA, $fileB)
            $collector.Collect()

            $collector.FunctionData.Count | Should -Be 2
        }

        It 'Should return zero functions for a file with no function definitions' {
            $file = New-TestFile 'NoFuncs.ps1' '# just a comment'
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $collector.FunctionData.Count | Should -Be 0
        }

        It 'Should not collect class methods as standalone functions' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\Classes\ClassWithMethod.ps1'
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $collector.FunctionData.Count | Should -Be 0
        }
    }

    Context 'Collection - Reset' {

        It 'Should clear FunctionData when Collect is called a second time with different files' {
            $file1 = New-TestFile 'FuncReset1.ps1' "Function Get-ResetA { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($file1)
            $collector.Collect()

            $file2 = New-TestFile 'FuncReset2.ps1' "Function Get-ResetB { [CmdletBinding()] param() }"
            $collector.IncludeFiles = @($file2)
            $collector.Collect()

            $collector.FunctionData.Count | Should -Be 1
            $collector.FunctionData.ContainsKey('Get-ResetB') | Should -BeTrue
        }

        It 'Should start with empty FunctionData after explicit Reset' {
            $file = New-TestFile 'FuncBeforeReset.ps1' "Function Get-ToReset { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $collector.Reset()

            $collector.FunctionData.Count | Should -Be 0
        }
    }

    Context 'Duplicate Detection' {

        It 'Should throw when the same function name appears in two files' {
            $fileA = New-TestFile 'FuncDupA.ps1' "Function Get-Duplicate { [CmdletBinding()] param() }"
            $fileB = New-TestFile 'FuncDupB.ps1' "Function Get-Duplicate { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExceptionType ([Exception])
        }

        It 'Should include the duplicate function name in the exception message' {
            $fileA = New-TestFile 'FuncDupMsgA.ps1' "Function Get-MyDuplicate { [CmdletBinding()] param() }"
            $fileB = New-TestFile 'FuncDupMsgB.ps1' "Function Get-MyDuplicate { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*Get-MyDuplicate*'
        }

        It 'Should be case-insensitive when detecting duplicates' {
            $fileA = New-TestFile 'FuncCaseDupA.ps1' "Function Get-CaseDuplicate { [CmdletBinding()] param() }"
            $fileB = New-TestFile 'FuncCaseDupB.ps1' "Function GET-CASEDUPLICATE { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExceptionType ([Exception])
        }
    }

    Context 'TryGetComponentDetail' {

        It 'Should return null for an unknown function name' {
            $file = New-TestFile 'FuncDet-Unknown.ps1' "Function Get-Known { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('Get-Unknown', [HashSet[string]]::new())

            $result | Should -BeNull
        }

        It 'Should return a detail object for a known function' {
            $file = New-TestFile 'FuncDet-Known.ps1' "Function Get-KnownFunc { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('Get-KnownFunc', [HashSet[string]]::new())

            $result | Should -Not -BeNull
        }

        It 'Should return Type = FunctionCollector' {
            $file = New-TestFile 'FuncDet-Type.ps1' "Function Get-TypedFunc { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('Get-TypedFunc', [HashSet[string]]::new())

            $result.Type | Should -Be ([PSScriptBuilderCollectorType]::FunctionCollector)
        }

        It 'Should return the correct function name' {
            $file = New-TestFile 'FuncDet-Name.ps1' "Function Get-NamedFunc { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('Get-NamedFunc', [HashSet[string]]::new())

            $result.Name | Should -Be 'Get-NamedFunc'
        }

        It 'Should include project-internal called functions in Dependencies' {
            $fileA = Join-Path $PSScriptRoot '..\..\..\TestData\Functions\FuncA.ps1'
            $fileB = Join-Path $PSScriptRoot '..\..\..\TestData\Functions\FuncCallsA.ps1'
            $collector = New-FuncCollector @($fileA, $fileB)
            $collector.Collect()

            $knownComponents = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $knownComponents.Add('Get-FuncA') | Out-Null
            $knownComponents.Add('Get-FuncCallsA') | Out-Null

            $result = $collector.TryGetComponentDetail('Get-FuncCallsA', $knownComponents)

            $result.Dependencies | Should -Contain 'Get-FuncA'
        }

        It 'Should not include external called functions in Dependencies' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\Functions\FuncWithExternalCalls.ps1'
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('Get-WithExternalCalls', [HashSet[string]]::new())

            $result.Dependencies.Count | Should -Be 0
        }

        It 'Should return empty Dependencies for a function with no calls and no type references' {
            $file = New-TestFile 'FuncDet-NoDeps.ps1' "Function Get-NoDeps { [CmdletBinding()] param() }"
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('Get-NoDeps', [HashSet[string]]::new())

            $result.Dependencies.Count | Should -Be 0
        }

        It 'Should not include a self-reference in Dependencies' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\Functions\FuncRecursive.ps1'
            $collector = New-FuncCollector @($file)
            $collector.Collect()

            $knownComponents = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $knownComponents.Add('Get-Recursive') | Out-Null

            $result = $collector.TryGetComponentDetail('Get-Recursive', $knownComponents)

            $result.Dependencies.Count | Should -Be 0
        }
    }

    Context 'Parse Error Detection' {

        It 'Should throw InvalidOperationException when a structural parse error prevents function collection' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\ParseErrorNoDefinitions.ps1'
            $collector = New-FuncCollector @($file)

            { $collector.Collect() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should include the file name in the exception message' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\ParseErrorNoDefinitions.ps1'
            $collector = New-FuncCollector @($file)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*ParseErrorNoDefinitions.ps1*'
        }

        It 'Should include line and column info in the exception message' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\ParseErrorNoDefinitions.ps1'
            $collector = New-FuncCollector @($file)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*Line*Col*'
        }

        It 'Should not throw when file has no parse errors and no function definitions' {
            $file = New-TestFile 'PE-Func-NoFuncs.ps1' '# No function definitions in this file'
            $collector = New-FuncCollector @($file)

            { $collector.Collect() } | Should -Not -Throw
        }
    }
}

using namespace System
using namespace System.IO

Describe 'PSScriptBuilderSourceMapGenerator' {

    BeforeAll {
        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            [File]::WriteAllText($path, $Content, [Text.Encoding]::UTF8)
            return $path
        }

        # Creates a ContentCollector with one collector, executes it, and returns the ContentCollector
        Function New-ExecutedCC {
            param([PSScriptBuilderCollectorBase] $Collector)
            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.AddCollector($Collector)
            $cc.Execute()
            return $cc
        }
    }

    Context 'CreateSourceMap - EnumCollector' {

        It 'Should return one entry for a single collected enum' {
            $file = New-TestFile 'SingleEnum.ps1' "enum SingleEnum { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.EnumData['SingleEnum'].SourceCode

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result.Count | Should -Be 1
        }

        It 'Should set ComponentName to the enum name' {
            $file = New-TestFile 'NamedEnum.ps1' "enum NamedEnum { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.EnumData['NamedEnum'].SourceCode

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result[0].ComponentName | Should -Be 'NamedEnum'
        }

        It 'Should set ComponentType to Enum' {
            $file = New-TestFile 'TypeEnum.ps1' "enum TypeEnum { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.EnumData['TypeEnum'].SourceCode

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result[0].ComponentType | Should -Be 'Enum'
        }

        It 'Should set OutputLineNumber to 1 when component is at the start of the script' {
            $file = New-TestFile 'StartEnum.ps1' "enum StartEnum { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.EnumData['StartEnum'].SourceCode

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result[0].OutputLineNumber | Should -Be 1
        }

        It 'Should set OutputLineNumber correctly when component is preceded by lines' {
            $file = New-TestFile 'OffsetEnum.ps1' "enum OffsetEnum { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $sourceCode  = $collector.EnumData['OffsetEnum'].SourceCode
            # Prepend exactly 2 lines before the component
            $finalScript = "# line 1`r`n# line 2`r`n$sourceCode"

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result[0].OutputLineNumber | Should -Be 3
        }

        It 'Should set ComponentLineNumber from the source file AST extent' {
            # Enum is on line 2 (preamble comment is line 1)
            $file = New-TestFile 'LineEnum.ps1' "# preamble`r`nenum LineEnum { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $sourceCode  = $collector.EnumData['LineEnum'].SourceCode
            $finalScript = $sourceCode

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result[0].ComponentLineNumber | Should -Be 2
        }

        It 'Should set Offset to 0 for all entries' {
            $file = New-TestFile 'ZeroOffset.ps1' "enum ZeroOffset { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.EnumData['ZeroOffset'].SourceCode

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result[0].Offset | Should -Be 0
        }

        It 'Should set SourceLineNumber equal to ComponentLineNumber (Offset is 0)' {
            $file = New-TestFile 'SourceLineEnum.ps1' "enum SourceLineEnum { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.EnumData['SourceLineEnum'].SourceCode

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result[0].SourceLineNumber | Should -Be $result[0].ComponentLineNumber
        }

        It 'Should omit a component not found in the final script' {
            $file = New-TestFile 'MissingEnum.ps1' "enum MissingEnum { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap('# unrelated script', $cc)

            $result.Count | Should -Be 0
        }

        It 'Should warn when a component is not found in the final script' {
            $file = New-TestFile 'MissingEnum.ps1' "enum MissingEnum { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $output   = & { [PSScriptBuilderSourceMapGenerator]::CreateSourceMap('# unrelated script', $cc) } 3>&1
            $warnings = $output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $warnings.Count        | Should -Be 1
            [string] $warnings[0] | Should -BeLike '*MissingEnum*'
        }

        It 'Should return entries for all collected enums found in the script' {
            $file = New-TestFile 'TwoEnums.ps1' "enum EnumA { Val }`r`nenum EnumB { Val }"
            $collector = [PSScriptBuilderEnumCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $codeA       = $collector.EnumData['EnumA'].SourceCode
            $codeB       = $collector.EnumData['EnumB'].SourceCode
            $finalScript = "$codeA`r`n$codeB"

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result.Count | Should -Be 2
        }
    }

    Context 'CreateSourceMap - ClassCollector' {

        It 'Should create one entry with ComponentType Class for a collected class' {
            $file = New-TestFile 'SampleClass.ps1' "class SampleClass { }"
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.ClassData['SampleClass'].SourceCode

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result.Count | Should -Be 1
            $result[0].ComponentType | Should -Be 'Class'
            $result[0].ComponentName | Should -Be 'SampleClass'
        }
    }

    Context 'CreateSourceMap - FunctionCollector' {

        It 'Should create one entry with ComponentType Function for a collected function' {
            $file = New-TestFile 'GetTestFunc.ps1' 'Function Get-TestFunc { [CmdletBinding()] param() }'
            $collector = [PSScriptBuilderFunctionCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.FunctionData['Get-TestFunc'].SourceCode

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result.Count | Should -Be 1
            $result[0].ComponentType | Should -Be 'Function'
            $result[0].ComponentName | Should -Be 'Get-TestFunc'
        }
    }

    Context 'CreateSourceMap - FileCollector' {

        It 'Should create one entry with ComponentType File for a collected file' {
            $file = New-TestFile 'included.ps1' '# file content'
            $collector = [PSScriptBuilderFileCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.FileData['included.ps1'].Content

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result.Count | Should -Be 1
            $result[0].ComponentType | Should -Be 'File'
        }

        It 'Should use FileName as ComponentName for file entries' {
            $file = New-TestFile 'named-file.ps1' '# content'
            $collector = [PSScriptBuilderFileCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $finalScript = $collector.FileData['named-file.ps1'].Content

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $cc)

            $result[0].ComponentName | Should -Be 'named-file.ps1'
        }
    }

    Context 'CreateSourceMap - UsingCollector' {

        It 'Should return an empty array when only UsingCollector is present' {
            $file = New-TestFile 'usings.ps1' 'using namespace System'
            $collector = [PSScriptBuilderUsingCollector]::new()
            $collector.IncludeFiles = @($file)
            $cc = New-ExecutedCC $collector

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap('using namespace System', $cc)

            $result.Count | Should -Be 0
        }
    }

    Context 'CreateSourceMap - empty ContentCollector' {

        It 'Should return an empty array when no collectors are registered' {
            $cc = [PSScriptBuilderContentCollector]::new()
            $cc.Execute()

            $result = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap('# empty', $cc)

            $result.Count | Should -Be 0
        }
    }
}

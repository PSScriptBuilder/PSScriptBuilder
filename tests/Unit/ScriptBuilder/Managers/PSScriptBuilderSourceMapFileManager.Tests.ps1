using namespace System
using namespace System.IO

Describe 'PSScriptBuilderSourceMapFileManager' {

    BeforeAll {
        Function New-OutputFile {
            param([string] $FileName = 'output.ps1', [string] $Content = '# output script')
            $path = Join-Path $TestDrive $FileName
            [File]::WriteAllText($path, $Content, [Text.Encoding]::UTF8)
            return $path
        }

        Function New-Location {
            param(
                [string] $ComponentName       = 'MyClass',
                [string] $ComponentType       = 'Class',
                [string] $SourceFile          = 'C:\src\MyClass.ps1',
                [int]    $SourceLineNumber    = 1,
                [int]    $ComponentLineNumber = 1,
                [int]    $OutputLineNumber    = 1,
                [int]    $Offset              = 0
            )
            return [PSScriptBuilderSourceLocation]::new(
                $ComponentName, $ComponentType, $SourceFile,
                $SourceLineNumber, $ComponentLineNumber, $OutputLineNumber, $Offset)
        }
    }

    #region GetSidecarPath

    Context 'GetSidecarPath' {

        It 'Should append .sourcemap.json to the output path' {
            $result = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath('C:\build\output.ps1')

            $result | Should -Be 'C:\build\output.ps1.sourcemap.json'
        }

        It 'Should work with paths that already have an extension' {
            $result = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath('C:\build\MyModule.psm1')

            $result | Should -Be 'C:\build\MyModule.psm1.sourcemap.json'
        }

        It 'Should throw ArgumentException when outputPath is null' {
            { [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when outputPath is empty' {
            { [PSScriptBuilderSourceMapFileManager]::GetSidecarPath('') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when outputPath is whitespace' {
            { [PSScriptBuilderSourceMapFileManager]::GetSidecarPath('   ') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    #endregion

    #region SourceMapExists

    Context 'SourceMapExists' {

        It 'Should return true when the sidecar file exists' {
            $sidecarPath = Join-Path $TestDrive 'exists.ps1.sourcemap.json'
            [File]::WriteAllText($sidecarPath, '{}', [Text.Encoding]::UTF8)

            $result = [PSScriptBuilderSourceMapFileManager]::SourceMapExists($sidecarPath)

            $result | Should -BeTrue
        }

        It 'Should return false when the sidecar file does not exist' {
            $sidecarPath = Join-Path $TestDrive 'missing.ps1.sourcemap.json'

            $result = [PSScriptBuilderSourceMapFileManager]::SourceMapExists($sidecarPath)

            $result | Should -BeFalse
        }

        It 'Should return false when sidecarPath is null' {
            $result = [PSScriptBuilderSourceMapFileManager]::SourceMapExists($null)

            $result | Should -BeFalse
        }

        It 'Should return false when sidecarPath is empty' {
            $result = [PSScriptBuilderSourceMapFileManager]::SourceMapExists('')

            $result | Should -BeFalse
        }
    }

    #endregion

    #region WriteSourceMapData / ReadSourceMapData roundtrip

    Context 'WriteSourceMapData' {

        It 'Should create the sidecar file alongside the output file' {
            $outputPath  = New-OutputFile 'write-test.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())

            Test-Path $sidecarPath | Should -BeTrue
        }

        It 'Should throw ArgumentException when outputPath is null' {
            { [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($null, @()) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when sourceMap is null' {
            $outputPath = New-OutputFile 'null-map.ps1'

            { [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should write a sidecar with zero components for an empty source map' {
            $outputPath  = New-OutputFile 'empty-map.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.Components.Count | Should -Be 0
        }
    }

    Context 'WriteSourceMapData / ReadSourceMapData - roundtrip' {

        It 'Should round-trip a single source location correctly' {
            $outputPath  = New-OutputFile 'roundtrip-single.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)
            $entry       = New-Location -ComponentName 'MyClass' -ComponentType 'Class' `
                -SourceFile 'C:\src\MyClass.ps1' -SourceLineNumber 14 -ComponentLineNumber 14 `
                -OutputLineNumber 100 -Offset 0

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @($entry))
            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.Components.Count                | Should -Be 1
            $result.Components[0].ComponentName     | Should -Be 'MyClass'
            $result.Components[0].ComponentType     | Should -Be 'Class'
            $result.Components[0].SourceFile        | Should -Be 'C:\src\MyClass.ps1'
            $result.Components[0].SourceLineNumber  | Should -Be 14
            $result.Components[0].ComponentLineNumber | Should -Be 14
            $result.Components[0].OutputLineNumber  | Should -Be 100
            $result.Components[0].Offset            | Should -Be 0
        }

        It 'Should round-trip multiple source locations preserving order' {
            $outputPath  = New-OutputFile 'roundtrip-multi.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)
            $entries = @(
                (New-Location -ComponentName 'EnumA' -ComponentType 'Enum' -OutputLineNumber 10),
                (New-Location -ComponentName 'ClassB' -ComponentType 'Class' -OutputLineNumber 20),
                (New-Location -ComponentName 'Get-Func' -ComponentType 'Function' -OutputLineNumber 30)
            )

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)
            $result = [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath)

            $result.Components.Count | Should -Be 3
            $result.Components[0].ComponentName | Should -Be 'EnumA'
            $result.Components[1].ComponentName | Should -Be 'ClassB'
            $result.Components[2].ComponentName | Should -Be 'Get-Func'
        }

        It 'Should store the OutputHash of the output file in the sidecar' {
            $outputPath  = New-OutputFile 'hash-test.ps1' '# known content'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)
            $expectedHash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            $storedHash = [PSScriptBuilderSourceMapFileManager]::ReadOutputHash($sidecarPath)

            $storedHash | Should -Be $expectedHash
        }
    }

    #endregion

    #region ReadSourceMapData - error cases

    Context 'ReadSourceMapData - error cases' {

        It 'Should throw FileNotFoundException when sidecar does not exist' {
            $sidecarPath = Join-Path $TestDrive 'missing.ps1.sourcemap.json'

            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($sidecarPath) } |
                Should -Throw -ExceptionType ([FileNotFoundException])
        }

        It 'Should throw ArgumentException when sidecarPath is null' {
            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData($null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when sidecarPath is empty' {
            { [PSScriptBuilderSourceMapFileManager]::ReadSourceMapData('') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    #endregion

    #region ReadOutputHash - error cases

    Context 'ReadOutputHash - error cases' {

        It 'Should throw FileNotFoundException when sidecar does not exist' {
            $sidecarPath = Join-Path $TestDrive 'missing-hash.ps1.sourcemap.json'

            { [PSScriptBuilderSourceMapFileManager]::ReadOutputHash($sidecarPath) } |
                Should -Throw -ExceptionType ([FileNotFoundException])
        }

        It 'Should throw ArgumentException when sidecarPath is null' {
            { [PSScriptBuilderSourceMapFileManager]::ReadOutputHash($null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    #endregion

    #region ReadOutputLineCount

    Context 'WriteSourceMapData / ReadOutputLineCount - roundtrip' {

        It 'Should store the line count of the output file in the sidecar' {
            $outputPath  = New-OutputFile 'linecount-test.ps1' "line1`nline2`nline3"
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)

            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            $storedCount = [PSScriptBuilderSourceMapFileManager]::ReadOutputLineCount($sidecarPath)

            $storedCount | Should -Be 3
        }
    }

    Context 'ReadOutputLineCount - error cases' {

        It 'Should throw FileNotFoundException when sidecar does not exist' {
            $sidecarPath = Join-Path $TestDrive 'missing-linecount.ps1.sourcemap.json'

            { [PSScriptBuilderSourceMapFileManager]::ReadOutputLineCount($sidecarPath) } |
                Should -Throw -ExceptionType ([FileNotFoundException])
        }

        It 'Should throw ArgumentException when sidecarPath is null' {
            { [PSScriptBuilderSourceMapFileManager]::ReadOutputLineCount($null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    #endregion ReadOutputLineCount
}

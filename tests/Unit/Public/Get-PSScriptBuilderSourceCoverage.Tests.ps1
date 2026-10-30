using namespace System
using namespace System.IO

Describe 'Get-PSScriptBuilderSourceCoverage' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-OutputFile {
            param([string] $FileName = 'output.psm1', [string] $Content = "line1`nline2`nline3`nline4`nline5")
            $path = Join-Path $TestDrive $FileName
            [File]::WriteAllText($path, $Content, [Text.Encoding]::UTF8)
            return $path
        }

        Function New-Location {
            param(
                [string] $ComponentName       = 'Foo',
                [string] $ComponentType       = 'Class',
                [string] $SourceFile          = 'C:\src\Foo.ps1',
                [int]    $SourceLineNumber    = 1,
                [int]    $ComponentLineNumber = 1,
                [int]    $OutputLineNumber    = 1,
                [int]    $Offset              = 0
            )
            return [PSScriptBuilderSourceLocation]::new(
                $ComponentName, $ComponentType, $SourceFile,
                $SourceLineNumber, $ComponentLineNumber, $OutputLineNumber, $Offset)
        }

        Function New-BuildResult {
            param([string] $OutputPath, [string] $SourceMapPath = "$OutputPath.sourcemap.json")
            $counts = [PSScriptBuilderBuildComponentCounts]::new()
            return [PSScriptBuilderBuildResult]::new(
                $OutputPath, 0, $null, $SourceMapPath, $counts, [TimeSpan]::Zero, @(), @(), $true)
        }

        Function New-CoverageStub {
            param(
                [string]   $OutputPath,
                [int[]]    $ExecutedLines = @(1),
                [int[]]    $MissedLines   = @()
            )
            return [PSCustomObject] @{
                CommandsExecuted = @($ExecutedLines | ForEach-Object { [PSCustomObject] @{ File = $OutputPath; Line = $_; HitCount = 1 } })
                CommandsMissed   = @($MissedLines   | ForEach-Object { [PSCustomObject] @{ File = $OutputPath; Line = $_; HitCount = 0 } })
            }
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    #region No source map written

    Context 'ByBuildResult - no source map written' {

        It 'Should throw when BuildResult.SourceMapPath is empty' {
            $outputPath  = New-OutputFile 'no-map.psm1'
            $buildResult = New-BuildResult -OutputPath $outputPath -SourceMapPath ''
            $coverage    = New-CoverageStub -OutputPath $outputPath

            { $buildResult | Get-PSScriptBuilderSourceCoverage -CodeCoverage $coverage } |
                Should -Throw
        }
    }

    #endregion

    #region ByBuildResult - successful translation

    Context 'ByBuildResult - successful translation' {

        It 'Should return one result per distinct source file' {
            $outputPath = New-OutputFile 'by-result.psm1'
            $entries    = @(
                (New-Location -ComponentName 'Foo' -SourceFile 'C:\src\Foo.ps1' -OutputLineNumber 1),
                (New-Location -ComponentName 'Bar' -SourceFile 'C:\src\Bar.ps1' -OutputLineNumber 3)
            )
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)

            $buildResult = New-BuildResult -OutputPath $outputPath
            $coverage    = New-CoverageStub -OutputPath $outputPath -ExecutedLines @(1, 3) -MissedLines @(2)

            $results = $buildResult | Get-PSScriptBuilderSourceCoverage -CodeCoverage $coverage

            $results.Count | Should -Be 2
        }

        It 'Should correctly attribute hits and misses to the right source file' {
            $outputPath = New-OutputFile 'attribution.psm1'
            $entries    = @(
                (New-Location -ComponentName 'Foo' -SourceFile 'C:\src\Foo.ps1' -OutputLineNumber 1)
            )
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)

            $buildResult = New-BuildResult -OutputPath $outputPath
            $coverage    = New-CoverageStub -OutputPath $outputPath -ExecutedLines @(1, 2) -MissedLines @(3)

            $results = $buildResult | Get-PSScriptBuilderSourceCoverage -CodeCoverage $coverage

            $results[0].SourceFile     | Should -Be 'C:\src\Foo.ps1'
            $results[0].HitCommands    | Should -Be 2
            $results[0].MissedCommands | Should -Be 1
        }
    }

    #endregion

    #region ByOutputPath - successful translation

    Context 'ByOutputPath - successful translation' {

        It 'Should return correctly translated results using an absolute output path' {
            $outputPath = New-OutputFile 'by-path.psm1'
            $entries    = @(
                (New-Location -ComponentName 'Foo' -SourceFile 'C:\src\Foo.ps1' -OutputLineNumber 1)
            )
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)
            $coverage = New-CoverageStub -OutputPath $outputPath -ExecutedLines @(1)

            $results = Get-PSScriptBuilderSourceCoverage -OutputPath $outputPath -CodeCoverage $coverage

            $results.Count | Should -Be 1
            $results[0].SourceFile | Should -Be 'C:\src\Foo.ps1'
        }
    }

    #endregion

    #region Missing sidecar

    Context 'ByOutputPath - missing sidecar' {

        It 'Should throw when the sidecar file does not exist' {
            $outputPath = New-OutputFile 'no-sidecar.psm1'
            # Deliberately do NOT call WriteSourceMapData
            $coverage = New-CoverageStub -OutputPath $outputPath

            { Get-PSScriptBuilderSourceCoverage -OutputPath $outputPath -CodeCoverage $coverage } |
                Should -Throw
        }
    }

    #endregion

    #region Stale source map warning

    Context 'Stale source map warning' {

        It 'Should emit a warning when the output file has changed since the source map was created' {
            $outputPath = New-OutputFile 'stale.psm1' 'line1'
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())

            # Modify the output file after writing the source map
            [File]::WriteAllText($outputPath, 'modified content', [Text.Encoding]::UTF8)
            $coverage = New-CoverageStub -OutputPath $outputPath

            $warnings = @()
            Get-PSScriptBuilderSourceCoverage -OutputPath $outputPath -CodeCoverage $coverage -WarningVariable warnings 3>$null | Out-Null

            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Should still return results even when the source map is stale' {
            $outputPath = New-OutputFile 'stale-return.psm1' 'line1'
            $entries    = @(New-Location -ComponentName 'Foo' -SourceFile 'C:\src\Foo.ps1' -OutputLineNumber 1)
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)
            [File]::WriteAllText($outputPath, 'changed', [Text.Encoding]::UTF8)
            $coverage = New-CoverageStub -OutputPath $outputPath

            $result = Get-PSScriptBuilderSourceCoverage -OutputPath $outputPath -CodeCoverage $coverage 3>$null

            $result.Count | Should -Be 1
        }
    }

    #endregion

    #region Empty coverage input

    Context 'Empty coverage input' {

        It 'Should return an empty array when there are no executed or missed commands' {
            $outputPath = New-OutputFile 'empty.psm1'
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            $coverage = New-CoverageStub -OutputPath $outputPath -ExecutedLines @() -MissedLines @()

            $results = Get-PSScriptBuilderSourceCoverage -OutputPath $outputPath -CodeCoverage $coverage

            $results.Count | Should -Be 0
        }
    }

    #endregion
}
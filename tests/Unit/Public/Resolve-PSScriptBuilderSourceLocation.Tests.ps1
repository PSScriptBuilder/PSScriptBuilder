using namespace System
using namespace System.IO

Describe 'Resolve-PSScriptBuilderSourceLocation' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

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

        Function New-BuildResult {
            param([string] $OutputPath)
            $counts = [PSScriptBuilderBuildComponentCounts]::new()
            return [PSScriptBuilderBuildResult]::new(
                $OutputPath, 0, $null, "$OutputPath.sourcemap.json", $counts, [TimeSpan]::Zero, @(), @(), $true)
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    #region Parameter validation

    Context 'Parameter validation' {

        It 'Should throw when -LineNumber and -ErrorRecord are both provided' {
            $outputPath = New-OutputFile 'both-params.ps1'
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())

            $ex = [Exception]::new("test")
            $er = [System.Management.Automation.ErrorRecord]::new($ex, "Id",
                [System.Management.Automation.ErrorCategory]::NotSpecified, $null)

            {
                Resolve-PSScriptBuilderSourceLocation `
                    -OutputPath $outputPath -LineNumber 1 -ErrorRecord $er
            } | Should -Throw
        }
    }

    #endregion

    #region ByBuildResult parameter set

    Context 'ByBuildResult - returns full source map when no filter is given' {

        It 'Should return all entries when called without -LineNumber or -ErrorRecord' {
            $outputPath = New-OutputFile 'by-result.ps1'
            $entries    = @(
                (New-Location -ComponentName 'EnumA'  -OutputLineNumber 10),
                (New-Location -ComponentName 'ClassB' -OutputLineNumber 50)
            )
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)

            $buildResult = New-BuildResult -OutputPath $outputPath
            $result = $buildResult | Resolve-PSScriptBuilderSourceLocation

            $result.Count | Should -Be 2
        }
    }

    Context 'ByBuildResult - LineNumber resolution' {

        It 'Should resolve a line number to the correct component' {
            $outputPath = New-OutputFile 'by-result-line.ps1' ((1..20 | ForEach-Object { "# line $_" }) -join "`n")
            $entries    = @(
                (New-Location -ComponentName 'MyEnum' -ComponentType 'Enum' -OutputLineNumber 5)
            )
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)

            $buildResult = New-BuildResult -OutputPath $outputPath
            $result = $buildResult | Resolve-PSScriptBuilderSourceLocation -LineNumber 7

            $result.ComponentName | Should -Be 'MyEnum'
            $result.Offset        | Should -Be 2
        }
    }

    #endregion

    #region ByOutputPath parameter set

    Context 'ByOutputPath - returns full source map when no filter is given' {

        It 'Should return all entries using an absolute output path' {
            $outputPath = New-OutputFile 'by-path.ps1'
            $entries    = @(
                (New-Location -ComponentName 'FuncA' -ComponentType 'Function' -OutputLineNumber 1)
            )
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)

            $result = Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath

            $result.Count | Should -Be 1
            $result[0].ComponentName | Should -Be 'FuncA'
        }
    }

    Context 'ByOutputPath - LineNumber resolution' {

        It 'Should resolve a line number using an absolute output path' {
            $outputPath = New-OutputFile 'by-path-line.ps1' ((1..110 | ForEach-Object { "# line $_" }) -join "`n")
            $entries    = @(
                (New-Location -ComponentName 'MyClass' -ComponentLineNumber 10 -OutputLineNumber 100)
            )
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)

            $result = Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath -LineNumber 105

            $result.ComponentName  | Should -Be 'MyClass'
            $result.Offset         | Should -Be 5
            $result.SourceLineNumber | Should -Be 15
        }
    }

    #endregion

    #region Missing sidecar

    Context 'Missing sidecar' {

        It 'Should throw when the sidecar file does not exist' {
            $outputPath = New-OutputFile 'no-sidecar.ps1'
            # Deliberately do NOT call WriteSourceMap

            { Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath } |
                Should -Throw
        }
    }

    #endregion

    #region Stale source map warning

    Context 'Stale source map warning' {

        It 'Should emit a warning when the output file has changed since the source map was created' {
            $outputPath = New-OutputFile 'stale.ps1' '# original content'
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())

            # Modify the output file after writing the source map
            [File]::WriteAllText($outputPath, '# modified content', [Text.Encoding]::UTF8)

            $warnings = @()
            Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath -WarningVariable warnings 3>$null

            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Should still return the source map even when stale' {
            $outputPath = New-OutputFile 'stale-return.ps1' '# original'
            $entries    = @(New-Location -ComponentName 'MyFunc' -OutputLineNumber 1)
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)
            [File]::WriteAllText($outputPath, '# changed', [Text.Encoding]::UTF8)

            $result = Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath 3>$null

            $result.Count | Should -Be 1
        }
    }

    #endregion

    #region Line number exceeds file length

    Context 'ByOutputPath - line number exceeds file length' {

        It 'Should return null and warn when LineNumber exceeds the output file length' {
            $outputPath = New-OutputFile 'bounds.ps1' "line1`nline2`nline3"
            $entries    = @(
                (New-Location -ComponentName 'MyFunc' -ComponentType 'Function' -OutputLineNumber 1)
            )
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)

            $output   = Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath -LineNumber 9999 3>&1
            $result   = $output | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] }
            $warnings = $output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $result   | Should -BeNullOrEmpty
            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    #endregion
}

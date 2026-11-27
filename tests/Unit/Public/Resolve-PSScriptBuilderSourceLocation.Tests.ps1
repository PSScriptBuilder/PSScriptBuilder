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

    Context 'ByOutputPath - ErrorRecord resolution' {

        It 'Should resolve an ErrorRecord that originated in the output script' {
            $outputPath = New-OutputFile 'error-output.ps1' 'throw "test error"'
            $entries    = @(New-Location -ComponentName 'MyFunc' -ComponentType 'Function' -OutputLineNumber 1)
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)
            $errorRecord = $null
            try { . $outputPath } catch { $errorRecord = $_ }

            $result = Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath -ErrorRecord $errorRecord

            $result.ComponentName | Should -Be 'MyFunc'
        }

        It 'Should return null and warn for an ErrorRecord that originated in a different script' {
            $outputPath = New-OutputFile 'error-output-other.ps1' '# output script'
            $entries    = @(New-Location -OutputLineNumber 1)
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)
            $otherPath   = New-OutputFile 'error-other.ps1' 'throw "test error"'
            $errorRecord = $null
            try { . $otherPath } catch { $errorRecord = $_ }

            $output   = Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath -ErrorRecord $errorRecord 3>&1
            $result   = $output | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] }
            $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })

            $result               | Should -BeNullOrEmpty
            $warnings.Count       | Should -Be 1
            [string] $warnings[0] | Should -BeLike '*originated in*'
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

    #region Unsupported source map format version

    Context 'Unsupported source map format version' {

        It 'Should throw with the format versions in the message when the source map uses a newer format' {
            $outputPath  = New-OutputFile 'newer-format.ps1'
            $sidecarPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($outputPath)
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            $data = [File]::ReadAllText($sidecarPath) | ConvertFrom-Json
            $data.FormatVersion = 2
            [File]::WriteAllText($sidecarPath, ($data | ConvertTo-Json -Depth 5))

            { Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath } |
                Should -Throw -ExpectedMessage '*format version 2*'
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

        It 'Should resolve and warn that staleness cannot be checked when the output file is missing' {
            $outputPath = New-OutputFile 'stale-missing.ps1' '# output script'
            $entries    = @(New-Location -ComponentName 'MyFunc' -OutputLineNumber 1)
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, $entries)
            Remove-Item -LiteralPath $outputPath

            $output   = Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath -LineNumber 1 2>&1 3>&1
            $result   = $output | Where-Object { $_ -is [PSScriptBuilderSourceLocation] }
            $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $errors   = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })

            $result.ComponentName | Should -Be 'MyFunc'
            $warnings.Count       | Should -Be 1
            [string] $warnings[0] | Should -BeLike '*could not be read*cannot be checked whether the source map is stale*'
            $errors.Count         | Should -Be 0
        }

        It 'Should make the warning available through -WarningVariable when the output file is missing' {
            $outputPath = New-OutputFile 'stale-missing-variable.ps1' '# output script'
            [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($outputPath, @())
            Remove-Item -LiteralPath $outputPath

            $warnings = @()
            Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath -WarningVariable warnings 3>$null | Out-Null

            $warnings.Count       | Should -Be 1
            [string] $warnings[0] | Should -BeLike '*could not be read*'
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

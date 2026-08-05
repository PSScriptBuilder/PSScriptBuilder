using namespace System
using namespace System.IO

Describe 'PSScriptBuilderBuildResultExporter' {

    BeforeAll {
        Function New-Counts {
            param(
                [int] $Usings = 0, [int] $Enums = 0,
                [int] $Classes = 0, [int] $Functions = 0, [int] $Files = 0
            )
            $c = [PSScriptBuilderBuildComponentCounts]::new()
            $c.UsingStatements     = $Usings
            $c.EnumDefinitions     = $Enums
            $c.ClassDefinitions    = $Classes
            $c.FunctionDefinitions = $Functions
            $c.FileContents        = $Files
            return $c
        }

        Function New-BuildResult {
            param(
                [string]                                $OutputPath       = 'C:\out.ps1',
                [long]                                  $OutputFileSize   = 512,
                [string]                                $BackupPath       = $null,
                [PSScriptBuilderBuildComponentCounts]   $ComponentCounts  = $null,
                [TimeSpan]                              $ExecutionTime    = [TimeSpan]::Zero,
                [string[]]                              $ProcessedFiles   = @(),
                [PSScriptBuilderBuildComponentDetail[]] $ComponentDetails = @(),
                [bool]                                  $SyntaxValid      = $true
            )
            if ($null -eq $ComponentCounts) { $ComponentCounts = New-Counts }
            return [PSScriptBuilderBuildResult]::new(
                $OutputPath, $OutputFileSize, $BackupPath, $ComponentCounts,
                $ExecutionTime, $ProcessedFiles, $ComponentDetails, $SyntaxValid)
        }

        Function New-Exporter {
            param(
                [PSScriptBuilderBuildResult] $BuildResult,
                [string]                     $Path,
                [bool]                       $Detailed = $false,
                [bool]                       $Force    = $false
            )
            return [PSScriptBuilderBuildResultExporter]::new($BuildResult, $Path, $Detailed, $Force)
        }
    }

    #region Export - Guard clause

    Context 'Export - guard clause' {

        It 'Should throw IOException when file already exists and Force is false' {
            $existingFile = Join-Path $TestDrive 'existing.json'
            [File]::WriteAllText($existingFile, '{}', [Text.Encoding]::UTF8)

            $exporter = New-Exporter -BuildResult (New-BuildResult) -Path $existingFile -Force $false

            { $exporter.Export() } | Should -Throw -ExceptionType ([IOException])
        }

        It 'Should not throw when file already exists and Force is true' {
            $existingFile = Join-Path $TestDrive 'force-overwrite.json'
            [File]::WriteAllText($existingFile, '{}', [Text.Encoding]::UTF8)

            $exporter = New-Exporter -BuildResult (New-BuildResult) -Path $existingFile -Force $true

            { $exporter.Export() } | Should -Not -Throw
        }

        It 'Should not throw when file does not exist and Force is false' {
            $newFile  = Join-Path $TestDrive 'new-file.json'
            $exporter = New-Exporter -BuildResult (New-BuildResult) -Path $newFile -Force $false

            { $exporter.Export() } | Should -Not -Throw
        }
    }

    #endregion Export - Guard clause

    #region Export - File creation

    Context 'Export - file creation' {

        It 'Should create the output file at the specified path' {
            $filePath = Join-Path $TestDrive 'result.json'
            $exporter = New-Exporter -BuildResult (New-BuildResult) -Path $filePath

            $exporter.Export()

            Test-Path $filePath | Should -BeTrue
        }

        It 'Should create the output directory when it does not exist' {
            $dir      = Join-Path $TestDrive 'nested\output'
            $filePath = Join-Path $dir 'result.json'
            $exporter = New-Exporter -BuildResult (New-BuildResult) -Path $filePath

            $exporter.Export()

            Test-Path $dir | Should -BeTrue
        }

        It 'Should return the absolute path of the created file' {
            $filePath = Join-Path $TestDrive 'return-path.json'
            $exporter = New-Exporter -BuildResult (New-BuildResult) -Path $filePath

            $returned = $exporter.Export()

            $returned | Should -Be $filePath
        }

        It 'Should overwrite an existing file when Force is true' {
            $filePath = Join-Path $TestDrive 'overwrite.json'
            [File]::WriteAllText($filePath, 'old content', [Text.Encoding]::UTF8)

            $exporter = New-Exporter -BuildResult (New-BuildResult) -Path $filePath -Force $true
            $exporter.Export()

            $content = Get-Content -Path $filePath -Raw
            $content | Should -Not -Be 'old content'
        }
    }

    #endregion Export - File creation

    #region Export - JSON structure (summary)

    Context 'Export - JSON structure without Detailed' {

        BeforeAll {
            $counts   = New-Counts -Usings 2 -Enums 1 -Classes 4 -Functions 3 -Files 0
            $elapsed  = [TimeSpan]::FromMilliseconds(1250)
            $result   = New-BuildResult `
                -OutputPath     'C:\build\out.ps1' `
                -OutputFileSize 8192 `
                -BackupPath     'C:\build\out.bak' `
                -ComponentCounts $counts `
                -ExecutionTime  $elapsed `
                -SyntaxValid    $true `
                -ProcessedFiles @('C:\src\a.ps1', 'C:\src\b.ps1') `
                -ComponentDetails @(
                    [PSScriptBuilderBuildComponentDetail]::new(
                        [PSScriptBuilderCollectorType]::ClassCollector, 'MyClass', 'C:\src\a.ps1', @()))

            $filePath = Join-Path $TestDrive 'summary.json'
            $exporter = New-Exporter -BuildResult $result -Path $filePath -Detailed $false
            $exporter.Export()

            $Script:RawJson = Get-Content -Path $filePath -Raw
            $Script:Json    = $Script:RawJson | ConvertFrom-Json
        }

        It 'Should write valid JSON' {
            $Script:Json | Should -Not -BeNullOrEmpty
        }

        It 'Should include generatedAt as an ISO-8601 formatted string' {
            $Script:RawJson | Should -Match '"generatedAt"\s*:\s*"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
        }

        It 'Should include outputPath' {
            $Script:Json.outputPath | Should -Be 'C:\build\out.ps1'
        }

        It 'Should include outputFileSizeBytes' {
            $Script:Json.outputFileSizeBytes | Should -Be 8192
        }

        It 'Should include backupPath' {
            $Script:Json.backupPath | Should -Be 'C:\build\out.bak'
        }

        It 'Should include syntaxValid' {
            $Script:Json.syntaxValid | Should -BeTrue
        }

        It 'Should include executionTimeMs as the total milliseconds' {
            $Script:Json.executionTimeMs | Should -Be 1250
        }

        It 'Should include totalComponents as sum of all counts' {
            $Script:Json.totalComponents | Should -Be 10
        }

        It 'Should include componentCounts with all sub-keys' {
            $Script:Json.componentCounts.usingStatements     | Should -Be 2
            $Script:Json.componentCounts.enumDefinitions     | Should -Be 1
            $Script:Json.componentCounts.classDefinitions    | Should -Be 4
            $Script:Json.componentCounts.functionDefinitions | Should -Be 3
            $Script:Json.componentCounts.fileContents        | Should -Be 0
        }

        It 'Should NOT include processedFiles when Detailed is false' {
            $Script:Json.PSObject.Properties.Name | Should -Not -Contain 'processedFiles'
        }

        It 'Should NOT include components when Detailed is false' {
            $Script:Json.PSObject.Properties.Name | Should -Not -Contain 'components'
        }
    }

    #endregion Export - JSON structure (summary)

    #region Export - JSON structure (detailed)

    Context 'Export - JSON structure with Detailed' {

        BeforeAll {
            $counts  = New-Counts -Classes 1 -Functions 1
            $detail1 = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::ClassCollector, 'MyClass', 'C:\src\a.ps1', @('BaseClass'))
            $detail2 = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::FunctionCollector, 'Get-MyThing', 'C:\src\b.ps1', @())

            $result = New-BuildResult `
                -ComponentCounts  $counts `
                -ProcessedFiles   @('C:\src\a.ps1', 'C:\src\b.ps1') `
                -ComponentDetails @($detail1, $detail2)

            $filePath = Join-Path $TestDrive 'detailed.json'
            $exporter = New-Exporter -BuildResult $result -Path $filePath -Detailed $true
            $exporter.Export()

            $Script:JsonDetailed = Get-Content -Path $filePath -Raw | ConvertFrom-Json
        }

        It 'Should include processedFiles when Detailed is true' {
            $Script:JsonDetailed.PSObject.Properties.Name | Should -Contain 'processedFiles'
        }

        It 'Should include all processed file paths' {
            $Script:JsonDetailed.processedFiles | Should -Contain 'C:\src\a.ps1'
            $Script:JsonDetailed.processedFiles | Should -Contain 'C:\src\b.ps1'
        }

        It 'Should include components when Detailed is true' {
            $Script:JsonDetailed.PSObject.Properties.Name | Should -Contain 'components'
        }

        It 'Should include the correct number of components' {
            $Script:JsonDetailed.components.Count | Should -Be 2
        }

        It 'Should map CollectorType enum to its string name' {
            $Script:JsonDetailed.components[0].type | Should -Be 'Class'
            $Script:JsonDetailed.components[1].type | Should -Be 'Function'
        }

        It 'Should include component name' {
            $Script:JsonDetailed.components[0].name | Should -Be 'MyClass'
            $Script:JsonDetailed.components[1].name | Should -Be 'Get-MyThing'
        }

        It 'Should include component sourceFile' {
            $Script:JsonDetailed.components[0].sourceFile | Should -Be 'C:\src\a.ps1'
        }

        It 'Should include component dependencies' {
            $Script:JsonDetailed.components[0].dependencies | Should -Contain 'BaseClass'
            $Script:JsonDetailed.components[1].dependencies | Should -BeNullOrEmpty
        }
    }

    #endregion Export - JSON structure (detailed)

    #region Export - backupPath null handling

    Context 'Export - null values in JSON' {

        It 'Should serialize null backupPath without throwing' {
            $filePath = Join-Path $TestDrive 'null-backup.json'
            $exporter = New-Exporter -BuildResult (New-BuildResult -BackupPath $null) -Path $filePath

            { $exporter.Export() } | Should -Not -Throw
        }
    }

    #endregion Export - null values in JSON
}

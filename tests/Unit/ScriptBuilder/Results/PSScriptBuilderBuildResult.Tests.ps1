using namespace System

Describe 'PSScriptBuilderBuildResult' {

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

        Function New-Result {
            param(
                [string]                                $OutputPath       = 'C:\out.ps1',
                [long]                                  $OutputFileSize   = 100,
                [string]                                $BackupPath       = $null,
                [PSScriptBuilderBuildComponentCounts]   $ComponentCounts  = $null,
                [TimeSpan]                              $ExecutionTime    = [TimeSpan]::Zero,
                [string[]]                              $ProcessedFiles   = @(),
                [PSScriptBuilderBuildComponentDetail[]] $ComponentDetails = @(),
                [bool]                                  $SyntaxValid      = $false
            )
            if ($null -eq $ComponentCounts) { $ComponentCounts = New-Counts }
            return [PSScriptBuilderBuildResult]::new(
                $OutputPath, $OutputFileSize, $BackupPath, $ComponentCounts,
                $ExecutionTime, $ProcessedFiles, $ComponentDetails,
                $SyntaxValid)
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set OutputPath' {
            $result = New-Result -OutputPath 'C:\output\script.ps1'

            $result.OutputPath | Should -Be 'C:\output\script.ps1'
        }

        It 'Should set OutputFileSize' {
            $result = New-Result -OutputFileSize 2048

            $result.OutputFileSize | Should -Be 2048
        }

        It 'Should set BackupPath' {
            $result = New-Result -BackupPath 'C:\backups\script.bak'

            $result.BackupPath | Should -Be 'C:\backups\script.bak'
        }

        It 'Should set BackupPath to null when not provided' {
            $result = New-Result -BackupPath $null

            $result.BackupPath | Should -BeNullOrEmpty
        }

        It 'Should set ComponentCounts' {
            $counts = New-Counts -Classes 3 -Functions 2
            $result = New-Result -ComponentCounts $counts

            $result.ComponentCounts.ClassDefinitions    | Should -Be 3
            $result.ComponentCounts.FunctionDefinitions | Should -Be 2
        }

        It 'Should set ExecutionTime' {
            $elapsed = [TimeSpan]::FromSeconds(1.5)
            $result  = New-Result -ExecutionTime $elapsed

            $result.ExecutionTime | Should -Be $elapsed
        }

        It 'Should set ProcessedFiles' {
            $files  = @('C:\a.ps1', 'C:\b.ps1')
            $result = New-Result -ProcessedFiles $files

            $result.ProcessedFiles | Should -Be $files
        }

        It 'Should set ComponentDetails' {
            $detail  = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::ClassCollector, 'MyClass', 'C:\file.ps1', @())
            $result  = New-Result -ComponentDetails @($detail)

            $result.ComponentDetails.Count | Should -Be 1
            $result.ComponentDetails[0].Name | Should -Be 'MyClass'
        }

        It 'Should set SyntaxValid' {
            $result = New-Result -SyntaxValid $true

            $result.SyntaxValid | Should -BeTrue
        }
    }

    Context 'TotalComponents - calculated property' {

        It 'Should calculate TotalComponents as sum of all counts' {
            $counts = New-Counts -Usings 1 -Enums 2 -Classes 3 -Functions 4 -Files 5
            $result = New-Result -ComponentCounts $counts

            $result.TotalComponents | Should -Be 15
        }

        It 'Should return 0 when all counts are zero' {
            $result = New-Result -ComponentCounts (New-Counts)

            $result.TotalComponents | Should -Be 0
        }
    }
}

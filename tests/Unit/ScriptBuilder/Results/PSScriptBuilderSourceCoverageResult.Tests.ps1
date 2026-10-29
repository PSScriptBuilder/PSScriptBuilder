Describe 'PSScriptBuilderSourceCoverageResult' {

    BeforeAll {
        Function New-CoverageResult {
            param(
                [string]                           $SourceFile      = 'C:\src\MyComponent.ps1',
                [int]                              $TotalCommands   = 10,
                [int]                              $HitCommands     = 7,
                [int]                              $MissedCommands  = 3,
                [double]                           $CoveragePercent = 70.0,
                [PSScriptBuilderSourceLocation[]]  $MissedLocations = @()
            )
            return [PSScriptBuilderSourceCoverageResult]::new(
                $SourceFile, $TotalCommands, $HitCommands, $MissedCommands, $CoveragePercent, $MissedLocations)
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set SourceFile' {
            $result = New-CoverageResult -SourceFile 'C:\project\src\BaseService.ps1'

            $result.SourceFile | Should -Be 'C:\project\src\BaseService.ps1'
        }

        It 'Should set TotalCommands' {
            $result = New-CoverageResult -TotalCommands 42

            $result.TotalCommands | Should -Be 42
        }

        It 'Should set HitCommands' {
            $result = New-CoverageResult -HitCommands 30

            $result.HitCommands | Should -Be 30
        }

        It 'Should set MissedCommands' {
            $result = New-CoverageResult -MissedCommands 12

            $result.MissedCommands | Should -Be 12
        }

        It 'Should set CoveragePercent' {
            $result = New-CoverageResult -CoveragePercent 71.4

            $result.CoveragePercent | Should -Be 71.4
        }

        It 'Should set MissedLocations' {
            $location = [PSScriptBuilderSourceLocation]::new(
                'MyComponent', 'Class', 'C:\src\MyComponent.ps1', 14, 14, 100, 0)

            $result = New-CoverageResult -MissedLocations @($location)

            $result.MissedLocations.Count    | Should -Be 1
            $result.MissedLocations[0].Offset | Should -Be 0
        }

        It 'Should allow an empty MissedLocations array (fully covered file)' {
            $result = New-CoverageResult -MissedLocations @()

            $result.MissedLocations.Count | Should -Be 0
        }
    }
}
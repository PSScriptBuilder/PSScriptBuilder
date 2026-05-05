Describe 'PSScriptBuilderComponentDependencyEntry' {

    BeforeAll {
        Function New-Entry {
            param(
                [string]   $Name           = 'ComponentA',
                [int]      $Depth          = 1,
                [string[]] $DependencyPath = @('Root', 'ComponentA')
            )
            return [PSScriptBuilderComponentDependencyEntry]::new($Name, $Depth, $DependencyPath)
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set Name' {
            $entry = New-Entry -Name 'Employee'

            $entry.Name | Should -Be 'Employee'
        }

        It 'Should set Depth' {
            $entry = New-Entry -Depth 2

            $entry.Depth | Should -Be 2
        }

        It 'Should set DependencyPath' {
            $path  = @('New-Employee', 'Employee', 'Person')
            $entry = New-Entry -DependencyPath $path

            $entry.DependencyPath | Should -Be $path
        }

        It 'Should set Depth to 1 for a direct dependency' {
            $entry = New-Entry -Depth 1

            $entry.Depth | Should -Be 1
        }

        It 'Should set Depth to 3 for a deeply transitive dependency' {
            $entry = New-Entry -Depth 3

            $entry.Depth | Should -Be 3
        }

        It 'Should preserve DependencyPath order' {
            $path  = @('Start', 'Middle', 'End')
            $entry = New-Entry -DependencyPath $path

            $entry.DependencyPath[0] | Should -Be 'Start'
            $entry.DependencyPath[1] | Should -Be 'Middle'
            $entry.DependencyPath[2] | Should -Be 'End'
        }

        It 'Should accept an empty DependencyPath' {
            $entry = New-Entry -DependencyPath @()

            $entry.DependencyPath | Should -BeNullOrEmpty
        }
    }
}

Describe 'PSScriptBuilderBuildComponentCounts' {

    Context 'Constructor - default values' {

        It 'Should initialise UsingStatements to 0' {
            $counts = [PSScriptBuilderBuildComponentCounts]::new()

            $counts.UsingStatements | Should -Be 0
        }

        It 'Should initialise EnumDefinitions to 0' {
            $counts = [PSScriptBuilderBuildComponentCounts]::new()

            $counts.EnumDefinitions | Should -Be 0
        }

        It 'Should initialise ClassDefinitions to 0' {
            $counts = [PSScriptBuilderBuildComponentCounts]::new()

            $counts.ClassDefinitions | Should -Be 0
        }

        It 'Should initialise FunctionDefinitions to 0' {
            $counts = [PSScriptBuilderBuildComponentCounts]::new()

            $counts.FunctionDefinitions | Should -Be 0
        }

        It 'Should initialise FileContents to 0' {
            $counts = [PSScriptBuilderBuildComponentCounts]::new()

            $counts.FileContents | Should -Be 0
        }
    }

    Context 'Property assignment' {

        It 'Should accept assigned values after construction' {
            $counts = [PSScriptBuilderBuildComponentCounts]::new()
            $counts.UsingStatements     = 2
            $counts.EnumDefinitions     = 3
            $counts.ClassDefinitions    = 4
            $counts.FunctionDefinitions = 5
            $counts.FileContents        = 1

            $counts.UsingStatements     | Should -Be 2
            $counts.EnumDefinitions     | Should -Be 3
            $counts.ClassDefinitions    | Should -Be 4
            $counts.FunctionDefinitions | Should -Be 5
            $counts.FileContents        | Should -Be 1
        }
    }
}

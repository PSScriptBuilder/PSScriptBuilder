Describe 'PSScriptBuilderDependencyAnalysisResult' {

    BeforeAll {
        Function New-Counts {
            param([int] $Classes = 0, [int] $Enums = 0, [int] $Functions = 0)
            $c = [PSScriptBuilderBuildComponentCounts]::new()
            $c.ClassDefinitions    = $Classes
            $c.EnumDefinitions     = $Enums
            $c.FunctionDefinitions = $Functions
            return $c
        }

        Function New-Result {
            param(
                [bool]     $HasCycles          = $false,
                [string[]] $CyclePath          = @(),
                [bool]     $HasCrossDeps       = $false,
                [string[]] $OrderedComponents  = @(),
                [PSScriptBuilderBuildComponentCounts] $Counts = $null,
                [int]      $TotalNodes         = 0,
                [int]      $TotalEdges         = 0
            )
            if ($null -eq $Counts) { $Counts = New-Counts }
            return [PSScriptBuilderDependencyAnalysisResult]::new(
                $HasCycles, $CyclePath, $HasCrossDeps, $OrderedComponents,
                $Counts, $TotalNodes, $TotalEdges, $null)
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set HasCycles' {
            $result = New-Result -HasCycles $true

            $result.HasCycles | Should -BeTrue
        }

        It 'Should set CyclePath' {
            $cycle  = @('ClassA', 'ClassB', 'ClassA')
            $result = New-Result -HasCycles $true -CyclePath $cycle

            $result.CyclePath | Should -Be $cycle
        }

        It 'Should set HasCrossDependencies' {
            $result = New-Result -HasCrossDeps $true

            $result.HasCrossDependencies | Should -BeTrue
        }

        It 'Should set OrderedComponents' {
            $order  = @('EnumA', 'ClassA', 'ClassB')
            $result = New-Result -OrderedComponents $order

            $result.OrderedComponents | Should -Be $order
        }

        It 'Should set ComponentCounts' {
            $counts = New-Counts -Classes 2 -Enums 1
            $result = New-Result -Counts $counts

            $result.ComponentCounts.ClassDefinitions | Should -Be 2
            $result.ComponentCounts.EnumDefinitions  | Should -Be 1
        }

        It 'Should set TotalNodes' {
            $result = New-Result -TotalNodes 5

            $result.TotalNodes | Should -Be 5
        }

        It 'Should set TotalEdges' {
            $result = New-Result -TotalEdges 3

            $result.TotalEdges | Should -Be 3
        }

        It 'Should set DependencyGraph to null when not provided' {
            $result = New-Result

            $result.DependencyGraph | Should -BeNullOrEmpty
        }
    }

    Context 'TotalComponents - calculated property' {

        It 'Should calculate TotalComponents as sum of all counts' {
            $counts = [PSScriptBuilderBuildComponentCounts]::new()
            $counts.UsingStatements     = 1
            $counts.EnumDefinitions     = 2
            $counts.ClassDefinitions    = 3
            $counts.FunctionDefinitions = 4
            $counts.FileContents        = 5

            $result = New-Result -Counts $counts

            $result.TotalComponents | Should -Be 15
        }

        It 'Should return 0 when ComponentCounts is null' {
            $result = [PSScriptBuilderDependencyAnalysisResult]::new(
                $false, @(), $false, @(), $null, 0, 0, $null)

            $result.TotalComponents | Should -Be 0
        }
    }
}

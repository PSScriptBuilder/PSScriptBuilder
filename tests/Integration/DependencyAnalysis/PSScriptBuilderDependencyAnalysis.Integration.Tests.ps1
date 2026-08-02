Describe 'DependencyAnalysis Integration - Get-PSScriptBuilderDependencyAnalysis' -Tag 'Integration' {

    Context 'Example 01: Functions-only - no cycles, no cross-dependencies' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\01-functions-only')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $collector = New-PSScriptBuilderCollector -Type Function -IncludePath 'src'
            $cc = New-PSScriptBuilderContentCollector -Collector $collector
            $script:Analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should report no cycles' {
            $script:Analysis.HasCycles | Should -BeFalse
        }

        It 'Should report no cross-dependencies' {
            $script:Analysis.HasCrossDependencies | Should -BeFalse
        }

        It 'Should return a non-empty ordered components list' {
            $script:Analysis.OrderedComponents.Count | Should -BeGreaterThan 0
        }

        It 'Should report correct function count' {
            $script:Analysis.ComponentCounts.FunctionDefinitions | Should -Be 3
        }
    }

    Context 'Example 02: Classes and Enums - correct component counts, no cross-dependencies' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\02-classes-and-enums')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $enumC  = New-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'
            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $cc = New-PSScriptBuilderContentCollector -Collector @($enumC, $classC, $funcC)
            $script:Analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should report 2 enum definitions' {
            $script:Analysis.ComponentCounts.EnumDefinitions | Should -Be 2
        }

        It 'Should report 3 class definitions' {
            $script:Analysis.ComponentCounts.ClassDefinitions | Should -Be 3
        }

        It 'Should report 3 function definitions' {
            $script:Analysis.ComponentCounts.FunctionDefinitions | Should -Be 3
        }

        It 'Should report no cross-dependencies' {
            $script:Analysis.HasCrossDependencies | Should -BeFalse
        }

        It 'Should report no cycles' {
            $script:Analysis.HasCycles | Should -BeFalse
        }
    }

    Context 'Example 07: OrderedMode - cross-dependencies detected, base class before derived' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\07-ordered-mode')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $cc = New-PSScriptBuilderContentCollector -Collector @($classC, $funcC)
            $script:Analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should report no cycles' {
            $script:Analysis.HasCycles | Should -BeFalse
        }

        It 'Should detect cross-dependencies between classes and functions' {
            $script:Analysis.HasCrossDependencies | Should -BeTrue
        }

        It 'Should place base class Person before derived class Employee in ordered components' {
            $ordered       = $script:Analysis.OrderedComponents
            $indexPerson   = [Array]::IndexOf($ordered, 'Person')
            $indexEmployee = [Array]::IndexOf($ordered, 'Employee')
            $indexPerson | Should -BeLessThan $indexEmployee
        }

        It 'Should place base class Person before derived class Contractor in ordered components' {
            $ordered          = $script:Analysis.OrderedComponents
            $indexPerson      = [Array]::IndexOf($ordered, 'Person')
            $indexContractor  = [Array]::IndexOf($ordered, 'Contractor')
            $indexPerson | Should -BeLessThan $indexContractor
        }
    }
}

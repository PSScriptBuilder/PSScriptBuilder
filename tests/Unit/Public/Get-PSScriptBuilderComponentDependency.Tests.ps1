using namespace System

Describe 'Get-PSScriptBuilderComponentDependency' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        # Build a simple graph: Employee -> Person (Inheritance), Employee -> Address (TypeReference)
        # New-Employee -> Employee (TypeReference), New-Employee -> Department (TypeReference)
        $script:graph = [PSScriptBuilderDependencyGraph]::new()
        $script:graph.AddEdge('Employee',    'Person',     [PSScriptBuilderDependencyEdgeType]::Inheritance)
        $script:graph.AddEdge('Employee',    'Address',    [PSScriptBuilderDependencyEdgeType]::TypeReference)
        $script:graph.AddEdge('New-Employee','Employee',   [PSScriptBuilderDependencyEdgeType]::TypeReference)
        $script:graph.AddEdge('New-Employee','Department', [PSScriptBuilderDependencyEdgeType]::TypeReference)
        $script:graph.AddNode('Person')
        $script:graph.AddNode('Address')
        $script:graph.AddNode('Department')

        # Wrap in a mock analysis result so pipeline piping works
        $script:mockAnalysis = [PSCustomObject]@{
            DependencyGraph = $script:graph
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Return type' {

        It 'Should return PSScriptBuilderComponentDependencyEntry objects' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Employee'

            $result | ForEach-Object {
                $_.GetType().Name | Should -Be 'PSScriptBuilderComponentDependencyEntry'
            }
        }
    }

    Context 'Direction - Dependencies (default)' {

        It 'Should return all transitive dependencies of Employee' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Employee'

            $names = $result | Select-Object -ExpandProperty Name
            $names | Should -Contain 'Person'
            $names | Should -Contain 'Address'
        }

        It 'Should not include the starting component itself' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Employee'

            $result | Select-Object -ExpandProperty Name | Should -Not -Contain 'Employee'
        }

        It 'Should return direct dependencies at Depth 1' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'New-Employee'

            $employee = $result | Where-Object { $_.Name -eq 'Employee' }
            $employee.Depth | Should -Be 1
        }

        It 'Should return transitive dependencies at Depth 2' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'New-Employee'

            $person = $result | Where-Object { $_.Name -eq 'Person' }
            $person.Depth | Should -Be 2
        }

        It 'Should include the full DependencyPath' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'New-Employee'

            $person = $result | Where-Object { $_.Name -eq 'Person' }
            $person.DependencyPath | Should -Be @('New-Employee', 'Employee', 'Person')
        }

        It 'Should return an empty result for a component with no dependencies' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Person'

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Direction - Dependents' {

        It 'Should return all dependents of Person' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Person' -Direction Dependents

            $names = $result | Select-Object -ExpandProperty Name
            $names | Should -Contain 'Employee'
            $names | Should -Contain 'New-Employee'
        }

        It 'Should return Employee at Depth 1 as direct dependent of Person' {
            $result   = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Person' -Direction Dependents
            $employee = $result | Where-Object { $_.Name -eq 'Employee' }

            $employee.Depth | Should -Be 1
        }

        It 'Should return New-Employee at Depth 2 as transitive dependent of Person' {
            $result     = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Person' -Direction Dependents
            $newEmployee = $result | Where-Object { $_.Name -eq 'New-Employee' }

            $newEmployee.Depth | Should -Be 2
        }
    }

    Context 'Parameter - EdgeType' {

        It 'Should return only inheritance dependencies when EdgeType is Inheritance' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Employee' -EdgeType Inheritance

            $names = $result | Select-Object -ExpandProperty Name
            $names | Should -Contain 'Person'
            $names | Should -Not -Contain 'Address'
        }

        It 'Should return only type reference dependencies when EdgeType is TypeReference' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Employee' -EdgeType TypeReference

            $names = $result | Select-Object -ExpandProperty Name
            $names | Should -Contain 'Address'
            $names | Should -Not -Contain 'Person'
        }

        It 'Should return an empty result when EdgeType does not match any edges' {
            $result = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'Employee' -EdgeType FunctionCall

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Error handling' {

        It 'Should throw when the component name does not exist in the graph' {
            { $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'NonExistent' } | Should -Throw
        }
    }
}

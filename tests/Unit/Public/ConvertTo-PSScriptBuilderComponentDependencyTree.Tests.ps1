using namespace System

Describe 'ConvertTo-PSScriptBuilderComponentDependencyTree' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        # Build graph: New-Employee -> Employee -> Person
        #                           -> Address
        $script:graph = [PSScriptBuilderDependencyGraph]::new()
        $script:graph.AddEdge('New-Employee', 'Employee', [PSScriptBuilderDependencyEdgeType]::TypeReference)
        $script:graph.AddEdge('New-Employee', 'Address',  [PSScriptBuilderDependencyEdgeType]::TypeReference)
        $script:graph.AddEdge('Employee',     'Person',   [PSScriptBuilderDependencyEdgeType]::Inheritance)
        $script:graph.AddNode('Person')
        $script:graph.AddNode('Address')

        $script:mockAnalysis = [PSCustomObject]@{ DependencyGraph = $script:graph }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Return type' {

        It 'Should return a string' {
            $result = $script:mockAnalysis |
                Get-PSScriptBuilderComponentDependency -Name 'New-Employee' |
                ConvertTo-PSScriptBuilderComponentDependencyTree

            $result | Should -BeOfType [string]
        }

        It 'Should return a single string, not an array' {
            $result = $script:mockAnalysis |
                Get-PSScriptBuilderComponentDependency -Name 'New-Employee' |
                ConvertTo-PSScriptBuilderComponentDependencyTree

            @($result).Count | Should -Be 1
        }
    }

    Context 'Tree content' {

        It 'Should include the root component name' {
            $result = $script:mockAnalysis |
                Get-PSScriptBuilderComponentDependency -Name 'New-Employee' |
                ConvertTo-PSScriptBuilderComponentDependencyTree

            $result | Should -Match 'New-Employee'
        }

        It 'Should include direct dependencies' {
            $result = $script:mockAnalysis |
                Get-PSScriptBuilderComponentDependency -Name 'New-Employee' |
                ConvertTo-PSScriptBuilderComponentDependencyTree

            $result | Should -Match 'Employee'
            $result | Should -Match 'Address'
        }

        It 'Should include transitive dependencies' {
            $result = $script:mockAnalysis |
                Get-PSScriptBuilderComponentDependency -Name 'New-Employee' |
                ConvertTo-PSScriptBuilderComponentDependencyTree

            $result | Should -Match 'Person'
        }

        It 'Should use Unicode box-drawing characters' {
            $result = $script:mockAnalysis |
                Get-PSScriptBuilderComponentDependency -Name 'New-Employee' |
                ConvertTo-PSScriptBuilderComponentDependencyTree

            # ├── or └──
            $result | Should -Match '[\u251C\u2514]\u2500\u2500'
        }
    }

    Context 'Pipeline input' {

        It 'Should accept pipeline input from Get-PSScriptBuilderComponentDependency' {
            $entries = $script:mockAnalysis | Get-PSScriptBuilderComponentDependency -Name 'New-Employee'

            { $entries | ConvertTo-PSScriptBuilderComponentDependencyTree } | Should -Not -Throw
        }

        It 'Should produce non-empty output for a component with dependencies' {
            $result = $script:mockAnalysis |
                Get-PSScriptBuilderComponentDependency -Name 'New-Employee' |
                ConvertTo-PSScriptBuilderComponentDependencyTree

            $result | Should -Not -BeNullOrEmpty
        }
    }
}

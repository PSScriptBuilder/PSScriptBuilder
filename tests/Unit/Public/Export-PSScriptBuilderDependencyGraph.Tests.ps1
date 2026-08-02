using namespace System
using namespace System.IO

Describe 'Export-PSScriptBuilderDependencyGraph' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        # Build simple graph: Employee -> Person (Inheritance), Employee -> Address (TypeReference)
        $script:graph = [PSScriptBuilderDependencyGraph]::new()
        $script:graph.AddEdge('Employee', 'Person',  [PSScriptBuilderDependencyEdgeType]::Inheritance)
        $script:graph.AddEdge('Employee', 'Address', [PSScriptBuilderDependencyEdgeType]::TypeReference)
        $script:graph.AddNode('Person')
        $script:graph.AddNode('Address')

        $script:mockAnalysis = [PSCustomObject]@{ DependencyGraph = $script:graph }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Return type - pipeline (no OutputPath)' {

        It 'Should return a string' {
            $result = $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph

            $result | Should -BeOfType [string]
        }

        It 'Should return non-empty output' {
            $result = $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Format - Mermaid (default)' {

        It 'Should include Mermaid flowchart keyword in output' {
            $result = $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph

            $result | Should -Match 'flowchart|graph'
        }

        It 'Should include component names in output' {
            $result = $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph

            $result | Should -Match 'Employee'
        }
    }

    Context 'Format - Dot' {

        It 'Should include digraph keyword for Dot format' {
            $result = $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -Format Dot

            $result | Should -Match 'digraph'
        }

        It 'Should include component names for Dot format' {
            $result = $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -Format Dot

            $result | Should -Match 'Employee'
        }
    }

    Context 'Parameter - OutputPath' {

        It 'Should write output to the specified file' {
            $outputPath = 'graph.dot'

            $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -Format Dot -OutputPath $outputPath

            $resolvedPath = Join-Path $TestDrive $outputPath
            $resolvedPath | Should -Exist
        }

        It 'Should return nothing to pipeline when OutputPath is specified' {
            $outputPath = 'graph2.dot'

            $result = $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -Format Dot -OutputPath $outputPath

            $result | Should -BeNullOrEmpty
        }

        It 'Should write file content that contains component names' {
            $outputPath = 'graph3.dot'

            $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -Format Dot -OutputPath $outputPath

            $resolvedPath = Join-Path $TestDrive $outputPath
            $fileContent  = Get-Content -Path $resolvedPath -Raw

            $fileContent | Should -Match 'Employee'
            $fileContent | Should -Match 'Person'
        }
    }

    Context 'Parameter - Force' {

        It 'Should throw when output file already exists without Force' {
            $outputPath = 'existing.dot'
            $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -Format Dot -OutputPath $outputPath

            { $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -Format Dot -OutputPath $outputPath } |
                Should -Throw
        }

        It 'Should overwrite existing file when Force is specified' {
            $outputPath = 'overwrite.dot'
            $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -Format Dot -OutputPath $outputPath

            { $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -Format Dot -OutputPath $outputPath -Force } |
                Should -Not -Throw
        }
    }

    Context 'Parameter - IncludeEdgeTypes' {

        It 'Should not throw when IncludeEdgeTypes is specified' {
            { $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -IncludeEdgeTypes } | Should -Not -Throw
        }

        It 'Should include edge type labels when IncludeEdgeTypes is specified' {
            $result = $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph -IncludeEdgeTypes

            $result | Should -Match 'Inheritance|TypeReference'
        }
    }

    Context 'Pipeline compatibility' {

        It 'Should accept DependencyGraph by property name from pipeline' {
            { $script:mockAnalysis | Export-PSScriptBuilderDependencyGraph } | Should -Not -Throw
        }
    }
}

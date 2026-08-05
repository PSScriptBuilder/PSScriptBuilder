using namespace System

Describe 'PSScriptBuilderDependencyGraphRenderer' {

    BeforeAll {
        Function New-EmptyGraph {
            return [PSScriptBuilderDependencyGraph]::new()
        }

        Function New-GraphWithEdge {
            param(
                [string] $From,
                [string] $To,
                $EdgeType = [PSScriptBuilderDependencyEdgeType]::Inheritance
            )
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge($From, $To, $EdgeType)
            return $graph
        }
    }

    Context 'RenderMermaid' {

        It 'Should start with "graph TD"' {
            $graph  = New-EmptyGraph
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaid($graph, $false)

            $result | Should -Match '^graph TD'
        }

        It 'Should render a placeholder comment when the graph is empty' {
            $graph  = New-EmptyGraph
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaid($graph, $false)

            $result | Should -Match '%% No components found'
        }

        It 'Should render a directed edge between two nodes' {
            $graph  = New-GraphWithEdge 'ClassA' 'ClassB'
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaid($graph, $false)

            $result | Should -Match 'ClassA --> ClassB'
        }

        It 'Should include edge type label when includeEdgeTypes is true' {
            $graph  = New-GraphWithEdge 'ClassA' 'ClassB' ([PSScriptBuilderDependencyEdgeType]::Inheritance)
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaid($graph, $true)

            $result | Should -Match 'ClassA -->\|Inheritance\| ClassB'
        }

        It 'Should not include edge type label when includeEdgeTypes is false' {
            $graph  = New-GraphWithEdge 'ClassA' 'ClassB' ([PSScriptBuilderDependencyEdgeType]::Inheritance)
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaid($graph, $false)

            $result | Should -Not -Match '\|Inheritance\|'
        }

        It 'Should throw ArgumentNullException when graph is null' {
            { [PSScriptBuilderDependencyGraphRenderer]::RenderMermaid($null, $false) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }

    Context 'RenderMermaidMarkdown' {

        It 'Should wrap the Mermaid diagram in a fenced code block' {
            $graph  = New-GraphWithEdge 'ClassA' 'ClassB'
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaidMarkdown($graph, $false)

            $result | Should -Match '```mermaid'
            $result | Should -Match 'ClassA --> ClassB'
        }

        It 'Should start with "```mermaid" and contain a closing "```"' {
            $graph  = New-EmptyGraph
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderMermaidMarkdown($graph, $false)

            $result | Should -Match '^```mermaid'
            $result | Should -Match '```'
        }

        It 'Should throw ArgumentNullException when graph is null' {
            { [PSScriptBuilderDependencyGraphRenderer]::RenderMermaidMarkdown($null, $false) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }

    Context 'RenderDot' {

        It 'Should start with "digraph PSScriptBuilder {"' {
            $graph  = New-EmptyGraph
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderDot($graph, $false)

            $result | Should -Match '^digraph PSScriptBuilder \{'
        }

        It 'Should render a placeholder comment when the graph is empty' {
            $graph  = New-EmptyGraph
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderDot($graph, $false)

            $result | Should -Match '// No components found'
        }

        It 'Should render a directed edge between two nodes' {
            $graph  = New-GraphWithEdge 'ClassA' 'ClassB'
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderDot($graph, $false)

            $result | Should -Match '"ClassA" -> "ClassB"'
        }

        It 'Should include edge type label when includeEdgeTypes is true' {
            $graph  = New-GraphWithEdge 'ClassA' 'ClassB' ([PSScriptBuilderDependencyEdgeType]::Inheritance)
            $result = [PSScriptBuilderDependencyGraphRenderer]::RenderDot($graph, $true)

            $result | Should -Match 'label="Inheritance"'
        }

        It 'Should throw ArgumentNullException when graph is null' {
            { [PSScriptBuilderDependencyGraphRenderer]::RenderDot($null, $false) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }
}

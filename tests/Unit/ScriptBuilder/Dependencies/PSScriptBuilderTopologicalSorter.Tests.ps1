using namespace System

Describe 'PSScriptBuilderTopologicalSorter' {

    Context 'Constructor' {

        It 'Should store the provided graph' {
            $graph = [PSScriptBuilderDependencyGraph]::new()

            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $sorter.Graph | Should -Be $graph
        }

        It 'Should throw ArgumentNullException for null graph' {
            { [PSScriptBuilderTopologicalSorter]::new($null) } | Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }

    Context 'Sort - Empty and trivial graphs' {

        It 'Should return an empty array for an empty graph' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $result.Count | Should -Be 0
        }

        It 'Should return a single node for a graph with one isolated node' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddNode('StandaloneClass')
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $result.Count | Should -Be 1
            $result | Should -Contain 'StandaloneClass'
        }

        It 'Should return all isolated nodes for a graph with multiple isolated nodes' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddNode('ClassA')
            $graph.AddNode('ClassB')
            $graph.AddNode('ClassC')
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $result.Count | Should -Be 3
            $result | Should -Contain 'ClassA'
            $result | Should -Contain 'ClassB'
            $result | Should -Contain 'ClassC'
        }
    }

    Context 'Sort - Ordering' {
        # Note on edge direction: AddEdge(A, B) means "A depends on B" - B must appear before A in the output.
        # This matches the natural graph direction used by PSScriptBuilderDependencyGraphBuilder.

        It 'Should place a prerequisite before its dependent in a two-node chain' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('DerivedClass', 'BaseClass', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $indexBase    = [Array]::IndexOf($result, 'BaseClass')
            $indexDerived = [Array]::IndexOf($result, 'DerivedClass')
            $indexBase | Should -BeLessThan $indexDerived
        }

        It 'Should maintain correct ordering across a three-node linear chain' {
            # B depends on A, C depends on B: sort output must be A, then B, then C
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $graph.AddEdge('C', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $indexA = [Array]::IndexOf($result, 'A')
            $indexB = [Array]::IndexOf($result, 'B')
            $indexC = [Array]::IndexOf($result, 'C')
            $indexA | Should -BeLessThan $indexB
            $indexB | Should -BeLessThan $indexC
        }

        It 'Should place a shared prerequisite before all its dependents in a diamond graph' {
            # Root has no dependencies; Left and Right depend on Root; Leaf depends on both
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('Left',  'Root', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $graph.AddEdge('Right', 'Root', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $graph.AddEdge('Leaf',  'Left', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $graph.AddEdge('Leaf',  'Right', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $indexRoot  = [Array]::IndexOf($result, 'Root')
            $indexLeft  = [Array]::IndexOf($result, 'Left')
            $indexRight = [Array]::IndexOf($result, 'Right')
            $indexLeaf  = [Array]::IndexOf($result, 'Leaf')
            $indexRoot  | Should -BeLessThan $indexLeft
            $indexRoot  | Should -BeLessThan $indexRight
            $indexLeft  | Should -BeLessThan $indexLeaf
            $indexRight | Should -BeLessThan $indexLeaf
        }

        It 'Should include all nodes from edges in the result' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $graph.AddEdge('C', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $result.Count | Should -Be 3
            $result | Should -Contain 'A'
            $result | Should -Contain 'B'
            $result | Should -Contain 'C'
        }

        It 'Should include isolated nodes alongside nodes with edges' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddNode('IsolatedClass')
            $graph.AddEdge('DerivedClass', 'BaseClass', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $result.Count | Should -Be 3
            $result | Should -Contain 'IsolatedClass'
            $result | Should -Contain 'BaseClass'
            $result | Should -Contain 'DerivedClass'
        }
    }

    Context 'Sort - TypeReference cycles are resolved gracefully' {

        It 'Should return all nodes for a direct TypeReference cycle between two nodes' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $result.Count | Should -Be 2
            $result | Should -Contain 'A'
            $result | Should -Contain 'B'
        }

        It 'Should return all nodes for an indirect TypeReference cycle across three nodes' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $graph.AddEdge('B', 'C', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $graph.AddEdge('C', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $result.Count | Should -Be 3
            $result | Should -Contain 'A'
            $result | Should -Contain 'B'
            $result | Should -Contain 'C'
        }

        It 'Should return all nodes for a TypeReference self-loop' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('A', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $result.Count | Should -Be 1
            $result | Should -Contain 'A'
        }
    }

    Context 'Sort - Inheritance cycles throw (safety net)' {

        It 'Should throw InvalidOperationException for a direct Inheritance cycle between two nodes' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            { $sorter.Sort() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException for an indirect Inheritance cycle across three nodes' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $graph.AddEdge('B', 'C', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $graph.AddEdge('C', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            { $sorter.Sort() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException for an Inheritance self-loop' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('A', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            { $sorter.Sort() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException for a direct StaticInitializer cycle between two nodes' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::StaticInitializer)
            $graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::StaticInitializer)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            { $sorter.Sort() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    Context 'Sort - Stuck node ordering' {

        It 'Should place the StaticInitializer prereq before its dependent when stuck in a TypeReference cycle' {
            # ZClass has a StaticInitializer edge to AHelper; AHelper has a TypeReference back to ZClass.
            # Both become stuck nodes in the full-graph pass.
            # The fatal-edge sub-sort uses StaticInitializer edges to establish correct order.
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('ZClass', 'AHelper', [PSScriptBuilderDependencyEdgeType]::StaticInitializer)
            $graph.AddEdge('AHelper', 'ZClass', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $result = $sorter.Sort()

            $result.Count | Should -Be 2
            $indexAHelper = [Array]::IndexOf($result, 'AHelper')
            $indexZClass  = [Array]::IndexOf($result, 'ZClass')
            $indexAHelper | Should -BeLessThan $indexZClass
        }
    }

    Context 'Sort - Idempotency' {

        It 'Should return identical results when Sort is called twice on the same instance' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $graph.AddEdge('C', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $sorter = [PSScriptBuilderTopologicalSorter]::new($graph)

            $first  = $sorter.Sort()
            $second = $sorter.Sort()

            $second.Count | Should -Be $first.Count
            for ($i = 0; $i -lt $first.Count; $i++) {
                $second[$i] | Should -Be $first[$i]
            }
        }
    }
}

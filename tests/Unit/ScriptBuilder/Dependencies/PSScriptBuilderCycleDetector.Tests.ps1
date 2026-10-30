using namespace System

Describe 'PSScriptBuilderCycleDetector' {

    BeforeEach {
        $script:graph = [PSScriptBuilderDependencyGraph]::new()
    }

    #region Constructor
    Context 'Constructor' {

        It 'Should instantiate with a valid graph' {
            { [PSScriptBuilderCycleDetector]::new($script:graph) } | Should -Not -Throw
        }

        It 'Should throw ArgumentNullException when graph is null' {
            { [PSScriptBuilderCycleDetector]::new($null) } | Should -Throw -ExceptionType ([ArgumentNullException])
        }

        It 'Should expose the Graph property' {
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.Graph | Should -Be $script:graph
        }
    }
    #endregion Constructor

    #region HasCycle
    Context 'HasCycle - empty and trivial graphs' {

        It 'Should return false for an empty graph' {
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.HasCycle() | Should -BeFalse
        }

        It 'Should return false for a single node with no dependencies' {
            $script:graph.AddNode('A')
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.HasCycle() | Should -BeFalse
        }

        It 'Should return false for a linear chain A -> B -> C' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'C', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddNode('C')
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.HasCycle() | Should -BeFalse
        }
    }

    Context 'HasCycle - self-reference' {

        It 'Should return true for a self-referencing node A -> A' {
            $script:graph.AddEdge('A', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.HasCycle() | Should -BeTrue
        }
    }

    Context 'HasCycle - simple cycles' {

        It 'Should return true for a 2-node cycle A -> B -> A' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.HasCycle() | Should -BeTrue
        }

        It 'Should return true for a 3-node cycle A -> B -> C -> A' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'C', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('C', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.HasCycle() | Should -BeTrue
        }
    }

    Context 'HasCycle - mixed graphs' {

        It 'Should return true when one subgraph is acyclic and another contains a cycle' {
            # Acyclic subgraph: X -> Y
            $script:graph.AddEdge('X', 'Y', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddNode('Y')

            # Cyclic subgraph: A -> B -> A
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.HasCycle() | Should -BeTrue
        }

        It 'Should return false for a diamond-shaped DAG A -> B, A -> C, B -> D, C -> D' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('A', 'C', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'D', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('C', 'D', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddNode('D')
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.HasCycle() | Should -BeFalse
        }
    }
    #endregion HasCycle

    #region GetCyclePath
    Context 'GetCyclePath - no cycle' {

        It 'Should return an empty array for an empty graph' {
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.GetCyclePath() | Should -BeNullOrEmpty
        }

        It 'Should return an empty array for an acyclic chain A -> B -> C' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'C', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddNode('C')
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $detector.GetCyclePath() | Should -BeNullOrEmpty
        }
    }

    Context 'GetCyclePath - self-reference' {

        It 'Should return path [A, A] for self-referencing node A -> A' {
            $script:graph.AddEdge('A', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $result   = $detector.GetCyclePath()

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0] | Should -Be 'A'
            $result[-1] | Should -Be 'A'
        }
    }

    Context 'GetCyclePath - simple cycles' {

        It 'Should return a path containing both nodes for a 2-node cycle A -> B -> A' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $result   = $detector.GetCyclePath()

            $result | Should -Not -BeNullOrEmpty
            # Path must start and end with the same node (closed cycle)
            $result[0] | Should -Be $result[-1]
            # Path must contain at least 3 elements (start, middle, start)
            $result.Count | Should -BeGreaterOrEqual 3
        }

        It 'Should return a path where first and last element are identical for a 3-node cycle' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'C', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('C', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $result   = $detector.GetCyclePath()

            $result | Should -Not -BeNullOrEmpty
            $result[0] | Should -Be $result[-1]
        }

        It 'Should return a path containing all 3 involved nodes for a 3-node cycle' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'C', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('C', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)
            $result   = $detector.GetCyclePath()

            $result | Should -Contain 'A'
            $result | Should -Contain 'B'
            $result | Should -Contain 'C'
        }
    }

    Context 'GetCyclePath - idempotency' {

        It 'Should return the same result on two consecutive calls' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)

            $result1 = $detector.GetCyclePath()
            $result2 = $detector.GetCyclePath()

            $result1 | Should -Be $result2
        }
    }
    #endregion GetCyclePath

    #region TypeReference cycles
    Context 'HasCycle - TypeReference cycle is not detected' {

        It 'Should return false for a 2-node TypeReference cycle A -> B -> A' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)

            $detector.HasCycle() | Should -BeFalse
        }

        It 'Should return false for a 3-node TypeReference cycle A -> B -> C -> A' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('B', 'C', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('C', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)

            $detector.HasCycle() | Should -BeFalse
        }
    }

    Context 'GetCyclePath - TypeReference cycle returns empty' {

        It 'Should return empty for a 2-node TypeReference cycle A -> B -> A' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)

            $detector.GetCyclePath() | Should -BeNullOrEmpty
        }

        It 'Should return empty for a 3-node TypeReference cycle A -> B -> C -> A' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('B', 'C', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('C', 'A', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)

            $detector.GetCyclePath() | Should -BeNullOrEmpty
        }
    }
    #endregion TypeReference cycles

    #region StaticInitializer cycles
    Context 'HasCycle - StaticInitializer cycle is detected' {

        It 'Should return true for a 2-node StaticInitializer cycle A -> B -> A' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::StaticInitializer)
            $script:graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::StaticInitializer)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)

            $detector.HasCycle() | Should -BeTrue
        }

        It 'Should return true for a cycle mixing Inheritance and StaticInitializer edges' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::StaticInitializer)
            $script:graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)

            $detector.HasCycle() | Should -BeTrue
        }
    }

    Context 'GetCyclePath - StaticInitializer cycle returns path' {

        It 'Should return the cycle path for a 2-node StaticInitializer cycle A -> B -> A' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::StaticInitializer)
            $script:graph.AddEdge('B', 'A', [PSScriptBuilderDependencyEdgeType]::StaticInitializer)
            $detector = [PSScriptBuilderCycleDetector]::new($script:graph)

            $result = $detector.GetCyclePath()

            $result.Count | Should -BeGreaterThan 0
            $result | Should -Contain 'A'
            $result | Should -Contain 'B'
        }
    }
    #endregion StaticInitializer cycles
}

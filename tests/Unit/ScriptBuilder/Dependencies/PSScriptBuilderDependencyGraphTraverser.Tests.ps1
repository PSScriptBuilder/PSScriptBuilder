using namespace System

Describe 'PSScriptBuilderDependencyGraphTraverser' {

    BeforeEach {
        $script:graph = [PSScriptBuilderDependencyGraph]::new()
    }

    #region Constructor
    Context 'Constructor' {

        It 'Should instantiate with a valid graph' {
            { [PSScriptBuilderDependencyGraphTraverser]::new($script:graph) } | Should -Not -Throw
        }

        It 'Should throw ArgumentNullException when graph is null' {
            { [PSScriptBuilderDependencyGraphTraverser]::new($null) } | Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }
    #endregion Constructor

    #region Traverse - Guard Clauses
    Context 'Traverse - Guard Clauses' {

        BeforeEach {
            $script:traverser = [PSScriptBuilderDependencyGraphTraverser]::new($script:graph)
        }

        It 'Should throw ArgumentException when name is null' {
            { $script:traverser.Traverse($null, [PSScriptBuilderTraversalDirection]::Dependencies) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when name is empty' {
            { $script:traverser.Traverse('', [PSScriptBuilderTraversalDirection]::Dependencies) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when name is whitespace' {
            { $script:traverser.Traverse('   ', [PSScriptBuilderTraversalDirection]::Dependencies) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw InvalidOperationException when name is not in the graph' {
            { $script:traverser.Traverse('Unknown', [PSScriptBuilderTraversalDirection]::Dependencies) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }
    #endregion Traverse - Guard Clauses

    #region Traverse - Direction Dependencies
    Context 'Traverse - Direction Dependencies' {

        BeforeEach {
            # ClassA -> ClassB -> ClassC
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassB', 'ClassC', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddNode('ClassC')
            $script:traverser = [PSScriptBuilderDependencyGraphTraverser]::new($script:graph)
        }

        It 'Should return an empty array when the component has no dependencies' {
            $result = $script:traverser.Traverse('ClassC', [PSScriptBuilderTraversalDirection]::Dependencies)
            $result.Count | Should -Be 0
        }

        It 'Should return all transitive dependencies' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies)
            $result.Count | Should -Be 2
        }

        It 'Should not include the root component in the results' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies)
            $result.Name | Should -Not -Contain 'ClassA'
        }

        It 'Should assign Depth 1 to a direct dependency' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies)
            $classB = $result | Where-Object { $_.Name -eq 'ClassB' }
            $classB.Depth | Should -Be 1
        }

        It 'Should assign Depth 2 to a transitive dependency' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies)
            $classC = $result | Where-Object { $_.Name -eq 'ClassC' }
            $classC.Depth | Should -Be 2
        }

        It 'Should set DependencyPath with root at index 0 for a direct dependency' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies)
            $classB = $result | Where-Object { $_.Name -eq 'ClassB' }
            $classB.DependencyPath[0] | Should -Be 'ClassA'
            $classB.DependencyPath[-1] | Should -Be 'ClassB'
        }

        It 'Should set DependencyPath including intermediate nodes for a transitive dependency' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies)
            $classC = $result | Where-Object { $_.Name -eq 'ClassC' }
            $classC.DependencyPath[0] | Should -Be 'ClassA'
            $classC.DependencyPath[1] | Should -Be 'ClassB'
            $classC.DependencyPath[2] | Should -Be 'ClassC'
        }
    }
    #endregion Traverse - Direction Dependencies

    #region Traverse - Cycle Handling
    Context 'Traverse - Cycle Handling' {

        BeforeEach {
            # ClassA -> ClassB -> ClassC -> ClassA (cycle)
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassB', 'ClassC', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassC', 'ClassA', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:traverser = [PSScriptBuilderDependencyGraphTraverser]::new($script:graph)
        }

        It 'Should not throw when a cycle exists in the graph' {
            { $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies) } | Should -Not -Throw
        }

        It 'Should not include the root component in the results even when it is reachable via a cycle' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies)
            $result.Name | Should -Not -Contain 'ClassA'
        }

        It 'Should visit each reachable component exactly once' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies)
            $result.Count | Should -Be 2
        }
    }
    #endregion Traverse - Cycle Handling

    #region Traverse - Direction Dependents
    Context 'Traverse - Direction Dependents' {

        BeforeEach {
            # ClassA -> ClassB -> ClassC
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassB', 'ClassC', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddNode('ClassC')
            $script:traverser = [PSScriptBuilderDependencyGraphTraverser]::new($script:graph)
        }

        It 'Should return an empty array when the component has no dependents' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependents)
            $result.Count | Should -Be 0
        }

        It 'Should return all transitive dependents' {
            $result = $script:traverser.Traverse('ClassC', [PSScriptBuilderTraversalDirection]::Dependents)
            $result.Count | Should -Be 2
        }

        It 'Should not include the root component in the results' {
            $result = $script:traverser.Traverse('ClassC', [PSScriptBuilderTraversalDirection]::Dependents)
            $result.Name | Should -Not -Contain 'ClassC'
        }

        It 'Should assign Depth 1 to a direct dependent' {
            $result = $script:traverser.Traverse('ClassC', [PSScriptBuilderTraversalDirection]::Dependents)
            $classB = $result | Where-Object { $_.Name -eq 'ClassB' }
            $classB.Depth | Should -Be 1
        }

        It 'Should assign Depth 2 to a transitive dependent' {
            $result = $script:traverser.Traverse('ClassC', [PSScriptBuilderTraversalDirection]::Dependents)
            $classA = $result | Where-Object { $_.Name -eq 'ClassA' }
            $classA.Depth | Should -Be 2
        }

        It 'Should set DependencyPath with root at index 0 for a direct dependent' {
            $result = $script:traverser.Traverse('ClassC', [PSScriptBuilderTraversalDirection]::Dependents)
            $classB = $result | Where-Object { $_.Name -eq 'ClassB' }
            $classB.DependencyPath[0] | Should -Be 'ClassC'
            $classB.DependencyPath[-1] | Should -Be 'ClassB'
        }

        It 'Should set DependencyPath including intermediate nodes for a transitive dependent' {
            $result = $script:traverser.Traverse('ClassC', [PSScriptBuilderTraversalDirection]::Dependents)
            $classA = $result | Where-Object { $_.Name -eq 'ClassA' }
            $classA.DependencyPath[0] | Should -Be 'ClassC'
            $classA.DependencyPath[1] | Should -Be 'ClassB'
            $classA.DependencyPath[2] | Should -Be 'ClassA'
        }
    }
    #endregion Traverse - Direction Dependents

    #region Traverse - EdgeType Filter - Dependencies
    Context 'Traverse - EdgeType Filter - Dependencies' {

        BeforeEach {
            # ClassA -[Inheritance]-> ClassB, ClassA -[TypeReference]-> ClassC
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('ClassA', 'ClassC', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:traverser = [PSScriptBuilderDependencyGraphTraverser]::new($script:graph)
        }

        It 'Should return only components reachable via Inheritance edges' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies, [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $result.Name | Should -Contain 'ClassB'
            $result.Name | Should -Not -Contain 'ClassC'
        }

        It 'Should return only components reachable via TypeReference edges' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies, [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result.Name | Should -Contain 'ClassC'
            $result.Name | Should -Not -Contain 'ClassB'
        }

        It 'Should return an empty array when no edges of the specified type exist' {
            # ClassA has only Inheritance and TypeReference edges — no FunctionCall
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies, [PSScriptBuilderDependencyEdgeType]::FunctionCall)

            $result.Count | Should -Be 0
        }
    }
    #endregion Traverse - EdgeType Filter - Dependencies

    #region Traverse - EdgeType Filter - Dependents
    Context 'Traverse - EdgeType Filter - Dependents' {

        BeforeEach {
            # ClassA -[Inheritance]-> Base, ClassB -[TypeReference]-> Base
            $script:graph.AddEdge('ClassA', 'Base', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('ClassB', 'Base', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddNode('Base')
            $script:traverser = [PSScriptBuilderDependencyGraphTraverser]::new($script:graph)
        }

        It 'Should return only components that depend via Inheritance edges' {
            $result = $script:traverser.Traverse('Base', [PSScriptBuilderTraversalDirection]::Dependents, [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $result.Name | Should -Contain 'ClassA'
            $result.Name | Should -Not -Contain 'ClassB'
        }

        It 'Should return only components that depend via TypeReference edges' {
            $result = $script:traverser.Traverse('Base', [PSScriptBuilderTraversalDirection]::Dependents, [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result.Name | Should -Contain 'ClassB'
            $result.Name | Should -Not -Contain 'ClassA'
        }
    }
    #endregion Traverse - EdgeType Filter - Dependents

    #region Traverse - EdgeType Filter - Inheritance Chain
    Context 'Traverse - EdgeType Filter - Inheritance Chain' {

        BeforeEach {
            # ClassA -[Inheritance]-> ClassB -[Inheritance]-> ClassC
            # ClassA -[TypeReference]-> ClassD
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('ClassB', 'ClassC', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('ClassA', 'ClassD', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddNode('ClassC')
            $script:graph.AddNode('ClassD')
            $script:traverser = [PSScriptBuilderDependencyGraphTraverser]::new($script:graph)
        }

        It 'Should return all transitive Inheritance ancestors and exclude TypeReference components' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies, [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $result.Count | Should -Be 2
            $result.Name | Should -Contain 'ClassB'
            $result.Name | Should -Contain 'ClassC'
            $result.Name | Should -Not -Contain 'ClassD'
        }

        It 'Should set DependencyPath containing only Inheritance chain nodes' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies, [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $classC = $result | Where-Object { $_.Name -eq 'ClassC' }
            $classC.DependencyPath[0] | Should -Be 'ClassA'
            $classC.DependencyPath[1] | Should -Be 'ClassB'
            $classC.DependencyPath[2] | Should -Be 'ClassC'
        }
    }
    #endregion Traverse - EdgeType Filter - Inheritance Chain

    #region Traverse - EdgeType Filter - Multiple EdgeTypes
    Context 'Traverse - EdgeType Filter - Multiple EdgeTypes' {

        BeforeEach {
            # ClassA -[Inheritance]-> ClassB, ClassA -[TypeReference]-> ClassC, ClassA -[FunctionCall]-> ClassD
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('ClassA', 'ClassC', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassA', 'ClassD', [PSScriptBuilderDependencyEdgeType]::FunctionCall)
            $script:traverser = [PSScriptBuilderDependencyGraphTraverser]::new($script:graph)
        }

        It 'Should return the union of components reachable via the specified edge types' {
            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies, @(
                [PSScriptBuilderDependencyEdgeType]::Inheritance,
                [PSScriptBuilderDependencyEdgeType]::TypeReference
            ))

            $result.Count | Should -Be 2
            $result.Name | Should -Contain 'ClassB'
            $result.Name | Should -Contain 'ClassC'
            $result.Name | Should -Not -Contain 'ClassD'
        }

        It 'Should not include duplicates when a component is reachable via multiple specified edge types' {
            # ClassA -[Inheritance]-> ClassB, ClassA -[TypeReference]-> ClassB (same target, two edge types)
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:traverser.Traverse('ClassA', [PSScriptBuilderTraversalDirection]::Dependencies, @(
                [PSScriptBuilderDependencyEdgeType]::Inheritance,
                [PSScriptBuilderDependencyEdgeType]::TypeReference
            ))

            ($result | Where-Object { $_.Name -eq 'ClassB' }).Count | Should -Be 1
        }
    }
    #endregion Traverse - EdgeType Filter - Multiple EdgeTypes
}

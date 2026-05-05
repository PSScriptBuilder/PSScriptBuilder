using namespace System
using namespace System.Collections.Generic

Describe 'PSScriptBuilderDependencyGraph' {

    BeforeEach {
        $script:graph = [PSScriptBuilderDependencyGraph]::new()
    }

    Context 'Constructor' {

        It 'Should create an empty graph' {
            $script:graph.Dependencies.Count | Should -Be 0
        }
    }

    Context 'AddNode' {

        It 'Should register a node with an empty dependency set' {
            $script:graph.AddNode('MyClass')

            $script:graph.Dependencies.ContainsKey('MyClass') | Should -BeTrue
            $script:graph.Dependencies['MyClass'].Count | Should -Be 0
        }

        It 'Should be idempotent when called multiple times with the same name' {
            $script:graph.AddNode('MyClass')
            $script:graph.AddNode('MyClass')

            $script:graph.Dependencies.Keys.Count | Should -Be 1
        }

        It 'Should throw ArgumentException for null name' {
            { $script:graph.AddNode($null) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for empty name' {
            { $script:graph.AddNode('') } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for whitespace name' {
            { $script:graph.AddNode('   ') } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'AddEdge' {

        It 'Should register a dependency between two components' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.GetDependencies('ClassA').Contains('ClassB') | Should -BeTrue
        }

        It 'Should auto-create the from-node when it does not exist' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.Dependencies.ContainsKey('ClassA') | Should -BeTrue
        }

        It 'Should add multiple dependencies for the same from-node' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassA', 'ClassC', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.Dependencies['ClassA'].Count | Should -Be 2
        }

        It 'Should be idempotent when the same edge is added twice' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.Dependencies['ClassA'].Count | Should -Be 1
        }

        It 'Should allow two distinct edge types to the same target' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::StaticInitializer)

            $script:graph.Dependencies['ClassA'].Count | Should -Be 2
        }

        It 'Should throw ArgumentException for null from-parameter' {
            { $script:graph.AddEdge($null, 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for empty from-parameter' {
            { $script:graph.AddEdge('', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for null to-parameter' {
            { $script:graph.AddEdge('ClassA', $null, [PSScriptBuilderDependencyEdgeType]::TypeReference) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for empty to-parameter' {
            { $script:graph.AddEdge('ClassA', '', [PSScriptBuilderDependencyEdgeType]::TypeReference) } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'GetDependencies' {

        It 'Should return all dependencies of a component' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassA', 'ClassC', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependencies('ClassA')

            $result.Count | Should -Be 2
            $result.Contains('ClassB') | Should -BeTrue
            $result.Contains('ClassC') | Should -BeTrue
        }

        It 'Should return an empty set for a component with no dependencies' {
            $script:graph.AddNode('IsolatedClass')

            $result = $script:graph.GetDependencies('IsolatedClass')

            $result.Count | Should -Be 0
        }

        It 'Should return an empty set for an unknown component' {
            $result = $script:graph.GetDependencies('UnknownClass')

            $result.Count | Should -Be 0
        }

        It 'Should return a copy that does not affect the internal graph when modified' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependencies('ClassA')
            $result.Add('ClassC') | Out-Null

            $script:graph.GetDependencies('ClassA').Count | Should -Be 1
        }

        It 'Should throw ArgumentException for null componentName' {
            { $script:graph.GetDependencies($null) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for empty componentName' {
            { $script:graph.GetDependencies('') } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'GetDependents' {

        It 'Should return all components that depend on the given component' {
            $script:graph.AddEdge('ClassA', 'BaseClass', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassB', 'BaseClass', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependents('BaseClass')

            $result.Count | Should -Be 2
            $result.Contains('ClassA') | Should -BeTrue
            $result.Contains('ClassB') | Should -BeTrue
        }

        It 'Should return an empty set for a component with no dependents' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependents('ClassA')

            $result.Count | Should -Be 0
        }

        It 'Should return an empty set for an unknown component' {
            $result = $script:graph.GetDependents('UnknownClass')

            $result.Count | Should -Be 0
        }

        It 'Should throw ArgumentException for null componentName' {
            { $script:graph.GetDependents($null) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for empty componentName' {
            { $script:graph.GetDependents('') } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'GetDependents - EdgeType filter' {

        It 'Should return only components that depend via the specified edge type' {
            $script:graph.AddEdge('ClassA', 'BaseClass', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('ClassB', 'BaseClass', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependents('BaseClass', [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $result.Count | Should -Be 1
            $result.Contains('ClassA') | Should -BeTrue
            $result.Contains('ClassB') | Should -BeFalse
        }

        It 'Should return an empty set when no component depends via the specified edge type' {
            $script:graph.AddEdge('ClassA', 'BaseClass', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependents('BaseClass', [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $result.Count | Should -Be 0
        }

        It 'Should return an empty set for an unknown component' {
            $result = $script:graph.GetDependents('UnknownClass', [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $result.Count | Should -Be 0
        }

        It 'Should throw ArgumentException for null componentName' {
            { $script:graph.GetDependents($null, [PSScriptBuilderDependencyEdgeType]::Inheritance) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for empty componentName' {
            { $script:graph.GetDependents('', [PSScriptBuilderDependencyEdgeType]::Inheritance) } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'GetAllNodes' {

        It 'Should return an empty set for an empty graph' {
            $result = $script:graph.GetAllNodes()

            $result.Count | Should -Be 0
        }

        It 'Should return both the from-node and the to-node of an edge' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetAllNodes()

            $result.Contains('ClassA') | Should -BeTrue
            $result.Contains('ClassB') | Should -BeTrue
        }

        It 'Should include isolated nodes registered via AddNode' {
            $script:graph.AddNode('IsolatedClass')

            $result = $script:graph.GetAllNodes()

            $result.Contains('IsolatedClass') | Should -BeTrue
        }

        It 'Should not return duplicate entries when a node appears as both key and value' {
            $script:graph.AddNode('ClassA')
            $script:graph.AddEdge('ClassB', 'ClassA', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetAllNodes()

            ($result | Where-Object { $_ -eq 'ClassA' }).Count | Should -Be 1
        }

        It 'Should return the correct total count without duplicates' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassC', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetAllNodes()

            $result.Count | Should -Be 3
        }
    }

    Context 'HasNode' {

        It 'Should return true for a node registered as a key via AddEdge' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.HasNode('ClassA') | Should -BeTrue
        }

        It 'Should return true for a node that is only depended upon (value only)' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.HasNode('ClassB') | Should -BeTrue
        }

        It 'Should return true for an isolated node registered via AddNode' {
            $script:graph.AddNode('IsolatedClass')

            $script:graph.HasNode('IsolatedClass') | Should -BeTrue
        }

        It 'Should return false for an unknown component' {
            $script:graph.HasNode('UnknownClass') | Should -BeFalse
        }

        It 'Should return false for null input without throwing' {
            $script:graph.HasNode($null) | Should -BeFalse
        }

        It 'Should return false for empty string input without throwing' {
            $script:graph.HasNode('') | Should -BeFalse
        }
    }

    Context 'GetEdgeCount' {

        It 'Should return 0 for an empty graph' {
            $script:graph.GetEdgeCount() | Should -Be 0
        }

        It 'Should return 0 when nodes are registered but have no edges' {
            $script:graph.AddNode('ClassA')
            $script:graph.AddNode('ClassB')

            $script:graph.GetEdgeCount() | Should -Be 0
        }

        It 'Should return the correct number of edges' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassA', 'ClassC', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('ClassB', 'ClassC', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.GetEdgeCount() | Should -Be 3
        }
    }

    Context 'GetNodeCount' {

        It 'Should return 0 for an empty graph' {
            $script:graph.GetNodeCount() | Should -Be 0
        }

        It 'Should count an isolated node registered via AddNode' {
            $script:graph.AddNode('IsolatedClass')

            $script:graph.GetNodeCount() | Should -Be 1
        }

        It 'Should count both the from-node and the to-node of an edge' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.GetNodeCount() | Should -Be 2
        }
    }

    Context 'Case Insensitivity' {

        It 'Should treat component names as case-insensitive in HasNode' {
            $script:graph.AddEdge('classA', 'classB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.HasNode('ClassA') | Should -BeTrue
            $script:graph.HasNode('CLASSB') | Should -BeTrue
        }

        It 'AddNode should be idempotent across different casings' {
            $script:graph.AddNode('MyClass')
            $script:graph.AddNode('myclass')
            $script:graph.AddNode('MYCLASS')

            $script:graph.Dependencies.Keys.Count | Should -Be 1
        }

        It 'AddEdge should treat the same name in different casings as the same node' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)
            $script:graph.AddEdge('classa', 'classb', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $script:graph.GetEdgeCount() | Should -Be 1
        }

        It 'GetDependencies should find a node regardless of casing' {
            $script:graph.AddEdge('ClassA', 'ClassB', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependencies('classa')

            $result.Contains('ClassB') | Should -BeTrue
        }
    }

    Context 'GetDependencies - filtered by edge type' {

        It 'Should return all targets regardless of edge type when no filter is specified' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('A', 'C', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependencies('A')

            $result.Count | Should -Be 2
            $result.Contains('B') | Should -BeTrue
            $result.Contains('C') | Should -BeTrue
        }

        It 'Should return only Inheritance targets when filtered by Inheritance' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('A', 'C', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependencies('A', [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $result.Count | Should -Be 1
            $result.Contains('B') | Should -BeTrue
        }

        It 'Should return only TypeReference targets when filtered by TypeReference' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('A', 'C', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependencies('A', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result.Count | Should -Be 1
            $result.Contains('C') | Should -BeTrue
        }

        It 'Should return an empty set when filtering by Inheritance but only TypeReference edges exist' {
            $script:graph.AddEdge('A', 'B', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependencies('A', [PSScriptBuilderDependencyEdgeType]::Inheritance)

            $result.Count | Should -Be 0
        }

        It 'Should return combined targets via unfiltered overload when both Inheritance and TypeReference edges exist' {
            $script:graph.AddEdge('A', 'Base', [PSScriptBuilderDependencyEdgeType]::Inheritance)
            $script:graph.AddEdge('A', 'Helper', [PSScriptBuilderDependencyEdgeType]::TypeReference)

            $result = $script:graph.GetDependencies('A')

            $result.Count | Should -Be 2
            $result.Contains('Base') | Should -BeTrue
            $result.Contains('Helper') | Should -BeTrue
        }

        It 'Should throw ArgumentException for null componentName in filtered overload' {
            { $script:graph.GetDependencies($null, [PSScriptBuilderDependencyEdgeType]::Inheritance) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for empty componentName in filtered overload' {
            { $script:graph.GetDependencies('', [PSScriptBuilderDependencyEdgeType]::Inheritance) } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }
}

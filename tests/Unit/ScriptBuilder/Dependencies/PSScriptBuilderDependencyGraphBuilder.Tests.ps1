using namespace System
using namespace System.Collections.Generic

Describe 'PSScriptBuilderDependencyGraphBuilder' {

    BeforeAll {
        # Injects a ClassData entry directly into a new ClassCollector (no file I/O).
        # Uses ClassName as CollectionKey to avoid duplicate key errors when multiple
        # ClassCollectors are added to the same ContentCollector.
        Function New-ClassCollectorWithData {
            param(
                [string]   $ClassName,
                [string]   $BaseClass                   = '',
                [string[]] $TypeReferences              = @(),
                [string[]] $StaticInitializerReferences = @(),
                [string[]] $CalledFunctions             = @()
            )
            $collector = [PSScriptBuilderClassCollector]::new($ClassName)
            $data = [PSScriptBuilderClassData]::new(
                $ClassName, "class $ClassName { }", 'fake.ps1',
                $BaseClass, $TypeReferences, $StaticInitializerReferences, $CalledFunctions
            )
            $collector.ClassData[$ClassName] = $data
            return $collector
        }

        # Injects a FunctionData entry directly into a new FunctionCollector (no file I/O).
        # Uses FunctionName as CollectionKey to avoid duplicate key errors when multiple
        # FunctionCollectors are added to the same ContentCollector.
        Function New-FuncCollectorWithData {
            param(
                [string]   $FunctionName,
                [string[]] $CalledFunctions = @(),
                [string[]] $TypeReferences  = @()
            )
            $collector = [PSScriptBuilderFunctionCollector]::new($FunctionName)
            $data = [PSScriptBuilderFunctionData]::new(
                $FunctionName, "Function $FunctionName { }", 'fake.ps1',
                $CalledFunctions, $TypeReferences
            )
            $collector.FunctionData[$FunctionName] = $data
            return $collector
        }

        Function New-Builder {
            param([PSScriptBuilderCollectorBase[]] $Collectors)
            $cc = [PSScriptBuilderContentCollector]::new()
            foreach ($c in $Collectors) { $cc.AddCollector($c) }
            return [PSScriptBuilderDependencyGraphBuilder]::new($cc)
        }
    }

    Context 'Constructor' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            { [PSScriptBuilderDependencyGraphBuilder]::new($null) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }

        It 'Should store the provided ContentCollector' {
            $cc      = [PSScriptBuilderContentCollector]::new()
            $builder = [PSScriptBuilderDependencyGraphBuilder]::new($cc)

            $builder.ContentCollector | Should -Be $cc
        }
    }

    Context 'Build - empty collector' {

        It 'Should return an empty graph for an empty ContentCollector' {
            $cc      = [PSScriptBuilderContentCollector]::new()
            $builder = [PSScriptBuilderDependencyGraphBuilder]::new($cc)

            $graph = $builder.Build()

            $graph.GetAllNodes().Count | Should -Be 0
        }
    }

    Context 'Build - isolated components registered as nodes' {

        It 'Should register a class with no dependencies as an isolated node' {
            $builder = New-Builder @(New-ClassCollectorWithData 'StandaloneClass')

            $graph = $builder.Build()

            $graph.Dependencies.ContainsKey('StandaloneClass') | Should -BeTrue
        }

        It 'Should register an isolated function as a node' {
            $builder = New-Builder @(New-FuncCollectorWithData 'Get-Standalone')

            $graph = $builder.Build()

            $graph.Dependencies.ContainsKey('Get-Standalone') | Should -BeTrue
        }
    }

    Context 'Build - class base class dependencies' {

        It 'Should add an edge when base class is defined in the project' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'BaseClass'),
                (New-ClassCollectorWithData 'DerivedClass' -BaseClass 'BaseClass')
            )

            $graph = $builder.Build()

            $graph.GetDependencies('DerivedClass').Contains('BaseClass') | Should -BeTrue
        }

        It 'Should not add an edge for an external base class not defined in the project' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'MyClass' -BaseClass 'ExternalFrameworkBase')
            )

            $graph = $builder.Build()

            $graph.GetDependencies('MyClass').Count | Should -Be 0
        }
    }

    Context 'Build - type reference dependencies' {

        It 'Should add an edge for a type reference defined in the project' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'HelperClass'),
                (New-ClassCollectorWithData 'ConsumerClass' -TypeReferences @('HelperClass'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('ConsumerClass').Contains('HelperClass') | Should -BeTrue
        }

        It 'Should not add an edge for an external type reference' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'MyClass' -TypeReferences @('System.Collections.Generic.List'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('MyClass').Count | Should -Be 0
        }
    }

    Context 'Build - function call dependencies' {

        It 'Should add an edge when a function calls another defined function' {
            $builder = New-Builder @(
                (New-FuncCollectorWithData 'Get-Helper'),
                (New-FuncCollectorWithData 'Get-Caller' -CalledFunctions @('Get-Helper'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('Get-Caller').Contains('Get-Helper') | Should -BeTrue
        }

        It 'Should not add an edge for an external function call' {
            $builder = New-Builder @(
                (New-FuncCollectorWithData 'Get-MyFunc' -CalledFunctions @('Write-Host'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('Get-MyFunc').Count | Should -Be 0
        }

        It 'Should add an edge when a class calls a defined function' {
            $builder = New-Builder @(
                (New-FuncCollectorWithData 'Get-Helper'),
                (New-ClassCollectorWithData 'MyClass' -CalledFunctions @('Get-Helper'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('MyClass').Contains('Get-Helper') | Should -BeTrue
        }
    }

    Context 'Build - self-loop prevention' {

        It 'Should not add a self-loop edge when a class type reference matches its own name' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'SelfClass' -TypeReferences @('SelfClass'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('SelfClass').Count | Should -Be 0
        }
    }

    Context 'Build - edge types stored correctly' {

        It 'Should store a base class dependency as an Inheritance edge' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'BaseClass'),
                (New-ClassCollectorWithData 'DerivedClass' -BaseClass 'BaseClass')
            )

            $graph = $builder.Build()

            $graph.GetDependencies('DerivedClass', [PSScriptBuilderDependencyEdgeType]::Inheritance).Contains('BaseClass') | Should -BeTrue
        }

        It 'Should store a type reference dependency as a TypeReference edge' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'HelperClass'),
                (New-ClassCollectorWithData 'ConsumerClass' -TypeReferences @('HelperClass'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('ConsumerClass', [PSScriptBuilderDependencyEdgeType]::TypeReference).Contains('HelperClass') | Should -BeTrue
        }

        It 'Should store a function call dependency as a FunctionCall edge' {
            $builder = New-Builder @(
                (New-FuncCollectorWithData 'Get-Helper'),
                (New-FuncCollectorWithData 'Get-Caller' -CalledFunctions @('Get-Helper'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('Get-Caller', [PSScriptBuilderDependencyEdgeType]::FunctionCall).Contains('Get-Helper') | Should -BeTrue
        }

        It 'Should store a static initializer reference as a StaticInitializer edge' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'DepClass'),
                (New-ClassCollectorWithData 'InitClass' -StaticInitializerReferences @('DepClass'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('InitClass', [PSScriptBuilderDependencyEdgeType]::StaticInitializer).Contains('DepClass') | Should -BeTrue
        }
    }

    Context 'Build - inheritance edge suppresses weaker edges' {

        It 'Should not add a TypeReference edge when an Inheritance edge to the same target already exists' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'BaseClass'),
                (New-ClassCollectorWithData 'DerivedClass' -BaseClass 'BaseClass' -TypeReferences @('BaseClass'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('DerivedClass', [PSScriptBuilderDependencyEdgeType]::Inheritance).Contains('BaseClass') | Should -BeTrue
            $graph.GetDependencies('DerivedClass', [PSScriptBuilderDependencyEdgeType]::TypeReference).Contains('BaseClass') | Should -BeFalse
        }

        It 'Should not add a StaticInitializer edge when an Inheritance edge to the same target already exists' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'BaseClass'),
                (New-ClassCollectorWithData 'DerivedClass' -BaseClass 'BaseClass' -StaticInitializerReferences @('BaseClass'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('DerivedClass', [PSScriptBuilderDependencyEdgeType]::Inheritance).Contains('BaseClass') | Should -BeTrue
            $graph.GetDependencies('DerivedClass', [PSScriptBuilderDependencyEdgeType]::StaticInitializer).Contains('BaseClass') | Should -BeFalse
        }

        It 'Should still add a TypeReference edge when no Inheritance edge to the same target exists' {
            $builder = New-Builder @(
                (New-ClassCollectorWithData 'HelperClass'),
                (New-ClassCollectorWithData 'ConsumerClass' -TypeReferences @('HelperClass'))
            )

            $graph = $builder.Build()

            $graph.GetDependencies('ConsumerClass', [PSScriptBuilderDependencyEdgeType]::TypeReference).Contains('HelperClass') | Should -BeTrue
        }
    }
}

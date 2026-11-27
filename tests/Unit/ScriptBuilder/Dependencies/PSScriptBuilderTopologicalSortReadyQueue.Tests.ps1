using namespace System
using namespace System.Collections.Generic

Describe 'PSScriptBuilderTopologicalSortReadyQueue' {

    BeforeAll {
        Function New-TypeMap {
            param([hashtable] $Types)
            $map = [Dictionary[string, PSScriptBuilderCollectorType]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($name in $Types.Keys) { $map[$name] = $Types[$name] }
            return $map
        }
    }

    Context 'Count' {

        It 'Should return 0 for a newly-created empty queue' {
            $queue = [PSScriptBuilderTopologicalSortReadyQueue]::new($null)

            $queue.Count() | Should -Be 0
        }

        It 'Should reflect the total across all three internal structures' {
            $types = New-TypeMap @{
                'Get-FuncA' = [PSScriptBuilderCollectorType]::FunctionCollector
                'ClassA'    = [PSScriptBuilderCollectorType]::ClassCollector
                'SomeEnum'  = [PSScriptBuilderCollectorType]::EnumCollector
            }
            $queue = [PSScriptBuilderTopologicalSortReadyQueue]::new($types)

            $queue.Add('Get-FuncA')
            $queue.Add('ClassA')
            $queue.Add('SomeEnum')

            $queue.Count() | Should -Be 3
        }
    }

    Context 'Add and Dequeue - type priority' {

        It 'Should dequeue a Function before a Class when both are ready' {
            $types = New-TypeMap @{
                'MyClass'    = [PSScriptBuilderCollectorType]::ClassCollector
                'Get-MyData' = [PSScriptBuilderCollectorType]::FunctionCollector
            }
            $queue = [PSScriptBuilderTopologicalSortReadyQueue]::new($types)
            $queue.Add('MyClass')
            $queue.Add('Get-MyData')

            $queue.Dequeue() | Should -Be 'Get-MyData'
            $queue.Dequeue() | Should -Be 'MyClass'
        }
    }

    Context 'Add and Dequeue - alphabetical tie-break within the same type' {

        It 'Should dequeue alphabetically-later classes first' {
            $types = New-TypeMap @{
                'Apple' = [PSScriptBuilderCollectorType]::ClassCollector
                'Mango' = [PSScriptBuilderCollectorType]::ClassCollector
                'Zebra' = [PSScriptBuilderCollectorType]::ClassCollector
            }
            $queue = [PSScriptBuilderTopologicalSortReadyQueue]::new($types)
            $queue.Add('Apple')
            $queue.Add('Zebra')
            $queue.Add('Mango')

            $queue.Dequeue() | Should -Be 'Zebra'
            $queue.Dequeue() | Should -Be 'Mango'
            $queue.Dequeue() | Should -Be 'Apple'
        }

        It 'Should dequeue alphabetically-later functions first' {
            $types = New-TypeMap @{
                'Get-Apple' = [PSScriptBuilderCollectorType]::FunctionCollector
                'Get-Zebra' = [PSScriptBuilderCollectorType]::FunctionCollector
            }
            $queue = [PSScriptBuilderTopologicalSortReadyQueue]::new($types)
            $queue.Add('Get-Apple')
            $queue.Add('Get-Zebra')

            $queue.Dequeue() | Should -Be 'Get-Zebra'
            $queue.Dequeue() | Should -Be 'Get-Apple'
        }
    }

    Context 'Add and Dequeue - fallback for untyped nodes' {

        It 'Should preserve FIFO arrival order for nodes with no entry in the type map' {
            $types = New-TypeMap @{}
            $queue = [PSScriptBuilderTopologicalSortReadyQueue]::new($types)
            $queue.Add('First')
            $queue.Add('Second')
            $queue.Add('Third')

            $queue.Dequeue() | Should -Be 'First'
            $queue.Dequeue() | Should -Be 'Second'
            $queue.Dequeue() | Should -Be 'Third'
        }

        It 'Should preserve FIFO arrival order when the type map itself is $null' {
            $queue = [PSScriptBuilderTopologicalSortReadyQueue]::new($null)
            $queue.Add('First')
            $queue.Add('Second')

            $queue.Dequeue() | Should -Be 'First'
            $queue.Dequeue() | Should -Be 'Second'
        }

        It 'Should route a node with an unrelated collector type (e.g. Enum) to the fallback queue' {
            $types = New-TypeMap @{ 'SomeEnum' = [PSScriptBuilderCollectorType]::EnumCollector }
            $queue = [PSScriptBuilderTopologicalSortReadyQueue]::new($types)
            $queue.Add('SomeEnum')

            $queue.Count() | Should -Be 1
            $queue.Dequeue() | Should -Be 'SomeEnum'
        }
    }

    Context 'Dequeue - priority ordering across all three structures' {

        It 'Should always drain Functions, then Classes, then the fallback queue' {
            $types = New-TypeMap @{
                'ClassA'    = [PSScriptBuilderCollectorType]::ClassCollector
                'Get-FuncA' = [PSScriptBuilderCollectorType]::FunctionCollector
                'SomeEnum'  = [PSScriptBuilderCollectorType]::EnumCollector
            }
            $queue = [PSScriptBuilderTopologicalSortReadyQueue]::new($types)
            $queue.Add('SomeEnum')
            $queue.Add('ClassA')
            $queue.Add('Get-FuncA')

            $queue.Dequeue() | Should -Be 'Get-FuncA'
            $queue.Dequeue() | Should -Be 'ClassA'
            $queue.Dequeue() | Should -Be 'SomeEnum'
        }
    }
}

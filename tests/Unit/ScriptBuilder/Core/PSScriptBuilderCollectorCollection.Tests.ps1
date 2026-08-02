using namespace System
using namespace System.Collections.Generic

Describe 'PSScriptBuilderCollectorCollection' {

    BeforeAll {
        Function New-Collection {
            return [PSScriptBuilderCollectorCollection]::new()
        }

        Function New-UsingCollector {
            param([string] $Key = 'Usings')
            return [PSScriptBuilderUsingCollector]::new($Key)
        }

        Function New-ClassCollector {
            param([string] $Key = 'Classes')
            return [PSScriptBuilderClassCollector]::new($Key)
        }

        Function New-EnumCollector {
            param([string] $Key = 'Enums')
            return [PSScriptBuilderEnumCollector]::new($Key)
        }

        Function New-FunctionCollector {
            param([string] $Key = 'Functions')
            return [PSScriptBuilderFunctionCollector]::new($Key)
        }

        Function New-FileCollector {
            param([string] $Key = 'Files')
            return [PSScriptBuilderFileCollector]::new($Key)
        }
    }

    Context 'Constructor' {

        It 'Should initialise with an empty Items dictionary' {
            $collection = New-Collection

            $collection.GetCount() | Should -Be 0
        }
    }

    Context 'Add' {

        It 'Should throw ArgumentNullException when collector is null' {
            $collection = New-Collection

            { $collection.Add($null) } | Should -Throw
        }

        It 'Should throw ArgumentException when CollectionKey is empty' {
            $collection = New-Collection
            $collector  = New-ClassCollector -Key ''

            { $collection.Add($collector) } | Should -Throw
        }

        It 'Should throw InvalidOperationException when a duplicate key is added' {
            $collection = New-Collection
            $collection.Add((New-ClassCollector -Key 'Classes'))

            { $collection.Add((New-ClassCollector -Key 'Classes')) } | Should -Throw
        }

        It 'Should add a collector and increment GetCount' {
            $collection = New-Collection
            $collection.Add((New-ClassCollector -Key 'Classes'))

            $collection.GetCount() | Should -Be 1
        }

        It 'Should accept collectors with different keys' {
            $collection = New-Collection
            $collection.Add((New-ClassCollector    -Key 'Classes'))
            $collection.Add((New-EnumCollector     -Key 'Enums'))
            $collection.Add((New-FunctionCollector -Key 'Functions'))

            $collection.GetCount() | Should -Be 3
        }
    }

    Context 'Exists' {

        It 'Should return $false for an empty collection' {
            $collection = New-Collection

            $collection.Exists('Classes') | Should -BeFalse
        }

        It 'Should return $false for whitespace key' {
            $collection = New-Collection

            $collection.Exists('   ') | Should -BeFalse
        }

        It 'Should return $true after adding a collector with that key' {
            $collection = New-Collection
            $collection.Add((New-ClassCollector -Key 'Classes'))

            $collection.Exists('Classes') | Should -BeTrue
        }

        It 'Should be case-insensitive' {
            $collection = New-Collection
            $collection.Add((New-ClassCollector -Key 'Classes'))

            $collection.Exists('CLASSES') | Should -BeTrue
            $collection.Exists('classes') | Should -BeTrue
        }
    }

    Context 'GetCollector' {

        It 'Should throw ArgumentException for whitespace key' {
            $collection = New-Collection

            { $collection.GetCollector('') } | Should -Throw
        }

        It 'Should throw KeyNotFoundException when key does not exist' {
            $collection = New-Collection

            { $collection.GetCollector('Missing') } | Should -Throw
        }

        It 'Should return the correct collector' {
            $collection = New-Collection
            $expected   = New-ClassCollector -Key 'Classes'
            $collection.Add($expected)

            $result = $collection.GetCollector('Classes')

            $result.CollectionKey | Should -Be 'Classes'
        }
    }

    Context 'Remove' {

        It 'Should throw ArgumentException for whitespace key' {
            $collection = New-Collection

            { $collection.Remove('') } | Should -Throw
        }

        It 'Should return $false when key does not exist' {
            $collection = New-Collection

            $collection.Remove('Missing') | Should -BeFalse
        }

        It 'Should return $true and remove the collector' {
            $collection = New-Collection
            $collection.Add((New-ClassCollector -Key 'Classes'))

            $result = $collection.Remove('Classes')

            $result                  | Should -BeTrue
            $collection.GetCount()   | Should -Be 0
        }
    }

    Context 'Clear' {

        It 'Should remove all collectors' {
            $collection = New-Collection
            $collection.Add((New-ClassCollector    -Key 'Classes'))
            $collection.Add((New-EnumCollector     -Key 'Enums'))

            $collection.Clear()

            $collection.GetCount() | Should -Be 0
        }
    }

    Context 'GetAll - sorting' {

        It 'Should return collectors sorted by CollectorType enum value' {
            $collection = New-Collection
            $collection.Add((New-FunctionCollector -Key 'Functions'))
            $collection.Add((New-UsingCollector    -Key 'Usings'))
            $collection.Add((New-ClassCollector    -Key 'Classes'))
            $collection.Add((New-EnumCollector     -Key 'Enums'))
            $collection.Add((New-FileCollector     -Key 'Files'))

            $result = $collection.GetAll()

            $result[0].CollectorType | Should -Be ([PSScriptBuilderCollectorType]::UsingCollector)
            $result[1].CollectorType | Should -Be ([PSScriptBuilderCollectorType]::EnumCollector)
            $result[2].CollectorType | Should -Be ([PSScriptBuilderCollectorType]::ClassCollector)
            $result[3].CollectorType | Should -Be ([PSScriptBuilderCollectorType]::FunctionCollector)
            $result[4].CollectorType | Should -Be ([PSScriptBuilderCollectorType]::FileCollector)
        }
    }

    Context 'Type-filtered getters' {

        BeforeAll {
            $script:TypeCollection = [PSScriptBuilderCollectorCollection]::new()
            $script:TypeCollection.Add((New-UsingCollector    -Key 'Usings'))
            $script:TypeCollection.Add((New-UsingCollector    -Key 'Usings2'))
            $script:TypeCollection.Add((New-ClassCollector    -Key 'Classes'))
            $script:TypeCollection.Add((New-EnumCollector     -Key 'Enums'))
            $script:TypeCollection.Add((New-FunctionCollector -Key 'Functions'))
            $script:TypeCollection.Add((New-FileCollector     -Key 'Files'))
        }

        It 'GetUsingCollectors should return only UsingCollectors' {
            $result = $script:TypeCollection.GetUsingCollectors()

            $result.Count | Should -Be 2
            $result | ForEach-Object { $_.CollectorType | Should -Be ([PSScriptBuilderCollectorType]::UsingCollector) }
        }

        It 'GetClassCollectors should return only ClassCollectors' {
            $result = $script:TypeCollection.GetClassCollectors()

            $result.Count | Should -Be 1
            $result[0].CollectionKey | Should -Be 'Classes'
        }

        It 'GetEnumCollectors should return only EnumCollectors' {
            $result = $script:TypeCollection.GetEnumCollectors()

            $result.Count | Should -Be 1
        }

        It 'GetFunctionCollectors should return only FunctionCollectors' {
            $result = $script:TypeCollection.GetFunctionCollectors()

            $result.Count | Should -Be 1
        }

        It 'GetFileCollectors should return only FileCollectors' {
            $result = $script:TypeCollection.GetFileCollectors()

            $result.Count | Should -Be 1
        }

        It 'Should return empty array when no collector of that type exists' {
            $empty = New-Collection
            $empty.Add((New-ClassCollector -Key 'Classes'))

            $result = $empty.GetUsingCollectors()

            $result.Count | Should -Be 0
        }
    }
}

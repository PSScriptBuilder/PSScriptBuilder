using namespace System
using namespace System.Collections.Generic
using namespace System.IO

Describe 'PSScriptBuilderContentCollector' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-ContentCollector {
            return [PSScriptBuilderContentCollector]::new()
        }

        Function New-ClassCollectorWithFile {
            param([string] $Key = 'Classes', [string] $FilePath)
            $collector = [PSScriptBuilderClassCollector]::new($Key)
            $collector.IncludeFiles = @($FilePath)
            return $collector
        }

        Function New-EnumCollectorWithFile {
            param([string] $Key = 'Enums', [string] $FilePath)
            $collector = [PSScriptBuilderEnumCollector]::new($Key)
            $collector.IncludeFiles = @($FilePath)
            return $collector
        }

        Function New-FunctionCollectorWithFile {
            param([string] $Key = 'Functions', [string] $FilePath)
            $collector = [PSScriptBuilderFunctionCollector]::new($Key)
            $collector.IncludeFiles = @($FilePath)
            return $collector
        }

        Function New-UsingCollectorWithFile {
            param([string] $Key = 'Usings', [string] $FilePath)
            $collector = [PSScriptBuilderUsingCollector]::new($Key)
            $collector.IncludeFiles = @($FilePath)
            return $collector
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Constructor' {

        It 'Should initialise with an empty Collectors collection' {
            $cc = New-ContentCollector

            $cc.GetCount() | Should -Be 0
        }
    }

    Context 'AddCollector / RemoveCollector / GetCollector' {

        It 'Should add a collector and make it retrievable' {
            $cc        = New-ContentCollector
            $filePath  = New-TestFile 'AddTest.ps1' 'class AddTestClass { }'
            $collector = New-ClassCollectorWithFile -FilePath $filePath

            $cc.AddCollector($collector)

            $cc.GetCount()                            | Should -Be 1
            $cc.GetCollector('Classes').CollectionKey | Should -Be 'Classes'
        }

        It 'Should remove a collector by key' {
            $cc        = New-ContentCollector
            $filePath  = New-TestFile 'RemoveTest.ps1' 'class RemoveTestClass { }'
            $collector = New-ClassCollectorWithFile -FilePath $filePath
            $cc.AddCollector($collector)

            $result = $cc.RemoveCollector('Classes')

            $result           | Should -BeTrue
            $cc.GetCount()    | Should -Be 0
        }

        It 'Should return $false when removing a non-existent key' {
            $cc = New-ContentCollector

            $cc.RemoveCollector('Missing') | Should -BeFalse
        }
    }

    Context 'Clear' {

        It 'Should remove all collectors' {
            $cc       = New-ContentCollector
            $filePath = New-TestFile 'ClearTest.ps1' 'class ClearTestClass { }'
            $cc.AddCollector((New-ClassCollectorWithFile -FilePath $filePath))

            $cc.Clear()

            $cc.GetCount() | Should -Be 0
        }
    }

    Context 'GetCollectors' {

        It 'Should return collectors sorted by CollectorType' {
            $cc = New-ContentCollector

            $classFile    = New-TestFile 'GCClass.ps1'    'class GCClass { }'
            $enumFile     = New-TestFile 'GCEnum.ps1'     'enum GCEnum { A }'
            $functionFile = New-TestFile 'GCFunction.ps1' 'Function Get-GCThing { }'

            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'Functions' -FilePath $functionFile))
            $cc.AddCollector((New-ClassCollectorWithFile    -Key 'Classes'   -FilePath $classFile))
            $cc.AddCollector((New-EnumCollectorWithFile     -Key 'Enums'     -FilePath $enumFile))

            $result = $cc.GetCollectors()

            $result[0].CollectorType | Should -Be ([PSScriptBuilderCollectorType]::EnumCollector)
            $result[1].CollectorType | Should -Be ([PSScriptBuilderCollectorType]::ClassCollector)
            $result[2].CollectorType | Should -Be ([PSScriptBuilderCollectorType]::FunctionCollector)
        }
    }

    Context 'Execute' {

        It 'Should be a no-op when no collectors are registered' {
            $cc = New-ContentCollector

            { $cc.Execute() } | Should -Not -Throw
        }

        It 'Should run Collect on each registered collector' {
            $cc = New-ContentCollector

            $classFile    = New-TestFile 'ExecClass.ps1'    'class ExecClass { }'
            $enumFile     = New-TestFile 'ExecEnum.ps1'     'enum ExecEnum { X }'

            $cc.AddCollector((New-ClassCollectorWithFile -Key 'Classes' -FilePath $classFile))
            $cc.AddCollector((New-EnumCollectorWithFile  -Key 'Enums'   -FilePath $enumFile))

            $cc.Execute()

            $cc.GetCollector('Classes').ClassData.Count | Should -Be 1
            $cc.GetCollector('Enums').EnumData.Count    | Should -Be 1
        }
    }

    Context 'GetCollectionKeys' {

        It 'Should return the keys of all registered collectors' {
            $cc = New-ContentCollector

            $classFile    = New-TestFile 'KeyClass.ps1' 'class KeyClass { }'
            $enumFile     = New-TestFile 'KeyEnum.ps1'  'enum KeyEnum { A }'

            $cc.AddCollector((New-ClassCollectorWithFile -Key 'MyClasses' -FilePath $classFile))
            $cc.AddCollector((New-EnumCollectorWithFile  -Key 'MyEnums'   -FilePath $enumFile))

            $keys = $cc.GetCollectionKeys()

            $keys | Should -Contain 'MyClasses'
            $keys | Should -Contain 'MyEnums'
        }
    }

    Context 'GetDefinedComponentNames' {

        It 'Should return names from Class, Enum, and Function collectors' {
            $cc = New-ContentCollector

            $classFile    = New-TestFile 'DefClass.ps1'    'class DefClass { }'
            $enumFile     = New-TestFile 'DefEnum.ps1'     'enum DefEnum { A }'
            $functionFile = New-TestFile 'DefFunction.ps1' 'Function Get-DefThing { }'

            $classCollector = New-ClassCollectorWithFile    -Key 'Classes'   -FilePath $classFile
            $enumCollector  = New-EnumCollectorWithFile     -Key 'Enums'     -FilePath $enumFile
            $fnCollector    = New-FunctionCollectorWithFile -Key 'Functions' -FilePath $functionFile

            $cc.AddCollector($classCollector)
            $cc.AddCollector($enumCollector)
            $cc.AddCollector($fnCollector)
            $cc.Execute()

            $names = $cc.GetDefinedComponentNames()

            $names.Contains('DefClass')    | Should -BeTrue
            $names.Contains('DefEnum')     | Should -BeTrue
            $names.Contains('Get-DefThing') | Should -BeTrue
        }
    }

    Context 'GetComponentSourceCode' {

        It 'Should return source code of a class by name' {
            $cc = New-ContentCollector

            $classFile  = New-TestFile 'SrcClass.ps1' "class SrcClass {`n    [string] `$Name`n}"
            $collector  = New-ClassCollectorWithFile -Key 'Classes' -FilePath $classFile
            $cc.AddCollector($collector)
            $cc.Execute()

            $source = $cc.GetComponentSourceCode('SrcClass')

            $source | Should -Match 'class SrcClass'
        }

        It 'Should throw when component is not found' {
            $cc = New-ContentCollector

            { $cc.GetComponentSourceCode('NoSuchComponent') } | Should -Throw
        }

        It 'Should throw ArgumentException for an empty name' {
            $cc = New-ContentCollector

            { $cc.GetComponentSourceCode('') } | Should -Throw
        }
    }

    Context 'Type-filtered collector getters' {

        It 'GetUsingCollectors should return only UsingCollectors' {
            $cc = New-ContentCollector

            $usingFile = New-TestFile 'UCUsing.ps1' 'using namespace System'
            $classFile = New-TestFile 'UCClass.ps1' 'class UCClass { }'

            $cc.AddCollector((New-UsingCollectorWithFile -Key 'Usings'  -FilePath $usingFile))
            $cc.AddCollector((New-ClassCollectorWithFile -Key 'Classes' -FilePath $classFile))

            $result = $cc.GetUsingCollectors()

            $result.Count | Should -Be 1
            $result[0].CollectionKey | Should -Be 'Usings'
        }
    }

    Context 'ValidateComponentNameUniqueness' {

        It 'Should throw InvalidOperationException when a Class and a Function share the same name' {
            $cc = New-ContentCollector

            $classFile    = New-TestFile 'VCNClass.ps1'    'class ConflictName { }'
            $functionFile = New-TestFile 'VCNFunction.ps1' 'Function ConflictName { }'

            $cc.AddCollector((New-ClassCollectorWithFile    -Key 'Classes'   -FilePath $classFile))
            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'Functions' -FilePath $functionFile))
            $cc.Execute()

            { $cc.ValidateComponentNameUniqueness() } | Should -Throw '*ConflictName*'
        }

        It 'Should not throw when only Class collectors are present' {
            $cc = New-ContentCollector

            $classFile = New-TestFile 'VCNClassOnly.ps1' 'class OnlyClass { }'

            $cc.AddCollector((New-ClassCollectorWithFile -Key 'Classes' -FilePath $classFile))
            $cc.Execute()

            { $cc.ValidateComponentNameUniqueness() } | Should -Not -Throw
        }

        It 'Should not throw when only Function collectors are present' {
            $cc = New-ContentCollector

            $functionFile = New-TestFile 'VCNFunctionOnly.ps1' 'Function OnlyFunction { }'

            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'Functions' -FilePath $functionFile))
            $cc.Execute()

            { $cc.ValidateComponentNameUniqueness() } | Should -Not -Throw
        }

        It 'Should not throw when Class and Function names are distinct' {
            $cc = New-ContentCollector

            $classFile    = New-TestFile 'VCNDistinctClass.ps1'    'class UniqueClass { }'
            $functionFile = New-TestFile 'VCNDistinctFunction.ps1' 'Function Get-UniqueFunction { }'

            $cc.AddCollector((New-ClassCollectorWithFile    -Key 'Classes'   -FilePath $classFile))
            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'Functions' -FilePath $functionFile))
            $cc.Execute()

            { $cc.ValidateComponentNameUniqueness() } | Should -Not -Throw
        }
    }
}

using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Describe 'PSScriptBuilderClassCollector' {

    # Helper: writes a .ps1 file to TestDrive: and returns the full path as string
    BeforeAll {
        Function New-TestFile {
            param(
                [string] $FileName,
                [string] $Content
            )
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        # Helper: creates a collector with IncludeFiles set to the provided paths
        Function New-Collector {
            param([string[]] $Files, [string] $Key = 'CLASS_DEFINITIONS')
            $collector = [PSScriptBuilderClassCollector]::new($Key)
            $collector.IncludeFiles = $Files
            return $collector
        }
    }

    Context 'Constructor' {

        It 'Should initialise with default CollectionKey' {
            $collector = [PSScriptBuilderClassCollector]::new()

            $collector.CollectionKey | Should -Be 'CLASS_DEFINITIONS'
        }

        It 'Should initialise with a custom CollectionKey' {
            $collector = [PSScriptBuilderClassCollector]::new('MyClasses')

            $collector.CollectionKey | Should -Be 'MyClasses'
        }

        It 'Should start with an empty ClassData dictionary' {
            $collector = [PSScriptBuilderClassCollector]::new()

            $collector.ClassData.Count | Should -Be 0
        }
    }

    Context 'Collection - basic' {

        It 'Should collect a single class from a file' {
            $file = New-TestFile 'SingleClass.ps1' @'
class MyClass {
    [string] $Name
}
'@
            $collector = New-Collector @($file)

            $collector.Collect()

            $collector.ClassData.Count | Should -Be 1
            $collector.ClassData.ContainsKey('MyClass') | Should -BeTrue
        }

        It 'Should collect multiple classes from a single file' {
            $file = New-TestFile 'MultiClass.ps1' @'
class ClassA {
    [string] $Name
}

class ClassB {
    [int] $Value
}
'@
            $collector = New-Collector @($file)

            $collector.Collect()

            $collector.ClassData.Count | Should -Be 2
            $collector.ClassData.ContainsKey('ClassA') | Should -BeTrue
            $collector.ClassData.ContainsKey('ClassB') | Should -BeTrue
        }

        It 'Should collect classes from multiple files' {
            $fileA = New-TestFile 'FileA.ps1' 'class ClassA { [string] $Name }'
            $fileB = New-TestFile 'FileB.ps1' 'class ClassB { [int] $Value }'
            $collector = New-Collector @($fileA, $fileB)

            $collector.Collect()

            $collector.ClassData.Count | Should -Be 2
        }

        It 'Should store the correct class name in ClassData' {
            $file = New-TestFile 'Named.ps1' 'class ExactName { }'
            $collector = New-Collector @($file)

            $collector.Collect()

            $collector.ClassData['ExactName'].Name | Should -Be 'ExactName'
        }

        It 'Should return zero classes for a file with no class definitions' {
            $file = New-TestFile 'NoClasses.ps1' '# just a comment'
            $collector = New-Collector @($file)

            $collector.Collect()

            $collector.ClassData.Count | Should -Be 0
        }
    }

    Context 'Collection - inheritance' {

        It 'Should capture the base class of a derived class' {
            $file = New-TestFile 'Derived.ps1' @'
class BaseClass { }
class DerivedClass : BaseClass { }
'@
            $collector = New-Collector @($file)

            $collector.Collect()

            $collector.ClassData['DerivedClass'].BaseClass | Should -Be 'BaseClass'
        }

        It 'Should store null BaseClass for a class without inheritance' {
            $file = New-TestFile 'NoBase.ps1' 'class StandaloneClass { }'
            $collector = New-Collector @($file)

            $collector.Collect()

            $collector.ClassData['StandaloneClass'].BaseClass | Should -BeNullOrEmpty
        }
    }

    Context 'Collection - static property initializers' {

        It 'Should store a type used in a static property initializer in StaticInitializerReferences' {
            $file = New-TestFile 'StaticInit.ps1' @'
class DepType { }
class WithStaticInit {
    static [DepType] $Default = [DepType]::new()
}
'@
            $collector = New-Collector @($file)

            $collector.Collect()

            $collector.ClassData['WithStaticInit'].StaticInitializerReferences | Should -Contain 'DepType'
        }

        It 'Should not list a static-initializer-only type reference in TypeReferences' {
            $file = New-TestFile 'StaticInitNotInTypeRefs.ps1' @'
class DepType { }
class WithStaticInit {
    static [DepType] $Default = [DepType]::new()
}
'@
            $collector = New-Collector @($file)

            $collector.Collect()

            $collector.ClassData['WithStaticInit'].TypeReferences | Should -Not -Contain 'DepType'
        }
    }

    Context 'Collection - Reset' {

        It 'Should clear ClassData when Collect is called a second time' {
            $file = New-TestFile 'ForReset.ps1' 'class ClassA { }'
            $collector = New-Collector @($file)
            $collector.Collect()

            $file2 = New-TestFile 'ForReset2.ps1' 'class ClassB { }'
            $collector.IncludeFiles = @($file2)
            $collector.Collect()

            $collector.ClassData.Count | Should -Be 1
            $collector.ClassData.ContainsKey('ClassB') | Should -BeTrue
        }

        It 'Should start with empty ClassData after explicit Reset' {
            $file = New-TestFile 'BeforeReset.ps1' 'class ClassA { }'
            $collector = New-Collector @($file)
            $collector.Collect()

            $collector.Reset()

            $collector.ClassData.Count | Should -Be 0
        }
    }

    Context 'Duplicate Detection' {

        It 'Should throw InvalidOperationException when the same class name appears in two files' {
            $fileA = New-TestFile 'DupA.ps1' 'class DuplicateClass { [string] $Name }'
            $fileB = New-TestFile 'DupB.ps1' 'class DuplicateClass { [int] $Value }'
            $collector = New-Collector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExceptionType ([Exception])
        }

        It 'Should include the duplicate class name in the exception message' {
            $fileA = New-TestFile 'DupMsgA.ps1' 'class MyDuplicate { }'
            $fileB = New-TestFile 'DupMsgB.ps1' 'class MyDuplicate { }'
            $collector = New-Collector @($fileA, $fileB)

            { $collector.Collect() } |
                Should -Throw -ExpectedMessage '*MyDuplicate*'
        }

        It 'Should be case-insensitive when detecting duplicates' {
            $fileA = New-TestFile 'DupCaseA.ps1' 'class MyClass { }'
            $fileB = New-TestFile 'DupCaseB.ps1' 'class MYCLASS { }'
            $collector = New-Collector @($fileA, $fileB)

            { $collector.Collect() } | Should -Throw -ExceptionType ([Exception])
        }
    }

    Context 'TryGetComponentDetail' {

        It 'Should return null for an unknown class name' {
            $file = New-TestFile 'Det-Unknown.ps1' 'class KnownClass { }'
            $collector = New-Collector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('UnknownClass', [HashSet[string]]::new())

            $result | Should -BeNull
        }

        It 'Should return a detail object for a known class' {
            $file = New-TestFile 'Det-Known.ps1' 'class MyKnownClass { }'
            $collector = New-Collector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('MyKnownClass', [HashSet[string]]::new())

            $result | Should -Not -BeNull
        }

        It 'Should return Type = ClassCollector' {
            $file = New-TestFile 'Det-Type.ps1' 'class TypedClass { }'
            $collector = New-Collector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('TypedClass', [HashSet[string]]::new())

            $result.Type | Should -Be ([PSScriptBuilderCollectorType]::ClassCollector)
        }

        It 'Should return the correct class name' {
            $file = New-TestFile 'Det-Name.ps1' 'class NamedClass { }'
            $collector = New-Collector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('NamedClass', [HashSet[string]]::new())

            $result.Name | Should -Be 'NamedClass'
        }

        It 'Should include a project-internal base class in Dependencies' {
            $fileA = New-TestFile 'Det-Base.ps1' 'class Child : BaseClass { }'
            $fileB = New-TestFile 'Det-BaseImpl.ps1' 'class BaseClass { }'
            $collector = New-Collector @($fileA, $fileB)
            $collector.Collect()

            $knownComponents = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $knownComponents.Add('Child') | Out-Null
            $knownComponents.Add('BaseClass') | Out-Null

            $result = $collector.TryGetComponentDetail('Child', $knownComponents)

            $result.Dependencies | Should -Contain 'BaseClass'
        }

        It 'Should not include an external base class in Dependencies' {
            $file = New-TestFile 'Det-ExtBase.ps1' 'class Child : ExternalBase { }'
            $collector = New-Collector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('Child', [HashSet[string]]::new())

            $result.Dependencies.Count | Should -Be 0
        }

        It 'Should return empty Dependencies for a class with no base class and no type references' {
            $file = New-TestFile 'Det-NoDeps.ps1' 'class Isolated { [string] $Name }'
            $collector = New-Collector @($file)
            $collector.Collect()

            $result = $collector.TryGetComponentDetail('Isolated', [HashSet[string]]::new())

            $result.Dependencies.Count | Should -Be 0
        }

        It 'Should not include a self-reference in Dependencies' {
            $file = New-TestFile 'Det-Self.ps1' 'class SelfRef { [SelfRef] $Child }'
            $collector = New-Collector @($file)
            $collector.Collect()

            $knownComponents = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $knownComponents.Add('SelfRef') | Out-Null

            $result = $collector.TryGetComponentDetail('SelfRef', $knownComponents)

            $result.Dependencies.Count | Should -Be 0
        }
    }

    Context 'Parse Error Detection' {

        It 'Should throw InvalidOperationException when a structural parse error prevents class collection' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\ParseErrorNoDefinitions.ps1'
            $collector = New-Collector @($file)

            { $collector.Collect() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should include the file name in the exception message' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\ParseErrorNoDefinitions.ps1'
            $collector = New-Collector @($file)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*ParseErrorNoDefinitions.ps1*'
        }

        It 'Should include line and column info in the exception message' {
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\ParseErrorNoDefinitions.ps1'
            $collector = New-Collector @($file)

            { $collector.Collect() } | Should -Throw -ExpectedMessage '*Line*Col*'
        }

        It 'Should not throw when file has a parse error but class definition is still collected' {
            # ClassWithParseError.ps1 has an unclosed method body — parse error present but class IS in AST
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\Classes\ClassWithParseError.ps1'
            $collector = New-Collector @($file)

            { $collector.Collect() } | Should -Not -Throw
        }

        It 'Should not throw when file has TypeNotFound error but class definition is still collected' {
            # Cross-file type reference causes TypeNotFound — non-structural, class still present in AST
            $file = Join-Path $PSScriptRoot '..\..\..\TestData\Classes\ClassWithTypeRefToB.ps1'
            $collector = New-Collector @($file)

            { $collector.Collect() } | Should -Not -Throw
        }

        It 'Should not throw when file has no parse errors and no class definitions' {
            $file = New-TestFile 'PE-Class-NoClasses.ps1' '# No class definitions in this file'
            $collector = New-Collector @($file)

            { $collector.Collect() } | Should -Not -Throw
        }
    }
}

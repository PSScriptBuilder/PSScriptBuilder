using namespace System

Describe 'PSScriptBuilderComponentNameValidator' {

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
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Constructor' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            { [PSScriptBuilderComponentNameValidator]::new($null) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }

        It 'Should store the provided ContentCollector' {
            $cc        = [PSScriptBuilderContentCollector]::new()
            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)

            $validator.ContentCollector | Should -Be $cc
        }
    }

    Context 'Validate - Class vs Function conflicts' {

        It 'Should throw InvalidOperationException when a Class and a Function share the same name' {
            $cc = New-ContentCollector

            $classFile    = New-TestFile 'VCNClass.ps1'    'class ConflictName { }'
            $functionFile = New-TestFile 'VCNFunction.ps1' 'Function ConflictName { }'

            $cc.AddCollector((New-ClassCollectorWithFile    -Key 'Classes'   -FilePath $classFile))
            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'Functions' -FilePath $functionFile))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Throw '*ConflictName*'
        }

        It 'Should not throw when only Class collectors are present' {
            $cc = New-ContentCollector

            $classFile = New-TestFile 'VCNClassOnly.ps1' 'class OnlyClass { }'

            $cc.AddCollector((New-ClassCollectorWithFile -Key 'Classes' -FilePath $classFile))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Not -Throw
        }

        It 'Should not throw when only Function collectors are present' {
            $cc = New-ContentCollector

            $functionFile = New-TestFile 'VCNFunctionOnly.ps1' 'Function OnlyFunction { }'

            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'Functions' -FilePath $functionFile))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Not -Throw
        }

        It 'Should not throw when Class and Function names are distinct' {
            $cc = New-ContentCollector

            $classFile    = New-TestFile 'VCNDistinctClass.ps1'    'class UniqueClass { }'
            $functionFile = New-TestFile 'VCNDistinctFunction.ps1' 'Function Get-UniqueFunction { }'

            $cc.AddCollector((New-ClassCollectorWithFile    -Key 'Classes'   -FilePath $classFile))
            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'Functions' -FilePath $functionFile))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Not -Throw
        }

        It 'Should throw InvalidOperationException when multiple independent Class-vs-Function collisions exist at once' {
            # Two Class collectors define ConflictX and ConflictY; two Function collectors define
            # the same two names - two independent Class-vs-Function collisions exist at once.
            # Which one is reported first is an implementation detail of scan order, so this only
            # asserts that it throws with the generic conflict message - not which specific
            # name/file pair is named.
            $cc = New-ContentCollector

            $classFileX    = New-TestFile 'VCNMultiCFClassX.ps1'    'class ConflictX { }'
            $classFileY    = New-TestFile 'VCNMultiCFClassY.ps1'    'class ConflictY { }'
            $functionFileX = New-TestFile 'VCNMultiCFFunctionX.ps1' 'Function ConflictX { }'
            $functionFileY = New-TestFile 'VCNMultiCFFunctionY.ps1' 'Function ConflictY { }'

            $cc.AddCollector((New-ClassCollectorWithFile    -Key 'ClassesX'   -FilePath $classFileX))
            $cc.AddCollector((New-ClassCollectorWithFile    -Key 'ClassesY'   -FilePath $classFileY))
            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'FunctionsX' -FilePath $functionFileX))
            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'FunctionsY' -FilePath $functionFileY))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Throw '*Component name conflict*'
        }
    }

    Context 'Validate - cross-collector same-type collisions' {

        It 'Should throw InvalidOperationException when two Class collectors define the same class name (case-insensitive)' {
            $cc = New-ContentCollector

            $classFileA = New-TestFile 'VCNClassA.ps1' 'class MyClass { }'
            $classFileB = New-TestFile 'VCNClassB.ps1' 'class myclass { }'

            $cc.AddCollector((New-ClassCollectorWithFile -Key 'ClassesA' -FilePath $classFileA))
            $cc.AddCollector((New-ClassCollectorWithFile -Key 'ClassesB' -FilePath $classFileB))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Throw '*MyClass*'
        }

        It 'Should throw InvalidOperationException when two Class collectors define the exact same class name (identical spelling)' {
            # Case-differing spelling is not a precondition for the bug - an identical spelling
            # across two collectors must be caught by the same mechanism (RFC 0018).
            $cc = New-ContentCollector

            $classFileA = New-TestFile 'VCNIdenticalClassA.ps1' 'class MyClass { }'
            $classFileB = New-TestFile 'VCNIdenticalClassB.ps1' 'class MyClass { }'

            $cc.AddCollector((New-ClassCollectorWithFile -Key 'ClassesA' -FilePath $classFileA))
            $cc.AddCollector((New-ClassCollectorWithFile -Key 'ClassesB' -FilePath $classFileB))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Throw '*MyClass*'
        }

        It 'Should throw InvalidOperationException when two Function collectors define the same function name (case-insensitive)' {
            $cc = New-ContentCollector

            $functionFileA = New-TestFile 'VCNFunctionA.ps1' 'Function Get-Thing { }'
            $functionFileB = New-TestFile 'VCNFunctionB.ps1' 'Function get-thing { }'

            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'FunctionsA' -FilePath $functionFileA))
            $cc.AddCollector((New-FunctionCollectorWithFile -Key 'FunctionsB' -FilePath $functionFileB))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Throw '*Get-Thing*'
        }

        It 'Should throw InvalidOperationException when two Enum collectors define the same enum name (case-insensitive)' {
            $cc = New-ContentCollector

            $enumFileA = New-TestFile 'VCNEnumA.ps1' 'enum MyEnum { Val }'
            $enumFileB = New-TestFile 'VCNEnumB.ps1' 'enum myenum { Val }'

            $cc.AddCollector((New-EnumCollectorWithFile -Key 'EnumsA' -FilePath $enumFileA))
            $cc.AddCollector((New-EnumCollectorWithFile -Key 'EnumsB' -FilePath $enumFileB))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Throw '*MyEnum*'
        }

        It 'Should not throw when multiple Class collectors define distinct class names' {
            $cc = New-ContentCollector

            $classFileA = New-TestFile 'VCNDistinctClassA.ps1' 'class ClassA { }'
            $classFileB = New-TestFile 'VCNDistinctClassB.ps1' 'class ClassB { }'

            $cc.AddCollector((New-ClassCollectorWithFile -Key 'ClassesA' -FilePath $classFileA))
            $cc.AddCollector((New-ClassCollectorWithFile -Key 'ClassesB' -FilePath $classFileB))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Not -Throw
        }

        It 'Should not throw when only one collector of a type is registered, even with a duplicate-looking scenario absent' {
            $cc = New-ContentCollector

            $classFile = New-TestFile 'VCNSingleCollector.ps1' 'class SoloClass { }'

            $cc.AddCollector((New-ClassCollectorWithFile -Key 'Classes' -FilePath $classFile))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Not -Throw
        }

        It 'Should throw InvalidOperationException when multiple independent same-type collisions exist across three or more collectors' {
            # C1 defines both ConflictX and ConflictY; C2 also defines ConflictY; C3 also defines
            # ConflictX - two independent collisions exist at once. Which one is reported first is
            # an implementation detail of scan order, so this only asserts that it throws with the
            # generic conflict message - not which specific name/file pair is named.
            $cc = New-ContentCollector

            $fileC1 = New-TestFile 'VCNMultiC1.ps1' "class ConflictX { }`nclass ConflictY { }"
            $fileC2 = New-TestFile 'VCNMultiC2.ps1' 'class ConflictY { }'
            $fileC3 = New-TestFile 'VCNMultiC3.ps1' 'class ConflictX { }'

            $cc.AddCollector((New-ClassCollectorWithFile -Key 'C1' -FilePath $fileC1))
            $cc.AddCollector((New-ClassCollectorWithFile -Key 'C2' -FilePath $fileC2))
            $cc.AddCollector((New-ClassCollectorWithFile -Key 'C3' -FilePath $fileC3))
            $cc.Execute()

            $validator = [PSScriptBuilderComponentNameValidator]::new($cc)
            { $validator.Validate() } | Should -Throw '*Component name conflict*'
        }
    }
}

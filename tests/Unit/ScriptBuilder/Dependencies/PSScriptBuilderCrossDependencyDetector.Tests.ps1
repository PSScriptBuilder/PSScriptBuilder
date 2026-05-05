using namespace System

Describe 'PSScriptBuilderCrossDependencyDetector' {

    BeforeAll {
        Function New-Detector {
            param(
                [string[]] $ClassNames    = @(),
                [string[]] $FunctionNames = @()
            )
            $cc = [PSScriptBuilderContentCollector]::new()

            if ($ClassNames.Count -gt 0) {
                $classC = [PSScriptBuilderClassCollector]::new()
                foreach ($name in $ClassNames) {
                    $classC.ClassData[$name] = [PSScriptBuilderClassData]::new(
                        $name, "class $name { }", 'fake.ps1', '', @(), @(), @()
                    )
                }
                $cc.AddCollector($classC)
            }

            if ($FunctionNames.Count -gt 0) {
                $funcC = [PSScriptBuilderFunctionCollector]::new()
                foreach ($name in $FunctionNames) {
                    $funcC.FunctionData[$name] = [PSScriptBuilderFunctionData]::new(
                        $name, "Function $name { }", 'fake.ps1', @(), @()
                    )
                }
                $cc.AddCollector($funcC)
            }

            return [PSScriptBuilderCrossDependencyDetector]::new($cc)
        }
    }

    Context 'Constructor' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            { [PSScriptBuilderCrossDependencyDetector]::new($null) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }

        It 'Should store the provided ContentCollector' {
            $cc       = [PSScriptBuilderContentCollector]::new()
            $detector = [PSScriptBuilderCrossDependencyDetector]::new($cc)

            $detector.ContentCollector | Should -Be $cc
        }
    }

    Context 'HasCrossDependencies - empty and null input' {

        It 'Should return false for null input' {
            $detector = New-Detector -ClassNames @('ClassA') -FunctionNames @('Get-Func')

            $detector.HasCrossDependencies($null) | Should -BeFalse
        }

        It 'Should return false for an empty array' {
            $detector = New-Detector -ClassNames @('ClassA') -FunctionNames @('Get-Func')

            $detector.HasCrossDependencies(@()) | Should -BeFalse
        }
    }

    Context 'HasCrossDependencies - no cross-dependency' {

        It 'Should return false when only classes appear in the list' {
            $detector = New-Detector -ClassNames @('ClassA', 'ClassB')

            $detector.HasCrossDependencies(@('ClassA', 'ClassB')) | Should -BeFalse
        }

        It 'Should return false when only functions appear in the list' {
            $detector = New-Detector -FunctionNames @('Get-A', 'Get-B')

            $detector.HasCrossDependencies(@('Get-A', 'Get-B')) | Should -BeFalse
        }

        It 'Should return false for a Class-then-Function sequence (Class->Function is not a cross-dependency)' {
            $detector = New-Detector -ClassNames @('ClassA') -FunctionNames @('Get-Func')

            $detector.HasCrossDependencies(@('ClassA', 'Get-Func')) | Should -BeFalse
        }
    }

    Context 'HasCrossDependencies - cross-dependency detected' {

        It 'Should return true for a Function-then-Class sequence' {
            $detector = New-Detector -ClassNames @('ClassA') -FunctionNames @('Get-Func')

            $detector.HasCrossDependencies(@('Get-Func', 'ClassA')) | Should -BeTrue
        }

        It 'Should return true when a second Class appears after a Function in a mixed sequence' {
            $detector = New-Detector -ClassNames @('ClassA', 'ClassB') -FunctionNames @('Get-Func')

            $detector.HasCrossDependencies(@('ClassA', 'Get-Func', 'ClassB')) | Should -BeTrue
        }
    }

    Context 'HasCrossDependencies - enums are ignored' {

        It 'Should return false when an enum appears in the sequence alongside classes (enum does not count as class or function)' {
            $cc = [PSScriptBuilderContentCollector]::new()

            $enumC = [PSScriptBuilderEnumCollector]::new()
            $enumC.EnumData['MyEnum'] = [PSScriptBuilderEnumData]::new('MyEnum', 'enum MyEnum { }', 'fake.ps1')
            $cc.AddCollector($enumC)

            $classC = [PSScriptBuilderClassCollector]::new()
            $classC.ClassData['ClassA'] = [PSScriptBuilderClassData]::new(
                'ClassA', 'class ClassA { }', 'fake.ps1', '', @(), @(), @()
            )
            $cc.AddCollector($classC)

            $detector = [PSScriptBuilderCrossDependencyDetector]::new($cc)

            # ClassA, then MyEnum - enum is ignored, so last known type stays Class -> no cross-dep
            $detector.HasCrossDependencies(@('ClassA', 'MyEnum')) | Should -BeFalse
        }
    }
}

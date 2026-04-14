using namespace System

Describe 'PSScriptBuilderDependencyAnalyzer - Analyze' {

    BeforeAll {
        $ClassesPath = Join-Path $PSScriptRoot '..\..\..\TestData\Classes'
        $CyclesPath  = Join-Path $PSScriptRoot '..\..\..\TestData\Classes\Cycles'
        $EnumsPath   = Join-Path $PSScriptRoot '..\..\..\TestData\Enums'
        $FuncsPath   = Join-Path $PSScriptRoot '..\..\..\TestData\Functions'

        # Creates a ClassCollector backed by real TestData files.
        Function New-ClassCollector {
            param([string[]] $Files, [string] $Key = 'Classes')
            $collector = [PSScriptBuilderClassCollector]::new($Key)
            $collector.IncludeFiles = $Files
            return $collector
        }

        # Creates an EnumCollector backed by real TestData files.
        Function New-EnumCollector {
            param([string[]] $Files, [string] $Key = 'Enums')
            $collector = [PSScriptBuilderEnumCollector]::new($Key)
            $collector.IncludeFiles = $Files
            return $collector
        }

        # Creates a FunctionCollector backed by real TestData files.
        Function New-FuncCollector {
            param([string[]] $Files, [string] $Key = 'Functions')
            $collector = [PSScriptBuilderFunctionCollector]::new($Key)
            $collector.IncludeFiles = $Files
            return $collector
        }

        # Builds a DependencyAnalyzer from one or more collectors.
        Function New-Analyzer {
            param([PSScriptBuilderCollectorBase[]] $Collectors)
            $cc = [PSScriptBuilderContentCollector]::new()
            foreach ($c in $Collectors) { $cc.AddCollector($c) }
            return [PSScriptBuilderDependencyAnalyzer]::new($cc)
        }
    }

    Context 'Constructor' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            { [PSScriptBuilderDependencyAnalyzer]::new($null) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }

    Context 'Analyze - empty ContentCollector' {

        It 'Should return a result with no cycles and empty OrderedComponents for an empty collector' {
            $cc       = [PSScriptBuilderContentCollector]::new()
            $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($cc)

            $result = $analyzer.Analyze()

            $result.HasCycles               | Should -BeFalse
            $result.HasCrossDependencies    | Should -BeFalse
            $result.OrderedComponents.Count | Should -Be 0
        }
    }

    Context 'Analyze - no cycles, correct ordering' {

        It 'Should place base class before derived class in OrderedComponents' {
            # ClassDerivedFromA : ClassA -> ClassA must appear before ClassDerivedFromA
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$ClassesPath\ClassA.ps1",
                    "$ClassesPath\ClassDerivedFromA.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeFalse
            $indexBase    = [Array]::IndexOf($result.OrderedComponents, 'ClassA')
            $indexDerived = [Array]::IndexOf($result.OrderedComponents, 'ClassDerivedFromA')
            $indexBase | Should -BeLessThan $indexDerived
        }

        It 'Should place grandparent before parent before child in a 3-level hierarchy' {
            # ClassGrandChild : ClassDerivedFromA : ClassA
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$ClassesPath\ClassA.ps1",
                    "$ClassesPath\ClassDerivedFromA.ps1",
                    "$ClassesPath\ClassGrandChild.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeFalse
            $indexA       = [Array]::IndexOf($result.OrderedComponents, 'ClassA')
            $indexDerived = [Array]::IndexOf($result.OrderedComponents, 'ClassDerivedFromA')
            $indexGrand   = [Array]::IndexOf($result.OrderedComponents, 'ClassGrandChild')
            $indexA       | Should -BeLessThan $indexDerived
            $indexDerived | Should -BeLessThan $indexGrand
        }

        It 'Should place callee function before caller function' {
            # Get-FuncCallsA calls Get-FuncA -> Get-FuncA must appear first
            $analyzer = New-Analyzer @(
                (New-FuncCollector @(
                    "$FuncsPath\FuncA.ps1",
                    "$FuncsPath\FuncCallsA.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeFalse
            $indexA      = [Array]::IndexOf($result.OrderedComponents, 'Get-FuncA')
            $indexCallsA = [Array]::IndexOf($result.OrderedComponents, 'Get-FuncCallsA')
            $indexA | Should -BeLessThan $indexCallsA
        }

        It 'Should include all components in OrderedComponents' {
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$ClassesPath\ClassA.ps1",
                    "$ClassesPath\ClassB.ps1"
                )),
                (New-FuncCollector @("$FuncsPath\FuncA.ps1"))
            )

            $result = $analyzer.Analyze()

            $result.OrderedComponents | Should -Contain 'ClassA'
            $result.OrderedComponents | Should -Contain 'ClassB'
            $result.OrderedComponents | Should -Contain 'Get-FuncA'
        }
    }

    Context 'Analyze - enum stabilization' {

        It 'Should place enum before class that uses it' {
            # ClassUsesEnumA has a property of type EnumA -> EnumA must appear first
            $analyzer = New-Analyzer @(
                (New-EnumCollector @("$EnumsPath\EnumA.ps1")),
                (New-ClassCollector @("$ClassesPath\ClassUsesEnumA.ps1"))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeFalse
            $indexEnum  = [Array]::IndexOf($result.OrderedComponents, 'EnumA')
            $indexClass = [Array]::IndexOf($result.OrderedComponents, 'ClassUsesEnumA')
            $indexEnum | Should -BeLessThan $indexClass
        }

        It 'Should place enum before class even when no explicit dependency exists' {
            # ClassA has no dependency on EnumA, but StabilizeEnumsFirst ensures enum is first
            $analyzer = New-Analyzer @(
                (New-EnumCollector @("$EnumsPath\EnumA.ps1")),
                (New-ClassCollector @("$ClassesPath\ClassA.ps1"))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeFalse
            $indexEnum  = [Array]::IndexOf($result.OrderedComponents, 'EnumA')
            $indexClass = [Array]::IndexOf($result.OrderedComponents, 'ClassA')
            $indexEnum | Should -BeLessThan $indexClass
        }
    }

    Context 'Analyze - Inheritance cycle' {

        It 'Should return HasCycles = true for a direct Inheritance cycle' {
            # InhCycleA : InhCycleB  and  InhCycleB : InhCycleA
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$CyclesPath\InhCycleA.ps1",
                    "$CyclesPath\InhCycleB.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeTrue
        }

        It 'Should return a non-empty CyclePath containing both cycle nodes' {
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$CyclesPath\InhCycleA.ps1",
                    "$CyclesPath\InhCycleB.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.CyclePath.Count | Should -BeGreaterThan 0
            $result.CyclePath | Should -Contain 'InhCycleA'
            $result.CyclePath | Should -Contain 'InhCycleB'
        }

        It 'Should return empty OrderedComponents when HasCycles is true' {
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$CyclesPath\InhCycleA.ps1",
                    "$CyclesPath\InhCycleB.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.OrderedComponents.Count | Should -Be 0
        }

        It 'Should return HasCrossDependencies = false when HasCycles is true' {
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$CyclesPath\InhCycleA.ps1",
                    "$CyclesPath\InhCycleB.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.HasCrossDependencies | Should -BeFalse
        }

        It 'Should detect a 3-node Inheritance chain cycle' {
            # InhChainA : InhChainB : InhChainC : InhChainA
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$CyclesPath\InhChainA.ps1",
                    "$CyclesPath\InhChainB.ps1",
                    "$CyclesPath\InhChainC.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeTrue
            $result.CyclePath | Should -Contain 'InhChainA'
            $result.CyclePath | Should -Contain 'InhChainB'
            $result.CyclePath | Should -Contain 'InhChainC'
        }
    }

    Context 'Analyze - StaticInitializer cycle' {

        It 'Should return HasCycles = true for a direct StaticInitializer cycle' {
            # StaticCycleA.Instance = [StaticCycleB]::new()  and  vice versa
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$CyclesPath\StaticCycleA.ps1",
                    "$CyclesPath\StaticCycleB.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeTrue
        }

        It 'Should return a non-empty CyclePath for a StaticInitializer cycle' {
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$CyclesPath\StaticCycleA.ps1",
                    "$CyclesPath\StaticCycleB.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.CyclePath | Should -Contain 'StaticCycleA'
            $result.CyclePath | Should -Contain 'StaticCycleB'
        }
    }

    Context 'Analyze - TypeReference cycle' {

        It 'Should return HasCycles = false for a TypeReference cycle' {
            # TypeRefCycleA { [TypeRefCycleB] $Prop }  and  vice versa — not fatal
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$CyclesPath\TypeRefCycleA.ps1",
                    "$CyclesPath\TypeRefCycleB.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeFalse
        }

        It 'Should return both nodes in OrderedComponents for a TypeReference cycle' {
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$CyclesPath\TypeRefCycleA.ps1",
                    "$CyclesPath\TypeRefCycleB.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.OrderedComponents.Count | Should -Be 2
            $result.OrderedComponents | Should -Contain 'TypeRefCycleA'
            $result.OrderedComponents | Should -Contain 'TypeRefCycleB'
        }
    }

    Context 'Analyze - StaticInitializer ordering (non-cycle)' {

        It 'Should place ClassB before ClassWithStaticInitOfB' {
            # ClassWithStaticInitOfB has static [ClassB] $Instance = [ClassB]::new()
            # StaticInitializer edge: ClassWithStaticInitOfB -> ClassB
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$ClassesPath\ClassB.ps1",
                    "$ClassesPath\ClassWithStaticInitOfB.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles | Should -BeFalse
            $indexB      = [Array]::IndexOf($result.OrderedComponents, 'ClassB')
            $indexStatic = [Array]::IndexOf($result.OrderedComponents, 'ClassWithStaticInitOfB')
            $indexB | Should -BeLessThan $indexStatic
        }
    }

    Context 'Analyze - cross-dependencies' {

        It 'Should return HasCrossDependencies = true when a class calls a function' {
            # ClassCallsFuncA calls Get-FuncA in a method
            # Topological order: Get-FuncA (function) before ClassCallsFuncA (class) — cross-dependency
            $analyzer = New-Analyzer @(
                (New-ClassCollector @("$ClassesPath\ClassCallsFuncA.ps1")),
                (New-FuncCollector  @("$FuncsPath\FuncA.ps1"))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles            | Should -BeFalse
            $result.HasCrossDependencies | Should -BeTrue
        }

        It 'Should return HasCrossDependencies = false when a function only depends on a class' {
            # Get-FuncUsesClassA uses [ClassA]::new() — function depends on class, natural order preserved
            $analyzer = New-Analyzer @(
                (New-ClassCollector @("$ClassesPath\ClassA.ps1")),
                (New-FuncCollector  @("$FuncsPath\FuncUsesClassA.ps1"))
            )

            $result = $analyzer.Analyze()

            $result.HasCycles            | Should -BeFalse
            $result.HasCrossDependencies | Should -BeFalse
        }
    }

    Context 'Analyze - component counts' {

        It 'Should return correct TotalNodes count' {
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$ClassesPath\ClassA.ps1",
                    "$ClassesPath\ClassDerivedFromA.ps1"
                )),
                (New-FuncCollector @("$FuncsPath\FuncA.ps1"))
            )

            $result = $analyzer.Analyze()

            $result.TotalNodes | Should -Be 3
        }

        It 'Should return correct TotalEdges count for a single FunctionCall edge' {
            # Get-FuncCallsA calls Get-FuncA — exactly one FunctionCall edge, no type annotations
            $analyzer = New-Analyzer @(
                (New-FuncCollector @(
                    "$FuncsPath\FuncA.ps1",
                    "$FuncsPath\FuncCallsA.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.TotalEdges | Should -Be 1
        }

        It 'Should return correct TotalEdges count for an Inheritance relationship' {
            # ClassDerivedFromA : ClassA creates one edge:
            # - Inheritance edge (from BaseClass)
            # The TypeReference edge to the same target is suppressed because an Inheritance edge already exists.
            $analyzer = New-Analyzer @(
                (New-ClassCollector @(
                    "$ClassesPath\ClassA.ps1",
                    "$ClassesPath\ClassDerivedFromA.ps1"
                ))
            )

            $result = $analyzer.Analyze()

            $result.TotalEdges | Should -Be 1
        }
    }
}

Describe 'PSScriptBuilderDependencyAnalyzer - StabilizeEnumsFirst' {

    # Helper: creates a ContentCollector with an EnumCollector pre-populated with the given enum names
    BeforeAll {
        Function New-AnalyzerWithEnums {
            param([string[]] $EnumNames)

            $enumCollector = [PSScriptBuilderEnumCollector]::new()

            foreach ($name in $EnumNames) {
                $enumData = [PSScriptBuilderEnumData]::new($name, "enum $name { }", 'test.ps1')
                $enumCollector.EnumData[$name] = $enumData
            }

            $contentCollector = [PSScriptBuilderContentCollector]::new()
            $contentCollector.AddCollector($enumCollector)

            return [PSScriptBuilderDependencyAnalyzer]::new($contentCollector)
        }
    }

    Context 'No enums registered' {

        It 'Should return the original array unchanged when no enum collector is registered' {
            $contentCollector = [PSScriptBuilderContentCollector]::new()
            $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($contentCollector)
            $input = @('ClassA', 'ClassB', 'FuncX')

            $result = $analyzer.StabilizeEnumsFirst($input)

            $result | Should -Be $input
        }

        It 'Should return an empty array unchanged' {
            $contentCollector = [PSScriptBuilderContentCollector]::new()
            $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($contentCollector)

            $result = $analyzer.StabilizeEnumsFirst(@())

            $result.Count | Should -Be 0
        }
    }

    Context 'Enums moved to front' {

        It 'Should place a single enum before all non-enums' {
            $analyzer = New-AnalyzerWithEnums @('StatusEnum')
            $input = @('ClassA', 'StatusEnum', 'ClassB')

            $result = $analyzer.StabilizeEnumsFirst($input)

            $result[0] | Should -Be 'StatusEnum'
        }

        It 'Should place all enums before all non-enums' {
            $analyzer = New-AnalyzerWithEnums @('ZebraEnum', 'AppleEnum')
            $input = @('ClassA', 'ZebraEnum', 'ClassB', 'AppleEnum', 'FuncX')

            $result = $analyzer.StabilizeEnumsFirst($input)

            $indexZebra = [Array]::IndexOf($result, 'ZebraEnum')
            $indexApple = [Array]::IndexOf($result, 'AppleEnum')
            $indexClassA = [Array]::IndexOf($result, 'ClassA')
            $indexClassB = [Array]::IndexOf($result, 'ClassB')
            $indexFuncX  = [Array]::IndexOf($result, 'FuncX')

            $indexZebra | Should -BeLessThan $indexClassA
            $indexApple | Should -BeLessThan $indexClassA
            $indexZebra | Should -BeLessThan $indexClassB
            $indexApple | Should -BeLessThan $indexFuncX
        }
    }

    Context 'Enums sorted alphabetically' {

        It 'Should sort enums case-insensitively in alphabetical order' {
            $analyzer = New-AnalyzerWithEnums @('ZebraEnum', 'appleEnum', 'MangoEnum')
            $input = @('ZebraEnum', 'ClassA', 'MangoEnum', 'appleEnum')

            $result = $analyzer.StabilizeEnumsFirst($input)

            $result[0] | Should -Be 'appleEnum'
            $result[1] | Should -Be 'MangoEnum'
            $result[2] | Should -Be 'ZebraEnum'
        }

        It 'Should return a single enum at position 0' {
            $analyzer = New-AnalyzerWithEnums @('OnlyEnum')
            $input = @('ClassA', 'OnlyEnum')

            $result = $analyzer.StabilizeEnumsFirst($input)

            $result[0] | Should -Be 'OnlyEnum'
        }
    }

    Context 'Non-enum order preserved' {

        It 'Should preserve the relative order of non-enum components' {
            $analyzer = New-AnalyzerWithEnums @('StatusEnum')
            $input = @('ClassC', 'StatusEnum', 'ClassA', 'ClassB')

            $result = $analyzer.StabilizeEnumsFirst($input)

            # After enum: ClassC, ClassA, ClassB - original relative order
            $indexC = [Array]::IndexOf($result, 'ClassC')
            $indexA = [Array]::IndexOf($result, 'ClassA')
            $indexB = [Array]::IndexOf($result, 'ClassB')

            $indexC | Should -BeLessThan $indexA
            $indexA | Should -BeLessThan $indexB
        }
    }

    Context 'All components are enums' {

        It 'Should return all enums alphabetically sorted' {
            $analyzer = New-AnalyzerWithEnums @('ZebraEnum', 'AppleEnum', 'MangoEnum')
            $input = @('ZebraEnum', 'MangoEnum', 'AppleEnum')

            $result = $analyzer.StabilizeEnumsFirst($input)

            $result[0] | Should -Be 'AppleEnum'
            $result[1] | Should -Be 'MangoEnum'
            $result[2] | Should -Be 'ZebraEnum'
        }
    }

    Context 'Total count' {

        It 'Should return the same number of components as the input' {
            $analyzer = New-AnalyzerWithEnums @('StatusEnum', 'BumpType')
            $input = @('ClassA', 'StatusEnum', 'FuncX', 'BumpType', 'ClassB')

            $result = $analyzer.StabilizeEnumsFirst($input)

            $result.Count | Should -Be $input.Count
        }

        It 'Should contain all original components after stabilization' {
            $analyzer = New-AnalyzerWithEnums @('StatusEnum')
            $input = @('ClassA', 'StatusEnum', 'ClassB')

            $result = $analyzer.StabilizeEnumsFirst($input)

            $result | Should -Contain 'ClassA'
            $result | Should -Contain 'StatusEnum'
            $result | Should -Contain 'ClassB'
        }
    }
}

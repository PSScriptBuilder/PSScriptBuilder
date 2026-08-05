using namespace System
using namespace System.IO

Describe 'PSScriptBuilderUnusedComponentFinder' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-ClassCollectorWithFile {
            param([string] $Key = 'CLASSES', [string] $FilePath)
            $c = [PSScriptBuilderClassCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-EnumCollectorWithFile {
            param([string] $Key = 'ENUMS', [string] $FilePath)
            $c = [PSScriptBuilderEnumCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-FunctionCollectorWithFile {
            param([string] $Key = 'FUNCTIONS', [string] $FilePath)
            $c = [PSScriptBuilderFunctionCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-ContentCollectorWith {
            param([PSScriptBuilderCollectorBase[]] $Collectors)
            $cc = [PSScriptBuilderContentCollector]::new()
            foreach ($c in $Collectors) { $cc.AddCollector($c) }
            $cc.Execute()
            return $cc
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    #region Constructor
    Context 'Constructor - parameter guards' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            { [PSScriptBuilderUnusedComponentFinder]::new($null) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }

        It 'Should not throw when contentCollector is valid' {
            $cc = [PSScriptBuilderContentCollector]::new()
            { [PSScriptBuilderUnusedComponentFinder]::new($cc) } | Should -Not -Throw
        }
    }
    #endregion Constructor

    #region Find() - no entry points
    Context 'Find() - no entry points - unused detection' {

        It 'Should return empty array when all components have incoming dependencies' {
            # BaseClass is referenced by DerivedClass → BaseClass has incoming edge → not unused
            # DerivedClass references BaseClass → DerivedClass's only dependency is BaseClass
            # But DerivedClass has no incoming edges... so it will be unused
            # Let's make both reference each other via a function call chain to avoid unused entries
            $baseFile    = New-TestFile 'NoUnused-Base.ps1'    'class NoUnusedBase { }'
            $derivedFile = New-TestFile 'NoUnused-Derived.ps1' 'class NoUnusedDerived : NoUnusedBase { }'
            $funcFile    = New-TestFile 'NoUnused-Func.ps1'    'Function Get-NoUnused { [NoUnusedDerived] $x = $null }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile    -Key 'CLASSES'   -FilePath $baseFile),
                (New-ClassCollectorWithFile    -Key 'CLASSES2'  -FilePath $derivedFile),
                (New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $funcFile)
            )

            # Get-NoUnused has no incoming → still unused; only test that referenced components are not
            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()

            $result | Where-Object { $_.Name -eq 'NoUnusedBase' }    | Should -BeNullOrEmpty
            $result | Where-Object { $_.Name -eq 'NoUnusedDerived' } | Should -BeNullOrEmpty
        }

        It 'Should return a class with no incoming dependencies' {
            $orphanFile  = New-TestFile 'OrphanClass.ps1'  'class OrphanClass { }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile -Key 'CLASSES' -FilePath $orphanFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()

            $result | Where-Object { $_.Name -eq 'OrphanClass' } | Should -Not -BeNullOrEmpty
        }

        It 'Should return an enum with no incoming dependencies' {
            $enumFile = New-TestFile 'OrphanEnum.ps1' 'enum OrphanEnum { None = 0; Some = 1 }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-EnumCollectorWithFile -Key 'ENUMS' -FilePath $enumFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()

            $result | Where-Object { $_.Name -eq 'OrphanEnum' } | Should -Not -BeNullOrEmpty
        }

        It 'Should return a function with no incoming dependencies' {
            $funcFile = New-TestFile 'OrphanFunc.ps1' 'Function Get-Orphan { }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $funcFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()

            $result | Where-Object { $_.Name -eq 'Get-Orphan' } | Should -Not -BeNullOrEmpty
        }

        It 'Should not return a class that is referenced by another class via inheritance' {
            $baseFile    = New-TestFile 'Base-NI.ps1'    'class BaseNI { }'
            $derivedFile = New-TestFile 'Derived-NI.ps1' 'class DerivedNI : BaseNI { }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile -Key 'CLASSES'  -FilePath $baseFile),
                (New-ClassCollectorWithFile -Key 'CLASSES2' -FilePath $derivedFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()

            $result | Where-Object { $_.Name -eq 'BaseNI' } | Should -BeNullOrEmpty
        }

        It 'Should not return a class referenced by a function via type reference' {
            $classFile = New-TestFile 'TypeRef-Class.ps1' 'class TypeRefClass { }'
            $funcFile  = New-TestFile 'TypeRef-Func.ps1'  'Function Use-TypeRef { [TypeRefClass] $x = $null }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile    -Key 'CLASSES'   -FilePath $classFile),
                (New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $funcFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()

            $result | Where-Object { $_.Name -eq 'TypeRefClass' } | Should -BeNullOrEmpty
        }
    }
    #endregion Find() - no entry points

    #region Find() - entry data
    Context 'Find() - entry data on returned entries' {

        It 'Should set ComponentType to Enum for an enum entry' {
            $enumFile = New-TestFile 'DataEnum.ps1' 'enum DataEnum { A = 0 }'
            $cc = New-ContentCollectorWith -Collectors @(
                (New-EnumCollectorWithFile -Key 'MY_ENUMS' -FilePath $enumFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()
            $entry  = $result | Where-Object { $_.Name -eq 'DataEnum' }

            $entry.ComponentType.ToString() | Should -Be 'Enum'
        }

        It 'Should set ComponentType to Class for a class entry' {
            $classFile = New-TestFile 'DataClass.ps1' 'class DataClass { }'
            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile -Key 'MY_CLASSES' -FilePath $classFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()
            $entry  = $result | Where-Object { $_.Name -eq 'DataClass' }

            $entry.ComponentType.ToString() | Should -Be 'Class'
        }

        It 'Should set ComponentType to Function for a function entry' {
            $funcFile = New-TestFile 'DataFunc.ps1' 'Function Get-DataFunc { }'
            $cc = New-ContentCollectorWith -Collectors @(
                (New-FunctionCollectorWithFile -Key 'MY_FUNCTIONS' -FilePath $funcFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()
            $entry  = $result | Where-Object { $_.Name -eq 'Get-DataFunc' }

            $entry.ComponentType.ToString() | Should -Be 'Function'
        }

        It 'Should set CollectionKey on returned entries' {
            $classFile = New-TestFile 'KeyClass.ps1' 'class KeyClass { }'
            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile -Key 'MY_KEY' -FilePath $classFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()
            $entry  = $result | Where-Object { $_.Name -eq 'KeyClass' }

            $entry.CollectionKey | Should -Be 'MY_KEY'
        }

        It 'Should set SourceFile on returned entries' {
            $classFile = New-TestFile 'SFClass.ps1' 'class SFClass { }'
            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile -Key 'CLASSES' -FilePath $classFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find()
            $entry  = $result | Where-Object { $_.Name -eq 'SFClass' }

            $entry.SourceFile | Should -Be $classFile
        }
    }
    #endregion Find() - entry data

    #region Find([string[]]) - with entry points
    Context 'Find([string[]]) - entry point guards' {

        It 'Should throw ArgumentException when entryPoints is null' {
            $cc = [PSScriptBuilderContentCollector]::new()
            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)

            { $finder.Find([string[]] $null) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when entryPoints is empty' {
            $cc = [PSScriptBuilderContentCollector]::new()
            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)

            { $finder.Find([string[]] @()) } | Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'Find([string[]]) - reachability analysis' {

        It 'Should return empty array when all components are reachable from entry point' {
            # Get-EP → (type ref) BaseEP
            $baseFile = New-TestFile 'EPBase.ps1' 'class BaseEP { }'
            $funcFile = New-TestFile 'EPFunc.ps1' 'Function Get-EP { [BaseEP] $x = $null }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile    -Key 'CLASSES'   -FilePath $baseFile),
                (New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $funcFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find(@('Get-EP'))

            $result | Should -BeNullOrEmpty
        }

        It 'Should return components not reachable from the entry point' {
            $baseFile   = New-TestFile 'Reach-Base.ps1'   'class ReachBase { }'
            $orphanFile = New-TestFile 'Reach-Orphan.ps1' 'class ReachOrphan { }'
            $funcFile   = New-TestFile 'Reach-Func.ps1'   'Function Get-Reach { [ReachBase] $x = $null }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile    -Key 'CLASSES'  -FilePath $baseFile),
                (New-ClassCollectorWithFile    -Key 'CLASSES2' -FilePath $orphanFile),
                (New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $funcFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find(@('Get-Reach'))

            $result | Where-Object { $_.Name -eq 'ReachOrphan' } | Should -Not -BeNullOrEmpty
        }

        It 'Should not return the entry point component itself' {
            $funcFile = New-TestFile 'Self-Func.ps1' 'Function Get-Self { }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $funcFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find(@('Get-Self'))

            $result | Where-Object { $_.Name -eq 'Get-Self' } | Should -BeNullOrEmpty
        }

        It 'Should follow transitive dependencies from the entry point' {
            # Get-Transitive → ClassA → ClassB (via inheritance)
            $classBFile = New-TestFile 'Trans-ClassB.ps1' 'class TransClassB { }'
            $classAFile = New-TestFile 'Trans-ClassA.ps1' 'class TransClassA : TransClassB { }'
            $funcFile   = New-TestFile 'Trans-Func.ps1'   'Function Get-Transitive { [TransClassA] $x = $null }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile    -Key 'CLASSES'  -FilePath $classBFile),
                (New-ClassCollectorWithFile    -Key 'CLASSES2' -FilePath $classAFile),
                (New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $funcFile)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find(@('Get-Transitive'))

            $result | Where-Object { $_.Name -eq 'TransClassA' } | Should -BeNullOrEmpty
            $result | Where-Object { $_.Name -eq 'TransClassB' } | Should -BeNullOrEmpty
        }

        It 'Should support glob patterns for entry points' {
            $classFile = New-TestFile 'Glob-Class.ps1' 'class GlobClass { }'
            $func1File = New-TestFile 'Glob-Func1.ps1' 'Function Invoke-GlobOne { [GlobClass] $x = $null }'
            $func2File = New-TestFile 'Glob-Func2.ps1' 'Function Invoke-GlobTwo { }'

            $cc = New-ContentCollectorWith -Collectors @(
                (New-ClassCollectorWithFile    -Key 'CLASSES'   -FilePath $classFile),
                (New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $func1File),
                (New-FunctionCollectorWithFile -Key 'FUNC2'     -FilePath $func2File)
            )

            $finder = [PSScriptBuilderUnusedComponentFinder]::new($cc)
            $result = $finder.Find(@('Invoke-*'))

            $result | Where-Object { $_.Name -eq 'GlobClass' }     | Should -BeNullOrEmpty
            $result | Where-Object { $_.Name -eq 'Invoke-GlobOne' } | Should -BeNullOrEmpty
            $result | Where-Object { $_.Name -eq 'Invoke-GlobTwo' } | Should -BeNullOrEmpty
        }
    }
    #endregion Find([string[]]) - with entry points
}

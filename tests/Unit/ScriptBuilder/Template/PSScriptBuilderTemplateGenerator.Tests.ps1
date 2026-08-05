using namespace System
using namespace System.IO

Describe 'PSScriptBuilderTemplateGenerator' {

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

        Function New-UsingCollectorWithFile {
            param([string] $Key = 'USINGS', [string] $FilePath)
            $c = [PSScriptBuilderUsingCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-FunctionCollectorWithFile {
            param([string] $Key = 'FUNCTIONS', [string] $FilePath)
            $c = [PSScriptBuilderFunctionCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-FileCollectorWithFile {
            param([string] $Key = 'FILES', [string] $FilePath)
            $c = [PSScriptBuilderFileCollector]::new($Key)
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

        Function New-Generator {
            param(
                [PSScriptBuilderContentCollector] $CC,
                [string] $OutputPath,
                [string] $OrderedComponentsKey = 'ORDERED_COMPONENTS',
                [bool]   $OrderedMode          = $false,
                [bool]   $Force                = $false
            )
            return [PSScriptBuilderTemplateGenerator]::new($CC, $OutputPath, $OrderedComponentsKey, $OrderedMode, $Force)
        }
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    #region Constructor
    Context 'Constructor - parameter guards' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            $output = Join-Path $TestDrive 'ctor-null.template'

            { [PSScriptBuilderTemplateGenerator]::new($null, $output, 'ORDERED_COMPONENTS', $false, $false) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }

        It 'Should throw ArgumentException when outputPath is null or empty' {
            $cc = [PSScriptBuilderContentCollector]::new()

            { [PSScriptBuilderTemplateGenerator]::new($cc, '', 'ORDERED_COMPONENTS', $false, $false) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when outputPath is whitespace' {
            $cc = [PSScriptBuilderContentCollector]::new()

            { [PSScriptBuilderTemplateGenerator]::new($cc, '   ', 'ORDERED_COMPONENTS', $false, $false) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when orderedComponentsKey is null or empty' {
            $cc     = [PSScriptBuilderContentCollector]::new()
            $output = Join-Path $TestDrive 'ctor-empty-key.template'

            { [PSScriptBuilderTemplateGenerator]::new($cc, $output, '', $false, $false) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when orderedComponentsKey is whitespace' {
            $cc     = [PSScriptBuilderContentCollector]::new()
            $output = Join-Path $TestDrive 'ctor-ws-key.template'

            { [PSScriptBuilderTemplateGenerator]::new($cc, $output, '   ', $false, $false) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should not throw when all parameters are valid' {
            $cc     = [PSScriptBuilderContentCollector]::new()
            $output = Join-Path $TestDrive 'ctor-valid.template'

            { [PSScriptBuilderTemplateGenerator]::new($cc, $output, 'ORDERED_COMPONENTS', $false, $false) } |
                Should -Not -Throw
        }
    }
    #endregion Constructor

    #region Generate - Guard
    Context 'Generate - output file guard' {

        It 'Should throw InvalidOperationException when output file exists and Force is false' {
            $classFile  = New-TestFile 'Guard-Class.ps1'    'class GuardClass { }'
            $outputPath = New-TestFile 'Guard-existing.template' '# existing'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath -Force $false

            { $gen.Generate() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should not throw when output file exists and Force is true' {
            $classFile  = New-TestFile 'GuardForce-Class.ps1'        'class GuardForceClass { }'
            $outputPath = New-TestFile 'GuardForce-existing.template' '# existing'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath -Force $true

            { $gen.Generate() } | Should -Not -Throw
        }

        It 'Should not throw when output file does not exist' {
            $classFile  = New-TestFile 'GuardNew-Class.ps1' 'class GuardNewClass { }'
            $outputPath = Join-Path $TestDrive 'GuardNew-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath

            { $gen.Generate() } | Should -Not -Throw
        }
    }
    #endregion Generate - Guard

    #region Generate - Mode determination
    Context 'Generate - Mode: Free' {

        It 'Should return mode Free when no cross-dependencies and OrderedMode is false' {
            $classFile  = New-TestFile 'Free-Class.ps1' 'class FreeClass { }'
            $outputPath = Join-Path $TestDrive 'Free-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $result.Mode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Free)
        }

        It 'Should include all collector placeholders in Free mode' {
            $classFile  = New-TestFile 'FreeMulti-Class.ps1' 'class FreeMultiClass { }'
            $enumFile   = New-TestFile 'FreeMulti-Enum.ps1'  'enum FreeMultiEnum { A }'
            $outputPath = Join-Path $TestDrive 'FreeMulti-output.template'

            $classCollector = New-ClassCollectorWithFile -Key 'CLASSES' -FilePath $classFile
            $enumCollector  = New-EnumCollectorWithFile  -Key 'ENUMS'   -FilePath $enumFile
            $cc             = New-ContentCollectorWith -Collectors @($enumCollector, $classCollector)
            $gen            = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $result.Placeholders | Should -Contain '{{CLASSES}}'
            $result.Placeholders | Should -Contain '{{ENUMS}}'
        }

        It 'Should not include ORDERED_COMPONENTS placeholder in Free mode' {
            $classFile  = New-TestFile 'FreeNoOrdered-Class.ps1' 'class FreeNoOrderedClass { }'
            $outputPath = Join-Path $TestDrive 'FreeNoOrdered-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $result.Placeholders | Should -Not -Contain '{{ORDERED_COMPONENTS}}'
        }
    }

    Context 'Generate - Mode: Ordered' {

        It 'Should return mode Ordered when cross-dependencies are detected' {
            # Cross-dependency: class calls a function (class depends on function, inverting natural order)
            $classFile    = New-TestFile 'Ord-Class.ps1'    'class OrdClass { [void] Run() { Get-OrdFunc } }'
            $functionFile = New-TestFile 'Ord-Function.ps1' 'Function Get-OrdFunc { }'
            $outputPath   = Join-Path $TestDrive 'Ord-output.template'

            $classCollector    = New-ClassCollectorWithFile    -Key 'CLASSES'    -FilePath $classFile
            $functionCollector = New-FunctionCollectorWithFile -Key 'FUNCTIONS'  -FilePath $functionFile
            $cc                = New-ContentCollectorWith -Collectors @($classCollector, $functionCollector)
            $gen               = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $result.Mode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Ordered)
        }

        It 'Should include ORDERED_COMPONENTS placeholder in Ordered mode' {
            $classFile    = New-TestFile 'OrdKey-Class.ps1'    'class OrdKeyClass { [void] Run() { Get-OrdKeyFunc } }'
            $functionFile = New-TestFile 'OrdKey-Function.ps1' 'Function Get-OrdKeyFunc { }'
            $outputPath   = Join-Path $TestDrive 'OrdKey-output.template'

            $classCollector    = New-ClassCollectorWithFile    -Key 'CLASSES'   -FilePath $classFile
            $functionCollector = New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $functionFile
            $cc                = New-ContentCollectorWith -Collectors @($classCollector, $functionCollector)
            $gen               = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $result.Placeholders | Should -Contain '{{ORDERED_COMPONENTS}}'
        }

        It 'Should not include ClassCollector or FunctionCollector placeholders in Ordered mode' {
            $classFile    = New-TestFile 'OrdExcl-Class.ps1'    'class OrdExclClass { [void] Run() { Get-OrdExclFunc } }'
            $functionFile = New-TestFile 'OrdExcl-Function.ps1' 'Function Get-OrdExclFunc { }'
            $outputPath   = Join-Path $TestDrive 'OrdExcl-output.template'

            $classCollector    = New-ClassCollectorWithFile    -Key 'CLASSES'   -FilePath $classFile
            $functionCollector = New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $functionFile
            $cc                = New-ContentCollectorWith -Collectors @($classCollector, $functionCollector)
            $gen               = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $result.Placeholders | Should -Not -Contain '{{CLASSES}}'
            $result.Placeholders | Should -Not -Contain '{{FUNCTIONS}}'
        }

        It 'Should use a custom OrderedComponentsKey in Ordered mode' {
            $classFile    = New-TestFile 'OrdCustomKey-Class.ps1'    'class OrdCustomKeyClass { [void] Run() { Get-OrdCustomKeyFunc } }'
            $functionFile = New-TestFile 'OrdCustomKey-Function.ps1' 'Function Get-OrdCustomKeyFunc { }'
            $outputPath   = Join-Path $TestDrive 'OrdCustomKey-output.template'

            $classCollector    = New-ClassCollectorWithFile    -Key 'CLASSES'   -FilePath $classFile
            $functionCollector = New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $functionFile
            $cc                = New-ContentCollectorWith -Collectors @($classCollector, $functionCollector)
            $gen               = New-Generator -CC $cc -OutputPath $outputPath -OrderedComponentsKey 'MY_ORDERED'

            $result = $gen.Generate()

            $result.Placeholders | Should -Contain '{{MY_ORDERED}}'
            $result.Placeholders | Should -Not -Contain '{{ORDERED_COMPONENTS}}'
        }
    }

    Context 'Generate - Mode: Hybrid' {

        It 'Should return mode Hybrid when no cross-dependencies but OrderedMode is true' {
            $classFile  = New-TestFile 'Hyb-Class.ps1' 'class HybClass { }'
            $outputPath = Join-Path $TestDrive 'Hyb-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath -OrderedMode $true

            $result = $gen.Generate()

            $result.Mode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Hybrid)
        }

        It 'Should include ORDERED_COMPONENTS placeholder in Hybrid mode' {
            $classFile  = New-TestFile 'HybKey-Class.ps1' 'class HybKeyClass { }'
            $outputPath = Join-Path $TestDrive 'HybKey-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath -OrderedMode $true

            $result = $gen.Generate()

            $result.Placeholders | Should -Contain '{{ORDERED_COMPONENTS}}'
        }

        It 'Should not include ClassCollector placeholder in Hybrid mode' {
            $classFile  = New-TestFile 'HybExcl-Class.ps1' 'class HybExclClass { }'
            $outputPath = Join-Path $TestDrive 'HybExcl-output.template'

            $collector = New-ClassCollectorWithFile -Key 'CLASSES' -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath -OrderedMode $true

            $result = $gen.Generate()

            $result.Placeholders | Should -Not -Contain '{{CLASSES}}'
        }
    }
    #endregion Generate - Mode determination

    #region Generate - Placeholders (Using/File in Ordered/Hybrid mode)
    Context 'Generate - Placeholders in Ordered/Hybrid mode' {

        It 'Should prepend UsingCollector placeholder before ORDERED_COMPONENTS' {
            $usingFile    = New-TestFile 'OrdUsing-Using.ps1'    'using namespace System'
            $classFile    = New-TestFile 'OrdUsing-Class.ps1'    'class OrdUsingClass { [void] Run() { Get-OrdUsingFunc } }'
            $functionFile = New-TestFile 'OrdUsing-Function.ps1' 'Function Get-OrdUsingFunc { }'
            $outputPath   = Join-Path $TestDrive 'OrdUsing-output.template'

            $usingCollector    = New-UsingCollectorWithFile    -Key 'USINGS'    -FilePath $usingFile
            $classCollector    = New-ClassCollectorWithFile    -Key 'CLASSES'   -FilePath $classFile
            $functionCollector = New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $functionFile
            $cc                = New-ContentCollectorWith -Collectors @($usingCollector, $classCollector, $functionCollector)
            $gen               = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $usingIndex   = [Array]::IndexOf($result.Placeholders, '{{USINGS}}')
            $orderedIndex = [Array]::IndexOf($result.Placeholders, '{{ORDERED_COMPONENTS}}')

            $usingIndex | Should -BeLessThan $orderedIndex
        }

        It 'Should append FileCollector placeholder after ORDERED_COMPONENTS' {
            $classFile    = New-TestFile 'OrdFile-Class.ps1'    'class OrdFileClass { [void] Run() { Get-OrdFileFunc } }'
            $functionFile = New-TestFile 'OrdFile-Function.ps1' 'Function Get-OrdFileFunc { }'
            $fileFile     = New-TestFile 'OrdFile-File.ps1'     '# file content'
            $outputPath   = Join-Path $TestDrive 'OrdFile-output.template'

            $classCollector    = New-ClassCollectorWithFile    -Key 'CLASSES'   -FilePath $classFile
            $functionCollector = New-FunctionCollectorWithFile -Key 'FUNCTIONS' -FilePath $functionFile
            $fileCollector     = New-FileCollectorWithFile     -Key 'FILES'     -FilePath $fileFile
            $cc                = New-ContentCollectorWith -Collectors @($classCollector, $functionCollector, $fileCollector)
            $gen               = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $orderedIndex = [Array]::IndexOf($result.Placeholders, '{{ORDERED_COMPONENTS}}')
            $fileIndex    = [Array]::IndexOf($result.Placeholders, '{{FILES}}')

            $fileIndex | Should -BeGreaterThan $orderedIndex
        }
    }
    #endregion Generate - Placeholders

    #region Generate - Result
    Context 'Generate - Result properties' {

        It 'Should return a PSScriptBuilderTemplateGenerationResult' {
            $classFile  = New-TestFile 'Res-Class.ps1' 'class ResClass { }'
            $outputPath = Join-Path $TestDrive 'Res-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $result.GetType().Name | Should -Be 'PSScriptBuilderTemplateGenerationResult'
        }

        It 'Should return the correct OutputPath in the result' {
            $classFile  = New-TestFile 'ResPath-Class.ps1' 'class ResPathClass { }'
            $outputPath = Join-Path $TestDrive 'ResPath-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath

            $result = $gen.Generate()

            $result.OutputPath | Should -Be $outputPath
        }

        It 'Should set OrderedMode to true in result when OrderedMode flag is true' {
            $classFile  = New-TestFile 'ResFlagTrue-Class.ps1' 'class ResFlagTrueClass { }'
            $outputPath = Join-Path $TestDrive 'ResFlagTrue-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath -OrderedMode $true

            $result = $gen.Generate()

            $result.OrderedMode | Should -BeTrue
        }

        It 'Should set OrderedMode to false in result when OrderedMode flag is false' {
            $classFile  = New-TestFile 'ResFlagFalse-Class.ps1' 'class ResFlagFalseClass { }'
            $outputPath = Join-Path $TestDrive 'ResFlagFalse-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath -OrderedMode $false

            $result = $gen.Generate()

            $result.OrderedMode | Should -BeFalse
        }
    }
    #endregion Generate - Result

    #region Generate - File writing
    Context 'Generate - File writing' {

        It 'Should create the template file at the specified output path' {
            $classFile  = New-TestFile 'Write-Class.ps1' 'class WriteClass { }'
            $outputPath = Join-Path $TestDrive 'Write-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath

            $gen.Generate() | Out-Null

            Test-Path $outputPath | Should -BeTrue
        }

        It 'Should write all placeholders into the template file content' {
            $classFile  = New-TestFile 'WriteContent-Class.ps1' 'class WriteContentClass { }'
            $outputPath = Join-Path $TestDrive 'WriteContent-output.template'

            $collector = New-ClassCollectorWithFile -Key 'CLASSES' -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath

            $gen.Generate() | Out-Null

            $content = Get-Content $outputPath -Raw
            $content | Should -Match '\{\{CLASSES\}\}'
        }

        It 'Should create the output directory when it does not exist' {
            $classFile  = New-TestFile 'Dir-Class.ps1' 'class DirClass { }'
            $subDir     = Join-Path $TestDrive 'subdir-new'
            $outputPath = Join-Path $subDir 'Dir-output.template'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith -Collectors @($collector)
            $gen       = New-Generator -CC $cc -OutputPath $outputPath

            $gen.Generate() | Out-Null

            Test-Path $subDir | Should -BeTrue
        }
    }
    #endregion Generate - File writing
}

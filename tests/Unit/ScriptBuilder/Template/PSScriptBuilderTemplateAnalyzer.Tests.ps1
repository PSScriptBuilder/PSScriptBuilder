using namespace System
using namespace System.IO

Describe 'PSScriptBuilderTemplateAnalyzer' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        Function New-TestFile {
            param([string] $FileName, [string] $Content)
            $path = Join-Path $TestDrive $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            return $path
        }

        Function New-ClassCollectorWithFile {
            param([string] $Key = 'CLASS_DEFINITIONS', [string] $FilePath)
            $c = [PSScriptBuilderClassCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-EnumCollectorWithFile {
            param([string] $Key = 'ENUM_DEFINITIONS', [string] $FilePath)
            $c = [PSScriptBuilderEnumCollector]::new($Key)
            $c.IncludeFiles = @($FilePath)
            return $c
        }

        Function New-UsingCollectorWithFile {
            param([string] $Key = 'USING_STATEMENTS', [string] $FilePath)
            $c = [PSScriptBuilderUsingCollector]::new($Key)
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

    Context 'Constructor - parameter guards' {

        It 'Should throw ArgumentNullException when contentCollector is null' {
            { [PSScriptBuilderTemplateAnalyzer]::new($null, 'template.psm1', 'ORDERED_COMPONENTS') } | Should -Throw
        }

        It 'Should throw ArgumentException when templatePath is empty' {
            $cc = [PSScriptBuilderContentCollector]::new()

            { [PSScriptBuilderTemplateAnalyzer]::new($cc, '', 'ORDERED_COMPONENTS') } | Should -Throw
        }

        It 'Should throw ArgumentException when orderedComponentsKey is empty' {
            $cc = [PSScriptBuilderContentCollector]::new()

            { [PSScriptBuilderTemplateAnalyzer]::new($cc, 'template.psm1', '') } | Should -Throw
        }

        It 'Should construct successfully with valid parameters' {
            $cc = [PSScriptBuilderContentCollector]::new()

            { [PSScriptBuilderTemplateAnalyzer]::new($cc, 'template.psm1', 'ORDERED_COMPONENTS') } | Should -Not -Throw
        }
    }

    Context 'Analyze - Free mode (no cross-dependencies)' {

        It 'Should return IsValid = $true for a valid Free mode template' {
            $classFile    = New-TestFile 'AClassDef.ps1' 'class AClassDef { }'
            $templateFile = New-TestFile 'valid-free.template' "{{CLASS_DEFINITIONS}}"

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith   -Collectors @($collector)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.IsValid | Should -BeTrue
        }

        It 'Should return IsValid = $false when a collector placeholder is missing' {
            $classFile    = New-TestFile 'MissingPlaceholder.ps1' 'class MissingPlaceholderClass { }'
            $templateFile = New-TestFile 'missing-placeholder.template' '# no placeholder'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith   -Collectors @($collector)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.IsValid | Should -BeFalse
        }

        It 'Should return ValidationErrors when template is invalid' {
            $classFile    = New-TestFile 'ErrorClass.ps1' 'class ErrorClass { }'
            $templateFile = New-TestFile 'invalid-template.template' '# no placeholder'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith   -Collectors @($collector)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.ValidationErrors | Should -Not -BeNullOrEmpty
        }

        It 'Should return the resolved template path in the result' {
            $classFile    = New-TestFile 'PathClass.ps1' 'class PathClass { }'
            $templateFile = New-TestFile 'path-check.template' "{{CLASS_DEFINITIONS}}"

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith   -Collectors @($collector)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.TemplatePath | Should -Be $templateFile
        }

        It 'Should detect the correct validation mode as Free when no cross-dependencies' {
            $classFile    = New-TestFile 'FreeModeClass.ps1' 'class FreeModeClass { }'
            $templateFile = New-TestFile 'free-mode.template' "{{CLASS_DEFINITIONS}}"

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith   -Collectors @($collector)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.ValidationMode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Free)
        }

        It 'Should extract placeholders found in the template' {
            $classFile    = New-TestFile 'ExtractClass.ps1' 'class ExtractClass { }'
            $templateFile = New-TestFile 'extract.template' "# header`n{{CLASS_DEFINITIONS}}`n# footer"

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith   -Collectors @($collector)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.PlaceholdersFound | Should -Contain '{{CLASS_DEFINITIONS}}'
        }

        It 'Should identify unknown placeholders in the result' {
            $classFile    = New-TestFile 'UnknownClass.ps1' 'class UnknownClass { }'
            $templateFile = New-TestFile 'unknown-placeholder.template' "{{CLASS_DEFINITIONS}}`n{{UNKNOWN_TOKEN}}"

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith   -Collectors @($collector)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.UnknownPlaceholders | Should -Contain '{{UNKNOWN_TOKEN}}'
        }

        It 'Should identify missing placeholders in the result' {
            $classFile    = New-TestFile 'MissingExpected.ps1' 'class MissingExpected { }'
            $templateFile = New-TestFile 'missing-expected.template' '# no placeholder'

            $collector = New-ClassCollectorWithFile -FilePath $classFile
            $cc        = New-ContentCollectorWith   -Collectors @($collector)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.MissingPlaceholders | Should -Contain '{{CLASS_DEFINITIONS}}'
        }

        It 'Should return PlaceholdersExpected matching all collector keys' {
            $classFile    = New-TestFile 'ExpectedKeys.ps1' 'class ExpectedKeysClass { }'
            $templateFile = New-TestFile 'expected-keys.template' '{{CLASS_DEFINITIONS}}'

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.PlaceholdersExpected | Should -Contain '{{CLASS_DEFINITIONS}}'
        }

        It 'Should return empty MissingPlaceholders for a valid template' {
            $classFile    = New-TestFile 'NoMissing.ps1' 'class NoMissingClass { }'
            $templateFile = New-TestFile 'no-missing.template' '{{CLASS_DEFINITIONS}}'

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.MissingPlaceholders | Should -BeNullOrEmpty
        }

        It 'Should return empty UnknownPlaceholders for a valid template' {
            $classFile    = New-TestFile 'NoUnknown.ps1' 'class NoUnknownClass { }'
            $templateFile = New-TestFile 'no-unknown.template' '{{CLASS_DEFINITIONS}}'

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.UnknownPlaceholders | Should -BeNullOrEmpty
        }

        It 'Should return TemplateSize greater than zero' {
            $classFile    = New-TestFile 'SizeClass.ps1' 'class SizeClass { }'
            $templateFile = New-TestFile 'size-check.template' '{{CLASS_DEFINITIONS}}'

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.TemplateSize | Should -BeGreaterThan 0
        }
    }

    Context 'Analyze - Ordered mode' {

        It 'Should return IsValid = $true for a template with no collectors and no placeholders' {
            # No collectors registered -> Free mode with 0 placeholders required -> valid
            $cc           = [PSScriptBuilderContentCollector]::new()
            $templateFile = New-TestFile 'cross-valid.template' "# This template has no placeholders"

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.IsValid | Should -BeTrue
        }

        It 'Should return ValidationMode = Free when no cross-dependencies are present' {
            # Without a Function->Class ordering transition there are no cross-dependencies.
            $classFile    = New-TestFile 'NoCrossClass.ps1'    'class NoCrossClass { }'
            $templateFile = New-TestFile 'no-cross.template'   "{{CLASS_DEFINITIONS}}"

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.ValidationMode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Free)
        }

        It 'Should return HasCrossDependencies = $false when no cross-dependencies are present' {
            $classFile    = New-TestFile 'NoCrossHas.ps1'     'class NoCrossHas { }'
            $templateFile = New-TestFile 'no-cross-has.template' "{{CLASS_DEFINITIONS}}"

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.HasCrossDependencies | Should -BeFalse
        }
    }

    Context 'Analyze - Hybrid mode (Free code + {{ORDERED_COMPONENTS}} template)' {

        It 'Should return ValidationMode = Hybrid when Free code uses {{ORDERED_COMPONENTS}} template' {
            $classFile    = New-TestFile 'HybridModeClass.ps1'   'class HybridModeClass { }'
            $templateFile = New-TestFile 'hybrid-mode.template'  '{{ORDERED_COMPONENTS}}'

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.ValidationMode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Hybrid)
        }

        It 'Should return PlaceholdersExpected = [{{ORDERED_COMPONENTS}}] for Hybrid mode with Class collector' {
            $classFile    = New-TestFile 'HybridExpClass.ps1'    'class HybridExpClass { }'
            $templateFile = New-TestFile 'hybrid-exp.template'   '{{ORDERED_COMPONENTS}}'

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.PlaceholdersExpected | Should -Be @('{{ORDERED_COMPONENTS}}')
        }

        It 'Should return PlaceholdersExpected containing Using and ORDERED_COMPONENTS for Hybrid mode' {
            $usingFile    = New-TestFile 'HybridUsingExp.ps1'    'using namespace System'
            $classFile    = New-TestFile 'HybridUsingClass.ps1'  'class HybridUsingClass { }'
            $templateFile = New-TestFile 'hybrid-using.template' "{{USING_STATEMENTS}}`n{{ORDERED_COMPONENTS}}"

            $usingC = New-UsingCollectorWithFile -FilePath $usingFile
            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($usingC, $classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.PlaceholdersExpected | Should -Contain '{{ORDERED_COMPONENTS}}'
            $result.PlaceholdersExpected | Should -Contain '{{USING_STATEMENTS}}'
        }

        It 'Should return HasCrossDependencies = $false in Hybrid mode (code structure unchanged)' {
            $classFile    = New-TestFile 'HybridHasCross.ps1'    'class HybridHasCross { }'
            $templateFile = New-TestFile 'hybrid-has-cross.template' '{{ORDERED_COMPONENTS}}'

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.HasCrossDependencies | Should -BeFalse
        }

        It 'Should return IsValid = $true for a valid Hybrid template' {
            $classFile    = New-TestFile 'HybridValid.ps1'    'class HybridValidClass { }'
            $templateFile = New-TestFile 'hybrid-valid.template' '{{ORDERED_COMPONENTS}}'

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.IsValid | Should -BeTrue
        }

        It 'Should return IsValid = $false when a forbidden Class placeholder is present in Hybrid template' {
            $classFile    = New-TestFile 'HybridForbidden.ps1'    'class HybridForbiddenClass { }'
            $templateFile = New-TestFile 'hybrid-forbidden.template' "{{ORDERED_COMPONENTS}}`n{{CLASS_DEFINITIONS}}"

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.IsValid | Should -BeFalse
        }

        It 'Should return empty MissingPlaceholders for a valid Hybrid template' {
            $classFile    = New-TestFile 'HybridNoMissing.ps1'    'class HybridNoMissingClass { }'
            $templateFile = New-TestFile 'hybrid-no-missing.template' '{{ORDERED_COMPONENTS}}'

            $classC = New-ClassCollectorWithFile -FilePath $classFile
            $cc     = New-ContentCollectorWith   -Collectors @($classC)

            $analyzer = [PSScriptBuilderTemplateAnalyzer]::new($cc, $templateFile, 'ORDERED_COMPONENTS')
            $result   = $analyzer.Analyze()

            $result.MissingPlaceholders | Should -BeNullOrEmpty
        }
    }
}

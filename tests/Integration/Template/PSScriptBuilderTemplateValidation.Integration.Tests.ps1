Describe 'Template Validation Integration - Test-PSScriptBuilderTemplate' -Tag 'Integration' {

    Context 'Example 02: Free Mode - valid template with individual collector placeholders' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\02-classes-and-enums')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $enumC  = New-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'
            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $script:CC           = New-PSScriptBuilderContentCollector -Collector @($enumC, $classC, $funcC)
            $script:TemplatePath = Join-Path $script:Root 'build\Templates\HRTools.ps1.template'
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return true for a valid Free Mode template' {
            $result = Test-PSScriptBuilderTemplate -ContentCollector $script:CC -TemplatePath $script:TemplatePath
            $result | Should -BeTrue
        }
    }

    Context 'Example 07: Ordered Mode - valid template with ORDERED_COMPONENTS placeholder' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\07-ordered-mode')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $script:CC           = New-PSScriptBuilderContentCollector -Collector @($classC, $funcC)
            $script:TemplatePath = Join-Path $script:Root 'build\Templates\HRWorkforce.ps1.template'
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return true for a valid Ordered Mode template' {
            $result = Test-PSScriptBuilderTemplate -ContentCollector $script:CC -TemplatePath $script:TemplatePath
            $result | Should -BeTrue
        }
    }

    Context 'Example 07: Ordered Mode - Free Mode-style template rejected for real cross-dependencies' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\07-ordered-mode')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $script:CC = New-PSScriptBuilderContentCollector -Collector @($classC, $funcC)

            # This project's classes call project-defined functions (a real cross-dependency),
            # which forces Ordered Mode. A Free Mode-style template with separate per-type
            # placeholders must therefore fail validation, not pass it.
            $script:TemplatePath = Join-Path $TestDrive 'FreeModeStyle.ps1.template'
            Set-Content -Path $script:TemplatePath -Value "{{CLASS_DEFINITIONS}}`n`n{{FUNCTION_DEFINITIONS}}"
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return false because the real cross-dependency requires the ordered components placeholder' {
            $result = Test-PSScriptBuilderTemplate -ContentCollector $script:CC -TemplatePath $script:TemplatePath
            $result | Should -BeFalse
        }
    }

    Context 'Example 02: Free Mode - a comment mentioning {{{{ORDERED_COMPONENTS}}}} is correctly escaped (RFC 0001)' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\02-classes-and-enums')).Path
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $enumC  = New-PSScriptBuilderCollector -Type Enum     -IncludePath 'src\Enums'
            $classC = New-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes'
            $funcC  = New-PSScriptBuilderCollector -Type Function -IncludePath 'src\Functions'
            $script:CC = New-PSScriptBuilderContentCollector -Collector @($enumC, $classC, $funcC)

            # A comment mentioning the escaped {{{{ORDERED_COMPONENTS}}}} placeholder must not force
            # Ordered/Hybrid Mode - this is the exact repro from RFC 0001's Motivation.
            $script:TemplatePath = Join-Path $TestDrive 'EscapedComment.ps1.template'
            $templateContent = "# Example: you could switch to Hybrid mode by using {{{{ORDERED_COMPONENTS}}}} instead`n{{ENUM_DEFINITIONS}}`n`n{{CLASS_DEFINITIONS}}`n`n{{FUNCTION_DEFINITIONS}}"
            Set-Content -Path $script:TemplatePath -Value $templateContent
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return true - the escaped comment must not force Ordered/Hybrid Mode' {
            $result = Test-PSScriptBuilderTemplate -ContentCollector $script:CC -TemplatePath $script:TemplatePath
            $result | Should -BeTrue
        }
    }
}

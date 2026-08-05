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
}

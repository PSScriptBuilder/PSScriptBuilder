Describe 'PSScriptBuilderTemplateAnalysisResult' {

    BeforeAll {
        Function New-Result {
            param(
                [bool]     $IsValid              = $true,
                [string[]] $ValidationErrors     = @(),
                [string]   $TemplatePath         = 'C:\template.psm1',
                [int]      $TemplateSize         = 100,
                [PSScriptBuilderTemplateValidationMode] $ValidationMode = [PSScriptBuilderTemplateValidationMode]::Free,
                [string]   $OrderedComponentsKey = 'ORDERED_COMPONENTS',
                [bool]     $HasCrossDeps         = $false,
                [string[]] $PlaceholdersFound    = @(),
                [string[]] $PlaceholdersExpected = @(),
                [string[]] $MissingPlaceholders  = @(),
                [string[]] $UnknownPlaceholders  = @()
            )
            return [PSScriptBuilderTemplateAnalysisResult]::new(
                $IsValid, $ValidationErrors, $TemplatePath, $TemplateSize,
                $ValidationMode, $OrderedComponentsKey, $HasCrossDeps,
                $PlaceholdersFound, $PlaceholdersExpected, $MissingPlaceholders, $UnknownPlaceholders)
        }
    }

    Context 'Constructor - property mapping' {

        It 'Should set IsValid' {
            $result = New-Result -IsValid $true

            $result.IsValid | Should -BeTrue
        }

        It 'Should set IsValid to false' {
            $result = New-Result -IsValid $false

            $result.IsValid | Should -BeFalse
        }

        It 'Should set ValidationErrors' {
            $errors = @('Error 1', 'Error 2')
            $result = New-Result -IsValid $false -ValidationErrors $errors

            $result.ValidationErrors | Should -Be $errors
        }

        It 'Should set TemplatePath' {
            $result = New-Result -TemplatePath 'C:\build\my.template'

            $result.TemplatePath | Should -Be 'C:\build\my.template'
        }

        It 'Should set TemplateSize' {
            $result = New-Result -TemplateSize 512

            $result.TemplateSize | Should -Be 512
        }

        It 'Should set ValidationMode to Free' {
            $result = New-Result -ValidationMode ([PSScriptBuilderTemplateValidationMode]::Free)

            $result.ValidationMode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Free)
        }

        It 'Should set ValidationMode to Ordered' {
            $result = New-Result -ValidationMode ([PSScriptBuilderTemplateValidationMode]::Ordered)

            $result.ValidationMode | Should -Be ([PSScriptBuilderTemplateValidationMode]::Ordered)
        }

        It 'Should set OrderedComponentsKey' {
            $result = New-Result -OrderedComponentsKey 'ORDERED_COMPONENTS'

            $result.OrderedComponentsKey | Should -Be 'ORDERED_COMPONENTS'
        }

        It 'Should set HasCrossDependencies' {
            $result = New-Result -HasCrossDeps $true

            $result.HasCrossDependencies | Should -BeTrue
        }

        It 'Should set PlaceholdersFound' {
            $found  = @('CLASSES', 'FUNCTIONS')
            $result = New-Result -PlaceholdersFound $found

            $result.PlaceholdersFound | Should -Be $found
        }

        It 'Should set PlaceholdersExpected' {
            $expected = @('CLASSES', 'FUNCTIONS')
            $result   = New-Result -PlaceholdersExpected $expected

            $result.PlaceholdersExpected | Should -Be $expected
        }

        It 'Should set MissingPlaceholders' {
            $missing = @('FUNCTIONS')
            $result  = New-Result -IsValid $false -MissingPlaceholders $missing

            $result.MissingPlaceholders | Should -Be $missing
        }

        It 'Should set UnknownPlaceholders' {
            $unknown = @('UNKNOWN_KEY')
            $result  = New-Result -IsValid $false -UnknownPlaceholders $unknown

            $result.UnknownPlaceholders | Should -Be $unknown
        }
    }
}

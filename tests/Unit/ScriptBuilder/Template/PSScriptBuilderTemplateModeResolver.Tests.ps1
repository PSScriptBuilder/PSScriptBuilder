Describe 'PSScriptBuilderTemplateModeResolver' {

    #region ExtractPlaceholders
    Context 'ExtractPlaceholders' {

        It 'Should extract a single placeholder' {
            $result = [PSScriptBuilderTemplateModeResolver]::ExtractPlaceholders('Hello {{NAME}}')
            $result | Should -Be @('{{NAME}}')
        }

        It 'Should extract multiple unique placeholders, sorted alphabetically' {
            $result = [PSScriptBuilderTemplateModeResolver]::ExtractPlaceholders('{{ZEBRA}} and {{APPLE}}')
            $result | Should -Be @('{{APPLE}}', '{{ZEBRA}}')
        }

        It 'Should deduplicate repeated placeholders' {
            $result = [PSScriptBuilderTemplateModeResolver]::ExtractPlaceholders('{{NAME}} says hi to {{NAME}}')
            $result | Should -Be @('{{NAME}}')
        }

        It 'Should return an empty array when no placeholders are present' {
            $result = [PSScriptBuilderTemplateModeResolver]::ExtractPlaceholders('No placeholders here')
            $result.Count | Should -Be 0
        }

        It 'Should not match single-brace text' {
            $result = [PSScriptBuilderTemplateModeResolver]::ExtractPlaceholders('{NOT_A_PLACEHOLDER}')
            $result.Count | Should -Be 0
        }
    }
    #endregion ExtractPlaceholders

    #region HasOrderedPlaceholder
    Context 'HasOrderedPlaceholder' {

        It 'Should return true when the default ordered-components placeholder is present' {
            $result = [PSScriptBuilderTemplateModeResolver]::HasOrderedPlaceholder('Hello {{ORDERED_COMPONENTS}}', 'ORDERED_COMPONENTS')
            $result | Should -BeTrue
        }

        It 'Should return true for a custom ordered-components key' {
            $result = [PSScriptBuilderTemplateModeResolver]::HasOrderedPlaceholder('Hello {{MY_KEY}}', 'MY_KEY')
            $result | Should -BeTrue
        }

        It 'Should return false when the ordered-components placeholder is absent' {
            $result = [PSScriptBuilderTemplateModeResolver]::HasOrderedPlaceholder('{{USING}} {{CLASS}}', 'ORDERED_COMPONENTS')
            $result | Should -BeFalse
        }

        It 'Should match case-insensitively' {
            $result = [PSScriptBuilderTemplateModeResolver]::HasOrderedPlaceholder('{{ordered_components}}', 'ORDERED_COMPONENTS')
            $result | Should -BeTrue
        }
    }
    #endregion HasOrderedPlaceholder

    #region IsOrderedModeRequired
    Context 'IsOrderedModeRequired' {

        It 'Should return true when cross-dependencies exist, regardless of placeholder' {
            $result = [PSScriptBuilderTemplateModeResolver]::IsOrderedModeRequired($true, 'no placeholder here', 'ORDERED_COMPONENTS')
            $result | Should -BeTrue
        }

        It 'Should return true when the ordered-components placeholder is present, regardless of cross-dependencies' {
            $result = [PSScriptBuilderTemplateModeResolver]::IsOrderedModeRequired($false, '{{ORDERED_COMPONENTS}}', 'ORDERED_COMPONENTS')
            $result | Should -BeTrue
        }

        It 'Should return true when both cross-dependencies and the placeholder are present' {
            $result = [PSScriptBuilderTemplateModeResolver]::IsOrderedModeRequired($true, '{{ORDERED_COMPONENTS}}', 'ORDERED_COMPONENTS')
            $result | Should -BeTrue
        }

        It 'Should return false when neither cross-dependencies nor the placeholder are present' {
            $result = [PSScriptBuilderTemplateModeResolver]::IsOrderedModeRequired($false, '{{USING}} {{CLASS}}', 'ORDERED_COMPONENTS')
            $result | Should -BeFalse
        }
    }
    #endregion IsOrderedModeRequired
}

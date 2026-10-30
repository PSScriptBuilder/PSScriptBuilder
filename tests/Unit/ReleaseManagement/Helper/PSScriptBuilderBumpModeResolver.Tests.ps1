using namespace System

Describe 'PSScriptBuilderBumpModeResolver' {

    #region DetermineBumpPatternMode
    Context 'DetermineBumpPatternMode' {

        It 'Should return Placeholder for a pattern with {{TOKEN}} placeholders only' {
            $result = [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode("ModuleVersion = '{{VERSION_FULL}}'")
            $result | Should -Be ([PSScriptBuilderBumpPatternMode]::Placeholder)
        }

        It 'Should return Placeholder for a pattern with multiple {{TOKEN}} placeholders' {
            $result = [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode('{{GIT_BRANCH}} - {{VERSION}}')
            $result | Should -Be ([PSScriptBuilderBumpPatternMode]::Placeholder)
        }

        It 'Should return Regex for a pattern with a capture group' {
            $result = [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode("ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'")
            $result | Should -Be ([PSScriptBuilderBumpPatternMode]::Regex)
        }

        It 'Should return Regex for a pattern with escaped outer parens around a real capture group' {
            $result = [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode('Branch: \(({REGEX_GIT_BRANCH})\)')
            $result | Should -Be ([PSScriptBuilderBumpPatternMode]::Regex)
        }

        It 'Should return Placeholder for a pattern with {{TOKEN}} and only escaped (non-capturing) parens' {
            $result = [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode('Copyright \(c\) {{YEAR}}')
            $result | Should -Be ([PSScriptBuilderBumpPatternMode]::Placeholder)
        }

        It 'Should throw ArgumentException for a pattern with neither placeholders nor capture groups' {
            { [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode('plain text, no markers') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for a pattern combining {{TOKEN}} placeholders and a capture group' {
            { [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode('{{GIT_BRANCH}} vs ({REGEX_GIT_BRANCH})') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should classify as Regex when a dangling, unclosed {{ coincides with a real capture group' {
            $result = [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode('Value: (\d+) {{')
            $result | Should -Be ([PSScriptBuilderBumpPatternMode]::Regex)
        }

        It 'Should classify as Placeholder when a dangling, unclosed ( coincides with a real placeholder' {
            $result = [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode('{{VERSION}} some (unrelated text')
            $result | Should -Be ([PSScriptBuilderBumpPatternMode]::Placeholder)
        }

        It 'Should throw ArgumentException for a standalone dangling, unclosed {{ with no other signal' {
            { [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode('Some text {{ incomplete') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException for a standalone dangling, unclosed ( with no other signal' {
            { [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode('Some text (incomplete') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }
    #endregion DetermineBumpPatternMode

    #region IsSimpleMode
    Context 'IsSimpleMode' {

        It 'Should return true when tokens is present and non-empty' {
            $fileConfig = [PSCustomObject] @{ path = 'x'; tokens = @('VERSION_FULL') }
            [PSScriptBuilderBumpModeResolver]::IsSimpleMode($fileConfig) | Should -BeTrue
        }

        It 'Should return false when tokens is absent' {
            $fileConfig = [PSCustomObject] @{ path = 'x' }
            [PSScriptBuilderBumpModeResolver]::IsSimpleMode($fileConfig) | Should -BeFalse
        }

        It 'Should return false when tokens is an empty array' {
            $fileConfig = [PSCustomObject] @{ path = 'x'; tokens = @() }
            [PSScriptBuilderBumpModeResolver]::IsSimpleMode($fileConfig) | Should -BeFalse
        }

        It 'Should return false when only items is present' {
            $fileConfig = [PSCustomObject] @{ path = 'x'; items = @(@{ pattern = 'p'; tokens = @('VERSION_FULL') }) }
            [PSScriptBuilderBumpModeResolver]::IsSimpleMode($fileConfig) | Should -BeFalse
        }
    }
    #endregion IsSimpleMode

    #region IsItemsMode
    Context 'IsItemsMode' {

        It 'Should return true when items is present and non-empty' {
            $fileConfig = [PSCustomObject] @{ path = 'x'; items = @(@{ pattern = 'p'; tokens = @('VERSION_FULL') }) }
            [PSScriptBuilderBumpModeResolver]::IsItemsMode($fileConfig) | Should -BeTrue
        }

        It 'Should return false when items is absent' {
            $fileConfig = [PSCustomObject] @{ path = 'x' }
            [PSScriptBuilderBumpModeResolver]::IsItemsMode($fileConfig) | Should -BeFalse
        }

        It 'Should return false when items is an empty array' {
            $fileConfig = [PSCustomObject] @{ path = 'x'; items = @() }
            [PSScriptBuilderBumpModeResolver]::IsItemsMode($fileConfig) | Should -BeFalse
        }

        It 'Should return false when only tokens is present' {
            $fileConfig = [PSCustomObject] @{ path = 'x'; tokens = @('VERSION_FULL') }
            [PSScriptBuilderBumpModeResolver]::IsItemsMode($fileConfig) | Should -BeFalse
        }
    }
    #endregion IsItemsMode
}

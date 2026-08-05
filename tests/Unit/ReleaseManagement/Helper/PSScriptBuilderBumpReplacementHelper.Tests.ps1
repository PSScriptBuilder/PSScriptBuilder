using namespace System
using namespace System.Collections.Specialized

Describe 'PSScriptBuilderBumpReplacementHelper' {

    # Helper: builds an OrderedDictionary from a plain hashtable
    BeforeAll {
        Function New-TokenMap {
            param([hashtable] $Tokens)
            $map = [OrderedDictionary]::new()
            foreach ($key in $Tokens.Keys) {
                $map[$key] = $Tokens[$key]
            }
            return $map
        }

        Function New-Helper {
            param([hashtable] $Tokens = @{ VERSION_FULL = '1.2.3'; BUILD_DATE = '2026-03-19' })
            return [PSScriptBuilderBumpReplacementHelper]::new((New-TokenMap $Tokens))
        }
    }

    Context 'Constructor' {

        It 'Should initialise TokenMap from parameter' {
            $helper = New-Helper @{ VERSION_FULL = '1.0.0' }

            $helper.TokenMap['VERSION_FULL'] | Should -Be '1.0.0'
        }

        It 'Should use DefaultRegexPatterns when no custom patterns are provided' {
            $helper = New-Helper

            $helper.RegexPatterns | Should -Not -BeNullOrEmpty
            $helper.RegexPatterns.ContainsKey('VERSION_FULL') | Should -BeTrue
        }

        It 'Should use custom RegexPatterns when provided' {
            $customPatterns = @{ MY_TOKEN = '\d+' }
            $helper = [PSScriptBuilderBumpReplacementHelper]::new(
                (New-TokenMap @{ MY_TOKEN = '42' }),
                $customPatterns
            )

            $helper.RegexPatterns.ContainsKey('MY_TOKEN') | Should -BeTrue
            $helper.RegexPatterns.ContainsKey('VERSION_FULL') | Should -BeFalse
        }

        It 'Should fall back to DefaultRegexPatterns when null is passed for RegexPatterns' {
            $helper = [PSScriptBuilderBumpReplacementHelper]::new(
                (New-TokenMap @{ VERSION_FULL = '1.0.0' }),
                $null
            )

            $helper.RegexPatterns.ContainsKey('VERSION_FULL') | Should -BeTrue
        }

        It 'Should throw ArgumentNullException when TokenMap is null' {
            { [PSScriptBuilderBumpReplacementHelper]::new($null) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }

    Context 'ApplySimpleReplacements' {

        It 'Should replace a single placeholder' {
            $helper  = New-Helper @{ VERSION_FULL = '2.0.0' }
            $content = 'Version: {{VERSION_FULL}}'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION_FULL'))

            $result.Content | Should -Be 'Version: 2.0.0'
        }

        It 'Should replace multiple placeholders in one call' {
            $helper  = New-Helper @{ VERSION_FULL = '1.2.3'; BUILD_DATE = '2026-03-19' }
            $content = 'Version : {{VERSION_FULL}}  Built : {{BUILD_DATE}}'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION_FULL', 'BUILD_DATE'))

            $result.Content | Should -Be 'Version : 1.2.3  Built : 2026-03-19'
        }

        It 'Should leave content unchanged when placeholder is absent' {
            $helper  = New-Helper @{ VERSION_FULL = '1.0.0' }
            $content = 'No placeholder here'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION_FULL'))

            $result.Content | Should -Be 'No placeholder here'
            $result.Changes.Count | Should -Be 0
        }

        It 'Should record one change entry per replaced placeholder' {
            $helper  = New-Helper @{ VERSION_FULL = '1.2.3'; BUILD_DATE = '2026-03-19' }
            $content = '{{VERSION_FULL}} {{BUILD_DATE}}'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION_FULL', 'BUILD_DATE'))

            $result.Changes.Count | Should -Be 2
        }

        It 'Should record the correct OldValue and NewValue in each change' {
            $helper  = New-Helper @{ VERSION_FULL = '3.0.0' }
            $content = '{{VERSION_FULL}}'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION_FULL'))

            $result.Changes[0].OldValue | Should -Be '{{VERSION_FULL}}'
            $result.Changes[0].NewValue | Should -Be '3.0.0'
        }

        It 'Should throw ArgumentException when tokens array is null' {
            $helper = New-Helper
            { $helper.ApplySimpleReplacements('content', $null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when tokens array is empty' {
            $helper = New-Helper
            { $helper.ApplySimpleReplacements('content', @()) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'ApplyPatternReplacements - Pattern Mode (placeholder)' {

        It 'Should replace a placeholder pattern with token value' {
            $helper  = New-Helper @{ VERSION_FULL = '1.5.0' }
            $content = "ModuleVersion = '{{VERSION_FULL}}'"
            $pattern = "ModuleVersion = '{{VERSION_FULL}}'"

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'))

            $result.Content | Should -Be "ModuleVersion = '1.5.0'"
        }

        It 'Should leave content unchanged when placeholder pattern is absent' {
            $helper  = New-Helper @{ VERSION_FULL = '1.5.0' }
            $content = "ModuleVersion = '2.0.0-different'"
            $pattern = "ModuleVersion = '{{VERSION_FULL}}'"

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'))

            $result.Content | Should -Be $content
            $result.Changes.Count | Should -Be 0
        }

        It 'Should throw ArgumentException when pattern is empty' {
            $helper = New-Helper
            { $helper.ApplyPatternReplacements('content', '', @('VERSION_FULL')) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when tokens array is empty' {
            $helper = New-Helper
            { $helper.ApplyPatternReplacements('content', 'some {{VERSION_FULL}}', @()) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw InvalidOperationException when token has no placeholder in pattern' {
            $helper  = New-Helper @{ VERSION_FULL = '1.0.0'; BUILD_DATE = '2026-01-01' }
            $content = 'some content'
            $pattern = 'Version = {{VERSION_FULL}}'  # BUILD_DATE has no placeholder

            { $helper.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL', 'BUILD_DATE')) } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    Context 'ApplyPatternReplacements - Regex Mode (capture groups)' {

        It 'Should replace a matched capture group with token value' {
            $helper  = New-Helper @{ VERSION_FULL = '2.0.0' }
            $content = "ModuleVersion = '1.0.0'"
            $pattern = "ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'"

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'))

            $result.Content | Should -Be "ModuleVersion = '2.0.0'"
        }

        It 'Should be idempotent - running twice produces the same result' {
            $helper  = New-Helper @{ VERSION_FULL = '1.2.3' }
            $content = "Version : 0.9.0"
            $pattern = "Version\s*:\s*({REGEX_VERSION_FULL})"

            $first  = $helper.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'))
            $second = $helper.ApplyPatternReplacements($first.Content, $pattern, @('VERSION_FULL'))

            $second.Content | Should -Be $first.Content
        }

        It 'Should update all occurrences when pattern matches multiple lines' {
            $helper  = New-Helper @{ BUILD_DATE = '2026-12-31' }
            $content = "Built : 2026-01-01`nDate  : 2026-01-01"
            $pattern = "(?:Built|Date)\s*:\s*({REGEX_BUILD_DATE})"

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('BUILD_DATE'))

            $result.Content | Should -Be "Built : 2026-12-31`nDate  : 2026-12-31"
        }

        It 'Should leave content unchanged when regex pattern finds no match' {
            $helper  = New-Helper @{ VERSION_FULL = '2.0.0' }
            $content = "SomethingElse = 'value'"
            $pattern = "ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'"

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'))

            $result.Content | Should -Be $content
            $result.Changes.Count | Should -Be 0
        }

        It 'Should throw when {REGEX_TOKEN} refers to an unknown token' {
            $helper  = [PSScriptBuilderBumpReplacementHelper]::new(
                (New-TokenMap @{ UNKNOWN_TOKEN = '1.0.0' }),
                @{}  # empty patterns - no UNKNOWN_TOKEN pattern defined
            )
            $content = 'Version = 1.0.0'
            $pattern = "Version\s*=\s*({REGEX_UNKNOWN_TOKEN})"

            { $helper.ApplyPatternReplacements($content, $pattern, @('UNKNOWN_TOKEN')) } |
                Should -Throw
        }
    }

    Context 'HasContentToReplace' {

        It 'Should return true when placeholder pattern is found in content' {
            $helper  = New-Helper
            $content = "ModuleVersion = '{{VERSION_FULL}}'"
            $pattern = "ModuleVersion = '{{VERSION_FULL}}'"

            $helper.HasContentToReplace($content, $pattern, @('VERSION_FULL')) | Should -BeTrue
        }

        It 'Should return false when placeholder pattern is absent from content' {
            $helper  = New-Helper
            $content = 'No placeholder here'
            $pattern = "ModuleVersion = '{{VERSION_FULL}}'"

            $helper.HasContentToReplace($content, $pattern, @('VERSION_FULL')) | Should -BeFalse
        }

        It 'Should return true when regex pattern matches content' {
            $helper  = New-Helper @{ VERSION_FULL = '1.0.0' }
            $content = "ModuleVersion = '1.0.0'"
            $pattern = "ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'"

            $helper.HasContentToReplace($content, $pattern, @('VERSION_FULL')) | Should -BeTrue
        }

        It 'Should return false when regex pattern finds no match' {
            $helper  = New-Helper @{ VERSION_FULL = '1.0.0' }
            $content = "UnrelatedContent = 'value'"
            $pattern = "ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'"

            $helper.HasContentToReplace($content, $pattern, @('VERSION_FULL')) | Should -BeFalse
        }

        It 'Should return false when regex pattern refers to unknown token (exception-safe)' {
            $helper  = [PSScriptBuilderBumpReplacementHelper]::new(
                (New-TokenMap @{ MY_TOKEN = '1' }),
                @{}  # no patterns
            )
            $content = 'some content'
            $pattern = "prefix\s*({REGEX_MY_TOKEN})"

            # Should not throw - returns false instead
            $result = $helper.HasContentToReplace($content, $pattern, @('MY_TOKEN'))
            $result | Should -BeFalse
        }
    }

    Context 'DefaultRegexPatterns' {

        It 'Should contain a pattern for VERSION_FULL' {
            [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns.ContainsKey('VERSION_FULL') |
                Should -BeTrue
        }

        It 'Should contain a pattern for BUILD_DATE' {
            [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns.ContainsKey('BUILD_DATE') |
                Should -BeTrue
        }

        It 'VERSION_FULL pattern should match a valid SemVer string' {
            $pattern = [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns['VERSION_FULL']
            '1.2.3' -match "^$pattern$" | Should -BeTrue
        }

        It 'VERSION_FULL pattern should match a SemVer string with prerelease' {
            $pattern = [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns['VERSION_FULL']
            '1.2.3-alpha.1' -match "^$pattern$" | Should -BeTrue
        }

        It 'BUILD_DATE pattern should match an ISO 8601 date' {
            $pattern = [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns['BUILD_DATE']
            '2026-03-19' -match "^$pattern$" | Should -BeTrue
        }

        It 'BUILD_DATE pattern should not match an invalid date format' {
            $pattern = [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns['BUILD_DATE']
            '19-03-2026' -match "^$pattern$" | Should -BeFalse
        }
    }
}

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

        It 'Should preserve decorative outer braces when the token is escaped as {{{{KEY}}}} (RFC 0001 non-regression)' {
            # RFC 0001's template escape syntax is explicitly out of scope for Release Management -
            # {{{{VERSION_FULL}}}} must keep producing {{1.3.0}} (substituted value wrapped in the
            # preserved, literal outer braces), exactly as it did before RFC 0001 existed.
            $helper  = New-Helper @{ VERSION_FULL = '1.3.0' }
            $content = '{{{{VERSION_FULL}}}}'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION_FULL'))

            $result.Content | Should -Be '{{1.3.0}}'
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

        It 'Should not corrupt a token value containing another tokens placeholder text (RFC 0007), order A' {
            # A real, git-permitted branch name like "feature/{{VERSION}}" must survive intact -
            # today, processing GIT_BRANCH before VERSION corrupts it because GIT_BRANCH's own
            # inserted value gets re-scanned by the later VERSION replacement step.
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/{{VERSION}}'; VERSION = '1.3.0' }
            $content = 'Branch: {{GIT_BRANCH}}, Version: {{VERSION}}'

            $result = $helper.ApplySimpleReplacements($content, @('GIT_BRANCH', 'VERSION'))

            $result.Content | Should -Be 'Branch: feature/{{VERSION}}, Version: 1.3.0'
        }

        It 'Should not corrupt a token value containing another tokens placeholder text (RFC 0007), order B' {
            # Same setup, reversed token order - must produce the identical, correct result.
            # Today this order happens to work by accident; the point of the fix is that BOTH
            # orders must produce the same output.
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/{{VERSION}}'; VERSION = '1.3.0' }
            $content = 'Branch: {{GIT_BRANCH}}, Version: {{VERSION}}'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION', 'GIT_BRANCH'))

            $result.Content | Should -Be 'Branch: feature/{{VERSION}}, Version: 1.3.0'
        }

        It 'Should replace every occurrence of the same token in one pass (RFC 0007 non-regression)' {
            # The discover/assemble fix must preserve .Replace()'s original "replace every
            # occurrence" semantics for a single token, not just the first.
            $helper  = New-Helper @{ VERSION_FULL = '2.0.0' }
            $content = '{{VERSION_FULL}} and again {{VERSION_FULL}} and once more {{VERSION_FULL}}'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION_FULL'))

            $result.Content | Should -Be '2.0.0 and again 2.0.0 and once more 2.0.0'
            $result.Changes.Count | Should -Be 1
        }

        It 'Should replace a differently-cased placeholder (RFC 0008)' {
            $helper  = New-Helper @{ VERSION_FULL = '2.0.0' }
            $content = 'Version: {{version_full}}'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION_FULL'))

            $result.Content | Should -Be 'Version: 2.0.0'
        }

        It 'Should replace both an exact-case and a differently-cased occurrence of the same token (RFC 0008)' {
            $helper  = New-Helper @{ VERSION_FULL = '2.0.0' }
            $content = '{{VERSION_FULL}} and {{version_full}}'

            $result = $helper.ApplySimpleReplacements($content, @('VERSION_FULL'))

            $result.Content | Should -Be '2.0.0 and 2.0.0'
        }

        It 'Should not corrupt an earlier calls inserted value when a later, separate call replaces a different token (RFC 0009), order A' {
            # GIT_BRANCH's own (git-permitted) value contains VERSION's placeholder text. Two
            # SEPARATE calls, threading the ledger forward - simulates two sequential items in a
            # bumpFiles entry, exactly as PSScriptBuilderBumpFilesProcessor calls this method.
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/{{VERSION}}'; VERSION = '1.3.0' }
            $content = 'Branch: {{GIT_BRANCH}}, Version: {{VERSION}}'

            $r1 = $helper.ApplySimpleReplacements($content, @('GIT_BRANCH'), [System.Collections.Generic.List[PSCustomObject]]::new())
            $r2 = $helper.ApplySimpleReplacements($r1.Content, @('VERSION'), $r1.ProtectedSpans)

            $r2.Content | Should -Be 'Branch: feature/{{VERSION}}, Version: 1.3.0'
        }

        It 'Should not corrupt an earlier calls inserted value when a later, separate call replaces a different token (RFC 0009), order B' {
            # Same setup, reversed call order - must produce the identical, correct result.
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/{{VERSION}}'; VERSION = '1.3.0' }
            $content = 'Branch: {{GIT_BRANCH}}, Version: {{VERSION}}'

            $r1 = $helper.ApplySimpleReplacements($content, @('VERSION'), [System.Collections.Generic.List[PSCustomObject]]::new())
            $r2 = $helper.ApplySimpleReplacements($r1.Content, @('GIT_BRANCH'), $r1.ProtectedSpans)

            $r2.Content | Should -Be 'Branch: feature/{{VERSION}}, Version: 1.3.0'
        }

        It 'Should produce the same Content and Changes as the two-parameter overload for a single call' {
            $helper1 = New-Helper @{ VERSION_FULL = '1.2.3' }
            $helper2 = New-Helper @{ VERSION_FULL = '1.2.3' }
            $content = 'Version: {{VERSION_FULL}}'

            $withoutLedger = $helper1.ApplySimpleReplacements($content, @('VERSION_FULL'))
            $withLedger    = $helper2.ApplySimpleReplacements($content, @('VERSION_FULL'), [System.Collections.Generic.List[PSCustomObject]]::new())

            $withLedger.Content | Should -Be $withoutLedger.Content
            $withLedger.Changes.Count | Should -Be $withoutLedger.Changes.Count
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

        It 'Should not corrupt a token value containing another tokens placeholder text (RFC 0007)' {
            # A single pattern referencing both tokens - GIT_BRANCH's own (git-permitted) value
            # contains VERSION's placeholder text. Order must not matter.
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/{{VERSION}}'; VERSION = '1.3.0' }
            $content = 'Info: {{GIT_BRANCH}} - {{VERSION}}'
            $pattern = '{{GIT_BRANCH}} - {{VERSION}}'

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('GIT_BRANCH', 'VERSION'))

            $result.Content | Should -Be 'Info: feature/{{VERSION}} - 1.3.0'
        }

        It 'Should not corrupt an earlier calls inserted value when a later, separate call replaces a different token via Placeholder Mode (RFC 0009), order A' {
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/{{VERSION}}'; VERSION = '1.3.0' }
            $content = 'Branch: {{GIT_BRANCH}}, Version: {{VERSION}}'

            $r1 = $helper.ApplyPatternReplacements($content, '{{GIT_BRANCH}}', @('GIT_BRANCH'), [System.Collections.Generic.List[PSCustomObject]]::new())
            $r2 = $helper.ApplyPatternReplacements($r1.Content, '{{VERSION}}', @('VERSION'), $r1.ProtectedSpans)

            $r2.Content | Should -Be 'Branch: feature/{{VERSION}}, Version: 1.3.0'
        }

        It 'Should not corrupt an earlier calls inserted value when a later, separate call replaces a different token via Placeholder Mode (RFC 0009), order B' {
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/{{VERSION}}'; VERSION = '1.3.0' }
            $content = 'Branch: {{GIT_BRANCH}}, Version: {{VERSION}}'

            $r1 = $helper.ApplyPatternReplacements($content, '{{VERSION}}', @('VERSION'), [System.Collections.Generic.List[PSCustomObject]]::new())
            $r2 = $helper.ApplyPatternReplacements($r1.Content, '{{GIT_BRANCH}}', @('GIT_BRANCH'), $r1.ProtectedSpans)

            $r2.Content | Should -Be 'Branch: feature/{{VERSION}}, Version: 1.3.0'
        }

        It 'Should produce the same Content and Changes as the three-parameter overload for a single Placeholder Mode call' {
            $helper1 = New-Helper @{ VERSION_FULL = '1.2.3' }
            $helper2 = New-Helper @{ VERSION_FULL = '1.2.3' }
            $content = "ModuleVersion = '{{VERSION_FULL}}'"
            $pattern = "ModuleVersion = '{{VERSION_FULL}}'"

            $withoutLedger = $helper1.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'))
            $withLedger    = $helper2.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'), [System.Collections.Generic.List[PSCustomObject]]::new())

            $withLedger.Content | Should -Be $withoutLedger.Content
            $withLedger.Changes.Count | Should -Be $withoutLedger.Changes.Count
        }

        It 'Should not match content whose literal text differs only in casing (content-level search stays case-sensitive)' {
            # Guards a fix found while implementing RFC 0009: the content-level search for the
            # pattern's own literal text must stay Ordinal - RFC 0008's case-insensitivity applies
            # only to token NAMES inside {{TOKEN}}, not to arbitrary literal text surrounding a pattern.
            $helper  = New-Helper @{ VERSION_FULL = '1.5.0' }
            $content = "moduleversion = '{{VERSION_FULL}}'"
            $pattern = "ModuleVersion = '{{VERSION_FULL}}'"

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'), [System.Collections.Generic.List[PSCustomObject]]::new())

            $result.Content | Should -Be $content
            $result.Changes.Count | Should -Be 0
        }

        It 'Should correctly replace a Placeholder Mode pattern containing an escaped literal parenthesis (RFC 0012)' {
            $helper  = New-Helper @{ YEAR = '2026' }
            $content = 'Copyright (c) {{YEAR}}'
            $pattern = 'Copyright \(c\) {{YEAR}}'

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('YEAR'))

            $result.Content | Should -Be 'Copyright (c) 2026'
        }

        It 'Should throw a clear error when a pattern mixes {{TOKEN}} with an unescaped parenthesis (RFC 0013)' {
            # This is the same pattern shape RFC 0012's "unescaped literal parenthesis" case
            # describes - a Placeholder-mode-intended pattern always contains {{TOKEN}}, so an
            # unescaped literal parenthesis in it is unavoidably a "mixed syntax" pattern. RFC
            # 0013 catches this earlier and with a clearer error than the old, unrelated "No
            # regex pattern defined" exception this used to throw.
            $helper  = New-Helper @{ YEAR = '2026' }
            $content = 'Copyright (c) 2025'
            $pattern = 'Copyright (c) {{YEAR}}'

            { $helper.ApplyPatternReplacements($content, $pattern, @('YEAR')) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw the mixed-syntax error even when one parenthesis in the pattern is already correctly escaped (RFC 0013)' {
            # A second, unescaped parenthesis is enough to trigger the error on its own,
            # regardless of another, correctly-escaped parenthesis elsewhere in the same pattern.
            $helper  = New-Helper @{ YEAR = '2026' }
            $pattern = 'Copyright \(c\) (2026) {{YEAR}}'

            { [PSScriptBuilderBumpModeResolver]::DetermineBumpPatternMode($pattern) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should correctly replace a Placeholder Mode pattern containing escaped literal braces around foreign, non-token text (RFC 0016)' {
            # A foreign templating system's own {{...}} syntax (e.g. Helm's {{ .Chart.Name }})
            # coexisting in the same file, escaped by the author per the RFC 0012 convention.
            $helper  = New-Helper @{ GIT_BRANCH = 'main' }
            $content = 'name: {{ site.name }} says {{GIT_BRANCH}}'
            $pattern = '\{\{ site.name \}\} says {{GIT_BRANCH}}'

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('GIT_BRANCH'))

            $result.Content | Should -Be 'name: {{ site.name }} says main'
        }

        It 'Should still throw when a declared token''s only pattern occurrence is escaped (RFC 0016)' {
            # The fix must NOT silently resolve this: the system cannot tell a typo apart from a
            # deliberate "keep this literal" intent, so the existing, unchanged validation error
            # must still surface rather than being silently papered over by brace-unescaping.
            $helper  = New-Helper @{ GIT_BRANCH = 'main'; YEAR = '2026' }
            $pattern = '\{\{GIT_BRANCH\}\} Year: {{YEAR}}'

            { $helper.ApplyPatternReplacements('irrelevant', $pattern, @('GIT_BRANCH', 'YEAR')) } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should replace only the unescaped occurrence when the same token name appears both escaped (literal) and unescaped (real) in one pattern (RFC 0016)' {
            $helper  = New-Helper @{ GIT_BRANCH = 'main' }
            $content = 'Example: {{GIT_BRANCH}} literal. Real: {{GIT_BRANCH}}'
            $pattern = 'Example: \{\{GIT_BRANCH\}\} literal. Real: {{GIT_BRANCH}}'

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('GIT_BRANCH'))

            $result.Content | Should -Be 'Example: {{GIT_BRANCH}} literal. Real: main'
        }

        It 'Should have HasContentToReplace correctly detect content with escaped, foreign brace text (RFC 0016)' {
            $helper  = New-Helper @{ GIT_BRANCH = 'main' }
            $content = 'name: {{ site.name }} says {{GIT_BRANCH}}'
            $pattern = '\{\{ site.name \}\} says {{GIT_BRANCH}}'

            $helper.HasContentToReplace($content, $pattern, @('GIT_BRANCH')) | Should -BeTrue
        }

        It 'Should not corrupt an earlier calls inserted value when a later, separate call has escaped foreign brace text (RFC 0016 + RFC 0009)' {
            # GIT_BRANCH's own value deliberately resembles the foreign brace text the second
            # call's pattern targets, to confirm the second call's brace-unescape does not
            # re-match text the first call already inserted for a different token.
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/{{ site.name }}'; YEAR = '2026' }
            $content = 'Branch: {{GIT_BRANCH}}, Helm: {{ site.name }} says {{YEAR}}'

            $r1 = $helper.ApplyPatternReplacements($content, '{{GIT_BRANCH}}', @('GIT_BRANCH'), [System.Collections.Generic.List[PSCustomObject]]::new())
            $r2 = $helper.ApplyPatternReplacements($r1.Content, '\{\{ site.name \}\} says {{YEAR}}', @('YEAR'), $r1.ProtectedSpans)

            $r2.Content | Should -Be 'Branch: feature/{{ site.name }}, Helm: {{ site.name }} says 2026'
        }

        It 'Should resolve multiple, nested-looking escaped parenthesis pairs in one pattern (RFC 0012)' {
            $helper  = New-Helper @{ YEAR = '2026' }
            $content = 'Copyright ((c)) {{YEAR}} (all rights reserved)'
            $pattern = 'Copyright \(\(c\)\) {{YEAR}} \(all rights reserved\)'

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('YEAR'))

            $result.Content | Should -Be 'Copyright ((c)) 2026 (all rights reserved)'
        }

        It 'Should resolve a dangling, unmatched escaped parenthesis correctly (RFC 0012 + RFC 0013)' {
            # An opening \( with no matching \) - never valid regex syntax, but Placeholder Mode
            # does plain literal-text matching, so a lone literal "(" is unremarkable here.
            $helper  = New-Helper @{ YEAR = '2026' }
            $content = 'Copyright (c {{YEAR}}'
            $pattern = 'Copyright \(c {{YEAR}}'

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('YEAR'))

            $result.Content | Should -Be 'Copyright (c 2026'
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

        It 'Should NOT corrupt a token value containing another tokens placeholder text (RFC 0007 non-regression)' {
            # Confirms ApplyRegexReplacements/ApplyMatchesWithCaptureGroups is already safe:
            # position-based, back-to-front replacement against matches found once, upfront.
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/{{VERSION}}'; VERSION = '1.3.0' }
            $content = "Branch: (feature-old), Version: (1.0.0)"
            $pattern = "Branch: \(({REGEX_GIT_BRANCH})\), Version: \(({REGEX_VERSION})\)"

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('GIT_BRANCH', 'VERSION'))

            $result.Content | Should -Be 'Branch: (feature/{{VERSION}}), Version: (1.3.0)'
        }

        It 'Should replace a differently-cased {REGEX_TOKEN} placeholder (RFC 0008)' {
            $helper  = New-Helper @{ VERSION_FULL = '2.0.0' }
            $content = "Version: (0.0.0)"
            $pattern = "Version: \(({regex_version_full})\)"

            $result = $helper.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'))

            $result.Content | Should -Be 'Version: (2.0.0)'
        }

        It 'Should NOT corrupt a custom regex value containing $&, $0, or $$ (RFC 0008 non-regression)' {
            # Guards against a naive -replace/Regex.Replace(str, pattern, replacementString) fix,
            # which would misinterpret these as replacement-string backreferences/escapes.
            # ReplaceRegexPatterns splices RegexPatterns values into the pattern itself - this must
            # stay a literal, verbatim substitution regardless of how the case-insensitivity fix
            # (RFC 0008) is implemented.
            $customPatterns = @{ CUSTOM_TOKEN = 'a$&b$0c$$d' }
            $helper  = [PSScriptBuilderBumpReplacementHelper]::new(
                (New-TokenMap @{ CUSTOM_TOKEN = 'irrelevant' }),
                $customPatterns
            )

            $result = $helper.ReplaceRegexPatterns('Info: ({REGEX_CUSTOM_TOKEN})', @('CUSTOM_TOKEN'))

            $result | Should -Be 'Info: (a$&b$0c$$d)'
        }

        It 'Should not corrupt an earlier items inserted value via an under-anchored later pattern (RFC 0009)' {
            $helper  = New-Helper @{ GIT_BRANCH = 'feature/(1.3.0)'; VERSION_FULL = '9.9.9' }
            $content = 'Branch: (old-branch), Version: (0.0.0)'

            $r1 = $helper.ApplyPatternReplacements($content, "Branch: \(({REGEX_GIT_BRANCH})\)", @('GIT_BRANCH'), [System.Collections.Generic.List[PSCustomObject]]::new())
            $r2 = $helper.ApplyPatternReplacements($r1.Content, "\(({REGEX_VERSION_FULL})\)", @('VERSION_FULL'), $r1.ProtectedSpans)

            $r2.Content | Should -Be 'Branch: (feature/(1.3.0)), Version: (9.9.9)'
        }

        It 'Should produce the same Content and Changes as the three-parameter overload for a single Regex Mode call' {
            $helper1 = New-Helper @{ VERSION_FULL = '2.0.0' }
            $helper2 = New-Helper @{ VERSION_FULL = '2.0.0' }
            $content = "ModuleVersion = '1.0.0'"
            $pattern = "ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'"

            $withoutLedger = $helper1.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'))
            $withLedger    = $helper2.ApplyPatternReplacements($content, $pattern, @('VERSION_FULL'), [System.Collections.Generic.List[PSCustomObject]]::new())

            $withLedger.Content | Should -Be $withoutLedger.Content
            $withLedger.Changes.Count | Should -Be $withoutLedger.Changes.Count
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

        It 'Should return true for a differently-cased {REGEX_TOKEN} pattern present in content (RFC 0008)' {
            $helper  = New-Helper @{ VERSION_FULL = '1.0.0' }
            $content = "ModuleVersion = '1.0.0'"
            $pattern = "ModuleVersion\s*=\s*'({regex_version_full})'"

            $helper.HasContentToReplace($content, $pattern, @('VERSION_FULL')) | Should -BeTrue
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

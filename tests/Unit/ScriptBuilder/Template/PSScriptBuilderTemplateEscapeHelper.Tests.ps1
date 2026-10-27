Describe 'PSScriptBuilderTemplateEscapeHelper' {

    Context 'Mask - no escape sequences present (RFC 0001)' {

        It 'Should return the content unchanged' {
            $content = "{{ENUM_DEFINITIONS}}`n{{CLASS_DEFINITIONS}}`n# a normal comment, no escapes here"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.MaskedContent | Should -Be $content
        }

        It 'Should return an empty escape map' {
            $content = "{{ENUM_DEFINITIONS}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.EscapeMap.Count | Should -Be 0
        }
    }

    Context 'Mask - a single valid four-brace escape sequence (RFC 0001)' {

        It 'Should remove the four-brace sequence from the masked content' {
            $content = "{{{{ORDERED_COMPONENTS}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.MaskedContent | Should -Not -Match '\{\{\{\{'
        }

        It 'Should not leave the two-brace token visible to a placeholder-matching consumer' {
            $content = "{{{{ORDERED_COMPONENTS}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.MaskedContent | Should -Not -Match ([regex]::Escape('{{ORDERED_COMPONENTS}}'))
        }

        It 'Should map the sentinel to the original, already-un-escaped two-brace text' {
            $content = "{{{{ORDERED_COMPONENTS}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.EscapeMap.Count  | Should -Be 1
            $result.EscapeMap.Values | Should -Contain '{{ORDERED_COMPONENTS}}'
        }
    }

    Context 'Mask - malformed brace counts must be rejected, not partially matched (RFC 0001)' {

        It 'Should not match an empty escape {{{{}}}}' {
            $content = "{{{{}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.MaskedContent   | Should -Be $content
            $result.EscapeMap.Count | Should -Be 0
        }

        It 'Should not match five consecutive braces on each side' {
            $content = "{{{{{KEY}}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.MaskedContent   | Should -Be $content
            $result.EscapeMap.Count | Should -Be 0
        }

        It 'Should not match six consecutive braces on each side' {
            $content = "{{{{{{KEY}}}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.MaskedContent   | Should -Be $content
            $result.EscapeMap.Count | Should -Be 0
        }

        It 'Should not match eight consecutive braces on each side' {
            $content = "{{{{{{{{KEY}}}}}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.MaskedContent   | Should -Be $content
            $result.EscapeMap.Count | Should -Be 0
        }

        It 'Should not match an asymmetric five-open/four-close sequence' {
            $content = "{{{{{KEY}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.MaskedContent   | Should -Be $content
            $result.EscapeMap.Count | Should -Be 0
        }
    }

    Context 'Mask - multiple escape sequences (RFC 0001)' {

        It 'Should mask two adjacent escapes with distinct sentinels' {
            $content = "{{{{FIRST}}}}{{{{SECOND}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.EscapeMap.Count | Should -Be 2
        }

        It 'Should mask two different escapes elsewhere in the same template with distinct sentinels' {
            $content = "{{{{ORDERED_COMPONENTS}}}} and also {{{{USING_STATEMENTS}}}} and {{REAL_ONE}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.EscapeMap.Count | Should -Be 2
            $result.MaskedContent   | Should -Match ([regex]::Escape('{{REAL_ONE}}'))
        }

        It 'Should mask the same key escaped twice with distinct sentinels, without cross-contamination' {
            $content = "{{{{DUP}}}} text between {{{{DUP}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.EscapeMap.Count | Should -Be 2
        }
    }

    Context 'Mask - an escape embedded in surrounding prose text (RFC 0001)' {

        It 'Should mask the embedded escape without touching a nearby real placeholder' {
            $content = "Use {{{{VERSION}}}} as literal text, not {{REAL_PLACEHOLDER}}."

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.MaskedContent | Should -Match ([regex]::Escape('{{REAL_PLACEHOLDER}}'))
            $result.MaskedContent | Should -Not -Match '\{\{\{\{'
        }
    }

    Context 'Mask - no plausibility check on escaped content (RFC 0001, deliberate)' {

        It 'Should mask arbitrary, non-identifier-shaped text between four braces without validation' {
            $content = "{{{{this is not an identifier at all!!! 123}}}}"

            $result = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $result.EscapeMap.Count | Should -Be 1
        }

        It 'Should restore arbitrary escaped text exactly, unchanged, as literal two-brace text' {
            $content    = "{{{{this is not an identifier at all!!! 123}}}}"
            $maskResult = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $unmasked = [PSScriptBuilderTemplateEscapeHelper]::Unmask($maskResult.MaskedContent, $maskResult.EscapeMap)

            $unmasked | Should -Be '{{this is not an identifier at all!!! 123}}'
        }
    }

    Context 'Unmask (RFC 0001)' {

        It 'Should restore a masked sequence as literal, un-escaped two-brace text' {
            $content    = "before {{{{ORDERED_COMPONENTS}}}} after"
            $maskResult = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $unmasked = [PSScriptBuilderTemplateEscapeHelper]::Unmask($maskResult.MaskedContent, $maskResult.EscapeMap)

            $unmasked | Should -Be 'before {{ORDERED_COMPONENTS}} after'
        }

        It 'Should restore multiple distinct escapes independently' {
            $content    = "{{{{ORDERED_COMPONENTS}}}} and also {{{{USING_STATEMENTS}}}} and {{REAL_ONE}}"
            $maskResult = [PSScriptBuilderTemplateEscapeHelper]::Mask($content)

            $unmasked = [PSScriptBuilderTemplateEscapeHelper]::Unmask($maskResult.MaskedContent, $maskResult.EscapeMap)

            $unmasked | Should -Be '{{ORDERED_COMPONENTS}} and also {{USING_STATEMENTS}} and {{REAL_ONE}}'
        }

        It 'Should return the content unchanged when the escape map is empty' {
            $content = "{{REAL_ONE}} only, no escapes"

            $unmasked = [PSScriptBuilderTemplateEscapeHelper]::Unmask($content, @{})

            $unmasked | Should -Be $content
        }
    }
}

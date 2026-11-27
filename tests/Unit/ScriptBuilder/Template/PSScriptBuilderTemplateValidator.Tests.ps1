using namespace System

Describe 'PSScriptBuilderTemplateValidator' {

    BeforeAll {
        Function New-ClassCollector {
            param([string] $Key = 'CLASS_DEFINITIONS')
            return [PSScriptBuilderClassCollector]::new($Key)
        }

        Function New-EnumCollector {
            param([string] $Key = 'ENUM_DEFINITIONS')
            return [PSScriptBuilderEnumCollector]::new($Key)
        }

        Function New-FunctionCollector {
            param([string] $Key = 'FUNCTION_DEFINITIONS')
            return [PSScriptBuilderFunctionCollector]::new($Key)
        }

        Function New-UsingCollector {
            param([string] $Key = 'USING_STATEMENTS')
            return [PSScriptBuilderUsingCollector]::new($Key)
        }

        Function New-FileCollector {
            param([string] $Key = 'FileContent')
            return [PSScriptBuilderFileCollector]::new($Key)
        }
    }

    Context 'Validate - parameter guards' {

        It 'Should throw when templateContent is empty' {
            $collectors = @(New-ClassCollector)

            { [PSScriptBuilderTemplateValidator]::Validate('', 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw when orderedComponentsKey is empty' {
            $collectors = @(New-ClassCollector)

            { [PSScriptBuilderTemplateValidator]::Validate('{{CLASS_DEFINITIONS}}', '', $false, $collectors) } | Should -Throw
        }

        It 'Should throw when collectors is null' {
            { [PSScriptBuilderTemplateValidator]::Validate('{{CLASS_DEFINITIONS}}', 'ORDERED_COMPONENTS', $false, $null) } | Should -Throw
        }
    }

    Context 'Validate - Ordered mode' {

        It 'Should throw when ORDERED_COMPONENTS placeholder is missing' {
            $collectors = @(New-ClassCollector)
            $template   = '# no placeholder here'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw
        }

        It 'Should throw when a Class collector placeholder is present (forbidden when {{ORDERED_COMPONENTS}} is used)' {
            $collectors = @(New-ClassCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{CLASS_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw
        }

        It 'Should throw when an Enum collector placeholder is present (forbidden when {{ORDERED_COMPONENTS}} is used)' {
            $collectors = @(New-EnumCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{ENUM_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw
        }

        It 'Should throw when a Function collector placeholder is present (forbidden when {{ORDERED_COMPONENTS}} is used)' {
            $collectors = @(New-FunctionCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{FUNCTION_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw
        }

        It 'Should NOT throw for a valid Ordered mode template with only ORDERED_COMPONENTS' {
            $template = "{{ORDERED_COMPONENTS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, @()) } | Should -Not -Throw
        }

        It 'Should NOT throw when Using placeholder appears before ORDERED_COMPONENTS' {
            $collectors = @(New-UsingCollector)
            $template   = "{{USING_STATEMENTS}}`n{{ORDERED_COMPONENTS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Not -Throw
        }

        It 'Should throw when Using placeholder appears after ORDERED_COMPONENTS' {
            $collectors = @(New-UsingCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{USING_STATEMENTS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should NOT throw when only one of several registered Using collectors has its placeholder in the template' {
            $collectors = @(New-UsingCollector -Key 'CoreUsing'; New-UsingCollector -Key 'IntegrationsUsing')
            $template   = "{{CoreUsing}}`n{{ORDERED_COMPONENTS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Not -Throw
        }

        It 'Should throw when more than one Using collector placeholder is present' {
            # Ordered/Hybrid Mode consolidates all registered Using collectors into a single
            # block, assigned to only the first placeholder found; a second Using placeholder
            # would otherwise be left unreplaced, literal text in the build output.
            $collectors = @(New-UsingCollector -Key 'CoreUsing'; New-UsingCollector -Key 'IntegrationsUsing')
            $template   = "{{CoreUsing}}`n{{IntegrationsUsing}}`n{{ORDERED_COMPONENTS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should NOT throw when File placeholder is present alongside ORDERED_COMPONENTS' {
            $collectors = @(New-FileCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{FileContent}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Not -Throw
        }

        It 'Should throw for a placeholder with whitespace in Ordered mode' {
            $template = '{{ ORDERED_COMPONENTS }}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, @()) } | Should -Throw
        }

        It 'Should throw for an unknown placeholder alongside ORDERED_COMPONENTS' {
            $template = "{{ORDERED_COMPONENTS}}`n{{UNKNOWN_TOKEN}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, @()) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should work with a custom ordered components key in Ordered mode' {
            $collectors = @(New-ClassCollector)
            $template   = '{{MY_COMPONENTS}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'MY_COMPONENTS', $true, $collectors) } | Should -Not -Throw
        }
    }

    Context 'Validate - Hybrid mode ($useOrderedMode = $true, HasCrossDependencies = $false)' {

        It 'Should NOT throw for {{ORDERED_COMPONENTS}} only, no collectors' {
            $template = '{{ORDERED_COMPONENTS}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, @()) } | Should -Not -Throw
        }

        It 'Should NOT throw when Using appears before ORDERED_COMPONENTS' {
            $collectors = @(New-UsingCollector)
            $template   = "{{USING_STATEMENTS}}`n{{ORDERED_COMPONENTS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Not -Throw
        }

        It 'Should throw when Using appears after ORDERED_COMPONENTS' {
            $collectors = @(New-UsingCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{USING_STATEMENTS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should NOT throw when File placeholder is present alongside ORDERED_COMPONENTS' {
            $collectors = @(New-FileCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{FileContent}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Not -Throw
        }

        It 'Should NOT throw when Class registered but no {{CLASS_DEFINITIONS}} in Hybrid template' {
            $collectors = @(New-ClassCollector)
            $template   = '{{ORDERED_COMPONENTS}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Not -Throw
        }

        It 'Should throw when {{CLASS_DEFINITIONS}} also present (forbidden when {{ORDERED_COMPONENTS}} is used)' {
            $collectors = @(New-ClassCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{CLASS_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw when {{ENUM_DEFINITIONS}} also present (forbidden when {{ORDERED_COMPONENTS}} is used)' {
            $collectors = @(New-EnumCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{ENUM_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw when {{FUNCTION_DEFINITIONS}} also present (forbidden when {{ORDERED_COMPONENTS}} is used)' {
            $collectors = @(New-FunctionCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{FUNCTION_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw when Using is registered but no Using placeholder is present in Hybrid template' {
            $collectors = @(New-UsingCollector)
            $template   = '{{ORDERED_COMPONENTS}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw
        }

        It 'Should work with a custom ordered components key in Hybrid mode' {
            $collectors = @(New-ClassCollector)
            $template   = '{{MY_COMPONENTS}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'MY_COMPONENTS', $true, $collectors) } | Should -Not -Throw
        }
    }

    Context 'Validate - Free mode' {

        It 'Should NOT throw for a valid Free mode template with all collector placeholders' {
            $collectors = @(New-EnumCollector; New-ClassCollector; New-FunctionCollector)
            $template   = "{{ENUM_DEFINITIONS}}`n{{CLASS_DEFINITIONS}}`n{{FUNCTION_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Not -Throw
        }

        It 'Should throw when a collector placeholder is missing from the template' {
            $collectors = @(New-ClassCollector; New-FunctionCollector)
            $template   = "{{CLASS_DEFINITIONS}}"  # FUNCTION_DEFINITIONS missing

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw when Using placeholder is not first' {
            $collectors = @(New-UsingCollector; New-ClassCollector)
            $template   = "{{CLASS_DEFINITIONS}}`n{{USING_STATEMENTS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw when Enum placeholder appears after Class placeholder' {
            $collectors = @(New-EnumCollector; New-ClassCollector)
            $template   = "{{CLASS_DEFINITIONS}}`n{{ENUM_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw for a duplicate placeholder' {
            $collectors = @(New-ClassCollector)
            $template   = "{{CLASS_DEFINITIONS}}`n{{CLASS_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw for a duplicate placeholder that differs only in case (RFC 0004)' {
            # Placeholder matching is documented as case-insensitive (docs/guides/templates.md),
            # so {{CLASS_DEFINITIONS}} and {{class_definitions}} are the same placeholder twice.
            $collectors = @(New-ClassCollector)
            $template   = "{{CLASS_DEFINITIONS}}`n{{class_definitions}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw for a single Using collectors placeholder appearing twice, differing only in case (RFC 0004)' {
            # ValidateNoDuplicatePlaceholders previously exempted Using collectors entirely -
            # this test confirms removing that exemption catches the duplicate.
            $collectors = @(New-UsingCollector)
            $template   = "{{USING_STATEMENTS}}`n{{using_statements}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw for multiple Using collectors each with their own placeholder' {
            # Using collectors are always consolidated into a single block, in every mode - a
            # second Using placeholder is rejected the same way Ordered/Hybrid Mode already did.
            $collectors = @(New-UsingCollector -Key 'CoreUsing'; New-UsingCollector -Key 'IntegrationsUsing')
            $template   = "{{CoreUsing}}`n{{IntegrationsUsing}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw for two distinct Using collectors each appearing once' {
            $collectors = @(New-UsingCollector -Key 'USING_STATEMENTS'; New-UsingCollector -Key 'EXTERNAL_USINGS')
            $template   = "{{USING_STATEMENTS}}`n{{EXTERNAL_USINGS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw when a Free Mode collector CollectionKey collides with a Release Management token (RFC 0006)' {
            $collectors = @(New-ClassCollector -Key 'VERSION')
            $template   = '{{VERSION}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw when the colliding CollectionKey differs only in case (RFC 0006)' {
            $collectors = @(New-ClassCollector -Key 'version')
            $template   = '{{version}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw when -OrderedComponentsKey itself collides with a Release Management token (RFC 0006 Repro 2)' {
            $collectors = @(New-ClassCollector)
            $template   = '{{CLASS_DEFINITIONS}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'VERSION', $false, $collectors) } | Should -Throw
        }

        It 'Should throw when the colliding -OrderedComponentsKey differs only in case (RFC 0006 Repro 2)' {
            $collectors = @(New-ClassCollector)
            $template   = '{{CLASS_DEFINITIONS}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'version', $false, $collectors) } | Should -Throw
        }

        It 'Should NOT throw for a collector CollectionKey that is not a Release Management token (RFC 0006)' {
            $collectors = @(New-ClassCollector -Key 'MY_CUSTOM_TOKEN')
            $template   = '{{MY_CUSTOM_TOKEN}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Not -Throw
        }

        It 'Should throw when a File collector CollectionKey collides with a Release Management token in Ordered Mode (RFC 0006)' {
            $collectors = @(New-FileCollector -Key 'GIT_BRANCH')
            $template   = '{{ORDERED_COMPONENTS}}'

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors) } | Should -Throw
        }

        It 'Should throw for a placeholder with whitespace' {
            $collectors = @()
            $template   = "{{ CLASS_DEFINITIONS }}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should throw when an unknown placeholder is present' {
            $collectors = @(New-ClassCollector)
            $template   = "{{CLASS_DEFINITIONS}}`n{{UnknownToken}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Throw
        }

        It 'Should NOT throw with Using first then Enum then Class' {
            $collectors = @(New-UsingCollector; New-EnumCollector; New-ClassCollector)
            $template   = "{{USING_STATEMENTS}}`n{{ENUM_DEFINITIONS}}`n{{CLASS_DEFINITIONS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Not -Throw
        }

        It 'Should NOT throw when {{ORDERED_COMPONENTS}} appears in Free mode template (always a known placeholder)' {
            $collectors = @(New-ClassCollector)
            $template   = "{{CLASS_DEFINITIONS}}`n{{ORDERED_COMPONENTS}}"

            { [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors) } | Should -Not -Throw
        }

        It 'Should return $true from IsValid() for a valid Free mode template' {
            $collectors = @(New-ClassCollector)
            $template   = '{{CLASS_DEFINITIONS}}'

            $result = [PSScriptBuilderTemplateValidator]::IsValid($template, 'ORDERED_COMPONENTS', $false, $collectors)

            $result | Should -BeTrue
        }

        It 'Should return $false from IsValid() for an invalid Free mode template' {
            $collectors = @(New-ClassCollector)
            $template   = '# no placeholder'

            $result = [PSScriptBuilderTemplateValidator]::IsValid($template, 'ORDERED_COMPONENTS', $false, $collectors)

            $result | Should -BeFalse
        }
    }

    Context 'ValidateNoForbiddenPlaceholders - error message' {

        It 'Should include the actual configured ordered placeholder token in the error message' {
            $collectors = @(New-ClassCollector)
            $template   = "{{MY_COMPONENTS}}`n{{CLASS_DEFINITIONS}}"

            $threw = $false
            try {
                [PSScriptBuilderTemplateValidator]::Validate($template, 'MY_COMPONENTS', $true, $collectors)
            }
            catch [InvalidOperationException] {
                $threw = $true
                $_.Exception.Message | Should -Match '\{\{MY_COMPONENTS\}\}'
            }

            $threw | Should -BeTrue
        }

        It 'Should include the escape-syntax hint (RFC 0001)' {
            $collectors = @(New-ClassCollector)
            $template   = "{{ORDERED_COMPONENTS}}`n{{CLASS_DEFINITIONS}}"

            $threw = $false
            try {
                [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors)
            }
            catch [InvalidOperationException] {
                $threw = $true
                $_.Exception.Message | Should -Match ([regex]::Escape('escape it as {{{{KEY}}}}'))
            }

            $threw | Should -BeTrue
        }
    }

    Context 'ValidateNoUnknownPlaceholders - error message' {

        It 'Should include the escape-syntax hint (RFC 0001)' {
            $collectors = @(New-ClassCollector)
            $template   = "{{CLASS_DEFINITIONS}}`n{{TYPO_KEY}}"

            $threw = $false
            try {
                [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors)
            }
            catch [InvalidOperationException] {
                $threw = $true
                $_.Exception.Message | Should -Match ([regex]::Escape('escape it as {{{{KEY}}}}'))
            }

            $threw | Should -BeTrue
        }
    }

    Context 'ValidateUsingPlaceholderCount - error message' {

        It 'Should name the winning placeholder and every ignored placeholder in the error message' {
            $collectors = @(New-UsingCollector -Key 'CoreUsing'; New-UsingCollector -Key 'IntegrationsUsing'; New-UsingCollector -Key 'CliUsing')
            $template   = "{{CoreUsing}}`n{{IntegrationsUsing}}`n{{CliUsing}}`n{{ORDERED_COMPONENTS}}"

            $threw = $false
            try {
                [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $true, $collectors)
            }
            catch [InvalidOperationException] {
                $threw = $true
                $_.Exception.Message | Should -Match ([regex]::Escape('{{CoreUsing}}'))
                $_.Exception.Message | Should -Match ([regex]::Escape('{{IntegrationsUsing}}'))
                $_.Exception.Message | Should -Match ([regex]::Escape('{{CliUsing}}'))
            }

            $threw | Should -BeTrue
        }

        It 'Should name the registered collector count when no Using placeholder is present, in either mode' {
            $collectors = @(New-UsingCollector -Key 'CoreUsing'; New-ClassCollector)
            $template   = '{{CLASS_DEFINITIONS}}'

            $threw = $false
            try {
                [PSScriptBuilderTemplateValidator]::Validate($template, 'ORDERED_COMPONENTS', $false, $collectors)
            }
            catch [InvalidOperationException] {
                $threw = $true
                $_.Exception.Message | Should -Match ([regex]::Escape('1 Using collector(s) registered'))
            }

            $threw | Should -BeTrue
        }
    }
}

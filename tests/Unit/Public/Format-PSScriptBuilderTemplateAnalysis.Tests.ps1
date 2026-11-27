Describe 'Format-PSScriptBuilderTemplateAnalysis' {

    BeforeAll {
        Function New-AnalysisResult {
            param(
                [bool]     $IsValid              = $true,
                [string[]] $ValidationErrors      = @(),
                [string]   $TemplatePath          = 'C:\proj\build\MyProject.ps1.template',
                [int]      $TemplateSize          = 512,
                [PSScriptBuilderTemplateValidationMode] $ValidationMode = [PSScriptBuilderTemplateValidationMode]::Free,
                [string]   $OrderedComponentsKey  = 'ORDERED_COMPONENTS',
                [bool]     $HasCrossDependencies  = $false,
                [string[]] $PlaceholdersFound     = @('USING', 'CLASS', 'FUNCTION'),
                [string[]] $PlaceholdersExpected  = @('USING', 'CLASS', 'FUNCTION'),
                [string[]] $MissingPlaceholders   = @(),
                [string[]] $UnknownPlaceholders   = @()
            )
            return [PSScriptBuilderTemplateAnalysisResult]::new(
                $IsValid, $ValidationErrors, $TemplatePath, $TemplateSize, $ValidationMode,
                $OrderedComponentsKey, $HasCrossDependencies, $PlaceholdersFound, $PlaceholdersExpected,
                $MissingPlaceholders, $UnknownPlaceholders)
        }

        <#
        Captures Write-Host output as text via the Information stream (6), which is where
        Write-Host writes since PowerShell 5 - a plain variable assignment does not capture it.
        #>
        Function ConvertTo-TextLines {
            param([Parameter(ValueFromPipeline)] $InputObject)
            process { $InputObject.ToString() }
        }
    }

    Context 'Compact output' {

        It 'Should include the template path, size, mode, cross-dependency status, and validation status' {
            $result = New-AnalysisResult -TemplatePath 'C:\proj\build\Foo.ps1.template' -TemplateSize 123
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match ([regex]::Escape('C:\proj\build\Foo.ps1.template'))
            ($output -join "`n") | Should -Match '123 characters'
            ($output -join "`n") | Should -Match 'Mode\s*: Free'
            ($output -join "`n") | Should -Match 'Cross-Deps\s*: None'
            ($output -join "`n") | Should -Match 'Status\s*: Valid'
        }

        It 'Should show "Detected" for Cross-Deps when HasCrossDependencies is true' {
            $result = New-AnalysisResult -HasCrossDependencies $true -ValidationMode ([PSScriptBuilderTemplateValidationMode]::Ordered)
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'Cross-Deps\s*: Detected'
        }

        It 'Should show "Invalid" for Status when IsValid is false' {
            $result = New-AnalysisResult -IsValid $false -ValidationErrors @('some error')
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'Status\s*: Invalid'
        }
    }

    Context 'Key line visibility' {

        It 'Should not display the Key line in Free mode' {
            $result = New-AnalysisResult -ValidationMode ([PSScriptBuilderTemplateValidationMode]::Free)
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Not -Match 'Key\s*:'
        }

        It 'Should display the Key line with the ordered components key in Hybrid mode' {
            $result = New-AnalysisResult -ValidationMode ([PSScriptBuilderTemplateValidationMode]::Hybrid) -OrderedComponentsKey 'ORDERED_COMPONENTS'
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'Key\s*: ORDERED_COMPONENTS'
        }

        It 'Should display the Key line with the ordered components key in Ordered mode' {
            $result = New-AnalysisResult -ValidationMode ([PSScriptBuilderTemplateValidationMode]::Ordered) -OrderedComponentsKey 'CUSTOM_KEY'
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'Key\s*: CUSTOM_KEY'
        }
    }

    Context 'Validation Errors section' {

        It 'Should list each validation error when the template is invalid' {
            $result = New-AnalysisResult -IsValid $false -ValidationErrors @('Missing required placeholder {{ORDERED_COMPONENTS}}', 'Forbidden placeholder {{CLASS}}')
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'Validation Errors'
            ($output -join "`n") | Should -Match ([regex]::Escape('Missing required placeholder {{ORDERED_COMPONENTS}}'))
            ($output -join "`n") | Should -Match ([regex]::Escape('Forbidden placeholder {{CLASS}}'))
        }

        It 'Should not display the section when the template is valid' {
            $result = New-AnalysisResult -IsValid $true
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Not -Match 'Validation Errors'
        }

        It 'Should not display the section when IsValid is true even if ValidationErrors is stale and non-empty' {
            <#
            Defensive regression: the cmdlet only shows this section when both IsValid is false
            AND ValidationErrors is non-empty - a caller that forgets to clear ValidationErrors
            on a since-fixed result must not resurrect a stale error message.
            #>
            $result = New-AnalysisResult -IsValid $true -ValidationErrors @('stale error not cleared')
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Not -Match 'Validation Errors'
        }
    }

    Context 'Placeholders section' {

        It 'Should display expected and found placeholders as comma-separated lists' {
            $result = New-AnalysisResult -PlaceholdersExpected @('USING', 'CLASS') -PlaceholdersFound @('USING', 'CLASS', 'FUNCTION')
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'Expected\s*: USING, CLASS'
            ($output -join "`n") | Should -Match 'Found\s*: USING, CLASS, FUNCTION'
        }

        It 'Should display "<none>" when no placeholders are expected or found' {
            $result = New-AnalysisResult -PlaceholdersExpected @() -PlaceholdersFound @()
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'Expected\s*: <none>'
            ($output -join "`n") | Should -Match 'Found\s*: <none>'
        }
    }

    Context 'Missing Placeholders section' {

        It 'Should list each missing placeholder when present' {
            $result = New-AnalysisResult -MissingPlaceholders @('ORDERED_COMPONENTS', 'USING')
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'Missing Placeholders'
            ($output -join "`n") | Should -Match 'ORDERED_COMPONENTS'
            ($output -join "`n") | Should -Match 'USING'
        }

        It 'Should not display the section when there are no missing placeholders' {
            $result = New-AnalysisResult -MissingPlaceholders @()
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Not -Match 'Missing Placeholders'
        }
    }

    Context 'Unknown Placeholders section' {

        It 'Should list each unknown placeholder when present' {
            $result = New-AnalysisResult -UnknownPlaceholders @('FOO', 'BAR')
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match 'Unknown Placeholders'
            ($output -join "`n") | Should -Match 'FOO'
            ($output -join "`n") | Should -Match 'BAR'
        }

        It 'Should not display the section when there are no unknown placeholders' {
            $result = New-AnalysisResult -UnknownPlaceholders @()
            $output = $result | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Not -Match 'Unknown Placeholders'
        }
    }

    Context 'Multiple results piped in together' {

        It 'Should render one full report per result' {
            $results = @(
                (New-AnalysisResult -TemplatePath 'C:\proj\A.ps1.template'),
                (New-AnalysisResult -TemplatePath 'C:\proj\B.ps1.template')
            )

            $output = $results | Format-PSScriptBuilderTemplateAnalysis 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match ([regex]::Escape('C:\proj\A.ps1.template'))
            ($output -join "`n") | Should -Match ([regex]::Escape('C:\proj\B.ps1.template'))
        }
    }
}

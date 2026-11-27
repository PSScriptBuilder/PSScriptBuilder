Describe 'Format-PSScriptBuilderBumpResult' {

    BeforeAll {
        <#
        Captures Write-Host output as text via the Information stream (6), which is where
        Write-Host writes since PowerShell 5 - a plain variable assignment does not capture it.
        #>
        Function ConvertTo-TextLines {
            param([Parameter(ValueFromPipeline)] $InputObject)
            process { $InputObject.ToString() }
        }

        Function New-BumpResult {
            param([hashtable[]] $ChangedItems)
            $detail = [PSCustomObject] @{
                Path         = 'C:\src\Foo.ps1'
                ChangedItems = @($ChangedItems | ForEach-Object { [PSCustomObject] $_ })
            }
            return [PSScriptBuilderBumpFilesResult]::new(1, 1, @($detail))
        }
    }

    Context 'Pattern line conditional display (parked item from RFC 0012, closed later)' {

        It 'Should hide the Pattern line when it equals Old Value (Simple/Placeholder Mode)' {
            $bumpResult = New-BumpResult -ChangedItems @(
                @{ Pattern = '{{VERSION_FULL}}'; Token = 'VERSION_FULL'; OldValue = '{{VERSION_FULL}}'; NewValue = '1.2.3' }
            )

            $output = $bumpResult | Format-PSScriptBuilderBumpResult 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Not -Match 'Pattern'
            ($output -join "`n") | Should -Match ([regex]::Escape('Old Value : {{VERSION_FULL}}'))
        }

        It 'Should show the Pattern line when it differs from Old Value (Regex Mode)' {
            $bumpResult = New-BumpResult -ChangedItems @(
                @{ Pattern = "ModuleVersion = '({REGEX_VERSION_FULL})'"; Token = 'VERSION_FULL'; OldValue = '1.0.0'; NewValue = '1.2.3' }
            )

            $output = $bumpResult | Format-PSScriptBuilderBumpResult 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Match ([regex]::Escape("Pattern   : ModuleVersion = '({REGEX_VERSION_FULL})'"))
        }

        It 'Should evaluate the Pattern-line condition per item, not once for the whole file (mixed Simple/Placeholder/Regex changes)' {
            $bumpResult = New-BumpResult -ChangedItems @(
                @{ Pattern = '{{VERSION_FULL}}'; Token = 'VERSION_FULL'; OldValue = '{{VERSION_FULL}}'; NewValue = '1.2.3' }
                @{ Pattern = 'Copyright (c) {{YEAR}}'; Token = 'YEAR'; OldValue = 'Copyright (c) {{YEAR}}'; NewValue = 'Copyright (c) 2026' }
                @{ Pattern = "ModuleVersion = '({REGEX_VERSION_FULL})'"; Token = 'VERSION_FULL'; OldValue = '1.0.0'; NewValue = '1.2.3' }
            )

            $output = $bumpResult | Format-PSScriptBuilderBumpResult 6>&1 | ConvertTo-TextLines
            $joined = $output -join "`n"

            ([regex]::Matches($joined, 'Pattern   :')).Count | Should -Be 1
            $joined | Should -Match ([regex]::Escape("Pattern   : ModuleVersion = '({REGEX_VERSION_FULL})'"))
        }

        It 'Should hide the Pattern line even for a Regex Mode change whose Pattern text coincidentally equals Old Value (documented, accepted behavior)' {
            # The condition compares text only, not which mode produced the change. If a Regex
            # Mode match's raw {REGEX_TOKEN} template text happens to literally equal the matched
            # content (only possible if real file content contains that literal, unresolved text),
            # the Pattern line is hidden too. Accepted consequence of the simple equality check,
            # not a bug - locked in here so it is not "fixed" by accident later.
            $bumpResult = New-BumpResult -ChangedItems @(
                @{ Pattern = '{REGEX_TOKEN}'; Token = 'TOKEN'; OldValue = '{REGEX_TOKEN}'; NewValue = 'X' }
            )

            $output = $bumpResult | Format-PSScriptBuilderBumpResult 6>&1 | ConvertTo-TextLines

            ($output -join "`n") | Should -Not -Match 'Pattern'
        }
    }
}

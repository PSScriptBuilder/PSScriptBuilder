Describe 'PSScriptBuilderWatchScriptRequest' {

    Context 'Constructor - property mapping' {

        It 'Should set ContentCollector from the provided value' {
            $request = [PSScriptBuilderWatchScriptRequest]::new($null, 'C:\template.ps1', 500, @('.ps1'), { })

            $request.ContentCollector | Should -BeNullOrEmpty
        }

        It 'Should set TemplatePath from the provided value' {
            $request = [PSScriptBuilderWatchScriptRequest]::new($null, 'C:\template.ps1', 500, @('.ps1'), { })

            $request.TemplatePath | Should -Be 'C:\template.ps1'
        }

        It 'Should set Debounce from the provided value' {
            $request = [PSScriptBuilderWatchScriptRequest]::new($null, 'C:\template.ps1', 750, @('.ps1'), { })

            $request.Debounce | Should -Be 750
        }

        It 'Should set IncludeExtensions from the provided array' {
            $extensions = @('.ps1', '.psm1')
            $request    = [PSScriptBuilderWatchScriptRequest]::new($null, 'C:\template.ps1', 500, $extensions, { })

            $request.IncludeExtensions | Should -Be $extensions
        }

        It 'Should set IncludeExtensions to an empty array when none provided' {
            $request = [PSScriptBuilderWatchScriptRequest]::new($null, 'C:\template.ps1', 500, @(), { })

            $request.IncludeExtensions.Count | Should -Be 0
        }

        It 'Should set ScriptBlock from the provided value' {
            $scriptBlock = { Write-Host 'changed' }
            $request     = [PSScriptBuilderWatchScriptRequest]::new($null, 'C:\template.ps1', 500, @('.ps1'), $scriptBlock)

            $request.ScriptBlock | Should -Be $scriptBlock
        }
    }

    Context 'Constructor - validation' {

        It 'Should throw ArgumentNullException when scriptBlock is null' {
            { [PSScriptBuilderWatchScriptRequest]::new($null, 'C:\template.ps1', 500, @('.ps1'), $null) } |
                Should -Throw -ExceptionType ([ArgumentNullException])
        }
    }
}

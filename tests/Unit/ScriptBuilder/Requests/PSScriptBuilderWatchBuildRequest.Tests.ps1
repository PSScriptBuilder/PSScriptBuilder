Describe 'PSScriptBuilderWatchBuildRequest' {

    Context 'Constructor - property mapping' {

        It 'Should set ContentCollector from the provided value' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.ContentCollector | Should -BeNullOrEmpty
        }

        It 'Should set TemplatePath from the provided value' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.TemplatePath | Should -Be 'C:\template.ps1'
        }

        It 'Should set OutputPath from the provided value' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.OutputPath | Should -Be 'C:\output.ps1'
        }

        It 'Should set Debounce from the provided value' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 750, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.Debounce | Should -Be 750
        }

        It 'Should set IncludeExtensions from the provided array' {
            $extensions = @('.ps1', '.psm1')
            $request    = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, $extensions, 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.IncludeExtensions | Should -Be $extensions
        }

        It 'Should set IncludeExtensions to an empty array when none provided' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @(), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.IncludeExtensions.Count | Should -Be 0
        }

        It 'Should set BackupPath from the provided value' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.BackupPath | Should -Be 'C:\backup'
        }

        It 'Should set OrderedComponentsKey from the provided value' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'MY_COMPONENTS', $false, $false, $null, $null)

            $request.OrderedComponentsKey | Should -Be 'MY_COMPONENTS'
        }

        It 'Should set EnableBackup to false when provided as false' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.EnableBackup | Should -BeFalse
        }

        It 'Should set EnableBackup to true when provided as true' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $true, $false, $null, $null)

            $request.EnableBackup | Should -BeTrue
        }

        It 'Should set SkipSyntaxValidation to false when provided as false' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.SkipSyntaxValidation | Should -BeFalse
        }

        It 'Should set SkipSyntaxValidation to true when provided as true' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $true, $null, $null)

            $request.SkipSyntaxValidation | Should -BeTrue
        }

        It 'Should set OnSuccess from the provided value' {
            $onSuccess = { Write-Host 'done' }
            $request   = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $onSuccess, $null)

            $request.OnSuccess | Should -Be $onSuccess
        }

        It 'Should set OnSuccess to null when not provided' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.OnSuccess | Should -BeNullOrEmpty
        }

        It 'Should set OnError from the provided value' {
            $onError = { param($result) Write-Host $result.Exception.Message }
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $onError)

            $request.OnError | Should -Be $onError
        }

        It 'Should set OnError to null when not provided' {
            $request = [PSScriptBuilderWatchBuildRequest]::new($null, 'C:\template.ps1', 'C:\output.ps1', 500, @('.ps1'), 'C:\backup', 'ORDERED_COMPONENTS', $false, $false, $null, $null)

            $request.OnError | Should -BeNullOrEmpty
        }
    }
}

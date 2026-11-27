Describe 'PSScriptBuilderScaffoldingResult' {

    Context 'Constructor - property mapping' {

        It 'Should set ProjectName from the provided value' {
            $result = [PSScriptBuilderScaffoldingResult]::new('MyProject', 'C:\Projects\MyProject', 'C:\Projects\MyProject\Build-MyProject.ps1', @(), @())

            $result.ProjectName | Should -Be 'MyProject'
        }

        It 'Should set ProjectPath from the provided value' {
            $result = [PSScriptBuilderScaffoldingResult]::new('MyProject', 'C:\Projects\MyProject', 'C:\Projects\MyProject\Build-MyProject.ps1', @(), @())

            $result.ProjectPath | Should -Be 'C:\Projects\MyProject'
        }

        It 'Should set BuildScriptPath from the provided value' {
            $result = [PSScriptBuilderScaffoldingResult]::new('MyProject', 'C:\Projects\MyProject', 'C:\Projects\MyProject\Build-MyProject.ps1', @(), @())

            $result.BuildScriptPath | Should -Be 'C:\Projects\MyProject\Build-MyProject.ps1'
        }

        It 'Should set CreatedFiles from the provided array' {
            $files  = @('C:\Projects\MyProject\file1.ps1', 'C:\Projects\MyProject\file2.json')
            $result = [PSScriptBuilderScaffoldingResult]::new('MyProject', 'C:\Projects\MyProject', 'C:\Projects\MyProject\Build-MyProject.ps1', $files, @())

            $result.CreatedFiles | Should -Be $files
        }

        It 'Should set CreatedFiles to an empty array when none provided' {
            $result = [PSScriptBuilderScaffoldingResult]::new('MyProject', 'C:\Projects\MyProject', 'C:\Projects\MyProject\Build-MyProject.ps1', @(), @())

            $result.CreatedFiles.Count | Should -Be 0
        }

        It 'Should set CreatedDirectories from the provided array' {
            $dirs   = @('C:\Projects\MyProject', 'C:\Projects\MyProject\src')
            $result = [PSScriptBuilderScaffoldingResult]::new('MyProject', 'C:\Projects\MyProject', 'C:\Projects\MyProject\Build-MyProject.ps1', @(), $dirs)

            $result.CreatedDirectories | Should -Be $dirs
        }

        It 'Should set CreatedDirectories to an empty array when none provided' {
            $result = [PSScriptBuilderScaffoldingResult]::new('MyProject', 'C:\Projects\MyProject', 'C:\Projects\MyProject\Build-MyProject.ps1', @(), @())

            $result.CreatedDirectories.Count | Should -Be 0
        }
    }
}

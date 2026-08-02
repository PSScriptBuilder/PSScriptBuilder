Describe 'PSScriptBuilderFileData' {

    Context 'Constructor - property mapping' {

        It 'Should set FileName from the provided value' {
            $data = [PSScriptBuilderFileData]::new('MyScript.ps1', 'C:\src\MyScript.ps1', '# content')

            $data.FileName | Should -Be 'MyScript.ps1'
        }

        It 'Should set FullPath from the provided value' {
            $data = [PSScriptBuilderFileData]::new('MyScript.ps1', 'C:\src\MyScript.ps1', '# content')

            $data.FullPath | Should -Be 'C:\src\MyScript.ps1'
        }

        It 'Should set Content from the provided value' {
            $data = [PSScriptBuilderFileData]::new('MyScript.ps1', 'C:\src\MyScript.ps1', '# file content')

            $data.Content | Should -Be '# file content'
        }

        It 'Should accept an empty string as Content' {
            $data = [PSScriptBuilderFileData]::new('Empty.ps1', 'C:\src\Empty.ps1', '')

            $data.Content | Should -Be ''
        }
    }
}

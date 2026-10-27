Describe 'PSScriptBuilderFunctionData' {

    Context 'Constructor - property mapping' {

        It 'Should set Name from the provided value' {
            $data = [PSScriptBuilderFunctionData]::new('Get-Thing', '# code', 'C:\file.ps1', @(), @())

            $data.Name | Should -Be 'Get-Thing'
        }

        It 'Should set SourceCode from the provided value' {
            $data = [PSScriptBuilderFunctionData]::new('Get-Thing', 'Function Get-Thing { }', 'C:\file.ps1', @(), @())

            $data.SourceCode | Should -Be 'Function Get-Thing { }'
        }

        It 'Should set SourceFile from the provided value' {
            $data = [PSScriptBuilderFunctionData]::new('Get-Thing', '# code', 'C:\src\Get-Thing.ps1', @(), @())

            $data.SourceFile | Should -Be 'C:\src\Get-Thing.ps1'
        }

        It 'Should set CalledFunctions from the provided array' {
            $funcs = @('Get-Other', 'Set-Other')
            $data  = [PSScriptBuilderFunctionData]::new('Get-Thing', '# code', 'C:\file.ps1', $funcs, @())

            $data.CalledFunctions | Should -Be $funcs
        }

        It 'Should set CalledFunctions to an empty array when none provided' {
            $data = [PSScriptBuilderFunctionData]::new('Get-Thing', '# code', 'C:\file.ps1', @(), @())

            $data.CalledFunctions.Count | Should -Be 0
        }

        It 'Should set TypeReferences from the provided array' {
            $refs = @('MyType', 'OtherType')
            $data = [PSScriptBuilderFunctionData]::new('Get-Thing', '# code', 'C:\file.ps1', @(), $refs)

            $data.TypeReferences | Should -Be $refs
        }

        It 'Should set TypeReferences to an empty array when none provided' {
            $data = [PSScriptBuilderFunctionData]::new('Get-Thing', '# code', 'C:\file.ps1', @(), @())

            $data.TypeReferences.Count | Should -Be 0
        }
    }
}

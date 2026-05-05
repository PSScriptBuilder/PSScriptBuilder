Describe 'PSScriptBuilderEnumData' {

    Context 'Constructor - property mapping' {

        It 'Should set Name from the provided value' {
            $data = [PSScriptBuilderEnumData]::new('MyEnum', 'enum MyEnum { Val }', 'C:\file.ps1')

            $data.Name | Should -Be 'MyEnum'
        }

        It 'Should set SourceCode from the provided value' {
            $data = [PSScriptBuilderEnumData]::new('MyEnum', 'enum MyEnum { Val }', 'C:\file.ps1')

            $data.SourceCode | Should -Be 'enum MyEnum { Val }'
        }

        It 'Should set SourceFile from the provided value' {
            $data = [PSScriptBuilderEnumData]::new('MyEnum', 'enum MyEnum { Val }', 'C:\src\MyEnum.ps1')

            $data.SourceFile | Should -Be 'C:\src\MyEnum.ps1'
        }
    }
}

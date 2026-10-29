Describe 'PSScriptBuilderClassData' {

    Context 'Constructor - property mapping' {

        It 'Should set Name from the provided value' {
            $data = [PSScriptBuilderClassData]::new('MyClass', '# code', 'C:\file.ps1', $null, @(), @(), @())

            $data.Name | Should -Be 'MyClass'
        }

        It 'Should set SourceCode from the provided value' {
            $data = [PSScriptBuilderClassData]::new('MyClass', 'class MyClass { }', 'C:\file.ps1', $null, @(), @(), @())

            $data.SourceCode | Should -Be 'class MyClass { }'
        }

        It 'Should set SourceFile from the provided value' {
            $data = [PSScriptBuilderClassData]::new('MyClass', '# code', 'C:\src\MyClass.ps1', $null, @(), @(), @())

            $data.SourceFile | Should -Be 'C:\src\MyClass.ps1'
        }

        It 'Should set BaseClass from the provided value' {
            $data = [PSScriptBuilderClassData]::new('ChildClass', '# code', 'C:\file.ps1', 'BaseClass', @(), @(), @())

            $data.BaseClass | Should -Be 'BaseClass'
        }

        It 'Should set BaseClass to null when not provided' {
            $data = [PSScriptBuilderClassData]::new('StandaloneClass', '# code', 'C:\file.ps1', $null, @(), @(), @())

            $data.BaseClass | Should -BeNullOrEmpty
        }

        It 'Should set TypeReferences from the provided array' {
            $refs = @('TypeA', 'TypeB')
            $data = [PSScriptBuilderClassData]::new('MyClass', '# code', 'C:\file.ps1', $null, $refs, @(), @())

            $data.TypeReferences | Should -Be $refs
        }

        It 'Should set TypeReferences to an empty array when none provided' {
            $data = [PSScriptBuilderClassData]::new('MyClass', '# code', 'C:\file.ps1', $null, @(), @(), @())

            $data.TypeReferences.Count | Should -Be 0
        }

        It 'Should set CalledFunctions from the provided array' {
            $funcs = @('Get-Something', 'Set-Something')
            $data  = [PSScriptBuilderClassData]::new('MyClass', '# code', 'C:\file.ps1', $null, @(), @(), $funcs)

            $data.CalledFunctions | Should -Be $funcs
        }

        It 'Should set CalledFunctions to an empty array when none provided' {
            $data = [PSScriptBuilderClassData]::new('MyClass', '# code', 'C:\file.ps1', $null, @(), @(), @())

            $data.CalledFunctions.Count | Should -Be 0
        }

        It 'Should set StaticInitializerReferences from the provided array' {
            $initRefs = @('InitTypeA', 'InitTypeB')
            $data     = [PSScriptBuilderClassData]::new('MyClass', '# code', 'C:\file.ps1', $null, @(), $initRefs, @())

            $data.StaticInitializerReferences | Should -Be $initRefs
        }
    }
}

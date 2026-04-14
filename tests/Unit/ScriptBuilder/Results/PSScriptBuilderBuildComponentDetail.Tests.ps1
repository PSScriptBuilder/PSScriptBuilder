Describe 'PSScriptBuilderBuildComponentDetail' {

    Context 'Constructor - property mapping' {

        It 'Should set Type from the provided value' {
            $detail = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::ClassCollector, 'MyClass', 'C:\file.ps1', @())

            $detail.Type | Should -Be ([PSScriptBuilderCollectorType]::ClassCollector)
        }

        It 'Should set Name from the provided value' {
            $detail = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::ClassCollector, 'MyClass', 'C:\file.ps1', @())

            $detail.Name | Should -Be 'MyClass'
        }

        It 'Should set SourceFile from the provided value' {
            $detail = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::ClassCollector, 'MyClass', 'C:\src\MyClass.ps1', @())

            $detail.SourceFile | Should -Be 'C:\src\MyClass.ps1'
        }

        It 'Should set Dependencies from the provided array' {
            $deps   = @('BaseClass', 'OtherType')
            $detail = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::ClassCollector, 'MyClass', 'C:\file.ps1', $deps)

            $detail.Dependencies | Should -Be $deps
        }

        It 'Should set Dependencies to an empty array when none provided' {
            $detail = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::EnumCollector, 'MyEnum', 'C:\file.ps1', @())

            $detail.Dependencies.Count | Should -Be 0
        }

        It 'Should accept EnumCollector as Type' {
            $detail = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::EnumCollector, 'MyEnum', 'C:\file.ps1', @())

            $detail.Type | Should -Be ([PSScriptBuilderCollectorType]::EnumCollector)
        }

        It 'Should accept FunctionCollector as Type' {
            $detail = [PSScriptBuilderBuildComponentDetail]::new(
                [PSScriptBuilderCollectorType]::FunctionCollector, 'Get-Thing', 'C:\file.ps1', @())

            $detail.Type | Should -Be ([PSScriptBuilderCollectorType]::FunctionCollector)
        }
    }
}

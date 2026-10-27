Describe 'PSScriptBuilderScaffoldingRequest' {

    Context 'Constructor - property mapping' {

        It 'Should set Name from the provided value' {
            $request = [PSScriptBuilderScaffoldingRequest]::new('MyProject', 'C:\Projects', $false, $false, $false)

            $request.Name | Should -Be 'MyProject'
        }

        It 'Should set Path from the provided value' {
            $request = [PSScriptBuilderScaffoldingRequest]::new('MyProject', 'C:\Projects', $false, $false, $false)

            $request.Path | Should -Be 'C:\Projects'
        }

        It 'Should set IncludeReleaseManagement to false when provided as false' {
            $request = [PSScriptBuilderScaffoldingRequest]::new('MyProject', 'C:\Projects', $false, $false, $false)

            $request.IncludeReleaseManagement | Should -BeFalse
        }

        It 'Should set IncludeReleaseManagement to true when provided as true' {
            $request = [PSScriptBuilderScaffoldingRequest]::new('MyProject', 'C:\Projects', $true, $false, $false)

            $request.IncludeReleaseManagement | Should -BeTrue
        }

        It 'Should set IncludeSampleFiles to false when provided as false' {
            $request = [PSScriptBuilderScaffoldingRequest]::new('MyProject', 'C:\Projects', $false, $false, $false)

            $request.IncludeSampleFiles | Should -BeFalse
        }

        It 'Should set IncludeSampleFiles to true when provided as true' {
            $request = [PSScriptBuilderScaffoldingRequest]::new('MyProject', 'C:\Projects', $false, $true, $false)

            $request.IncludeSampleFiles | Should -BeTrue
        }

        It 'Should set Force to false when provided as false' {
            $request = [PSScriptBuilderScaffoldingRequest]::new('MyProject', 'C:\Projects', $false, $false, $false)

            $request.Force | Should -BeFalse
        }

        It 'Should set Force to true when provided as true' {
            $request = [PSScriptBuilderScaffoldingRequest]::new('MyProject', 'C:\Projects', $false, $false, $true)

            $request.Force | Should -BeTrue
        }
    }
}

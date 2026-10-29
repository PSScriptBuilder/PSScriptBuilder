Describe 'PSScriptBuilderReleaseDataOperationRequest' {

    Context 'Constructor - parameterless (default values)' {

        It 'Should initialise BumpType to None' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new()

            $request.BumpType | Should -Be ([PSScriptBuilderBumpType]::None)
        }

        It 'Should initialise UpdateBuildDetails to false' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new()

            $request.UpdateBuildDetails | Should -BeFalse
        }

        It 'Should initialise UpdateGitDetails to false' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new()

            $request.UpdateGitDetails | Should -BeFalse
        }

        It 'Should initialise Prerelease to null' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new()

            $request.Prerelease | Should -BeNullOrEmpty
        }

        It 'Should initialise BuildMetadata to null' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new()

            $request.BuildMetadata | Should -BeNullOrEmpty
        }

        It 'Should initialise ClearPrerelease to false' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new()

            $request.ClearPrerelease | Should -BeFalse
        }

        It 'Should initialise ClearBuildMetadata to false' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new()

            $request.ClearBuildMetadata | Should -BeFalse
        }

        It 'Should initialise Version to null' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new()

            $request.Version | Should -BeNullOrEmpty
        }
    }

    Context 'Constructor - with parameters' {

        It 'Should set BumpType correctly' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::Major,
                $false, $false, $null, $null, $false, $false, $null
            )

            $request.BumpType | Should -Be ([PSScriptBuilderBumpType]::Major)
        }

        It 'Should set UpdateBuildDetails correctly' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $true, $false, $null, $null, $false, $false, $null
            )

            $request.UpdateBuildDetails | Should -BeTrue
        }

        It 'Should set UpdateGitDetails correctly' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $true, $null, $null, $false, $false, $null
            )

            $request.UpdateGitDetails | Should -BeTrue
        }

        It 'Should set Prerelease correctly' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, 'beta.1', $null, $false, $false, $null
            )

            $request.Prerelease | Should -Be 'beta.1'
        }

        It 'Should set BuildMetadata correctly' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, 'build.42', $false, $false, $null
            )

            $request.BuildMetadata | Should -Be 'build.42'
        }

        It 'Should set ClearPrerelease correctly' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, $null, $true, $false, $null
            )

            $request.ClearPrerelease | Should -BeTrue
        }

        It 'Should set ClearBuildMetadata correctly' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, $null, $false, $true, $null
            )

            $request.ClearBuildMetadata | Should -BeTrue
        }

        It 'Should set Version correctly when provided' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, $null, $false, $false, '2.0.0'
            )

            $request.Version | Should -Be '2.0.0'
        }

        It 'Should set Version to null when not provided' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::Minor,
                $false, $false, $null, $null, $false, $false, $null
            )

            $request.Version | Should -BeNullOrEmpty
        }
    }
}

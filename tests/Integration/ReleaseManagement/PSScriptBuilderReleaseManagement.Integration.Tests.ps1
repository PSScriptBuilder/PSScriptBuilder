Describe 'ReleaseManagement Integration - Full Release Workflow' -Tag 'Integration' {

    BeforeAll {
        $script:ExampleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\11-mixed-bump-mode')).Path
    }

    Context 'Get-PSScriptBuilderReleaseData - reads initial version from fixture' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-01'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:Data = Get-PSScriptBuilderReleaseData
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null result' {
            $script:Data | Should -Not -BeNullOrEmpty
        }

        It 'Should report initial full version as 1.0.0' {
            $script:Data.Version.Full | Should -Be '1.0.0'
        }

        It 'Should report initial patch version as 0' {
            $script:Data.Version.Patch | Should -Be 0
        }

        It 'Should report initial build number as 0' {
            $script:Data.Build.Number | Should -Be 0
        }
    }

    Context 'Test-PSScriptBuilderReleaseData - valid release data returns true' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-02'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:IsValid = Test-PSScriptBuilderReleaseData
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return true for a valid release data file' {
            $script:IsValid | Should -BeTrue
        }
    }

    Context 'Update-PSScriptBuilderReleaseData - patch bump increments version' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-03'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:Result = Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails
            $script:Updated = Get-PSScriptBuilderReleaseData
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null result' {
            $script:Result | Should -Not -BeNullOrEmpty
        }

        It 'Should report at least one operation performed' {
            $script:Result.TotalOperationsPerformed | Should -BeGreaterThan 0
        }

        It 'Should increment the patch version to 1' {
            $script:Updated.Version.Patch | Should -Be 1
        }

        It 'Should update the full version string to 1.0.1' {
            $script:Updated.Version.Full | Should -Be '1.0.1'
        }

        It 'Should increment the build number' {
            $script:Updated.Build.Number | Should -BeGreaterThan 0
        }
    }

    Context 'Get-PSScriptBuilderBumpConfiguration - returns configured bump files' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-04'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:BumpConfig = Get-PSScriptBuilderBumpConfiguration
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null configuration' {
            $script:BumpConfig | Should -Not -BeNullOrEmpty
        }

        It 'Should contain at least one bump file entry' {
            $script:BumpConfig.bumpFiles.Count | Should -BeGreaterThan 0
        }

        It 'Should reference AppConfig.psd1 as the bump target' {
            $script:BumpConfig.bumpFiles[0].path | Should -Match 'AppConfig\.psd1'
        }
    }

    Context 'Update-PSScriptBuilderBumpFiles - applies new version to HRModule.psd1' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-05'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            # build/Output is excluded from git - create the bump target files as they would exist after a build
            $outputDir = [System.IO.Path]::Combine($script:Root, 'build', 'Output')
            [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($outputDir)
            $psd1Content = "@{`n    ModuleVersion = '1.0.0'`n    RootModule = 'AppConfig.psm1'`n    GUID = 'c3d4e5f6-a7b8-9012-cdef-123456789012'`n}"
            [System.IO.File]::WriteAllText(([System.IO.Path]::Combine($outputDir, 'AppConfig.psd1')), $psd1Content)

            # First bump the version to 1.0.1
            Update-PSScriptBuilderReleaseData -Patch | Out-Null

            # Then apply the new version to configured files
            $script:Result  = Update-PSScriptBuilderBumpFiles
            $script:PsdPath = [System.IO.Path]::Combine($script:Root, 'build', 'Output', 'AppConfig.psd1')
            $script:Content = Get-Content -Path $script:PsdPath -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null result' {
            $script:Result | Should -Not -BeNullOrEmpty
        }

        It 'Should report 2 files processed' {
            $script:Result.TotalFilesProcessed | Should -Be 2
        }

        It 'Should report 2 files modified' {
            $script:Result.TotalFilesModified | Should -Be 2
        }

        It 'Should update ModuleVersion in AppConfig.psd1 to 1.0.1' {
            $script:Content | Should -Match "ModuleVersion\s*=\s*'1\.0\.1'"
        }

        It 'Should not leave the old version placeholder in AppConfig.psd1' {
            $script:Content | Should -Not -Match "ModuleVersion\s*=\s*'1\.0\.0'"
        }
    }

    Context 'Update-PSScriptBuilderReleaseData - explicit version sets version directly' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-06'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:Result  = Update-PSScriptBuilderReleaseData -Version '2.0.0'
            $script:Updated = Get-PSScriptBuilderReleaseData
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null result' {
            $script:Result | Should -Not -BeNullOrEmpty
        }

        It 'Should report at least one operation performed' {
            $script:Result.TotalOperationsPerformed | Should -BeGreaterThan 0
        }

        It 'Should set the full version to 2.0.0' {
            $script:Updated.Version.Full | Should -Be '2.0.0'
        }

        It 'Should set major version to 2' {
            $script:Updated.Version.Major | Should -Be 2
        }

        It 'Should set minor version to 0' {
            $script:Updated.Version.Minor | Should -Be 0
        }

        It 'Should set patch version to 0' {
            $script:Updated.Version.Patch | Should -Be 0
        }

        It 'Should not change the build number when -UpdateBuildDetails is not specified' {
            $script:Updated.Build.Number | Should -Be 0
        }
    }
}

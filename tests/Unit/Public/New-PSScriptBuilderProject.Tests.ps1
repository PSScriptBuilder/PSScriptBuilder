using namespace System.IO

Describe 'New-PSScriptBuilderProject' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Parameter - Name (mandatory)' {

        It 'Should throw when Name is an empty string' {
            { New-PSScriptBuilderProject -Name '' -Path $TestDrive } | Should -Throw
        }
    }

    Context 'Parameter - Path' {

        It 'Should use the provided Path as the parent directory' {
            $parentPath = [Path]::Combine($TestDrive, 'custom-parent')
            New-Item -ItemType Directory -Path $parentPath -Force | Out-Null

            New-PSScriptBuilderProject -Name 'PathTest' -Path $parentPath

            Test-Path ([Path]::Combine($parentPath, 'PathTest')) | Should -BeTrue
        }

        It 'Should use current working directory when Path is not provided' {
            $cwdPath = [Path]::Combine($TestDrive, 'cwd-test')
            New-Item -ItemType Directory -Path $cwdPath -Force | Out-Null
            Push-Location $cwdPath

            New-PSScriptBuilderProject -Name 'CwdProject'

            Pop-Location
            Test-Path ([Path]::Combine($cwdPath, 'CwdProject')) | Should -BeTrue
        }
    }

    Context 'Return value' {

        It 'Should return a PSScriptBuilderScaffoldingResult' {
            $result = New-PSScriptBuilderProject -Name 'ReturnTest' -Path $TestDrive

            $result.GetType().Name | Should -Be 'PSScriptBuilderScaffoldingResult'
        }

        It 'Should return the correct ProjectName' {
            $result = New-PSScriptBuilderProject -Name 'NameTest' -Path $TestDrive

            $result.ProjectName | Should -Be 'NameTest'
        }

        It 'Should return the correct ProjectPath' {
            $result = New-PSScriptBuilderProject -Name 'PathResultTest' -Path $TestDrive

            $result.ProjectPath | Should -Be ([Path]::Combine($TestDrive, 'PathResultTest'))
        }
    }

    Context 'IncludeReleaseManagement switch' {

        It 'Should not create release files when switch is not specified' {
            New-PSScriptBuilderProject -Name 'NoRmCmdlet' -Path $TestDrive

            $projectPath = [Path]::Combine($TestDrive, 'NoRmCmdlet')
            Test-Path ([Path]::Combine($projectPath, 'build', 'Release')) | Should -BeFalse
        }

        It 'Should create release files when switch is specified' {
            New-PSScriptBuilderProject -Name 'WithRmCmdlet' -Path $TestDrive -IncludeReleaseManagement

            $projectPath = [Path]::Combine($TestDrive, 'WithRmCmdlet')
            Test-Path ([Path]::Combine($projectPath, 'build', 'Release', 'psscriptbuilder.releasedata.json')) | Should -BeTrue
        }
    }

    Context 'Force switch' {

        It 'Should throw when target is not empty and Force is not specified' {
            $existingPath = [Path]::Combine($TestDrive, 'ForceTestProject')
            New-Item -ItemType Directory -Path $existingPath -Force | Out-Null
            Set-Content -Path ([Path]::Combine($existingPath, 'existing.txt')) -Value 'content'

            { New-PSScriptBuilderProject -Name 'ForceTestProject' -Path $TestDrive } | Should -Throw
        }

        It 'Should not throw when target is not empty and Force is specified' {
            $existingPath = [Path]::Combine($TestDrive, 'ForceTestProjectForced')
            New-Item -ItemType Directory -Path $existingPath -Force | Out-Null
            Set-Content -Path ([Path]::Combine($existingPath, 'existing.txt')) -Value 'content'

            { New-PSScriptBuilderProject -Name 'ForceTestProjectForced' -Path $TestDrive -Force } | Should -Not -Throw
        }
    }
}

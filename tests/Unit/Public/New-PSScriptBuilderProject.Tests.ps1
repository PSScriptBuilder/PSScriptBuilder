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

        # Set-Location does not change the process working directory, against which .NET resolves
        # relative paths - the project used to end up there
        It 'Should resolve a relative Path against the PowerShell location, not the process directory' {
            $location = [Path]::Combine($TestDrive, 'rel-location')
            $process  = [Path]::Combine($TestDrive, 'rel-process')
            New-Item -ItemType Directory -Path $location, $process -Force | Out-Null

            $savedDirectory = [Environment]::CurrentDirectory
            [Environment]::CurrentDirectory = $process
            Push-Location $location
            try {
                New-PSScriptBuilderProject -Name 'RelativeProject' -Path '.\projects' | Out-Null
            }
            finally {
                Pop-Location
                [Environment]::CurrentDirectory = $savedDirectory
            }

            Test-Path ([Path]::Combine($location, 'projects', 'RelativeProject')) | Should -BeTrue
            Test-Path ([Path]::Combine($process, 'projects')) | Should -BeFalse
        }

        # The provider path of such a drive is relative, so the project used to be created silently in
        # the process working directory; Env: exists on every platform, unlike HKCU:
        It 'Should throw for <Case> and create nothing in the process directory' -ForEach @(
            @{ Case = 'a -Path on another provider''s drive';                   Path = 'Env:\provider-project'; Location = $null }
            @{ Case = 'no -Path while the location is on another provider''s drive'; Path = $null;                   Location = 'Env:\' }
        ) {
            $process = [Path]::Combine($TestDrive, 'provider-process-' + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $process -Force | Out-Null

            $savedDirectory = [Environment]::CurrentDirectory
            [Environment]::CurrentDirectory = $process
            if ($Location) { Push-Location $Location }
            try {
                $parameters = @{ Name = 'ProviderProject' }
                if ($Path) { $parameters['Path'] = $Path }
                { New-PSScriptBuilderProject @parameters } |
                    Should -Throw -ExpectedMessage '*Environment provider*not to a file system path*'
            }
            finally {
                if ($Location) { Pop-Location }
                [Environment]::CurrentDirectory = $savedDirectory
            }

            @(Get-ChildItem $process -Recurse -Force).Count | Should -Be 0
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

            # The path is resolved to its full name, which expands an 8.3 short name in $TestDrive
            $result.ProjectPath | Should -Be ([Path]::GetFullPath([Path]::Combine($TestDrive, 'PathResultTest')))
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

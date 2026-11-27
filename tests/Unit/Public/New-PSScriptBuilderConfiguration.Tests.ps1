Describe 'New-PSScriptBuilderConfiguration' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    AfterEach {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'ProjectRoot resolution' {

        It 'Should use -Path when provided' {
            $root = Join-Path $TestDrive 'nr-param'
            New-Item -Path $root -ItemType Directory -Force | Out-Null

            New-PSScriptBuilderConfiguration -Path $root

            Test-Path (Join-Path $root 'psscriptbuilder.config.json') | Should -BeTrue
        }

        It 'Should use Global:PSScriptBuilderProjectRoot when -Path is not provided' {
            $root = Join-Path $TestDrive 'nr-global'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            $Global:PSScriptBuilderProjectRoot = $root

            New-PSScriptBuilderConfiguration

            Test-Path (Join-Path $root 'psscriptbuilder.config.json') | Should -BeTrue
        }

        It 'Should use current working directory when neither -Path nor global is set' {
            $root = Join-Path $TestDrive 'nr-cwd'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            Push-Location $root

            New-PSScriptBuilderConfiguration

            Pop-Location
            Test-Path (Join-Path $root 'psscriptbuilder.config.json') | Should -BeTrue
        }
    }

    Context 'Force parameter' {

        It 'Should throw when config file already exists and -Force is not specified' {
            $root = Join-Path $TestDrive 'nr-noforce'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $root 'psscriptbuilder.config.json') -Value '{}' -Encoding UTF8

            { New-PSScriptBuilderConfiguration -Path $root } | Should -Throw
        }

        It 'Should not throw when config file already exists and -Force is specified' {
            $root = Join-Path $TestDrive 'nr-force'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $root 'psscriptbuilder.config.json') -Value '{}' -Encoding UTF8

            { New-PSScriptBuilderConfiguration -Path $root -Force } | Should -Not -Throw
        }
    }

    Context 'WhatIf' {

        It 'Should not create the file when -WhatIf is specified' {
            $root = Join-Path $TestDrive 'nr-whatif'
            New-Item -Path $root -ItemType Directory -Force | Out-Null

            New-PSScriptBuilderConfiguration -Path $root -WhatIf

            Test-Path (Join-Path $root 'psscriptbuilder.config.json') | Should -BeFalse
        }
    }

    Context 'Missing target directory' {

        It 'Should create the target directory when it does not exist' {
            $root = Join-Path $TestDrive 'nr-missing\nested'

            New-PSScriptBuilderConfiguration -Path $root

            Test-Path (Join-Path $root 'psscriptbuilder.config.json') | Should -BeTrue
        }

        It 'Should not create the target directory when -WhatIf is specified' {
            $root = Join-Path $TestDrive 'nr-missing-whatif'

            New-PSScriptBuilderConfiguration -Path $root -WhatIf

            Test-Path $root | Should -BeFalse
        }
    }

    Context 'Relative -Path' {

        # Set-Location does not change the process working directory, against which .NET resolves
        # relative paths - the configuration file used to end up there
        It 'Should resolve a relative -Path against the PowerShell location, not the process directory' {
            $location = Join-Path $TestDrive 'nr-rel-location'
            $process  = Join-Path $TestDrive 'nr-rel-process'
            New-Item -Path $location, $process -ItemType Directory -Force | Out-Null

            $savedDirectory = [System.Environment]::CurrentDirectory
            [System.Environment]::CurrentDirectory = $process
            Push-Location $location
            try {
                New-PSScriptBuilderConfiguration -Path '.\cfg'
            }
            finally {
                Pop-Location
                [System.Environment]::CurrentDirectory = $savedDirectory
            }

            Test-Path (Join-Path $location 'cfg\psscriptbuilder.config.json') | Should -BeTrue
            Test-Path (Join-Path $process 'cfg') | Should -BeFalse
        }
    }

    Context 'Path on another provider''s drive' {

        # The provider path of such a drive is relative, so .NET would resolve it against the process
        # working directory; Env: exists on every platform, unlike HKCU:
        BeforeEach {
            $script:Process = Join-Path $TestDrive ('nr-provider-' + [Guid]::NewGuid().ToString('N'))
            New-Item -Path $script:Process -ItemType Directory -Force | Out-Null
            $script:SavedDirectory = [System.Environment]::CurrentDirectory
            [System.Environment]::CurrentDirectory = $script:Process
        }

        AfterEach {
            [System.Environment]::CurrentDirectory = $script:SavedDirectory
        }

        It 'Should throw for -Path on another provider''s drive and create nothing' {
            { New-PSScriptBuilderConfiguration -Path 'Env:\nr-provider' } |
                Should -Throw -ExpectedMessage '*Environment provider*not to a file system path*'

            @(Get-ChildItem $script:Process -Recurse -Force).Count | Should -Be 0
        }

        It 'Should throw without -Path while the current location is on another provider''s drive' {
            Push-Location 'Env:\'
            try {
                { New-PSScriptBuilderConfiguration } |
                    Should -Throw -ExpectedMessage '*Environment provider*not to a file system path*'
            }
            finally {
                Pop-Location
            }

            @(Get-ChildItem $script:Process -Recurse -Force).Count | Should -Be 0
        }
    }
}

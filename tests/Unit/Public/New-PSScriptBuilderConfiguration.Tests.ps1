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
}

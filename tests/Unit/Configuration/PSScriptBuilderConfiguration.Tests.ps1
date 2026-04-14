using namespace System
using namespace System.IO

Describe 'PSScriptBuilderConfiguration' {

    BeforeAll {
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        $script:ValidJson = @'
{
    "release": {
        "dataFile":       "releasedata.json",
        "bumpConfigFile": "bumpconfig.json"
    },
    "build": {
        "outputPath":             "Output",
        "backupPath":             "Backup",
        "templatePath":           "Templates",
        "orderedComponentsKey":   "ORDERED_COMPONENTS",
        "backupEnabled":          false,
        "syntaxValidationEnabled": true
    }
}
'@
        $script:ConfigPath = Join-Path $TestDrive 'psscriptbuilder.config.json'
        $script:ValidJson | Set-Content -Path $script:ConfigPath -Encoding UTF8

        # Ensure referenced paths exist (BuildOptions validates directory existence)
        New-Item -Path (Join-Path $TestDrive 'Output')    -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $TestDrive 'Backup')    -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $TestDrive 'Templates') -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        [PSScriptBuilderConfiguration]::Reset()
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Constructor' {

        It 'Should populate Build options when constructed with a valid config file path' {
            $config = [PSScriptBuilderConfiguration]::new($script:ConfigPath)

            $config.Build | Should -Not -BeNull
        }

        It 'Should populate Release options when constructed with a valid config file path' {
            $config = [PSScriptBuilderConfiguration]::new($script:ConfigPath)

            $config.Release | Should -Not -BeNull
        }
    }

    Context 'GetConfigurationFlattened' {

        It 'Should return an OrderedDictionary' {
            $config = [PSScriptBuilderConfiguration]::new($script:ConfigPath)

            $result = $config.GetConfigurationFlattened()

            $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
        }

        It 'Should contain the BuildOutputPath key' {
            $config = [PSScriptBuilderConfiguration]::new($script:ConfigPath)

            $result = $config.GetConfigurationFlattened()

            $result.Contains('BuildOutputPath') | Should -BeTrue
        }

        It 'Should contain the ReleaseDataFile key' {
            $config = [PSScriptBuilderConfiguration]::new($script:ConfigPath)

            $result = $config.GetConfigurationFlattened()

            $result.Contains('ReleaseDataFile') | Should -BeTrue
        }
    }

    Context 'Singleton lifecycle - Load' {

        It 'Load should return a configuration instance' {
            $result = [PSScriptBuilderConfiguration]::Load()

            $result | Should -Not -BeNull
        }

        It 'Load called twice should return the same cached instance' {
            $first  = [PSScriptBuilderConfiguration]::Load()
            $second = [PSScriptBuilderConfiguration]::Load()

            $second | Should -Be $first
        }

        It 'Load should set IsLoaded to true' {
            [PSScriptBuilderConfiguration]::Load() | Out-Null

            [PSScriptBuilderConfiguration]::IsLoaded | Should -BeTrue
        }
    }

    Context 'Singleton lifecycle - Set' {

        It 'Set should replace the cached Current instance' {
            $custom = [PSScriptBuilderConfiguration]::new($script:ConfigPath)

            [PSScriptBuilderConfiguration]::Set($custom)

            [PSScriptBuilderConfiguration]::Current | Should -Be $custom
        }

        It 'Set should mark IsLoaded as true' {
            $custom = [PSScriptBuilderConfiguration]::new($script:ConfigPath)

            [PSScriptBuilderConfiguration]::Set($custom)

            [PSScriptBuilderConfiguration]::IsLoaded | Should -BeTrue
        }
    }

    Context 'Singleton lifecycle - Reset' {

        It 'Reset should set Current to null' {
            [PSScriptBuilderConfiguration]::Load() | Out-Null

            [PSScriptBuilderConfiguration]::Reset()

            [PSScriptBuilderConfiguration]::Current | Should -BeNull
        }

        It 'Reset should set IsLoaded to false' {
            [PSScriptBuilderConfiguration]::Load() | Out-Null

            [PSScriptBuilderConfiguration]::Reset()

            [PSScriptBuilderConfiguration]::IsLoaded | Should -BeFalse
        }
    }

    Context 'Singleton lifecycle - GetCurrent' {

        It 'GetCurrent should trigger Load and return an instance when not yet loaded' {
            [PSScriptBuilderConfiguration]::IsLoaded | Should -BeFalse

            $result = [PSScriptBuilderConfiguration]::GetCurrent()

            $result | Should -Not -BeNull
        }

        It 'GetCurrent should return the same instance as Load when already loaded' {
            $loaded = [PSScriptBuilderConfiguration]::Load()

            $result = [PSScriptBuilderConfiguration]::GetCurrent()

            $result | Should -Be $loaded
        }
    }

    Context 'CreateDefault' {

        It 'Should create the configuration file with default content' {
            $root       = Join-Path $TestDrive 'cd-new'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            $configPath = Join-Path $root 'psscriptbuilder.config.json'

            [PSScriptBuilderConfiguration]::CreateDefault($root, $false)

            Test-Path $configPath | Should -BeTrue
        }

        It 'Should write valid JSON to the configuration file' {
            $root       = Join-Path $TestDrive 'cd-json'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            $configPath = Join-Path $root 'psscriptbuilder.config.json'

            [PSScriptBuilderConfiguration]::CreateDefault($root, $false)

            $content = Get-Content $configPath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should throw InvalidOperationException when config file already exists and force is false' {
            $root       = Join-Path $TestDrive 'cd-exists'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            $configPath = Join-Path $root 'psscriptbuilder.config.json'
            Set-Content -Path $configPath -Value '{}' -Encoding UTF8

            { [PSScriptBuilderConfiguration]::CreateDefault($root, $false) } |
                Should -Throw -ExceptionType ([System.InvalidOperationException])
        }

        It 'Should overwrite the configuration file when force is true' {
            $root       = Join-Path $TestDrive 'cd-force'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            $configPath = Join-Path $root 'psscriptbuilder.config.json'
            Set-Content -Path $configPath -Value '{}' -Encoding UTF8

            { [PSScriptBuilderConfiguration]::CreateDefault($root, $true) } | Should -Not -Throw

            $content = Get-Content $configPath -Raw
            ($content | ConvertFrom-Json).build | Should -Not -BeNull
        }
    }
}

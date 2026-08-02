using namespace System
using namespace System.IO

Describe 'PSScriptBuilderConfigLoader' {

    BeforeAll {
        $script:ValidJsonString = @'
{
    "release": {
        "dataFile":       "build/Release/releasedata.json",
        "bumpConfigFile": "build/Release/bumpconfig.json"
    },
    "build": {
        "outputPath":              "build/Output",
        "backupPath":              "build/Backup",
        "templatePath":            "build/Templates",
        "orderedComponentsKey":    "ORDERED_COMPONENTS",
        "backupEnabled":           false,
        "syntaxValidationEnabled": false
    }
}
'@
    }

    Context 'LoadFromJsonString' {

        It 'Should return a PSCustomObject for valid JSON' {
            $result = [PSScriptBuilderConfigLoader]::LoadFromJsonString($script:ValidJsonString)

            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should deserialise the release section' {
            $result = [PSScriptBuilderConfigLoader]::LoadFromJsonString($script:ValidJsonString)

            $result.release | Should -Not -BeNullOrEmpty
        }

        It 'Should deserialise the build section' {
            $result = [PSScriptBuilderConfigLoader]::LoadFromJsonString($script:ValidJsonString)

            $result.build | Should -Not -BeNullOrEmpty
        }

        It 'Should throw ArgumentException for invalid JSON' {
            { [PSScriptBuilderConfigLoader]::LoadFromJsonString('not valid json {{{') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'LoadFromFile' {

        It 'Should load a valid JSON config file and return a PSCustomObject' {
            $path = Join-Path $TestDrive 'config.json'
            $script:ValidJsonString | Set-Content -Path $path -Encoding UTF8

            $result = [PSScriptBuilderConfigLoader]::LoadFromFile($path)

            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should throw FileNotFoundException for a non-existent file' {
            $path = Join-Path $TestDrive 'nonexistent.json'

            { [PSScriptBuilderConfigLoader]::LoadFromFile($path) } |
                Should -Throw -ExceptionType ([FileNotFoundException])
        }
    }

    Context 'LoadReleaseOptions' {

        It 'Should throw InvalidOperationException when release section is missing' {
            $config = [PSCustomObject] @{ build = [PSCustomObject] @{} }

            { [PSScriptBuilderConfigLoader]::LoadReleaseOptions($config) } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should return a PSScriptBuilderReleaseOptions instance for valid config' {
            $config = [PSCustomObject] @{
                Release = [PSCustomObject] @{
                    dataFile       = (Join-Path $TestDrive 'releasedata.json')
                    bumpConfigFile = (Join-Path $TestDrive 'bumpconfig.json')
                }
            }

            $result = [PSScriptBuilderConfigLoader]::LoadReleaseOptions($config)

            $result.GetType().Name | Should -Be 'PSScriptBuilderReleaseOptions'
        }
    }

    Context 'LoadBuildOptions' {

        It 'Should throw InvalidOperationException when build section is missing' {
            $config = [PSCustomObject] @{ release = [PSCustomObject] @{} }

            { [PSScriptBuilderConfigLoader]::LoadBuildOptions($config) } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should return a PSScriptBuilderBuildOptions instance for valid config' {
            $outPath = Join-Path $TestDrive 'Output'
            New-Item -Path $outPath -ItemType Directory -Force | Out-Null

            $config = [PSCustomObject] @{
                Build = [PSCustomObject] @{
                    outputPath              = $outPath
                    backupPath              = (Join-Path $TestDrive 'Backup')
                    templatePath            = (Join-Path $TestDrive 'Templates')
                    orderedComponentsKey    = 'ORDERED_COMPONENTS'
                    backupEnabled           = $false
                    syntaxValidationEnabled = $false
                }
            }

            $result = [PSScriptBuilderConfigLoader]::LoadBuildOptions($config)

            $result.GetType().Name | Should -Be 'PSScriptBuilderBuildOptions'
        }
    }
}

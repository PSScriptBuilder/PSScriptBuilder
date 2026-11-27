using namespace System.IO

Describe 'PSScriptBuilderReleaseOptions' {

    BeforeAll {
        Function New-ReleaseConfig {
            param(
                [string] $DataFile,
                [string] $BumpConfigFile
            )
            return [PSCustomObject] @{
                dataFile       = $DataFile
                bumpConfigFile = $BumpConfigFile
            }
        }
    }

    Context 'Constructor' {

        It 'Should set DataFile from config' {
            $dataPath = Join-Path $TestDrive 'releasedata.json'
            $options = [PSScriptBuilderReleaseOptions]::new((New-ReleaseConfig $dataPath (Join-Path $TestDrive 'bump.json')))

            $options.DataFile | Should -Be $dataPath
        }

        It 'Should set BumpConfigFile from config' {
            $bumpPath = Join-Path $TestDrive 'bump.json'
            $options = [PSScriptBuilderReleaseOptions]::new((New-ReleaseConfig (Join-Path $TestDrive 'data.json') $bumpPath))

            $options.BumpConfigFile | Should -Be $bumpPath
        }
    }
}

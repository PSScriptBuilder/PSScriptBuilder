using namespace System
using namespace System.IO

Describe 'PSScriptBuilderBumpConfigFileManager' {

    BeforeAll {
        Function New-ValidBumpConfig {
            return [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path   = 'some\file.ps1'
                        tokens = @('VERSION')
                    }
                )
            }
        }

        Function New-Manager {
            param([string] $Path)
            return [PSScriptBuilderBumpConfigFileManager]::new($Path)
        }

        Function Write-BumpConfigFile {
            param([string] $Path, [PSCustomObject] $Data)
            $json = $Data | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
        }
    }

    Context 'Constructor' {

        It 'Should set BumpConfigFilePath from the provided path' {
            $path    = Join-Path $TestDrive 'bump.json'
            $manager = New-Manager -Path $path

            $manager.BumpConfigFilePath | Should -Be $path
        }
    }

    Context 'Load - no-arg (delegates to stored path)' {

        It 'Should load and return a PSCustomObject when the file exists' {
            $path = Join-Path $TestDrive 'bump-load-noarg.json'
            Write-BumpConfigFile -Path $path -Data (New-ValidBumpConfig)

            $manager = New-Manager -Path $path
            $result  = $manager.Load()

            $result              | Should -Not -BeNullOrEmpty
            $result.bumpFiles    | Should -Not -BeNullOrEmpty
        }

        It 'Should throw FileNotFoundException when the file does not exist' {
            $path    = Join-Path $TestDrive 'missing-bump.json'
            $manager = New-Manager -Path $path

            { $manager.Load() } | Should -Throw
        }
    }

    Context 'Load - explicit path' {

        It 'Should load and return a PSCustomObject for a valid JSON file' {
            $path = Join-Path $TestDrive 'bump-explicit.json'
            Write-BumpConfigFile -Path $path -Data (New-ValidBumpConfig)

            $manager = New-Manager -Path $path
            $result  = $manager.Load($path)

            $result           | Should -Not -BeNullOrEmpty
            $result.bumpFiles | Should -Not -BeNullOrEmpty
        }

        It 'Should throw when the file does not exist' {
            $missing = Join-Path $TestDrive 'does-not-exist.json'
            $manager = New-Manager -Path $missing

            { $manager.Load($missing) } | Should -Throw
        }

        It 'Should throw when the file contains invalid JSON' {
            $path = Join-Path $TestDrive 'invalid-bump.json'
            [System.IO.File]::WriteAllText($path, 'not valid json {{', [System.Text.Encoding]::UTF8)

            $manager = New-Manager -Path $path

            { $manager.Load($path) } | Should -Throw
        }
    }

    Context 'Save - no-arg path (delegates to stored path)' {

        It 'Should persist data that can be reloaded via Load()' {
            $path   = Join-Path $TestDrive 'bump-save-noarg.json'
            $config = New-ValidBumpConfig

            $manager = New-Manager -Path $path
            $manager.Save($config)
            $loaded  = $manager.Load()

            $loaded                        | Should -Not -BeNullOrEmpty
            $loaded.bumpFiles              | Should -Not -BeNullOrEmpty
            $loaded.bumpFiles[0].path      | Should -Be 'some\file.ps1'
            $loaded.bumpFiles[0].tokens[0] | Should -Be 'VERSION'
        }
    }

    Context 'Save - explicit path' {

        It 'Should write the file to the provided path and allow reload' {
            $storePath   = Join-Path $TestDrive 'store.json'
            $explicitPath = Join-Path $TestDrive 'explicit-save.json'
            $config       = New-ValidBumpConfig

            $manager = New-Manager -Path $storePath
            $manager.Save($explicitPath, $config)

            $loaded = $manager.Load($explicitPath)

            $loaded                        | Should -Not -BeNullOrEmpty
            $loaded.bumpFiles[0].tokens[0] | Should -Be 'VERSION'
        }
    }

    Context 'Exists - no-arg (uses stored path)' {

        It 'Should return $true when the file exists' {
            $path = Join-Path $TestDrive 'exists-bump.json'
            Write-BumpConfigFile -Path $path -Data (New-ValidBumpConfig)

            $manager = New-Manager -Path $path
            $manager.Exists() | Should -BeTrue
        }

        It 'Should return $false when the file does not exist' {
            $path    = Join-Path $TestDrive 'no-file-bump.json'
            $manager = New-Manager -Path $path

            $manager.Exists() | Should -BeFalse
        }
    }

    Context 'Exists - explicit path (uses GetProjectRootedPath)' {

        BeforeAll {
            $Global:PSScriptBuilderProjectRoot = $TestDrive
        }

        AfterAll {
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return $true for a relative path when file exists' {
            $fileName = 'rooted-bump.json'
            $fullPath  = Join-Path $TestDrive $fileName
            Write-BumpConfigFile -Path $fullPath -Data (New-ValidBumpConfig)

            $storePath = Join-Path $TestDrive 'store-bump.json'
            $manager   = New-Manager -Path $storePath

            $manager.Exists($fileName) | Should -BeTrue
        }

        It 'Should return $false for a relative path when file does not exist' {
            $storePath = Join-Path $TestDrive 'store-bump2.json'
            $manager   = New-Manager -Path $storePath

            $manager.Exists('nonexistent-rooted.json') | Should -BeFalse
        }
    }
}

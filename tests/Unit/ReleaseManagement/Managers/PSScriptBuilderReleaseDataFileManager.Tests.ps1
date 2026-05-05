using namespace System
using namespace System.IO

Describe 'PSScriptBuilderReleaseDataFileManager' {

    BeforeAll {
        Function New-ValidReleaseData {
            return [PSCustomObject] @{
                version = [PSCustomObject] @{
                    major         = 1
                    minor         = 0
                    patch         = 0
                    prerelease    = $null
                    buildmetadata = $null
                    full          = '1.0.0'
                }
                build = [PSCustomObject] @{
                    number    = 1
                    date      = '2026-03-19'
                    time      = '00:00:00'
                    timestamp = '2026-03-19T00:00:00Z'
                    year      = 2026
                    month     = 3
                    day       = 19
                    hour      = 0
                    minute    = 0
                    second    = 0
                }
                git = [PSCustomObject] @{
                    commit      = $null
                    commitShort = $null
                    branch      = $null
                    tag         = $null
                }
            }
        }

        Function New-Manager {
            param([string] $Path)
            return [PSScriptBuilderReleaseDataFileManager]::new($Path)
        }

        Function Write-ReleaseDataFile {
            param([string] $Path, [PSCustomObject] $Data)
            $json = $Data | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
        }
    }

    Context 'Constructor' {

        It 'Should set ReleaseDataFilePath from the provided path' {
            $path    = Join-Path $TestDrive 'releasedata.json'
            $manager = New-Manager -Path $path

            $manager.ReleaseDataFilePath | Should -Be $path
        }
    }

    Context 'Load - no-arg (delegates to stored path)' {

        It 'Should load and return a PSCustomObject when the file exists' {
            $path = Join-Path $TestDrive 'releasedata-load.json'
            Write-ReleaseDataFile -Path $path -Data (New-ValidReleaseData)

            $manager = New-Manager -Path $path
            $result  = $manager.Load()

            $result         | Should -Not -BeNullOrEmpty
            $result.version | Should -Not -BeNullOrEmpty
            $result.build   | Should -Not -BeNullOrEmpty
        }

        It 'Should throw when the file does not exist' {
            $path    = Join-Path $TestDrive 'missing-releasedata.json'
            $manager = New-Manager -Path $path

            { $manager.Load() } | Should -Throw
        }
    }

    Context 'Load - explicit path' {

        It 'Should load and return a PSCustomObject for a valid JSON file' {
            $path = Join-Path $TestDrive 'releasedata-explicit.json'
            Write-ReleaseDataFile -Path $path -Data (New-ValidReleaseData)

            $manager = New-Manager -Path $path
            $result  = $manager.Load($path)

            $result                  | Should -Not -BeNullOrEmpty
            $result.version.major    | Should -Be 1
            $result.version.minor    | Should -Be 0
            $result.version.patch    | Should -Be 0
        }

        It 'Should throw when the file does not exist' {
            $missing = Join-Path $TestDrive 'does-not-exist.json'
            $manager = New-Manager -Path $missing

            { $manager.Load($missing) } | Should -Throw
        }

        It 'Should throw when the file contains invalid JSON' {
            $path = Join-Path $TestDrive 'invalid-releasedata.json'
            [System.IO.File]::WriteAllText($path, '{ broken json: [', [System.Text.Encoding]::UTF8)

            $manager = New-Manager -Path $path

            { $manager.Load($path) } | Should -Throw
        }
    }

    Context 'Save - no-arg path (delegates to stored path)' {

        It 'Should persist data that can be reloaded via Load()' {
            $path = Join-Path $TestDrive 'releasedata-save.json'
            $data = New-ValidReleaseData

            $manager = New-Manager -Path $path
            $manager.Save($data)
            $loaded  = $manager.Load()

            $loaded               | Should -Not -BeNullOrEmpty
            $loaded.version.major | Should -Be 1
            $loaded.version.minor | Should -Be 0
            $loaded.version.full  | Should -Be '1.0.0'
            $loaded.build.number  | Should -Be 1
        }
    }

    Context 'Save - explicit path' {

        It 'Should write the file to the provided path and allow reload' {
            $storePath    = Join-Path $TestDrive 'store.json'
            $explicitPath = Join-Path $TestDrive 'explicit-rd-save.json'
            $data         = New-ValidReleaseData

            $manager = New-Manager -Path $storePath
            $manager.Save($explicitPath, $data)

            $loaded = $manager.Load($explicitPath)

            $loaded              | Should -Not -BeNullOrEmpty
            $loaded.version.full | Should -Be '1.0.0'
        }
    }

    Context 'Exists - no-arg (uses stored path)' {

        It 'Should return $true when the file exists' {
            $path = Join-Path $TestDrive 'exists-rd.json'
            Write-ReleaseDataFile -Path $path -Data (New-ValidReleaseData)

            $manager = New-Manager -Path $path
            $manager.Exists() | Should -BeTrue
        }

        It 'Should return $false when the file does not exist' {
            $path    = Join-Path $TestDrive 'no-file-rd.json'
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
            $fileName = 'rooted-rd.json'
            $fullPath  = Join-Path $TestDrive $fileName
            Write-ReleaseDataFile -Path $fullPath -Data (New-ValidReleaseData)

            $storePath = Join-Path $TestDrive 'store-rd.json'
            $manager   = New-Manager -Path $storePath

            $manager.Exists($fileName) | Should -BeTrue
        }

        It 'Should return $false for a relative path when file does not exist' {
            $storePath = Join-Path $TestDrive 'store-rd2.json'
            $manager   = New-Manager -Path $storePath

            $manager.Exists('nonexistent-rooted-rd.json') | Should -BeFalse
        }
    }

    Context 'Normalize' {

        It 'Should do nothing when build is null' {
            $data    = [PSCustomObject] @{ build = $null }
            $manager = New-Manager -Path (Join-Path $TestDrive 'dummy.json')

            { $manager.Normalize($data) } | Should -Not -Throw
        }

        It 'Should do nothing when build.timestamp is null' {
            $data = [PSCustomObject] @{
                build = [PSCustomObject] @{ timestamp = $null }
            }
            $manager = New-Manager -Path (Join-Path $TestDrive 'dummy.json')

            { $manager.Normalize($data) } | Should -Not -Throw
        }

        It 'Should do nothing when build.timestamp is already a string' {
            $data = [PSCustomObject] @{
                build = [PSCustomObject] @{ timestamp = '2026-03-19T00:00:00Z' }
            }
            $manager = New-Manager -Path (Join-Path $TestDrive 'dummy.json')

            $manager.Normalize($data)

            $data.build.timestamp | Should -Be '2026-03-19T00:00:00Z'
        }

        It 'Should convert a UTC DateTime to ISO 8601 string with Z suffix' {
            $dt   = [DateTime]::new(2026, 3, 19, 22, 41, 59, [System.DateTimeKind]::Utc)
            $data = [PSCustomObject] @{
                build = [PSCustomObject] @{ timestamp = $dt }
            }
            $manager = New-Manager -Path (Join-Path $TestDrive 'dummy.json')

            $manager.Normalize($data)

            $data.build.timestamp | Should -Be '2026-03-19T22:41:59Z'
            $data.build.timestamp | Should -BeOfType [string]
        }

        It 'Should convert a local DateTime to UTC ISO 8601 string with Z suffix' {
            $dt   = [DateTime]::new(2026, 3, 19, 22, 41, 59, [System.DateTimeKind]::Local)
            $data = [PSCustomObject] @{
                build = [PSCustomObject] @{ timestamp = $dt }
            }
            $manager = New-Manager -Path (Join-Path $TestDrive 'dummy.json')

            $manager.Normalize($data)

            $data.build.timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'
            $data.build.timestamp | Should -BeOfType [string]
        }
    }
}

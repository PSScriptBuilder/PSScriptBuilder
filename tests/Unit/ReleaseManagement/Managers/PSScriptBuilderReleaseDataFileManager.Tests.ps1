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

    Context 'Serialize' {

        # Byte for byte what the former Save method wrote, so a release produces the same file
        It 'Should return exactly what the former Save wrote (JSON depth 10, UTF-8 with BOM)' {
            $data = New-ValidReleaseData
            $path = Join-Path $TestDrive 'serialize-reference.json'
            [System.IO.File]::WriteAllText($path, ($data | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($true, $true))

            $result = (New-Manager -Path $path).Serialize($data)

            [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($result, [System.IO.File]::ReadAllBytes($path)) | Should -BeTrue
        }

        It 'Should round-trip through Deserialize' {
            $manager = New-Manager -Path (Join-Path $TestDrive 'roundtrip.json')

            $loaded = $manager.Deserialize($manager.Serialize((New-ValidReleaseData)), 'roundtrip.json')

            $loaded.version.full | Should -Be '1.0.0'
            $loaded.build.number | Should -Be 1
            $loaded.build.timestamp | Should -BeOfType ([string])
        }
    }

    Context 'Deserialize' {

        It 'Should throw ArgumentException naming the file for invalid JSON' {
            $manager = New-Manager -Path (Join-Path $TestDrive 'any.json')
            $bytes   = [System.Text.Encoding]::UTF8.GetBytes('{ broken json: [')

            { $manager.Deserialize($bytes, 'C:\project\broken.json') } |
                Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage "*C:\project\broken.json*invalid JSON*"
        }

        # PowerShell 7 reads the timestamp as DateTime; converting it back used to move it to the end
        # of the build section, so unchanged release data was reported and written as changed
        It 'Should serialize deserialized release data to the same bytes' {
            $manager = New-Manager -Path (Join-Path $TestDrive 'roundtrip.json')
            $bytes   = $manager.Serialize((New-ValidReleaseData))

            $result = $manager.Serialize($manager.Deserialize($bytes, 'roundtrip.json'))

            [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($result, $bytes) | Should -BeTrue
        }
    }

    Context 'ReadBytes' {

        It 'Should return the exact bytes of the configured file' {
            $path = Join-Path $TestDrive 'readbytes.json'
            Write-ReleaseDataFile -Path $path -Data (New-ValidReleaseData)

            $result = (New-Manager -Path $path).ReadBytes()

            [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($result, [System.IO.File]::ReadAllBytes($path)) | Should -BeTrue
        }

        It 'Should throw FileNotFoundException with the former Load message when the file does not exist' {
            $path = Join-Path $TestDrive 'readbytes-missing.json'

            { (New-Manager -Path $path).ReadBytes() } |
                Should -Throw -ExceptionType ([FileNotFoundException]) -ExpectedMessage '*because it does not exist*'
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

        It 'Should keep the position of the converted timestamp in the build section' {
            $dt   = [DateTime]::new(2026, 3, 19, 22, 41, 59, [System.DateTimeKind]::Utc)
            $data = [PSCustomObject] @{
                build = [PSCustomObject] [ordered] @{ date = '2026-03-19'; timestamp = $dt; year = 2026 }
            }
            $manager = New-Manager -Path (Join-Path $TestDrive 'dummy.json')

            $manager.Normalize($data)

            ($data.build.PSObject.Properties.Name -join ',') | Should -Be 'date,timestamp,year'
        }
    }
}

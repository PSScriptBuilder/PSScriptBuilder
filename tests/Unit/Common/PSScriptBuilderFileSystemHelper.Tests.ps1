using namespace System.IO

Describe 'PSScriptBuilderFileSystemHelper' {

    #region EnsureDirectoryExists
    Context 'EnsureDirectoryExists - creates directory' {

        It 'Should create a new directory that does not exist' {
            $newDir = Join-Path $TestDrive 'new-dir'

            [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($newDir)

            Test-Path $newDir -PathType Container | Should -BeTrue
        }

        It 'Should create nested directories recursively' {
            $nestedDir = Join-Path (Join-Path (Join-Path $TestDrive 'parent') 'child') 'grandchild'

            [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($nestedDir)

            Test-Path $nestedDir -PathType Container | Should -BeTrue
        }

        It 'Should not throw when directory already exists' {
            $existingDir = Join-Path $TestDrive 'existing-dir'
            New-Item -Path $existingDir -ItemType Directory | Out-Null

            { [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($existingDir) } |
                Should -Not -Throw
        }
    }
    #endregion EnsureDirectoryExists

    #region EnsureFileExists
    Context 'EnsureFileExists - single parameter overload' {

        It 'Should create file when it does not exist' {
            $filePath = Join-Path $TestDrive 'ensure-file-empty.txt'

            [PSScriptBuilderFileSystemHelper]::EnsureFileExists($filePath)

            Test-Path $filePath -PathType Leaf | Should -BeTrue
        }

        It 'Should not throw when file already exists' {
            $filePath = Join-Path $TestDrive 'ensure-existing.txt'
            New-Item -Path $filePath -ItemType File | Out-Null

            { [PSScriptBuilderFileSystemHelper]::EnsureFileExists($filePath) } |
                Should -Not -Throw
        }

        It 'Should not overwrite existing file content' {
            $filePath = Join-Path $TestDrive 'ensure-no-overwrite.txt'
            $original = 'original content'
            [File]::WriteAllText($filePath, $original)

            [PSScriptBuilderFileSystemHelper]::EnsureFileExists($filePath)

            $result = [File]::ReadAllText($filePath)
            $result | Should -Be $original
        }
    }

    Context 'EnsureFileExists - two parameter overload' {

        It 'Should create file with content when it does not exist' {
            $filePath = Join-Path $TestDrive 'ensure-with-content.txt'
            $content  = 'initial content'

            [PSScriptBuilderFileSystemHelper]::EnsureFileExists($filePath, $content)

            Test-Path $filePath -PathType Leaf | Should -BeTrue
        }

        It 'Should write correct content to new file' {
            $filePath = Join-Path $TestDrive 'ensure-content-check.txt'
            $content  = 'my content'

            [PSScriptBuilderFileSystemHelper]::EnsureFileExists($filePath, $content)
            $result = [File]::ReadAllText($filePath, [Text.UTF8Encoding]::new($true, $true))

            $result | Should -Be $content
        }

        It 'Should create parent directories if needed' {
            $filePath = Join-Path (Join-Path (Join-Path $TestDrive 'nested-dir') 'sub') 'file.txt'

            [PSScriptBuilderFileSystemHelper]::EnsureFileExists($filePath, 'data')

            Test-Path $filePath -PathType Leaf | Should -BeTrue
        }

        It 'Should not overwrite existing file when called with content' {
            $filePath  = Join-Path $TestDrive 'ensure-no-overwrite-content.txt'
            $original  = 'original'
            [File]::WriteAllText($filePath, $original)

            [PSScriptBuilderFileSystemHelper]::EnsureFileExists($filePath, 'should not replace')

            $result = [File]::ReadAllText($filePath)
            $result | Should -Be $original
        }
    }
    #endregion EnsureFileExists

    #region GetProjectRootedPath
    Context 'GetProjectRootedPath' {

        BeforeAll {
            $Global:PSScriptBuilderProjectRoot = $TestDrive
        }

        AfterAll {
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return already-rooted path unchanged' {
            $absolutePath = Join-Path (Join-Path $TestDrive 'some') 'file.txt'

            $result = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($absolutePath)

            $result | Should -Be $absolutePath
        }

        It 'Should combine project root with relative path' {
            $relative = 'subdir\file.ps1'
            $sep      = [System.IO.Path]::DirectorySeparatorChar

            $result = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($relative)

            $normalizedRelative = $relative.Replace('\', $sep)
            $result | Should -Be ([Path]::GetFullPath([Path]::Combine($TestDrive, $normalizedRelative)))
        }
    }
    #endregion GetProjectRootedPath

    #region NewBackupDirectoryName
    Context 'NewBackupDirectoryName' {

        It 'Should return a string' {
            $result = [PSScriptBuilderFileSystemHelper]::NewBackupDirectoryName()
            $result | Should -BeOfType ([string])
        }

        It 'Should start with PSScriptBuilder_Backup_' {
            $result = [PSScriptBuilderFileSystemHelper]::NewBackupDirectoryName()
            $result | Should -Match '^PSScriptBuilder_Backup_'
        }

        It 'Should match expected format PSScriptBuilder_Backup_yyMMdd_HHmmss_xxxxxxxx' {
            $result = [PSScriptBuilderFileSystemHelper]::NewBackupDirectoryName()
            $result | Should -Match '^PSScriptBuilder_Backup_\d{6}_\d{6}_[0-9a-f]{8}$'
        }

        It 'Should return unique values on consecutive calls' {
            $result1 = [PSScriptBuilderFileSystemHelper]::NewBackupDirectoryName()
            Start-Sleep -Milliseconds 1100
            $result2 = [PSScriptBuilderFileSystemHelper]::NewBackupDirectoryName()

            $result1 | Should -Not -Be $result2
        }
    }
    #endregion NewBackupDirectoryName

    #region NewBackupFileName
    Context 'NewBackupFileName' {

        It 'Should return a string' {
            $result = [PSScriptBuilderFileSystemHelper]::NewBackupFileName('script.ps1')
            $result | Should -BeOfType ([string])
        }

        It 'Should include the original filename' {
            $result = [PSScriptBuilderFileSystemHelper]::NewBackupFileName('script.ps1')
            $result | Should -Match '^script\.ps1\.'
        }

        It 'Should end with .bak' {
            $result = [PSScriptBuilderFileSystemHelper]::NewBackupFileName('script.ps1')
            $result | Should -Match '\.bak$'
        }

        It 'Should match pattern filename.yyMMdd_HHmmss.bak' {
            $result = [PSScriptBuilderFileSystemHelper]::NewBackupFileName('script.ps1')
            $result | Should -Match '^script\.ps1\.\d{6}_\d{6}\.bak$'
        }

        It 'Should use only the filename from a full path' {
            $sep    = [System.IO.Path]::DirectorySeparatorChar
            $result = [PSScriptBuilderFileSystemHelper]::NewBackupFileName("some${sep}dir${sep}script.ps1")
            $result | Should -Match '^script\.ps1\.'
        }
    }
    #endregion NewBackupFileName

    #region GetTruncatedPath
    Context 'GetTruncatedPath' {

        It 'Should return path unchanged when within maxLength' {
            $path   = 'C:\short\path.txt'
            $result = [PSScriptBuilderFileSystemHelper]::GetTruncatedPath($path, 100)
            $result | Should -Be $path
        }

        It 'Should return path unchanged when exactly at maxLength' {
            $path   = 'C:\short\path.txt'
            $result = [PSScriptBuilderFileSystemHelper]::GetTruncatedPath($path, $path.Length)
            $result | Should -Be $path
        }

        It 'Should truncate a long path' {
            $path   = 'C:\Data\_GIT\Privat\PSScriptBuilder\src\Classes\ReleaseManagement\Managers\Deep\very_long_file.json'
            $result = [PSScriptBuilderFileSystemHelper]::GetTruncatedPath($path, 60)
            $result.Length | Should -BeLessOrEqual 60
        }

        It 'Should include ellipsis in truncated path' {
            $path   = 'C:\Data\_GIT\Privat\PSScriptBuilder\src\Classes\ReleaseManagement\Managers\Deep\very_long_file.json'
            $result = [PSScriptBuilderFileSystemHelper]::GetTruncatedPath($path, 60)
            $result | Should -Match '\.\.\.'
        }

        It 'Should handle path shorter than ellipsis gracefully' {
            $path   = 'C:\a\b\c\d\e\f\g\h\i\j\k\l.txt'
            $result = [PSScriptBuilderFileSystemHelper]::GetTruncatedPath($path, 10)
            $result | Should -Not -BeNullOrEmpty
        }
    }
    #endregion GetTruncatedPath
}

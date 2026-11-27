using namespace System.IO

Describe 'PSScriptBuilderFileSystemHelper' {

    BeforeAll {
        # PowerShell wraps an exception of a .NET call in MethodInvocationException, which
        # Should -Throw -ExceptionType does not unwrap
        Function Get-ThrownException {
            param([scriptblock] $ScriptBlock)
            try {
                & $ScriptBlock
            }
            catch {
                $exception = $_.Exception
                while ($exception -is [System.Management.Automation.MethodInvocationException] -and $null -ne $exception.InnerException) {
                    $exception = $exception.InnerException
                }
                return $exception
            }
            return $null
        }
    }

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

        It 'Should throw when a file already exists at the path' {
            $collidePath = Join-Path $TestDrive 'collide-dir'
            Set-Content -Path $collidePath -Value 'I am a file'

            { [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($collidePath) } |
                Should -Throw
        }

        It 'Should throw IOException naming the blocking file when it is a parent of the path' {
            $blocker  = Join-Path $TestDrive 'blocking-file.txt'
            Set-Content -Path $blocker -Value 'I am a file'
            $nested   = Join-Path $blocker 'sub'
            $expected = '*' + [WildcardPattern]::Escape($blocker) + '*'

            $thrown = Get-ThrownException { [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($nested) }

            $thrown         | Should -BeOfType ([IOException])
            $thrown.Message | Should -BeLike $expected
        }

        It 'Should throw ArgumentException for a relative path' {
            { [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists('relative-dir') } |
                Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage '*must be absolute*'
        }

        It 'Should throw ArgumentException for a <Case> path' -ForEach @(
            @{ Case = 'null';       Path = $null }
            @{ Case = 'empty';      Path = '' }
            @{ Case = 'whitespace'; Path = '   ' }
        ) {
            { [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($Path) } |
                Should -Throw -ExceptionType ([System.ArgumentException])
        }
    }
    #endregion EnsureDirectoryExists

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

    #region ResolveFileSystemPath
    Context 'ResolveFileSystemPath' {

        # Set-Location does not change the process working directory, against which .NET resolves
        # relative paths; Env: exists on every platform, unlike HKCU:
        BeforeAll {
            $script:Location = Join-Path $TestDrive 'resolve-location'
            $script:Process  = Join-Path $TestDrive 'resolve-process'
            New-Item -Path $script:Location, $script:Process -ItemType Directory -Force | Out-Null
        }

        BeforeEach {
            $script:SavedDirectory = [Environment]::CurrentDirectory
            [Environment]::CurrentDirectory = $script:Process
            Push-Location $script:Location
        }

        AfterEach {
            Pop-Location
            [Environment]::CurrentDirectory = $script:SavedDirectory
        }

        It 'Should resolve a relative path against the PowerShell location, not the process directory' {
            $result = [PSScriptBuilderFileSystemHelper]::ResolveFileSystemPath($ExecutionContext.SessionState.Path, (Join-Path '.' 'sub'))

            # GetFullPath expands an 8.3 short name in $TestDrive, as the method does
            $result | Should -Be ([Path]::GetFullPath((Join-Path $script:Location 'sub')))
        }

        It 'Should resolve . to the PowerShell location' {
            $result = [PSScriptBuilderFileSystemHelper]::ResolveFileSystemPath($ExecutionContext.SessionState.Path, '.')

            $result | Should -Be ([Path]::GetFullPath($script:Location))
        }

        It 'Should return an absolute path that does not exist unchanged' {
            $absolute = Join-Path $TestDrive 'does-not-exist'

            $result = [PSScriptBuilderFileSystemHelper]::ResolveFileSystemPath($ExecutionContext.SessionState.Path, $absolute)

            $result | Should -Be ([Path]::GetFullPath($absolute))
        }

        # Windows ignores the trailing space when the directory is created, but a path combined from the
        # unchanged result kept it and named a directory that does not exist
        It 'Should remove a trailing space from the last segment' -Skip:($env:OS -ne 'Windows_NT') {
            $result = [PSScriptBuilderFileSystemHelper]::ResolveFileSystemPath($ExecutionContext.SessionState.Path, ((Join-Path '.' 'sub') + ' '))

            $result | Should -Be ([Path]::GetFullPath((Join-Path $script:Location 'sub')))
        }

        It 'Should throw ArgumentException naming the provider for a path on another provider''s drive' {
            $thrown = Get-ThrownException { [PSScriptBuilderFileSystemHelper]::ResolveFileSystemPath($ExecutionContext.SessionState.Path, 'Env:\resolve-probe') }

            $thrown         | Should -BeOfType ([ArgumentException])
            $thrown.Message | Should -BeLike "*'Env:\resolve-probe'*Environment provider*not to a file system path*"
        }

        It 'Should throw ArgumentException for . while the current location is on another provider''s drive' {
            Push-Location 'Env:\'
            try {
                $thrown = Get-ThrownException { [PSScriptBuilderFileSystemHelper]::ResolveFileSystemPath($ExecutionContext.SessionState.Path, '.') }
            }
            finally {
                Pop-Location
            }

            $thrown         | Should -BeOfType ([ArgumentException])
            $thrown.Message | Should -BeLike '*Environment provider*'
        }
    }
    #endregion ResolveFileSystemPath

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

    #region GetProjectRelativePath
    Context 'GetProjectRelativePath' {

        BeforeAll {
            $Global:PSScriptBuilderProjectRoot = $TestDrive
        }

        AfterAll {
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return relative path when file is under project root' {
            $sep      = [System.IO.Path]::DirectorySeparatorChar
            $file     = Join-Path (Join-Path $TestDrive 'src') 'file.ps1'
            $expected = "src${sep}file.ps1"

            $result = [PSScriptBuilderFileSystemHelper]::GetProjectRelativePath($file)

            $result | Should -Be $expected
        }

        It 'Should return full path when file is outside project root' {
            $file = Join-Path ([System.IO.Path]::GetTempPath()) 'other' | Join-Path -ChildPath 'file.ps1'

            $result = [PSScriptBuilderFileSystemHelper]::GetProjectRelativePath($file)

            $result | Should -Be $file
        }

        It 'Should not match path with same prefix but different directory' {
            $parent     = [System.IO.Path]::GetDirectoryName($TestDrive.TrimEnd('\', '/'))
            $samePrefix = Join-Path $parent ($([System.IO.Path]::GetFileName($TestDrive.TrimEnd('\', '/'))) + '_backup')
            $file       = Join-Path (Join-Path $samePrefix 'src') 'file.ps1'

            $result = [PSScriptBuilderFileSystemHelper]::GetProjectRelativePath($file)

            $result | Should -Be $file
        }

        It 'Should return full path when project root is not set' {
            $Global:PSScriptBuilderProjectRoot = $null
            $file = Join-Path (Join-Path $TestDrive 'src') 'file.ps1'

            $result = [PSScriptBuilderFileSystemHelper]::GetProjectRelativePath($file)

            $result | Should -Be $file
            $Global:PSScriptBuilderProjectRoot = $TestDrive
        }

        It 'Should match case-insensitively' {
            $upper    = $TestDrive.ToUpper()
            $sep      = [System.IO.Path]::DirectorySeparatorChar
            $file     = Join-Path (Join-Path $upper 'src') 'file.ps1'
            $expected = "src${sep}file.ps1"

            $result = [PSScriptBuilderFileSystemHelper]::GetProjectRelativePath($file)

            $result | Should -Be $expected
        }

        It 'Should return empty string when given empty string' {
            $result = [PSScriptBuilderFileSystemHelper]::GetProjectRelativePath('')

            $result | Should -Be ''
        }

        It 'Should normalize backslashes in the input before comparing (regression: cross-platform input)' {
            $Global:PSScriptBuilderProjectRoot = 'C:\FakeProject'
            $file = 'C:\FakeProject\src\file.ps1'

            $result = [PSScriptBuilderFileSystemHelper]::GetProjectRelativePath($file)

            $result | Should -Be 'src\file.ps1'

            $Global:PSScriptBuilderProjectRoot = $TestDrive
        }
    }
    #endregion GetProjectRelativePath

    #region GetPathComparer
    Context 'GetPathComparer' {

        It 'Should return a StringComparer' {
            [PSScriptBuilderFileSystemHelper]::GetPathComparer() | Should -BeOfType ([System.StringComparer])
        }

        It 'Should ignore letter case on Windows' -Skip:($env:OS -ne 'Windows_NT') {
            $comparer = [PSScriptBuilderFileSystemHelper]::GetPathComparer()

            $comparer.Equals('C:\Project\File.TXT', 'c:\project\file.txt') | Should -BeTrue
        }

        It 'Should compare letter case on Unix-like systems' -Skip:($env:OS -eq 'Windows_NT') {
            $comparer = [PSScriptBuilderFileSystemHelper]::GetPathComparer()

            $comparer.Equals('/project/File.txt', '/project/file.txt') | Should -BeFalse
        }

        It 'Should still tell different paths apart' {
            $comparer = [PSScriptBuilderFileSystemHelper]::GetPathComparer()

            $comparer.Equals('C:\Project\one.txt', 'C:\Project\two.txt') | Should -BeFalse
        }
    }
    #endregion GetPathComparer
}

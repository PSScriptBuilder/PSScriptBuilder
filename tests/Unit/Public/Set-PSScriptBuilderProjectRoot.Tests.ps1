Describe 'Set-PSScriptBuilderProjectRoot' {

    AfterEach {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Parameter - Path' {

        It 'Should set the project root to an existing directory' {
            $root = Join-Path $TestDrive 'spr-existing'
            New-Item -Path $root -ItemType Directory -Force | Out-Null

            Set-PSScriptBuilderProjectRoot -Path $root

            # The root is stored with its full name, which expands an 8.3 short name in $TestDrive
            $Global:PSScriptBuilderProjectRoot | Should -Be ([System.IO.DirectoryInfo]::new($root).FullName)
        }

        # Resolve-Path -Path read the name as a wildcard pattern and silently set the root to App1
        It 'Should use a name with brackets as it is' {
            $parent = Join-Path $TestDrive 'spr-brackets'
            $root   = Join-Path $parent 'App[1]'
            New-Item -Path $root, (Join-Path $parent 'App1') -ItemType Directory -Force | Out-Null

            Set-PSScriptBuilderProjectRoot -Path $root

            $Global:PSScriptBuilderProjectRoot | Should -Be ([System.IO.DirectoryInfo]::new($root).FullName)
        }

        # Resolve-Path -Path matched both directories and set the root to an array; Windows PowerShell
        # 5.1 returns nothing for such a literal path, PowerShell 7 throws ItemNotFoundException
        It 'Should throw ItemNotFoundException for a wildcard pattern that matches several directories' {
            $parent = Join-Path $TestDrive 'spr-wildcard'
            New-Item -Path (Join-Path $parent 'sa'), (Join-Path $parent 'sb') -ItemType Directory -Force | Out-Null

            { Set-PSScriptBuilderProjectRoot -Path (Join-Path $parent 's*') } |
                Should -Throw -ExceptionType ([System.Management.Automation.ItemNotFoundException])
            $Global:PSScriptBuilderProjectRoot | Should -BeNullOrEmpty
        }

        # Such a path used to resolve silently to the current location
        It 'Should throw ArgumentException for a path of white space only' {
            { Set-PSScriptBuilderProjectRoot -Path '   ' } |
                Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage '*white space only*'
            $Global:PSScriptBuilderProjectRoot | Should -BeNullOrEmpty
        }

        # Windows ignores the trailing space, so the path is accepted, but every path combined from the
        # stored root kept it and named a directory that does not exist
        It 'Should store the root without a trailing space' -Skip:($env:OS -ne 'Windows_NT') {
            $root = Join-Path $TestDrive 'spr-trailing'
            New-Item -Path $root -ItemType Directory -Force | Out-Null

            Set-PSScriptBuilderProjectRoot -Path ($root + ' ')

            $Global:PSScriptBuilderProjectRoot | Should -Be ([System.IO.DirectoryInfo]::new($root).FullName)
        }

        # Files below a root stored as a short name are enumerated with their long names, so they no
        # longer matched the root
        It 'Should store the root without an 8.3 short name' -Skip:($env:OS -ne 'Windows_NT') {
            $root = Join-Path $TestDrive 'spr-long directory name'
            New-Item -Path $root -ItemType Directory -Force | Out-Null
            $shortPath = (New-Object -ComObject Scripting.FileSystemObject).GetFolder($root).ShortPath
            $longPath  = [System.IO.DirectoryInfo]::new($root).FullName

            if ($shortPath -eq $longPath) {
                Set-ItResult -Skipped -Because 'the drive of $TestDrive has no 8.3 short names'
                return
            }

            Set-PSScriptBuilderProjectRoot -Path $shortPath

            $Global:PSScriptBuilderProjectRoot | Should -Be $longPath
        }

        It 'Should throw when the path is a file' {
            $file = Join-Path $TestDrive 'spr-file.txt'
            Set-Content -Path $file -Value 'I am a file'

            { Set-PSScriptBuilderProjectRoot -Path $file } | Should -Throw -ExpectedMessage '*not a valid directory*'
            $Global:PSScriptBuilderProjectRoot | Should -BeNullOrEmpty
        }

        # A container of another provider (e.g. a registry key) passed the directory check, and its
        # provider path was set as the project root; Env: exists on every platform, unlike HKCU:
        It 'Should throw for a path on another provider''s drive' {
            { Set-PSScriptBuilderProjectRoot -Path 'Env:\' } |
                Should -Throw -ExpectedMessage '*Environment provider*not to a file system path*'
            $Global:PSScriptBuilderProjectRoot | Should -BeNullOrEmpty
        }
    }

    Context 'Pipeline input' {

        # Windows PowerShell 5.1 converts an item of Get-ChildItem to its name only, which was resolved
        # against the current location; the PSPath property names the full path
        It 'Should set the project root from Get-ChildItem output, independent of the current location' {
            $parent = Join-Path $TestDrive 'spr-pipeline'
            $root   = Join-Path $parent 'project'
            New-Item -Path $root -ItemType Directory -Force | Out-Null

            Push-Location 'Env:\'
            try {
                Get-ChildItem -LiteralPath $parent -Directory | Set-PSScriptBuilderProjectRoot
            }
            finally {
                Pop-Location
            }

            $Global:PSScriptBuilderProjectRoot | Should -Be ([System.IO.DirectoryInfo]::new($root).FullName)
        }
    }
}

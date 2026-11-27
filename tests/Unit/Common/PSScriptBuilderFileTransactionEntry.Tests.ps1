using namespace System
using namespace System.IO
using namespace System.Text

Describe 'PSScriptBuilderFileTransactionEntry' {

    BeforeAll {
        $script:Encoding = [UTF8Encoding]::new($true)

        Function New-TestFile {
            param([string] $Name, [string] $Content = 'old content')
            $path = Join-Path $TestDrive $Name
            [File]::WriteAllText($path, $Content, $script:Encoding)
            return $path
        }

        Function New-Entry {
            param(
                [PSScriptBuilderFileChangeType] $ChangeType = [PSScriptBuilderFileChangeType]::Replace,
                [string] $Path,
                [string] $NewContent = 'new content'
            )
            $expected = $null
            if ($ChangeType -eq [PSScriptBuilderFileChangeType]::Replace -and [File]::Exists($Path)) {
                $expected = [File]::ReadAllBytes($Path)
            }
            $newBytes = $script:Encoding.GetPreamble() + $script:Encoding.GetBytes($NewContent)
            return [PSScriptBuilderFileTransactionEntry]::new($ChangeType, $Path, $expected, [byte[]] $newBytes)
        }

        # PowerShell wraps exceptions of .NET calls in a MethodInvocationException
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

    Context 'Constructor' {

        It 'Should set all values' {
            $entry = [PSScriptBuilderFileTransactionEntry]::new([PSScriptBuilderFileChangeType]::Create, 'C:\x\file.txt', $null, [byte[]] (1, 2))

            $entry.ChangeType       | Should -Be ([PSScriptBuilderFileChangeType]::Create)
            $entry.Path             | Should -Be 'C:\x\file.txt'
            $entry.ExpectedBytes    | Should -BeNullOrEmpty
            $entry.NewBytes.Length  | Should -Be 2
        }
    }

    Context 'UnwrapException' {

        It 'Should return the inner exception of nested MethodInvocationExceptions' {
            $cause   = [IOException]::new('cause')
            $wrapped = [System.Management.Automation.MethodInvocationException]::new('outer', [System.Management.Automation.MethodInvocationException]::new('inner', $cause))

            [PSScriptBuilderFileTransactionEntry]::UnwrapException($wrapped) | Should -Be $cause
        }

        It 'Should return any other exception unchanged' {
            $exception = [InvalidOperationException]::new('plain')

            [PSScriptBuilderFileTransactionEntry]::UnwrapException($exception) | Should -Be $exception
        }
    }

    Context 'Open' {

        It 'Should open an existing file for Replace' {
            $entry = New-Entry -Path (New-TestFile 'open-replace.txt')
            try {
                { $entry.Open() } | Should -Not -Throw
            }
            finally {
                $entry.Close()
            }
        }

        It 'Should throw UnauthorizedAccessException for a read-only file' -Skip:($env:OS -ne 'Windows_NT' -and (& id -u) -eq '0') {
            $path = New-TestFile 'open-readonly.txt'
            (Get-Item $path).IsReadOnly = $true
            try {
                $entry  = New-Entry -Path $path
                $thrown = Get-ThrownException { $entry.Open() }
            }
            finally {
                (Get-Item $path).IsReadOnly = $false
            }

            $thrown | Should -BeOfType ([UnauthorizedAccessException])
        }

        It 'Should throw IOException for a file locked by another handle' -Skip:($env:OS -ne 'Windows_NT') {
            $path = New-TestFile 'open-locked.txt'
            $lock = [File]::Open($path, [FileMode]::Open, [FileAccess]::Read, [FileShare]::Read)
            try {
                $entry  = New-Entry -Path $path
                $thrown = Get-ThrownException { $entry.Open() }
            }
            finally {
                $lock.Dispose()
            }

            $thrown | Should -BeOfType ([IOException])
        }

        It 'Should create the file and missing directories for Create' {
            $path  = [Path]::Combine($TestDrive, 'create-dir', 'sub', 'new.txt')
            $entry = New-Entry -ChangeType Create -Path $path
            $entry.Open()
            $entry.Close()

            Test-Path $path -PathType Leaf | Should -BeTrue
        }

        It 'Should throw IOException for Create when the file exists, and leave that file unchanged' {
            $path   = New-TestFile 'create-existing.txt' 'existing content'
            $entry  = New-Entry -ChangeType Create -Path $path
            $thrown = Get-ThrownException { $entry.Open() }
            $entry.DeleteIfCreated()

            $thrown | Should -BeOfType ([IOException])
            [File]::ReadAllText($path) | Should -Be 'existing content'
        }
    }

    Context 'IsUnchanged' {

        It 'Should return <Expected> when the file <Case>' -ForEach @(
            @{ Case = 'is unchanged';         Change = $null;                  Expected = $true }
            @{ Case = 'was changed';          Change = 'other content';        Expected = $false }
            @{ Case = 'got longer';           Change = 'old content and more'; Expected = $false }
            @{ Case = 'was emptied';          Change = '';                     Expected = $false }
        ) {
            $path  = New-TestFile ("unchanged-$($Case -replace '\W', '').txt")
            $entry = New-Entry -Path $path
            if ($null -ne $Change) {
                [File]::WriteAllText($path, $Change)
            }

            $entry.Open()
            try {
                $entry.IsUnchanged() | Should -Be $Expected
            }
            finally {
                $entry.Close()
            }
        }

        It 'Should return $true for an empty file expected empty' {
            $path = Join-Path $TestDrive 'unchanged-empty.txt'
            [File]::WriteAllBytes($path, [byte[]]::new(0))
            $entry = [PSScriptBuilderFileTransactionEntry]::new([PSScriptBuilderFileChangeType]::Replace, $path, [byte[]]::new(0), [byte[]] (65))

            $entry.Open()
            try {
                $entry.IsUnchanged() | Should -BeTrue
            }
            finally {
                $entry.Close()
            }
        }
    }

    Context 'Backup, Write, Restore' {

        It 'Should write the backup next to the file with the original content' {
            $path  = New-TestFile 'backup.txt'
            $entry = New-Entry -Path $path
            $entry.Open()
            try {
                $entry.Backup()
            }
            finally {
                $entry.Close()
            }

            $backup = $path + '.psscriptbuilder-backup'
            [File]::ReadAllText($backup) | Should -Be 'old content'
            $entry.RemoveBackup()
            Test-Path $backup | Should -BeFalse
        }

        It 'Should throw IOException and leave an existing backup untouched' {
            $path   = New-TestFile 'backup-existing.txt'
            $backup = $path + '.psscriptbuilder-backup'
            [File]::WriteAllText($backup, 'backup of an earlier run')
            $entry  = New-Entry -Path $path

            $entry.Open()
            try {
                $thrown = Get-ThrownException { $entry.Backup() }
            }
            finally {
                $entry.Close()
            }
            $entry.RemoveBackup()

            $thrown | Should -BeOfType ([IOException])
            $thrown.Message | Should -BeLike '*already exists*previous run did not complete*'
            [File]::ReadAllText($backup) | Should -Be 'backup of an earlier run'
        }

        It 'Should write the new content and restore the original byte for byte' {
            $path     = New-TestFile 'write-restore.txt'
            $original = [File]::ReadAllBytes($path)
            $entry    = New-Entry -Path $path -NewContent 'brand new content'

            $entry.Open()
            try {
                $entry.Backup()
                $entry.Write()
                # The entry holds the file open for writing, so it is read with write sharing allowed
                $stream = [FileStream]::new($path, [FileMode]::Open, [FileAccess]::Read, [FileShare]::ReadWrite)
                try {
                    $written = [StreamReader]::new($stream).ReadToEnd()
                }
                finally {
                    $stream.Dispose()
                }
                $entry.Restore()
            }
            finally {
                $entry.Close()
            }
            $entry.RemoveBackup()

            $written | Should -Be 'brand new content'
            [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals([File]::ReadAllBytes($path), $original) | Should -BeTrue
        }

        # Outside Windows a creation time cannot be set: SetCreationTimeUtc changes the time of the
        # last write instead
        It 'Should keep the creation time when writing' -Skip:($env:OS -ne 'Windows_NT') {
            $path = New-TestFile 'write-creation.txt'
            [File]::SetCreationTimeUtc($path, [datetime]::SpecifyKind([datetime] '2020-01-01', 'Utc'))
            $entry = New-Entry -Path $path

            $entry.Open()
            try {
                $entry.Write()
            }
            finally {
                $entry.Close()
            }

            (Get-Item $path).CreationTimeUtc.Year | Should -Be 2020
        }

        It 'Should update a hard link to the file as well' -Skip:($env:OS -ne 'Windows_NT') {
            $path = New-TestFile 'write-hardlink.txt'
            $link = Join-Path $TestDrive 'write-hardlink-other.txt'
            cmd /c mklink /H "$link" "$path" | Out-Null
            $entry = New-Entry -Path $path -NewContent 'seen by both links'

            $entry.Open()
            try {
                $entry.Write()
            }
            finally {
                $entry.Close()
            }

            [File]::ReadAllText($link) | Should -Be 'seen by both links'
        }
    }

    Context 'Close, DeleteIfCreated, RemoveBackup' {

        It 'Should allow Close before Open and more than once' {
            $entry = New-Entry -Path (New-TestFile 'close.txt')

            { $entry.Close(); $entry.Close() } | Should -Not -Throw
        }

        It 'Should delete a file it created' {
            $path  = Join-Path $TestDrive 'delete-created.txt'
            $entry = New-Entry -ChangeType Create -Path $path
            $entry.Open()
            $entry.Close()

            $entry.DeleteIfCreated()

            Test-Path $path | Should -BeFalse
        }

        It 'Should not delete a file it did not create' {
            $path  = New-TestFile 'delete-not-created.txt'
            $entry = New-Entry -Path $path

            $entry.DeleteIfCreated()

            Test-Path $path | Should -BeTrue
        }

        It 'Should not delete a backup it did not create' {
            $path   = New-TestFile 'remove-foreign-backup.txt'
            $backup = $path + '.psscriptbuilder-backup'
            [File]::WriteAllText($backup, 'foreign')
            $entry  = New-Entry -Path $path

            $entry.RemoveBackup()

            Test-Path $backup | Should -BeTrue
        }
    }
}

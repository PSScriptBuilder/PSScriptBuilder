using namespace System
using namespace System.IO
using namespace System.Text

Describe 'PSScriptBuilderFileTransaction' {

    BeforeAll {
        $script:Encoding = [UTF8Encoding]::new($true)

        # Derived classes that simulate failures which cannot be produced with real files once they
        # are open. They are defined at run time, because a class in this file could not derive from
        # a module type when the file is parsed.
        $definition = @'
class FailingEntry : PSScriptBuilderFileTransactionEntry {
    [bool] $FailWrite
    [bool] $FailRestore

    FailingEntry([PSScriptBuilderFileChangeType] $changeType, [string] $path, [byte[]] $expectedBytes, [byte[]] $newBytes) : base($changeType, $path, $expectedBytes, $newBytes) {
    }

    [void] Write() {
        if ($this.FailWrite) {
            # Write part of the content first, so the restore has to undo a partial write
            $this.Stream.SetLength(0)
            $this.Stream.Write($this.NewBytes, 0, 1)
            $this.Stream.Flush($true)
            throw [System.IO.IOException]::new('simulated write failure')
        }
        $this.WriteBytes($this.NewBytes)
    }

    [void] Restore() {
        if ($this.FailRestore) {
            throw [System.IO.IOException]::new("'$($this.Path)' could not be restored (simulated)")
        }
        $this.WriteBytes([System.IO.File]::ReadAllBytes($this.BackupPath))
    }
}

class FailingTransaction : PSScriptBuilderFileTransaction {
    [string[]] $FailWriteNames   = @()
    [string[]] $FailRestoreNames = @()

    hidden [PSScriptBuilderFileTransactionEntry] NewEntry([PSScriptBuilderFileChangeType] $changeType, [string] $path, [byte[]] $expectedBytes, [byte[]] $newBytes) {
        $entry = [FailingEntry]::new($changeType, $path, $expectedBytes, $newBytes)
        $name  = [System.IO.Path]::GetFileName($path)
        $entry.FailWrite   = $this.FailWriteNames -contains $name
        $entry.FailRestore = $this.FailRestoreNames -contains $name
        return $entry
    }
}
'@
        . ([scriptblock]::Create($definition))

        Function ConvertTo-Bytes {
            param([string] $Text)
            return [byte[]] ($script:Encoding.GetPreamble() + $script:Encoding.GetBytes($Text))
        }

        Function New-TestFile {
            param([string] $RelativePath, [string] $Content)
            $path = Join-Path $TestDrive $RelativePath
            $null = [Directory]::CreateDirectory([Path]::GetDirectoryName($path))
            [File]::WriteAllBytes($path, (ConvertTo-Bytes $Content))
            return $path
        }

        Function Get-Bytes {
            param([string] $Path)
            return [File]::ReadAllBytes($Path)
        }

        Function Test-SameBytes {
            param([byte[]] $Left, [byte[]] $Right)
            return [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($Left, $Right)
        }

        Function Get-Backups {
            return @(Get-ChildItem $TestDrive -Recurse -Force -Filter '*.psscriptbuilder-backup')
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

    AfterEach {
        Get-ChildItem $TestDrive -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
        Get-ChildItem $TestDrive -Force | Remove-Item -Recurse -Force
    }

    Context 'Commit - success' {

        It 'Should write every file and leave no backup' {
            $one = New-TestFile 'one.txt' 'one old'
            $two = New-TestFile 'two.txt' 'two old'
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $transaction.AddReplace($one, (Get-Bytes $one), (ConvertTo-Bytes 'one new'))
            $transaction.AddReplace($two, (Get-Bytes $two), (ConvertTo-Bytes 'two new'))

            $warnings = $transaction.Commit()

            Test-SameBytes (Get-Bytes $one) (ConvertTo-Bytes 'one new') | Should -BeTrue
            Test-SameBytes (Get-Bytes $two) (ConvertTo-Bytes 'two new') | Should -BeTrue
            (Get-Backups).Count  | Should -Be 0
            $null -eq $warnings  | Should -BeFalse
            $warnings.Count      | Should -Be 0
        }

        It 'Should create a new file in a missing directory' {
            $path = [Path]::Combine($TestDrive, 'new-dir', 'created.txt')
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $transaction.AddCreate($path, (ConvertTo-Bytes 'created'))

            $null = $transaction.Commit()

            Test-SameBytes (Get-Bytes $path) (ConvertTo-Bytes 'created') | Should -BeTrue
        }

        It 'Should do nothing for an empty transaction' {
            $transaction = [PSScriptBuilderFileTransaction]::new()

            $warnings = $transaction.Commit()

            $warnings.Count | Should -Be 0
        }

        It 'Should handle an empty file and empty new content' {
            $path = Join-Path $TestDrive 'empty.txt'
            [File]::WriteAllBytes($path, [byte[]]::new(0))
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $transaction.AddReplace($path, [byte[]]::new(0), [byte[]]::new(0))

            { $null = $transaction.Commit() } | Should -Not -Throw
            (Get-Bytes $path).Length | Should -Be 0
        }

        It 'Should write nothing to the verbose, warning or error stream' {
            $path = New-TestFile 'streams.txt' 'old'
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $transaction.AddReplace($path, (Get-Bytes $path), (ConvertTo-Bytes 'new'))

            $savedPreference          = $Global:VerbosePreference
            $Global:VerbosePreference = 'Continue'
            try {
                $streamed = @(& { $null = $transaction.Commit() } *>&1)
            }
            finally {
                $Global:VerbosePreference = $savedPreference
            }

            $streamed.Count | Should -Be 0
        }
    }

    Context 'Commit - stops before any file is changed' {

        It 'Should change no file when a later file <Case>' -ForEach @(
            @{ Case = 'is read-only';                  Kind = 'ReadOnly' }
            @{ Case = 'is locked by another handle';   Kind = 'Locked' }
            @{ Case = 'already exists for a Create';   Kind = 'Exists' }
            @{ Case = 'was changed after preparation'; Kind = 'Changed' }
            @{ Case = 'has a backup of an earlier run'; Kind = 'Backup' }
        ) {
            if ($Kind -eq 'Locked' -and $env:OS -ne 'Windows_NT') {
                Set-ItResult -Skipped -Because 'exclusive file locks are only enforced on Windows'
                return
            }
            if ($Kind -eq 'ReadOnly' -and $env:OS -ne 'Windows_NT' -and (& id -u) -eq '0') {
                Set-ItResult -Skipped -Because 'root may write a read-only file'
                return
            }

            $first  = New-TestFile 'first.txt' 'first old'
            $second = New-TestFile 'second.txt' 'second old'
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $transaction.AddReplace($first, (Get-Bytes $first), (ConvertTo-Bytes 'first new'))
            switch ($Kind) {
                'Exists' { $transaction.AddCreate($second, (ConvertTo-Bytes 'second new')) }
                default  { $transaction.AddReplace($second, (Get-Bytes $second), (ConvertTo-Bytes 'second new')) }
            }
            $firstBefore  = Get-Bytes $first
            $secondBefore = Get-Bytes $second

            $lock = $null
            switch ($Kind) {
                'ReadOnly' { (Get-Item $second).IsReadOnly = $true }
                'Locked'   { $lock = [File]::Open($second, [FileMode]::Open, [FileAccess]::Read, [FileShare]::Read) }
                'Changed'  { [File]::WriteAllBytes($second, (ConvertTo-Bytes 'edited meanwhile')); $secondBefore = Get-Bytes $second }
                'Backup'   { [File]::WriteAllText($second + '.psscriptbuilder-backup', 'earlier run') }
            }
            try {
                $thrown = Get-ThrownException { $null = $transaction.Commit() }
            }
            finally {
                if ($null -ne $lock) { $lock.Dispose() }
            }

            $thrown | Should -Not -BeNullOrEmpty
            Test-SameBytes (Get-Bytes $first) $firstBefore   | Should -BeTrue
            Test-SameBytes (Get-Bytes $second) $secondBefore | Should -BeTrue
            $ownBackups = @(Get-Backups | Where-Object { $Kind -ne 'Backup' -or $_.Name -ne 'second.txt.psscriptbuilder-backup' })
            $ownBackups.Count | Should -Be 0
            if ($Kind -eq 'Backup') {
                [File]::ReadAllText($second + '.psscriptbuilder-backup') | Should -Be 'earlier run'
            }
        }

        It 'Should report a changed file as InvalidOperationException' {
            $path = New-TestFile 'changed.txt' 'old'
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $transaction.AddReplace($path, (Get-Bytes $path), (ConvertTo-Bytes 'new'))
            [File]::WriteAllBytes($path, (ConvertTo-Bytes 'edited'))

            $thrown = Get-ThrownException { $null = $transaction.Commit() }

            $thrown | Should -BeOfType ([InvalidOperationException])
            $thrown.Message | Should -BeLike '*was changed after the changes were prepared*No file was changed*'
        }

        It 'Should delete a file it created when a later file cannot be opened' -Skip:($env:OS -ne 'Windows_NT' -and (& id -u) -eq '0') {
            $created  = Join-Path $TestDrive 'created-then-aborted.txt'
            $readOnly = New-TestFile 'readonly-after-create.txt' 'old'
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $transaction.AddCreate($created, (ConvertTo-Bytes 'new'))
            $transaction.AddReplace($readOnly, (Get-Bytes $readOnly), (ConvertTo-Bytes 'new'))
            (Get-Item $readOnly).IsReadOnly = $true

            $thrown = Get-ThrownException { $null = $transaction.Commit() }

            $thrown | Should -BeOfType ([IOException])
            $thrown.Message | Should -BeLike '*cannot be opened for writing*No file was changed*'
            Test-Path $created | Should -BeFalse
        }
    }

    Context 'Commit - failure while writing' {

        It 'Should restore every file byte for byte, also the partially written one, and leave no backup' {
            $first  = New-TestFile 'w-first.txt' 'first old'
            $second = New-TestFile 'w-second.txt' 'second old'
            $third  = New-TestFile 'w-third.txt' 'third old'
            $before = @{ First = Get-Bytes $first; Second = Get-Bytes $second; Third = Get-Bytes $third }
            $transaction = [FailingTransaction]::new()
            $transaction.FailWriteNames = @('w-second.txt')
            foreach ($path in $first, $second, $third) {
                $transaction.AddReplace($path, (Get-Bytes $path), (ConvertTo-Bytes 'new content'))
            }

            $thrown = Get-ThrownException { $null = $transaction.Commit() }

            $thrown | Should -BeOfType ([IOException])
            $thrown.Message | Should -BeLike '*All files were restored*'
            $thrown.InnerException.Message | Should -Be 'simulated write failure'
            Test-SameBytes (Get-Bytes $first) $before.First   | Should -BeTrue
            Test-SameBytes (Get-Bytes $second) $before.Second | Should -BeTrue
            Test-SameBytes (Get-Bytes $third) $before.Third   | Should -BeTrue
            (Get-Backups).Count | Should -Be 0
        }

        It 'Should delete a created file after a failure while writing' {
            $created = Join-Path $TestDrive 'w-created.txt'
            $failing = New-TestFile 'w-failing.txt' 'old'
            $transaction = [FailingTransaction]::new()
            $transaction.FailWriteNames = @('w-failing.txt')
            $transaction.AddCreate($created, (ConvertTo-Bytes 'new'))
            $transaction.AddReplace($failing, (Get-Bytes $failing), (ConvertTo-Bytes 'new'))

            $null = Get-ThrownException { $null = $transaction.Commit() }

            Test-Path $created | Should -BeFalse
        }

        # Two backups in one shared directory used to overwrite each other (RFC 0026, finding 6)
        It 'Should restore two files of the same name in different folders with their own content' {
            $one = New-TestFile 'one\same.txt' 'content of one'
            $two = New-TestFile 'two\same.txt' 'content of two'
            $failing = New-TestFile 'w-fail-last.txt' 'old'
            $transaction = [FailingTransaction]::new()
            $transaction.FailWriteNames = @('w-fail-last.txt')
            foreach ($path in $one, $two, $failing) {
                $transaction.AddReplace($path, (Get-Bytes $path), (ConvertTo-Bytes 'new content'))
            }

            $null = Get-ThrownException { $null = $transaction.Commit() }

            Test-SameBytes (Get-Bytes $one) (ConvertTo-Bytes 'content of one') | Should -BeTrue
            Test-SameBytes (Get-Bytes $two) (ConvertTo-Bytes 'content of two') | Should -BeTrue
        }

        It 'Should keep the backups and name them when restoring fails' {
            $first  = New-TestFile 'r-first.txt' 'first old'
            $second = New-TestFile 'r-second.txt' 'second old'
            $transaction = [FailingTransaction]::new()
            $transaction.FailWriteNames   = @('r-second.txt')
            $transaction.FailRestoreNames = @('r-first.txt')
            foreach ($path in $first, $second) {
                $transaction.AddReplace($path, (Get-Bytes $path), (ConvertTo-Bytes 'new content'))
            }

            $thrown = Get-ThrownException { $null = $transaction.Commit() }

            $thrown | Should -BeOfType ([IOException])
            $thrown.Message | Should -BeLike '*cleanup failed too*backups were kept*r-first.txt*'
            Test-Path ($first + '.psscriptbuilder-backup') | Should -BeTrue
            [File]::ReadAllText($first + '.psscriptbuilder-backup') | Should -Be 'first old'
        }
    }

    Context 'AddReplace and AddCreate' {

        It 'Should throw ArgumentException for a <Case> path' -ForEach @(
            @{ Case = 'null';     Path = $null }
            @{ Case = 'empty';    Path = '' }
            @{ Case = 'relative'; Path = 'relative\file.txt' }
        ) {
            $transaction = [PSScriptBuilderFileTransaction]::new()

            { $transaction.AddCreate($Path, [byte[]] (65)) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentNullException for missing <Case>' -ForEach @(
            @{ Case = 'expected bytes' }
            @{ Case = 'new bytes' }
        ) {
            $path = Join-Path $TestDrive 'null-bytes.txt'
            $transaction = [PSScriptBuilderFileTransaction]::new()

            if ($Case -eq 'expected bytes') {
                { $transaction.AddReplace($path, $null, [byte[]] (65)) } | Should -Throw -ExceptionType ([ArgumentNullException])
            }
            else {
                { $transaction.AddReplace($path, [byte[]] (65), $null) } | Should -Throw -ExceptionType ([ArgumentNullException])
            }
        }

        It 'Should reject the same file added twice' {
            $path = Join-Path $TestDrive 'twice.txt'
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $transaction.AddCreate($path, [byte[]] (65))

            { $transaction.AddCreate($path, [byte[]] (66)) } | Should -Throw -ExceptionType ([ArgumentException]) -ExpectedMessage '*more than once*'
        }

        It 'Should reject the same file added twice in a different letter case on Windows' -Skip:($env:OS -ne 'Windows_NT') {
            $path = Join-Path $TestDrive 'Twice-Case.txt'
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $transaction.AddCreate($path, [byte[]] (65))

            { $transaction.AddCreate($path.ToUpperInvariant(), [byte[]] (66)) } | Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should not allow adding files or committing again after Commit' {
            $transaction = [PSScriptBuilderFileTransaction]::new()
            $null = $transaction.Commit()

            { $transaction.AddCreate((Join-Path $TestDrive 'late.txt'), [byte[]] (65)) } | Should -Throw -ExceptionType ([InvalidOperationException])
            { $null = $transaction.Commit() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }
}

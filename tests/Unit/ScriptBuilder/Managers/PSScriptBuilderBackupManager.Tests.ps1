using namespace System
using namespace System.IO

Describe 'PSScriptBuilderBackupManager' {

    BeforeAll {
        Function New-SourceFile {
            param([string] $Path, [string] $Content = 'source content')
            [File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
        }
    }

    #region CreateBackup

    Context 'CreateBackup - parameter validation' {

        It 'Should throw ArgumentException when filePath is null or empty' {
            $backupDir = Join-Path $TestDrive 'backups'

            { [PSScriptBuilderBackupManager]::CreateBackup($null, $backupDir) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when filePath is whitespace' {
            $backupDir = Join-Path $TestDrive 'backups'

            { [PSScriptBuilderBackupManager]::CreateBackup('   ', $backupDir) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when backupDirectoryPath is null or empty' {
            $sourceFile = Join-Path $TestDrive 'source.ps1'
            New-SourceFile -Path $sourceFile

            { [PSScriptBuilderBackupManager]::CreateBackup($sourceFile, $null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when backupDirectoryPath is whitespace' {
            $sourceFile = Join-Path $TestDrive 'source-ws.ps1'
            New-SourceFile -Path $sourceFile

            { [PSScriptBuilderBackupManager]::CreateBackup($sourceFile, '   ') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'CreateBackup - file does not exist' {

        It 'Should return null when the source file does not exist' {
            $missing   = Join-Path $TestDrive 'does-not-exist.ps1'
            $backupDir = Join-Path $TestDrive 'backups-missing'

            $result = [PSScriptBuilderBackupManager]::CreateBackup($missing, $backupDir)

            $result | Should -BeNullOrEmpty
        }

        It 'Should not create the backup directory when the source file does not exist' {
            $missing   = Join-Path $TestDrive 'absent.ps1'
            $backupDir = Join-Path $TestDrive 'backups-absent'

            [PSScriptBuilderBackupManager]::CreateBackup($missing, $backupDir)

            Test-Path $backupDir | Should -BeFalse
        }
    }

    Context 'CreateBackup - successful backup' {

        It 'Should return a non-empty path when the source file exists' {
            $sourceFile = Join-Path $TestDrive 'script.ps1'
            $backupDir  = Join-Path $TestDrive 'backups-ok'
            New-SourceFile -Path $sourceFile

            $result = [PSScriptBuilderBackupManager]::CreateBackup($sourceFile, $backupDir)

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should create the backup file at the returned path' {
            $sourceFile = Join-Path $TestDrive 'script-created.ps1'
            $backupDir  = Join-Path $TestDrive 'backups-created'
            New-SourceFile -Path $sourceFile

            $result = [PSScriptBuilderBackupManager]::CreateBackup($sourceFile, $backupDir)

            Test-Path $result | Should -BeTrue
        }

        It 'Should create the backup directory when it does not exist' {
            $sourceFile = Join-Path $TestDrive 'script-newdir.ps1'
            $backupDir  = Join-Path $TestDrive 'backups-newdir'
            New-SourceFile -Path $sourceFile

            [PSScriptBuilderBackupManager]::CreateBackup($sourceFile, $backupDir) | Out-Null

            Test-Path $backupDir | Should -BeTrue
        }

        It 'Should store the backup inside the specified backup directory' {
            $sourceFile = Join-Path $TestDrive 'script-dir.ps1'
            $backupDir  = Join-Path $TestDrive 'backups-dir'
            New-SourceFile -Path $sourceFile

            $result = [PSScriptBuilderBackupManager]::CreateBackup($sourceFile, $backupDir)

            $result | Should -Match ([Regex]::Escape($backupDir))
        }

        It 'Should give the backup a .bak extension' {
            $sourceFile = Join-Path $TestDrive 'script-ext.ps1'
            $backupDir  = Join-Path $TestDrive 'backups-ext'
            New-SourceFile -Path $sourceFile

            $result = [PSScriptBuilderBackupManager]::CreateBackup($sourceFile, $backupDir)

            $result | Should -Match '\.bak$'
        }

        It 'Should preserve the original file name in the backup file name' {
            $sourceFile = Join-Path $TestDrive 'MyScript.ps1'
            $backupDir  = Join-Path $TestDrive 'backups-name'
            New-SourceFile -Path $sourceFile

            $result = [PSScriptBuilderBackupManager]::CreateBackup($sourceFile, $backupDir)

            [Path]::GetFileName($result) | Should -BeLike 'MyScript.ps1*'
        }

        It 'Should copy the source content to the backup file' {
            $expectedContent = 'backup content check'
            $sourceFile      = Join-Path $TestDrive 'content-check.ps1'
            $backupDir       = Join-Path $TestDrive 'backups-content'
            New-SourceFile -Path $sourceFile -Content $expectedContent

            $result          = [PSScriptBuilderBackupManager]::CreateBackup($sourceFile, $backupDir)
            $actualContent   = [File]::ReadAllText($result)

            $actualContent | Should -Be $expectedContent
        }
    }

    #endregion CreateBackup

    #region RestoreBackup

    Context 'RestoreBackup - parameter validation' {

        It 'Should throw ArgumentException when backupPath is null or empty' {
            $target = Join-Path $TestDrive 'target.ps1'

            { [PSScriptBuilderBackupManager]::RestoreBackup($null, $target) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when backupPath is whitespace' {
            $target = Join-Path $TestDrive 'target-ws.ps1'

            { [PSScriptBuilderBackupManager]::RestoreBackup('   ', $target) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when targetPath is null or empty' {
            $backup = Join-Path $TestDrive 'some.bak'
            New-SourceFile -Path $backup

            { [PSScriptBuilderBackupManager]::RestoreBackup($backup, $null) } |
                Should -Throw -ExceptionType ([ArgumentException])
        }

        It 'Should throw ArgumentException when targetPath is whitespace' {
            $backup = Join-Path $TestDrive 'some-ws.bak'
            New-SourceFile -Path $backup

            { [PSScriptBuilderBackupManager]::RestoreBackup($backup, '   ') } |
                Should -Throw -ExceptionType ([ArgumentException])
        }
    }

    Context 'RestoreBackup - backup file does not exist' {

        It 'Should throw FileNotFoundException when the backup file does not exist' {
            $missingBackup = Join-Path $TestDrive 'missing.bak'
            $target        = Join-Path $TestDrive 'restored.ps1'

            { [PSScriptBuilderBackupManager]::RestoreBackup($missingBackup, $target) } |
                Should -Throw -ExceptionType ([FileNotFoundException])
        }
    }

    Context 'RestoreBackup - successful restore' {

        It 'Should create the restored file at the target path' {
            $expectedContent = 'restored content'
            $backupFile      = Join-Path $TestDrive 'restore.bak'
            $targetFile      = Join-Path $TestDrive 'restored.ps1'
            New-SourceFile -Path $backupFile -Content $expectedContent

            [PSScriptBuilderBackupManager]::RestoreBackup($backupFile, $targetFile)

            Test-Path $targetFile | Should -BeTrue
        }

        It 'Should write the backup content to the target file' {
            $expectedContent = 'content to restore'
            $backupFile      = Join-Path $TestDrive 'restore-content.bak'
            $targetFile      = Join-Path $TestDrive 'restored-content.ps1'
            New-SourceFile -Path $backupFile -Content $expectedContent

            [PSScriptBuilderBackupManager]::RestoreBackup($backupFile, $targetFile)
            $actual = [File]::ReadAllText($targetFile)

            $actual | Should -Be $expectedContent
        }

        It 'Should overwrite an existing target file' {
            $backupFile  = Join-Path $TestDrive 'overwrite.bak'
            $targetFile  = Join-Path $TestDrive 'overwrite-target.ps1'
            New-SourceFile -Path $backupFile -Content 'new content'
            New-SourceFile -Path $targetFile -Content 'old content'

            [PSScriptBuilderBackupManager]::RestoreBackup($backupFile, $targetFile)
            $actual = [File]::ReadAllText($targetFile)

            $actual | Should -Be 'new content'
        }

        It 'Should retain the backup file after restore' {
            $backupFile = Join-Path $TestDrive 'retain.bak'
            $targetFile = Join-Path $TestDrive 'retain-target.ps1'
            New-SourceFile -Path $backupFile -Content 'retained'

            [PSScriptBuilderBackupManager]::RestoreBackup($backupFile, $targetFile)

            Test-Path $backupFile | Should -BeTrue
        }
    }

    #endregion RestoreBackup

    #region HasBackup

    Context 'HasBackup' {

        It 'Should return false when the path is null or empty' {
            [PSScriptBuilderBackupManager]::HasBackup($null) | Should -BeFalse
            [PSScriptBuilderBackupManager]::HasBackup('')   | Should -BeFalse
        }

        It 'Should return false when the backup file does not exist' {
            $missing = Join-Path $TestDrive 'nonexistent.bak'

            [PSScriptBuilderBackupManager]::HasBackup($missing) | Should -BeFalse
        }

        It 'Should return true when the backup file exists' {
            $backup = Join-Path $TestDrive 'exists.bak'
            New-SourceFile -Path $backup

            [PSScriptBuilderBackupManager]::HasBackup($backup) | Should -BeTrue
        }
    }

    #endregion HasBackup
}

using namespace System
using namespace System.Collections.Specialized
using namespace System.IO

Describe 'PSScriptBuilderBumpFilesProcessor' {

    BeforeAll {
        Function New-TokenMap {
            param([hashtable] $Tokens)
            $map = [OrderedDictionary]::new()
            foreach ($key in $Tokens.Keys) { $map[$key] = $Tokens[$key] }
            return $map
        }

        # Writes a file to TestDrive and returns its full path
        Function New-BumpFile {
            param([string] $Name, [string] $Content)
            $path = Join-Path $TestDrive $Name
            Set-Content -Path $path -Value $Content -Encoding UTF8 -NoNewline
            return $path
        }

        # Builds a minimal PSCustomObject bumpFiles config for one file
        Function New-SimpleConfig {
            param([string] $FilePath, [string[]] $Tokens)
            return [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path        = $FilePath
                        tokens      = $Tokens
                        description = 'Test simple mode'
                    }
                )
            }
        }

        Function New-RegexConfig {
            param([string] $FilePath, [string] $Pattern, [string[]] $Tokens)
            return [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path        = $FilePath
                        description = 'Test regex mode'
                        items       = @(
                            [PSCustomObject] @{
                                pattern = $Pattern
                                tokens  = $Tokens
                            }
                        )
                    }
                )
            }
        }

        Function New-Processor {
            param([PSCustomObject] $Config, [hashtable] $Tokens)
            return [PSScriptBuilderBumpFilesProcessor]::new($Config, (New-TokenMap $Tokens))
        }
    }

    Context 'Constructor' {

        It 'Should initialise BumpFilesConfig and TokenMap' {
            $path   = New-BumpFile 'dummy.txt' 'content'
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '1.0.0' }

            $proc.BumpFilesConfig | Should -Not -BeNullOrEmpty
            $proc.TokenMap['VERSION_FULL'] | Should -Be '1.0.0'
        }

        It 'Should create a ReplacementHelper instance' {
            $path   = New-BumpFile 'dummy.txt' 'content'
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '1.0.0' }

            $proc.ReplacementHelper | Should -Not -BeNullOrEmpty
        }
    }

    Context 'UpdateBumpFilesInMemory - Simple Mode' {

        It 'Should replace a placeholder and return the new content' {
            $path   = New-BumpFile 'module.ps1' "Version = '{{VERSION_FULL}}'"
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].newContent | Should -Be "Version = '2.0.0'"
        }

        It 'Should not write the file to disk (in-memory only)' {
            $path            = New-BumpFile 'module.ps1' "Version = '{{VERSION_FULL}}'"
            $originalContent = Get-Content $path -Raw
            $config          = New-SimpleConfig $path @('VERSION_FULL')
            $proc            = New-Processor $config @{ VERSION_FULL = '9.9.9' }

            $proc.UpdateBumpFilesInMemory() | Out-Null

            Get-Content $path -Raw | Should -Be $originalContent
        }

        It 'Should return TotalProcessed = 1 for one file' {
            $path   = New-BumpFile 'module.ps1' '{{VERSION_FULL}}'
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '1.0.0' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.TotalProcessed | Should -Be 1
        }

        It 'Should return an empty Changes list when content is unchanged' {
            $path   = New-BumpFile 'module.ps1' 'No placeholder here'
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '1.0.0' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes.Count | Should -Be 0
        }

        It 'Should process two separate files and count both' {
            $pathA = New-BumpFile 'fileA.ps1' '{{VERSION_FULL}}'
            $pathB = New-BumpFile 'fileB.ps1' '{{BUILD_DATE}}'

            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $pathA; tokens = @('VERSION_FULL') }
                    [PSCustomObject] @{ path = $pathB; tokens = @('BUILD_DATE') }
                )
            }
            $proc = New-Processor $config @{ VERSION_FULL = '1.0.0'; BUILD_DATE = '2026-03-19' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.TotalProcessed | Should -Be 2
            $result.Changes.Count  | Should -Be 2
        }

        It 'Should apply two entries for the same file sequentially (two-phase bumping)' {
            $path = New-BumpFile 'template.ps1' "Version : {{VERSION_FULL}}"

            # Phase 1: Simple Mode replaces the placeholder
            # Phase 2: Regex Mode would then update idempotently
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path   = $path
                        tokens = @('VERSION_FULL')
                    }
                    [PSCustomObject] @{
                        path  = $path
                        items = @(
                            [PSCustomObject] @{
                                pattern = "Version\s*:\s*({REGEX_VERSION_FULL})"
                                tokens  = @('VERSION_FULL')
                            }
                        )
                    }
                )
            }
            $proc   = New-Processor $config @{ VERSION_FULL = '3.0.0' }
            $result = $proc.UpdateBumpFilesInMemory()

            # Only one group (same file) -> TotalProcessed = 1
            $result.TotalProcessed | Should -Be 1
            $result.Changes[0].newContent | Should -Be "Version : 3.0.0"
        }
    }

    Context 'UpdateBumpFilesInMemory - Regex Mode' {

        It 'Should replace a regex capture group with token value' {
            $path   = New-BumpFile 'manifest.psd1' "ModuleVersion = '1.0.0'"
            $config = New-RegexConfig $path "ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'" @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.5.1' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].newContent | Should -Be "ModuleVersion = '2.5.1'"
        }

        It 'Should return empty Changes list when regex finds no match' {
            $path   = New-BumpFile 'manifest.psd1' "SomethingElse = 'value'"
            $config = New-RegexConfig $path "ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'" @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes.Count | Should -Be 0
        }

        It 'Should throw when regex mode token has empty value' {
            $path   = New-BumpFile 'manifest.psd1' "SomethingElse = 'value'"
            $config = New-RegexConfig $path "ModuleVersion\s*=\s*'({REGEX_VERSION_FULL})'" @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '' }

            { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    Context 'UpdateBumpFilesInMemory - Error Handling' {

        It 'Should throw InvalidOperationException when BumpFilesConfig is null' {
            $proc = [PSScriptBuilderBumpFilesProcessor]::new($null, (New-TokenMap @{ VERSION_FULL = '1.0.0' }))

            { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw when configured file does not exist' {
            $config = New-SimpleConfig (Join-Path $TestDrive 'nonexistent.ps1') @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '1.0.0' }

            { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw InvalidOperationException when bumpFile entry has neither tokens nor items' {
            $path   = New-BumpFile 'module.ps1' 'content'
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $path; description = 'Missing both' }
                )
            }
            $proc = New-Processor $config @{ VERSION_FULL = '1.0.0' }

            { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should throw when a token referenced in content is missing from TokenMap' {
            $path   = New-BumpFile 'module.ps1' '{{MISSING_TOKEN}}'
            $config = New-SimpleConfig $path @('MISSING_TOKEN')
            $proc   = New-Processor $config @{ VERSION_FULL = '1.0.0' }  # MISSING_TOKEN not in map

            { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }
}

using namespace System
using namespace System.IO

Describe 'PSScriptBuilderBumpFilesProcessor' {

    BeforeAll {
        Function New-TokenMap {
            param([hashtable] $Tokens)
            $map = [ordered] @{}
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

        It 'Should return each change as PSScriptBuilderBumpFileChange with the file path, both contents and the replacements' {
            $path   = New-BumpFile 'typed.ps1' "Version = '{{VERSION_FULL}}'"
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0' }

            $change = $proc.UpdateBumpFilesInMemory().Changes[0]

            $change                    | Should -BeOfType ([PSScriptBuilderBumpFileChange])
            $change.FilePath           | Should -Be $path
            $change.OriginalContent    | Should -Be "Version = '{{VERSION_FULL}}'"
            $change.NewContent         | Should -Be "Version = '2.0.0'"
            $change.ChangedItems.Count | Should -Be 1
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

        It 'Should not corrupt an earlier entrys inserted value with a later, unrelated tokens entry (RFC 0009)' {
            # GIT_BRANCH's own (git-permitted) value contains VERSION_FULL's placeholder text.
            # Entry 1 (GIT_BRANCH) runs first and inserts it; Entry 2 (VERSION_FULL) must not
            # re-scan and corrupt what Entry 1 just inserted.
            $path   = New-BumpFile 'module.ps1' 'Branch: {{GIT_BRANCH}}, Version: {{VERSION_FULL}}'
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $path; tokens = @('GIT_BRANCH') }
                    [PSCustomObject] @{ path = $path; tokens = @('VERSION_FULL') }
                )
            }
            $proc = New-Processor $config @{ GIT_BRANCH = 'feature/{{VERSION_FULL}}'; VERSION_FULL = '1.3.0' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].newContent | Should -Be 'Branch: feature/{{VERSION_FULL}}, Version: 1.3.0'
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

        It 'Should not corrupt an earlier items inserted value via an under-anchored later pattern (RFC 0009)' {
            # Item 1 (GIT_BRANCH) inserts 'feature/(1.3.0)' - which itself looks like a
            # VERSION_FULL match. Item 2's pattern has no distinguishing prefix, so it must not
            # touch the '(1.3.0)' that Item 1 just inserted - only the real 'Version: (...)' one.
            $path   = New-BumpFile 'module.ps1' 'Branch: (old-branch), Version: (0.0.0)'
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path  = $path
                        items = @(
                            [PSCustomObject] @{ pattern = "Branch: \(({REGEX_GIT_BRANCH})\)"; tokens = @('GIT_BRANCH') }
                            [PSCustomObject] @{ pattern = "\(({REGEX_VERSION_FULL})\)";        tokens = @('VERSION_FULL') }
                        )
                    }
                )
            }
            $proc = New-Processor $config @{ GIT_BRANCH = 'feature/(1.3.0)'; VERSION_FULL = '9.9.9' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].newContent | Should -Be 'Branch: (feature/(1.3.0)), Version: (9.9.9)'
        }

        It 'Should replace the same token at two different locations via two separate items (RFC 0009 non-regression)' {
            # Both items target the SAME token at different spots - must not be mistaken for a
            # cross-token collision and must not block either legitimate replacement.
            $path   = New-BumpFile 'module.ps1' 'A: {{VERSION_FULL}}, B: {{VERSION_FULL}}'
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path  = $path
                        items = @(
                            [PSCustomObject] @{ pattern = 'A: {{VERSION_FULL}}'; tokens = @('VERSION_FULL') }
                            [PSCustomObject] @{ pattern = 'B: {{VERSION_FULL}}'; tokens = @('VERSION_FULL') }
                        )
                    }
                )
            }
            $proc = New-Processor $config @{ VERSION_FULL = '1.0.0' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].newContent | Should -Be 'A: 1.0.0, B: 1.0.0'
        }
    }

    Context 'UpdateBumpFilesInMemory - Letter case (RFC 0027)' {

        It 'Should replace both spellings of a placeholder and report one changed item' {
            $path   = New-BumpFile 'both.ps1' 'A={{VERSION_FULL}} B={{version_full}}'
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0' }

            $change = $proc.UpdateBumpFilesInMemory().Changes[0]

            $change.NewContent         | Should -BeExactly 'A=2.0.0 B=2.0.0'
            $change.ChangedItems.Count | Should -Be 1
        }

        It 'Should replace a placeholder when the configuration names the token in lower case' {
            $path   = New-BumpFile 'configlower.ps1' 'A={{VERSION_FULL}}'
            $config = New-SimpleConfig $path @('version_full')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].NewContent | Should -BeExactly 'A=2.0.0'
        }

        It 'Should throw when a placeholder in another letter case names a token without a value' {
            $path     = New-BumpFile 'emptylower.ps1' 'P=[{{version_prerelease}}]'
            $config   = New-SimpleConfig $path @('VERSION_PRERELEASE')
            $proc     = New-Processor $config @{ VERSION_PRERELEASE = '' }
            $expected = "Failed to process bump file '$path': Token validation failed - " +
                        "Token 'VERSION_PRERELEASE' has no value (null or empty); " +
                        "written in the file as '{{version_prerelease}}'"

            $errorRecord = { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException]) -PassThru

            $errorRecord.Exception.Message | Should -BeExactly $expected
        }

        It 'Should name every spelling written in the file once, in the order of the file' {
            $path   = New-BumpFile 'spellings.ps1' 'A={{version_prerelease}} B={{VERSION_PRERELEASE}} C={{Version_Prerelease}} D={{version_prerelease}}'
            $config = New-SimpleConfig $path @('VERSION_PRERELEASE')
            $proc   = New-Processor $config @{ VERSION_PRERELEASE = '' }

            $errorRecord = { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException]) -PassThru

            $errorRecord.Exception.Message |
                Should -BeLikeExactly "*; written in the file as '{{version_prerelease}}', '{{VERSION_PRERELEASE}}', '{{Version_Prerelease}}'"
        }

        It 'Should not name the spelling when the file writes the token as the configuration does' {
            $path   = New-BumpFile 'samecase.ps1' 'P=[{{VERSION_PRERELEASE}}]'
            $config = New-SimpleConfig $path @('VERSION_PRERELEASE')
            $proc   = New-Processor $config @{ VERSION_PRERELEASE = '' }

            $errorRecord = { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException]) -PassThru

            $errorRecord.Exception.Message | Should -BeLikeExactly "*Token 'VERSION_PRERELEASE' has no value (null or empty)"
        }

        It 'Should name the configured token and the spelling in the file for a token that does not exist' {
            $path   = New-BumpFile 'unknown.ps1' 'X=[{{missing_token}}]'
            $config = New-SimpleConfig $path @('MISSING_TOKEN')
            $proc   = New-Processor $config @{ VERSION_FULL = '1.0.0' }

            $errorRecord = { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException]) -PassThru

            $errorRecord.Exception.Message |
                Should -BeLikeExactly "*Token 'MISSING_TOKEN' not found in TokenMap; written in the file as '{{missing_token}}'"
        }

        It 'Should report the first failing token in the order of the configuration' {
            $path   = New-BumpFile 'twofailing.ps1' 'B={{GIT_TAG}} A={{VERSION_PRERELEASE}}'
            $config = New-SimpleConfig $path @('VERSION_PRERELEASE', 'GIT_TAG')
            $proc   = New-Processor $config @{ VERSION_PRERELEASE = ''; GIT_TAG = '' }

            $errorRecord = { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException]) -PassThru

            $errorRecord.Exception.Message | Should -BeLikeExactly "*Token 'VERSION_PRERELEASE' has no value*"
        }

        It 'Should keep the original exception as inner exception' {
            $path   = New-BumpFile 'inner.ps1' 'X=[{{missing_token}}]'
            $config = New-SimpleConfig $path @('MISSING_TOKEN')
            $proc   = New-Processor $config @{ VERSION_FULL = '1.0.0' }

            $errorRecord = { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException]) -PassThru

            $validationException = $errorRecord.Exception.InnerException
            $validationException                | Should -BeOfType ([InvalidOperationException])
            $validationException.InnerException | Should -BeOfType ([System.Collections.Generic.KeyNotFoundException])
        }

        It 'Should not validate a token whose placeholder is not in the file' {
            $path   = New-BumpFile 'absent.ps1' 'A={{VERSION_FULL}}'
            $config = New-SimpleConfig $path @('VERSION_FULL', 'VERSION_PRERELEASE')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0'; VERSION_PRERELEASE = '' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].NewContent | Should -BeExactly 'A=2.0.0'
        }

        It 'Should not validate a token whose placeholder only occurs in a value inserted for another token' {
            # The first entry inserts text that looks like the placeholder of the second entry's
            # token. The replacement skips it (RFC 0009), so the validation must skip it as well.
            $path   = New-BumpFile 'inserted.ps1' 'Branch: {{GIT_BRANCH}}'
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $path; tokens = @('GIT_BRANCH') }
                    [PSCustomObject] @{ path = $path; tokens = @('VERSION_PRERELEASE') }
                )
            }
            $proc = New-Processor $config @{ GIT_BRANCH = 'feature/{{version_prerelease}}'; VERSION_PRERELEASE = '' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].NewContent | Should -BeExactly 'Branch: feature/{{version_prerelease}}'
        }

        It 'Should validate a token whose placeholder occurs in the file and in an inserted value' {
            $path   = New-BumpFile 'insertedandreal.ps1' 'Branch: {{GIT_BRANCH}} P={{VERSION_PRERELEASE}}'
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $path; tokens = @('GIT_BRANCH') }
                    [PSCustomObject] @{ path = $path; tokens = @('VERSION_PRERELEASE') }
                )
            }
            $proc = New-Processor $config @{ GIT_BRANCH = 'feature/{{version_prerelease}}'; VERSION_PRERELEASE = '' }

            $errorRecord = { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException]) -PassThru

            $errorRecord.Exception.Message | Should -BeLikeExactly "*Token 'VERSION_PRERELEASE' has no value (null or empty)"
        }

        It 'Should not join the entries of a nested tokens list into one token' {
            # A nested list must not be flattened into the token 'VERSION_MAJOR': that token has a
            # value, so the run would succeed and write the text of the list into the file.
            $path   = New-BumpFile 'nested.ps1' 'A={{VERSION_FULL}} B={{VERSION_MAJOR}}'
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $path; tokens = @('VERSION_FULL', @('VERSION_MAJOR')) }
                )
            }
            $proc = New-Processor $config @{ VERSION_FULL = '2.0.0'; VERSION_MAJOR = '2' }

            { $proc.UpdateBumpFilesInMemory() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }

        It 'Should report a change when a regex match differs from the token value only in letter case' {
            $path   = New-BumpFile 'caseonly.ps1' 'Prerelease=Beta'
            $config = New-RegexConfig $path 'Prerelease=({REGEX_VERSION_PRERELEASE})' @('VERSION_PRERELEASE')
            $proc   = New-Processor $config @{ VERSION_PRERELEASE = 'beta' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes.Count                 | Should -Be 1
            $result.Changes[0].NewContent         | Should -BeExactly 'Prerelease=beta'
            $result.Changes[0].ChangedItems.Count | Should -Be 1
        }

        It 'Should report no change when a regex match equals the token value exactly' {
            $path   = New-BumpFile 'equal.ps1' 'Prerelease=beta'
            $config = New-RegexConfig $path 'Prerelease=({REGEX_VERSION_PRERELEASE})' @('VERSION_PRERELEASE')
            $proc   = New-Processor $config @{ VERSION_PRERELEASE = 'beta' }
            Mock Write-Warning {} -ModuleName PSScriptBuilder

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes.Count | Should -Be 0
        }

        # Built from character codes, so that the test does not depend on the encoding of this file
        It 'Should report a change when a regex match differs from the token value only in <Case>' -ForEach @(
            @{ Case = 'the spelling of a sharp s';              File = 'sharps.txt'; Old = ('stra' + [char] 0x00DF + 'e'); New = 'strasse' }
            @{ Case = 'the Unicode form of an accented letter'; File = 'accent.txt'; Old = ('caf' + [char] 0x00E9);        New = ('cafe' + [char] 0x0301) }
            @{ Case = 'a soft hyphen';                          File = 'hyphen.txt'; Old = 'beta';                         New = ('beta' + [char] 0x00AD) }
        ) {
            $path   = New-BumpFile $File "Branch=$Old;"
            $config = New-RegexConfig $path 'Branch=(.+);' @('GIT_BRANCH')
            $proc   = New-Processor $config @{ GIT_BRANCH = $New }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes.Count | Should -Be 1
            [int[]] [char[]] $result.Changes[0].NewContent | Should -Be ([int[]] [char[]] "Branch=$New;")
        }

        It 'Should not name a spelling for a token of an items entry' {
            $path   = New-BumpFile 'items.ps1' 'P=[{{VERSION_PRERELEASE}}]'
            $config = New-RegexConfig $path 'P=[{{VERSION_PRERELEASE}}]' @('version_prerelease')
            $proc   = New-Processor $config @{ VERSION_PRERELEASE = '' }

            $errorRecord = { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([InvalidOperationException]) -PassThru

            $errorRecord.Exception.Message | Should -Not -BeLikeExactly '*written in the file as*'
        }
    }

    Context 'UpdateBumpFilesInMemory - Zero-Match Warning (RFC 0019)' {

        # -ModuleName is required, not optional: PSScriptBuilderBumpFilesProcessor is a class
        # living inside the PSScriptBuilder module (loaded via 'using module'). Its method body
        # resolves Write-Warning through that module's own scope, not the test file's - a Mock
        # without -ModuleName silently never intercepts it (see PSScriptBuilderCodeCoverageTranslator.Tests.ps1).

        It 'Should warn and produce no Changes entry when a Placeholder-mode entry matches nothing (already bumped by a prior run)' {
            $path   = New-BumpFile 'module.ps1' "Version = '1.0.0'"   # {{VERSION_FULL}} already gone
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '1.0.0' }
            Mock Write-Warning {} -ModuleName PSScriptBuilder

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes.Count | Should -Be 0
            Should -Invoke Write-Warning -Times 1 -ModuleName PSScriptBuilder `
                -ParameterFilter { $Message -match [regex]::Escape($path) }
        }

        It 'Should not warn when a Mixed Bump Mode pair has its Regex fallback match on a second run' {
            $path   = New-BumpFile 'template.ps1' "Version : 3.0.0"   # {{VERSION_FULL}} already gone; Regex still matches
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $path; tokens = @('VERSION_FULL') }
                    [PSCustomObject] @{
                        path  = $path
                        items = @(
                            [PSCustomObject] @{ pattern = "Version\s*:\s*({REGEX_VERSION_FULL})"; tokens = @('VERSION_FULL') }
                        )
                    }
                )
            }
            $proc = New-Processor $config @{ VERSION_FULL = '4.0.0' }
            Mock Write-Warning {} -ModuleName PSScriptBuilder

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].newContent | Should -Be "Version : 4.0.0"
            Should -Invoke Write-Warning -Times 0 -ModuleName PSScriptBuilder
        }

        It 'Should not warn when every configured entry matches and changes content' {
            $path   = New-BumpFile 'module.ps1' "Version = '{{VERSION_FULL}}'"
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0' }
            Mock Write-Warning {} -ModuleName PSScriptBuilder

            $proc.UpdateBumpFilesInMemory() | Out-Null

            Should -Invoke Write-Warning -Times 0 -ModuleName PSScriptBuilder
        }

        It 'Should not warn when a partial Regex fallback masks other, now-stale tokens (documents accepted limitation)' {
            # Models this project's own build/Release/psscriptbuilder.bumpconfig.json shape:
            # one Simple Mode entry with several tokens, and one Items/Regex entry that only
            # covers a subset of them. VERSION/BUILD_DATE have no fallback and go silently
            # stale; GIT_BRANCH's fallback still matches, so the file-level check sees a change
            # and never warns - this is the deliberately accepted "partial staleness" tradeoff.
            $path    = New-BumpFile 'module.psm1' "Version = 'OLD_VERSION'`nBuildDate = 'OLD_DATE'`nGitBranch = 'old-branch'"
            $config  = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $path; tokens = @('VERSION', 'BUILD_DATE', 'GIT_BRANCH') }
                    [PSCustomObject] @{
                        path  = $path
                        items = @(
                            [PSCustomObject] @{ pattern = "GitBranch\s*=\s*'({REGEX_GIT_BRANCH})'"; tokens = @('GIT_BRANCH') }
                        )
                    }
                )
            }
            $proc = New-Processor $config @{ VERSION = '9.9.9'; BUILD_DATE = '2026-09-29'; GIT_BRANCH = 'feature/x' }
            Mock Write-Warning {} -ModuleName PSScriptBuilder

            $result = $proc.UpdateBumpFilesInMemory()

            $result.Changes[0].newContent | Should -Be "Version = 'OLD_VERSION'`nBuildDate = 'OLD_DATE'`nGitBranch = 'feature/x'"
            Should -Invoke Write-Warning -Times 0 -ModuleName PSScriptBuilder
        }

        It 'Should warn only for the stale file when a run mixes stale and successfully-bumped files' {
            $staleFile = New-BumpFile 'stale.ps1' 'no placeholder here'
            $fileB     = New-BumpFile 'fileB.ps1' '{{VERSION_FULL}}'
            $fileC     = New-BumpFile 'fileC.ps1' '{{BUILD_DATE}}'
            $config    = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $staleFile; tokens = @('VERSION_FULL') }
                    [PSCustomObject] @{ path = $fileB; tokens = @('VERSION_FULL') }
                    [PSCustomObject] @{ path = $fileC; tokens = @('BUILD_DATE') }
                )
            }
            $proc = New-Processor $config @{ VERSION_FULL = '1.0.0'; BUILD_DATE = '2026-09-29' }
            Mock Write-Warning {} -ModuleName PSScriptBuilder

            $result = $proc.UpdateBumpFilesInMemory()

            $result.TotalProcessed | Should -Be 3
            $result.Changes.Count  | Should -Be 2
            Should -Invoke Write-Warning -Times 1 -ModuleName PSScriptBuilder `
                -ParameterFilter { $Message -match [regex]::Escape($staleFile) }
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

    Context 'UpdateBumpFilesInMemory - Reading and grouping (RFC 0026)' {

        It 'Should keep the exact bytes read from the file' {
            $path   = New-BumpFile 'bytes.ps1' "Version = '{{VERSION_FULL}}'"
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0' }

            $change = $proc.UpdateBumpFilesInMemory().Changes[0]

            [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($change.OriginalBytes, [File]::ReadAllBytes($path)) | Should -BeTrue
        }

        It 'Should read a UTF-16 file as before' {
            $path = Join-Path $TestDrive 'utf16.psd1'
            [File]::WriteAllText($path, "@{ ModuleVersion = '{{VERSION_FULL}}' }", [System.Text.UnicodeEncoding]::new($false, $true))
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0' }

            $change = $proc.UpdateBumpFilesInMemory().Changes[0]

            $change.OriginalContent | Should -BeExactly "@{ ModuleVersion = '{{VERSION_FULL}}' }"
            $change.NewContent      | Should -BeExactly "@{ ModuleVersion = '2.0.0' }"
        }

        It 'Should report invalid UTF-8 as an IOException naming the encoding' {
            $path = Join-Path $TestDrive 'ansi.txt'
            [File]::WriteAllText($path, ('Version ' + [char] 0xFC + ' {{VERSION_FULL}}'), [System.Text.Encoding]::GetEncoding(1252))
            $config = New-SimpleConfig $path @('VERSION_FULL')
            $proc   = New-Processor $config @{ VERSION_FULL = '2.0.0' }

            { $proc.UpdateBumpFilesInMemory() } |
                Should -Throw -ExceptionType ([IOException]) -ExpectedMessage '*invalid UTF-8 encoding*'
        }

        It 'Should group two entries for the same file in a different letter case into one change on Windows' -Skip:($env:OS -ne 'Windows_NT') {
            $path   = New-BumpFile 'grouped.ps1' "A = '{{VERSION_FULL}}'; B = '{{VERSION_MAJOR}}'"
            $config = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $path;                    tokens = @('VERSION_FULL') }
                    [PSCustomObject] @{ path = $path.ToUpperInvariant(); tokens = @('VERSION_MAJOR') }
                )
            }
            $proc = New-Processor $config @{ VERSION_FULL = '2.0.0'; VERSION_MAJOR = '2' }

            $result = $proc.UpdateBumpFilesInMemory()

            $result.TotalProcessed        | Should -Be 1
            $result.Changes.Count         | Should -Be 1
            $result.Changes[0].NewContent | Should -Be "A = '2.0.0'; B = '2'"
        }

        It 'Should process the files in the configured order' {
            $paths = foreach ($name in 'zeta.ps1', 'alpha.ps1', 'mid.ps1') {
                New-BumpFile $name "V = '{{VERSION_FULL}}'"
            }
            $config = [PSCustomObject] @{
                bumpFiles = @($paths | ForEach-Object { [PSCustomObject] @{ path = $_; tokens = @('VERSION_FULL') } })
            }
            $proc = New-Processor $config @{ VERSION_FULL = '2.0.0' }

            $result = $proc.UpdateBumpFilesInMemory()

            ($result.Changes | ForEach-Object { Split-Path $_.FilePath -Leaf }) -join ',' | Should -Be 'zeta.ps1,alpha.ps1,mid.ps1'
        }
    }
}

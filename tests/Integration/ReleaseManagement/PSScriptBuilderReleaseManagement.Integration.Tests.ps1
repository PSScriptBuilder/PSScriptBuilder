Describe 'ReleaseManagement Integration - Full Release Workflow' -Tag 'Integration' {

    BeforeAll {
        $script:ExampleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\examples\11-mixed-bump-mode')).Path
        $script:Fixture    = (Resolve-Path (Join-Path $PSScriptRoot '..\..\Fixtures\BumpFileStressTest')).Path
        $script:ModulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\build\Output\PSScriptBuilder.psd1')).Path
        $script:ShellExe   = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }

        Function New-ProjectCopy {
            param([string] $Name)
            $root = Join-Path $TestDrive $Name
            Copy-Item -Path $script:Fixture -Destination $root -Recurse
            return $root
        }

        Function Invoke-ChildCommand {
            param([string] $Root, [string] $Command, [string[]] $Answers = @())
            $scriptPath = Join-Path $TestDrive ([Guid]::NewGuid().ToString() + '.ps1')
            $newLine    = [Environment]::NewLine
            $lines      = @("using module '$script:ModulePath'", "Set-PSScriptBuilderProjectRoot -Path '$Root'", $Command)
            [System.IO.File]::WriteAllText($scriptPath, ($lines -join $newLine) + $newLine)
            # Not named $input - that is an automatic variable
            $stdin   = ($Answers -join $newLine) + $newLine
            # Windows PowerShell 5.1 turns each stderr line of a native command into an error
            # record, which the test runner's ErrorActionPreference Stop would make terminating
            $ErrorActionPreference = 'Continue'
            $output  = @($stdin | & $script:ShellExe -NoProfile -File $scriptPath 2>&1 | ForEach-Object { "$_" })
            # The host echoes every answer it reads: on Windows on a line of its own, on Linux at
            # the end of the prompt line, after its colon
            $prompts = 0
            if ($Answers.Count -gt 0) {
                $escaped = @($Answers | Select-Object -Unique | ForEach-Object { [regex]::Escape($_) })
                $pattern = '(^|:)\s*({0})$' -f ($escaped -join '|')
                $prompts = @($output | Where-Object { $_ -cmatch $pattern }).Count
            }
            $result  = [PSCustomObject] @{
                ExitCode = $LASTEXITCODE
                Output   = $output
                Prompts  = $prompts
            }
            return $result
        }
    }

    Context 'Get-PSScriptBuilderReleaseData - reads initial version from fixture' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-01'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:Data = Get-PSScriptBuilderReleaseData
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null result' {
            $script:Data | Should -Not -BeNullOrEmpty
        }

        It 'Should report initial full version as 1.0.0' {
            $script:Data.Version.Full | Should -Be '1.0.0'
        }

        It 'Should report initial patch version as 0' {
            $script:Data.Version.Patch | Should -Be 0
        }

        It 'Should report initial build number as 0' {
            $script:Data.Build.Number | Should -Be 0
        }
    }

    Context 'Test-PSScriptBuilderReleaseData - valid release data returns true' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-02'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:IsValid = Test-PSScriptBuilderReleaseData
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return true for a valid release data file' {
            $script:IsValid | Should -BeTrue
        }
    }

    Context 'Update-PSScriptBuilderReleaseData - patch bump increments version' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-03'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:Result = Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails
            $script:Updated = Get-PSScriptBuilderReleaseData
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null result' {
            $script:Result | Should -Not -BeNullOrEmpty
        }

        It 'Should report at least one operation performed' {
            $script:Result.TotalOperationsPerformed | Should -BeGreaterThan 0
        }

        It 'Should increment the patch version to 1' {
            $script:Updated.Version.Patch | Should -Be 1
        }

        It 'Should update the full version string to 1.0.1' {
            $script:Updated.Version.Full | Should -Be '1.0.1'
        }

        It 'Should increment the build number' {
            $script:Updated.Build.Number | Should -BeGreaterThan 0
        }
    }

    Context 'Get-PSScriptBuilderBumpConfiguration - returns configured bump files' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-04'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:BumpConfig = Get-PSScriptBuilderBumpConfiguration
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null configuration' {
            $script:BumpConfig | Should -Not -BeNullOrEmpty
        }

        It 'Should contain at least one bump file entry' {
            $script:BumpConfig.bumpFiles.Count | Should -BeGreaterThan 0
        }

        It 'Should reference AppConfig.psd1 as the bump target' {
            $script:BumpConfig.bumpFiles[0].path | Should -Match 'AppConfig\.psd1'
        }
    }

    Context 'Update-PSScriptBuilderBumpFiles - applies new version to AppConfig.psd1' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-05'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            # build/Output is excluded from git - create the bump target files as they would exist after a build
            $outputDir = [System.IO.Path]::Combine($script:Root, 'build', 'Output')
            [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($outputDir)
            $psd1Content = "@{`n    ModuleVersion = '1.0.0'`n    RootModule = 'AppConfig.psm1'`n    GUID = 'c3d4e5f6-a7b8-9012-cdef-123456789012'`n}"
            [System.IO.File]::WriteAllText(([System.IO.Path]::Combine($outputDir, 'AppConfig.psd1')), $psd1Content)

            # First bump the version to 1.0.1
            Update-PSScriptBuilderReleaseData -Patch | Out-Null

            # Then apply the new version to configured files
            $script:Result  = Update-PSScriptBuilderBumpFiles
            $script:PsdPath = [System.IO.Path]::Combine($script:Root, 'build', 'Output', 'AppConfig.psd1')
            $script:Content = Get-Content -Path $script:PsdPath -Raw
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null result' {
            $script:Result | Should -Not -BeNullOrEmpty
        }

        It 'Should report 2 files processed' {
            $script:Result.TotalFilesProcessed | Should -Be 2
        }

        It 'Should report 2 files modified' {
            $script:Result.TotalFilesModified | Should -Be 2
        }

        It 'Should update ModuleVersion in AppConfig.psd1 to 1.0.1' {
            $script:Content | Should -Match "ModuleVersion\s*=\s*'1\.0\.1'"
        }

        It 'Should not leave the old version placeholder in AppConfig.psd1' {
            $script:Content | Should -Not -Match "ModuleVersion\s*=\s*'1\.0\.0'"
        }
    }

    Context 'Update-PSScriptBuilderReleaseData - explicit version sets version directly' {

        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-06'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse
            $Global:PSScriptBuilderProjectRoot = $script:Root

            $script:Result  = Update-PSScriptBuilderReleaseData -Version '2.0.0'
            $script:Updated = Get-PSScriptBuilderReleaseData
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return a non-null result' {
            $script:Result | Should -Not -BeNullOrEmpty
        }

        It 'Should report at least one operation performed' {
            $script:Result.TotalOperationsPerformed | Should -BeGreaterThan 0
        }

        It 'Should set the full version to 2.0.0' {
            $script:Updated.Version.Full | Should -Be '2.0.0'
        }

        It 'Should set major version to 2' {
            $script:Updated.Version.Major | Should -Be 2
        }

        It 'Should set minor version to 0' {
            $script:Updated.Version.Minor | Should -Be 0
        }

        It 'Should set patch version to 0' {
            $script:Updated.Version.Patch | Should -Be 0
        }

        It 'Should not change the build number when -UpdateBuildDetails is not specified' {
            $script:Updated.Build.Number | Should -Be 0
        }
    }

    Context 'Update-PSScriptBuilderBumpFiles -WhatIf - does not fail or change anything (regression)' {

        <#
        This runs in a real, separate process rather than calling the cmdlet directly from this
        It block. The ambient -WhatIf of a cmdlet reaches the cmdlets called inside PowerShell
        classes through the preference-variable scope chain, which Pester's It block execution
        breaks (RFC 0022) - a real child process is unaffected and shows the behavior a user
        sees. Since RFC 0026 the classes no longer call such cmdlets; the test guards that
        -WhatIf still neither fails nor changes anything.
        #>
        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()
            $script:Root = Join-Path $TestDrive 'ctx-whatif'
            Copy-Item -Path $script:ExampleRoot -Destination $script:Root -Recurse

            $script:ManifestPath = Join-Path $script:Root 'build\Output\AppConfig.psd1'
            $script:ManifestBefore = Get-Content -Path $script:ManifestPath -Raw

            $modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\build\Output\PSScriptBuilder.psd1')).Path
            $shellExe   = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
            $command    = "using module '$modulePath'; Set-PSScriptBuilderProjectRoot -Path '$($script:Root)'; Update-PSScriptBuilderBumpFiles -WhatIf | Out-Null"

            & $shellExe -NoProfile -Command $command 2>&1 | Out-Null
            $script:ExitCode = $LASTEXITCODE
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should exit successfully without throwing' {
            $script:ExitCode | Should -Be 0
        }

        It 'Should not modify the bump target file' {
            $manifestAfter = Get-Content -Path $script:ManifestPath -Raw
            $manifestAfter | Should -Be $script:ManifestBefore
        }
    }

    Context 'Confirmation, -WhatIf and transactional writes in a separate process (RFC 0026)' {

        <#
        Prompts and -WhatIf output are only produced faithfully in a real process (see the context
        above). The answers to the prompts are passed through standard input; the process echoes
        every answer it reads, so the number of echoed answers is the number of prompts shown.
        Where the answer is echoed differs between Windows and Linux (see Invoke-ChildCommand).
        #>
        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()

            Function Get-FileHashes {
                param([string] $Root)
                $hashes = @{}
                Get-ChildItem $Root -Recurse -File -Force | Where-Object { $_.Extension -ne '.ps1' } | ForEach-Object {
                    $hashes[$_.FullName] = (Get-FileHash $_.FullName).Hash
                }
                return $hashes
            }

            Function Test-SameHashes {
                param([hashtable] $Before, [hashtable] $After)
                if ($Before.Count -ne $After.Count) { return $false }
                foreach ($key in $Before.Keys) {
                    if ($Before[$key] -ne $After[$key]) { return $false }
                }
                return $true
            }

            Function Get-BackupCount {
                param([string] $Root)
                $local = @(Get-ChildItem $Root -Recurse -Force -Filter '*.psscriptbuilder-backup').Count
                return $local
            }

            $script:TempBackupsBefore = @(Get-ChildItem ([System.IO.Path]::GetTempPath()) -Directory -Filter 'PSScriptBuilder_Backup_*').Count
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should list the bump files under -WhatIf without internal steps and change nothing' {
            $root   = New-ProjectCopy 'rfc26-whatif'
            $before = Get-FileHashes $root

            $run = Invoke-ChildCommand -Root $root -Command 'Update-PSScriptBuilderBumpFiles -WhatIf | Out-Null'

            $run.ExitCode | Should -Be 0
            $text = $run.Output -join [Environment]::NewLine
            $text | Should -BeLike '*What if: Updating * bump file(s):*'
            $text | Should -BeLike '*Manifest.psd1*'
            $text | Should -Not -BeLike '*Create Directory*'
            $text | Should -Not -BeLike '*Copy File*'
            Test-SameHashes $before (Get-FileHashes $root) | Should -BeTrue
            Get-BackupCount $root | Should -Be 0
        }

        It 'Should ask exactly once under -Confirm and change nothing when the answer is No' {
            $root   = New-ProjectCopy 'rfc26-confirm-no'
            $before = Get-FileHashes $root

            $run = Invoke-ChildCommand -Root $root -Command 'Update-PSScriptBuilderBumpFiles -Confirm | Out-Null' -Answers @('n', 'n', 'n')

            $run.ExitCode | Should -Be 0
            $run.Prompts  | Should -Be 1
            Test-SameHashes $before (Get-FileHashes $root) | Should -BeTrue
            Get-BackupCount $root | Should -Be 0
        }

        It 'Should ask exactly once under -Confirm and write all files when the answer is Yes' {
            $root = New-ProjectCopy 'rfc26-confirm-yes'

            $run = Invoke-ChildCommand -Root $root -Command 'Update-PSScriptBuilderBumpFiles -Confirm | Out-Null' -Answers @('y', 'y', 'y')

            $run.ExitCode | Should -Be 0
            $run.Prompts  | Should -Be 1
            Get-Content (Join-Path $root 'build\Output\Manifest.psd1') -Raw | Should -Match "ModuleVersion = '1\.0\.0'"
            Get-BackupCount $root | Should -Be 0
        }

        It 'Should not ask when no bump file changes' {
            $root = New-ProjectCopy 'rfc26-no-change'
            [System.IO.File]::WriteAllText((Join-Path $root 'plain.txt'), 'no placeholder here')
            $config = [PSCustomObject] @{ bumpFiles = @([PSCustomObject] @{ path = 'plain.txt'; tokens = @('VERSION') }) }
            [System.IO.File]::WriteAllText((Join-Path $root 'build\Release\psscriptbuilder.bumpconfig.json'), ($config | ConvertTo-Json -Depth 5))

            $run = Invoke-ChildCommand -Root $root -Command 'Update-PSScriptBuilderBumpFiles -Confirm -WarningAction SilentlyContinue | Out-Null' -Answers @('y', 'y')

            $run.ExitCode | Should -Be 0
            $run.Prompts  | Should -Be 0
        }

        It 'Should not ask when the release data does not change' {
            $root   = New-ProjectCopy 'rfc26-rd-no-change'
            $file   = Join-Path $root 'build\Release\psscriptbuilder.releasedata.json'
            $before = (Get-FileHash $file).Hash

            $run = Invoke-ChildCommand -Root $root -Command "Update-PSScriptBuilderReleaseData -Version '1.0.0' -Confirm | Out-Null" -Answers @('y', 'y')

            $run.ExitCode | Should -Be 0
            $run.Prompts  | Should -Be 0
            (Get-FileHash $file).Hash | Should -Be $before
        }

        # A failed preparation used to rewrite the release data file, also under -WhatIf
        It 'Should leave an invalid release data file untouched under -WhatIf' {
            $root = New-ProjectCopy 'rfc26-rd-invalid'
            $file = Join-Path $root 'build\Release\psscriptbuilder.releasedata.json'
            $data = Get-Content $file -Raw | ConvertFrom-Json
            $data.version.major = 'abc'
            [System.IO.File]::WriteAllText($file, ($data | ConvertTo-Json -Depth 10 -Compress))
            $before = (Get-FileHash $file).Hash

            $null = Invoke-ChildCommand -Root $root -Command 'Update-PSScriptBuilderReleaseData -Patch -WhatIf | Out-Null'

            (Get-FileHash $file).Hash | Should -Be $before
        }

        It 'Should ask exactly once when creating release data in a project without a release directory' {
            $root = New-ProjectCopy 'rfc26-new-rd'
            Remove-Item (Join-Path $root 'build\Release') -Recurse -Force

            $run = Invoke-ChildCommand -Root $root -Command 'New-PSScriptBuilderReleaseData -Confirm | Out-Null' -Answers @('y', 'y', 'y')

            $run.ExitCode | Should -Be 0
            $run.Prompts  | Should -Be 1
            Test-Path (Join-Path $root 'build\Release\psscriptbuilder.releasedata.json') | Should -BeTrue
        }

        # A returned warning that is not consumed ends up in the cmdlet's output, and an assigned one
        # may be dropped silently. Such a warning cannot be provoked from a test, so the source is
        # checked for every call being the head of a foreach loop that writes the warnings.
        It 'Should write every warning returned by <Method> in <Cmdlet>' -ForEach @(
            @{ Cmdlet = 'Update-PSScriptBuilderBumpFiles';   Method = 'PersistBumpFilesChanges' }
            @{ Cmdlet = 'Update-PSScriptBuilderReleaseData'; Method = 'PersistReleaseDataChanges' }
            @{ Cmdlet = 'New-PSScriptBuilderReleaseData';    Method = 'PersistReleaseDataChanges' }
        ) {
            $sourcePath = [System.IO.Path]::Combine($PSScriptRoot, '..', '..', '..', 'src', 'Public', "$Cmdlet.ps1")
            $ast        = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $sourcePath).Path, [ref] $null, [ref] $null)
            $calls      = @($ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                $node.Member.Value -eq $Method
            }, $true))

            # The call is wrapped in a CommandExpressionAst inside the loop head's PipelineAst
            $written = @($calls | Where-Object {
                $pipeline   = $_.Parent.Parent
                $loop       = $pipeline.Parent
                $isLoopHead = $loop -is [System.Management.Automation.Language.ForEachStatementAst] -and
                              [object]::ReferenceEquals($loop.Condition, $pipeline)
                $isLoopHead -and $null -ne $loop.Body.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Write-Warning'
                }, $true)
            })

            $calls.Count   | Should -BeGreaterThan 0
            $written.Count | Should -Be $calls.Count
        }

        It 'Should not have left any backup directory in the temp folder' {
            @(Get-ChildItem ([System.IO.Path]::GetTempPath()) -Directory -Filter 'PSScriptBuilder_Backup_*').Count |
                Should -Be $script:TempBackupsBefore
        }
    }

    Context 'Letter case and duplicate tokens through the cmdlets (RFC 0027)' {

        <#
        Each test runs its commands in a separate process on its own copy of the fixture, so that
        no project state is shared between the tests. The process prints one line per result; an
        error is printed as its message, so that a test sees the text and not the console layout.
        #>
        BeforeAll {
            [PSScriptBuilderConfiguration]::Reset()

            Function Set-ProjectFile {
                param([string] $Root, [string] $RelativePath, [string] $Content)
                [System.IO.File]::WriteAllText((Join-Path $Root $RelativePath), $Content)
            }

            Function Get-ProjectFile {
                param([string] $Root, [string] $RelativePath)
                return [System.IO.File]::ReadAllText((Join-Path $Root $RelativePath))
            }

            Function Set-BumpFiles {
                param([string] $Root, [PSCustomObject[]] $BumpFiles)
                $config = [PSCustomObject] @{ bumpFiles = $BumpFiles }
                Set-ProjectFile $Root 'build\Release\psscriptbuilder.bumpconfig.json' ($config | ConvertTo-Json -Depth 5)
            }

            Function Set-ReleaseDataValue {
                param([string] $Root, [string] $Section, [hashtable] $Values)
                $relativePath = 'build\Release\psscriptbuilder.releasedata.json'
                $data         = Get-ProjectFile $Root $relativePath | ConvertFrom-Json
                foreach ($property in $Values.Keys) {
                    $data.$Section.$property = $Values[$property]
                }
                Set-ProjectFile $Root $relativePath ($data | ConvertTo-Json -Depth 5)
            }

            $script:TestCommand   = 'Test-PSScriptBuilderBumpConfiguration -ErrorVariable problems -ErrorAction SilentlyContinue; ' +
                                    '$problems | ForEach-Object { "ERROR: " + $_.Exception.Message }'
            $script:UpdateCommand = 'try { $result = Update-PSScriptBuilderBumpFiles -ErrorAction Stop; "MODIFIED: " + $result.TotalFilesModified } ' +
                                    'catch { "ERROR: " + $_.Exception.Message }'
        }

        AfterAll {
            [PSScriptBuilderConfiguration]::Reset()
            $Global:PSScriptBuilderProjectRoot = $null
        }

        It 'Should return false from Test-PSScriptBuilderBumpConfiguration and report every duplicated token' {
            $root = New-ProjectCopy 'rfc27-test-duplicates'
            Set-BumpFiles $root @(
                [PSCustomObject] @{ path = 'a.txt'; tokens = @('VERSION', 'version') }
                [PSCustomObject] @{ path = 'b.txt'; items = @(
                    [PSCustomObject] @{ pattern = 'V=({REGEX_VERSION})-({REGEX_VERSION})'; tokens = @('VERSION', 'Version') }
                ) }
            )

            $run = Invoke-ChildCommand -Root $root -Command $script:TestCommand

            $errors = @($run.Output | Where-Object { $_ -clike 'ERROR: *' })
            $run.Output | Where-Object { $_ -cnotlike 'ERROR: *' } | Should -BeExactly 'False'
            $errors.Count | Should -Be 2
            $errors[0] | Should -MatchExactly ('^ERROR: ' + [regex]::Escape('{bumpFiles[0]}: '))
            $errors[0] | Should -BeLikeExactly "*Token 'VERSION' is listed more than once ('VERSION' and 'version')*"
            $errors[1] | Should -MatchExactly ('^ERROR: ' + [regex]::Escape('{bumpFiles[1].items[0]}: '))
            $errors[1] | Should -BeLikeExactly "*('VERSION' and 'Version')*use one item per capture group"
        }

        It 'Should reject a duplicated token in Update-PSScriptBuilderBumpFiles and change no file' {
            $root = New-ProjectCopy 'rfc27-update-duplicates'
            Set-BumpFiles $root @(
                [PSCustomObject] @{ path = 'first.txt'; tokens = @('VERSION') }
                [PSCustomObject] @{ path = 'second.txt'; tokens = @('VERSION', 'version') }
            )
            Set-ProjectFile $root 'first.txt' 'A={{VERSION}}'
            Set-ProjectFile $root 'second.txt' 'B={{VERSION}}'

            $run = Invoke-ChildCommand -Root $root -Command $script:UpdateCommand

            $run.Output | Should -BeLikeExactly "ERROR: *Token 'VERSION' is listed more than once ('VERSION' and 'version')*"
            Get-ProjectFile $root 'first.txt'  | Should -BeExactly 'A={{VERSION}}'
            Get-ProjectFile $root 'second.txt' | Should -BeExactly 'B={{VERSION}}'
        }

        It 'Should name the spelling in the file when a token without a value stops the update, and change no file' {
            $root = New-ProjectCopy 'rfc27-update-spelling'
            Set-BumpFiles $root @(
                [PSCustomObject] @{ path = 'first.txt'; tokens = @('VERSION') }
                [PSCustomObject] @{ path = 'second.txt'; tokens = @('VERSION_PRERELEASE') }
            )
            Set-ProjectFile $root 'first.txt' 'A={{VERSION}}'
            Set-ProjectFile $root 'second.txt' 'P=[{{version_prerelease}}]'

            $run = Invoke-ChildCommand -Root $root -Command $script:UpdateCommand

            $run.Output | Should -BeLikeExactly "ERROR: *Token 'VERSION_PRERELEASE' has no value (null or empty); written in the file as '{{version_prerelease}}'"
            Get-ProjectFile $root 'first.txt'  | Should -BeExactly 'A={{VERSION}}'
            Get-ProjectFile $root 'second.txt' | Should -BeExactly 'P=[{{version_prerelease}}]'
        }

        It 'Should replace every spelling of a placeholder' {
            $root = New-ProjectCopy 'rfc27-update-spellings'
            Set-BumpFiles $root @(
                [PSCustomObject] @{ path = 'spellings.txt'; tokens = @('version') }
            )
            Set-ProjectFile $root 'spellings.txt' 'A={{version}} B={{VERSION}} C={{Version}}'

            $run = Invoke-ChildCommand -Root $root -Command $script:UpdateCommand

            $run.Output | Should -BeExactly 'MODIFIED: 1'
            Get-ProjectFile $root 'spellings.txt' | Should -BeExactly 'A=1.0.0 B=1.0.0 C=1.0.0'
        }

        It 'Should leave an empty bump file alone without an error' {
            $root = New-ProjectCopy 'rfc27-update-empty'
            Set-BumpFiles $root @(
                [PSCustomObject] @{ path = 'empty.txt'; tokens = @('VERSION') }
            )
            Set-ProjectFile $root 'empty.txt' ''

            $run = Invoke-ChildCommand -Root $root -Command $script:UpdateCommand

            # The run warns that nothing matched; the console wraps that text, so only the result lines are checked
            $run.Output | Where-Object { $_ -clike 'ERROR: *' }    | Should -BeNullOrEmpty
            $run.Output | Where-Object { $_ -clike 'MODIFIED: *' } | Should -BeExactly 'MODIFIED: 0'
            Get-ProjectFile $root 'empty.txt' | Should -BeExactly ''
        }

        It 'Should write a bump file whose value changes in letter case only' {
            $root = New-ProjectCopy 'rfc27-update-caseonly'
            Set-ReleaseDataValue $root 'version' @{ prerelease = 'beta'; full = '1.0.0-beta' }
            Set-BumpFiles $root @(
                [PSCustomObject] @{ path = 'case.txt'; items = @(
                    [PSCustomObject] @{ pattern = 'Prerelease=({REGEX_VERSION_PRERELEASE})'; tokens = @('VERSION_PRERELEASE') }
                ) }
            )
            Set-ProjectFile $root 'case.txt' 'Prerelease=Beta'

            $run = Invoke-ChildCommand -Root $root -Command $script:UpdateCommand

            $run.Output | Should -BeExactly 'MODIFIED: 1'
            Get-ProjectFile $root 'case.txt' | Should -BeExactly 'Prerelease=beta'
        }

        # Built from character codes, so that the test does not depend on the encoding of this file
        It 'Should write a bump file whose value changes only in <Case>' -ForEach @(
            @{ Case = 'the spelling of a sharp s';              Name = 'rfc27-sharp-s'; Old = ('stra' + [char] 0x00DF + 'e'); New = 'strasse' }
            @{ Case = 'the Unicode form of an accented letter'; Name = 'rfc27-accent';  Old = ('caf' + [char] 0x00E9);        New = ('cafe' + [char] 0x0301) }
            @{ Case = 'a soft hyphen';                          Name = 'rfc27-hyphen';  Old = 'beta';                         New = ('beta' + [char] 0x00AD) }
        ) {
            $root = New-ProjectCopy $Name
            Set-ReleaseDataValue $root 'git' @{ branch = $New }
            Set-BumpFiles $root @(
                [PSCustomObject] @{ path = 'branch.txt'; items = @(
                    [PSCustomObject] @{ pattern = 'Branch=(.+);'; tokens = @('GIT_BRANCH') }
                ) }
            )
            Set-ProjectFile $root 'branch.txt' "Branch=$Old;"

            $run = Invoke-ChildCommand -Root $root -Command $script:UpdateCommand

            $run.Output | Should -BeExactly 'MODIFIED: 1'
            # Compared by character codes: Should would compare the texts by language rules
            [int[]] [char[]] (Get-ProjectFile $root 'branch.txt') | Should -Be ([int[]] [char[]] "Branch=$New;")
        }

        It 'Should list and write release data that changes in letter case only' {
            $root = New-ProjectCopy 'rfc27-releasedata-caseonly'
            Set-ReleaseDataValue $root 'version' @{ prerelease = 'Beta'; full = '1.0.0-Beta' }
            $command = '$result = Update-PSScriptBuilderReleaseData -Prerelease beta; ' +
                       'foreach ($change in $result.Changes["Version"]) { "{0}: {1} -> {2}" -f $change.Property, $change.OldValue, $change.NewValue }'

            $run = Invoke-ChildCommand -Root $root -Command $command

            $run.Output | Should -BeExactly @('prerelease: Beta -> beta', 'full: 1.0.0-Beta -> 1.0.0-beta')
            $written = Get-ProjectFile $root 'build\Release\psscriptbuilder.releasedata.json' | ConvertFrom-Json
            $written.version.prerelease | Should -BeExactly 'beta'
            $written.version.full       | Should -BeExactly '1.0.0-beta'
        }
    }
}

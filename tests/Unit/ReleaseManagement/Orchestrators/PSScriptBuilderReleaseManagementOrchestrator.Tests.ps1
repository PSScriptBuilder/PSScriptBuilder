using namespace System
using namespace System.Collections.Specialized
using namespace System.IO

Describe 'PSScriptBuilderReleaseManagementOrchestrator' {

    BeforeAll {
        # Create a temporary config JSON pointing to test files inside TestDrive. In a -replace
        # replacement a backslash is literal, so '\\' writes the JSON escape for one backslash.
        Function New-TestConfig {
            param([string] $TestRoot)
            $configPath    = Join-Path $TestRoot 'test.config.json'
            $rdPath        = Join-Path $TestRoot 'releasedata.json'
            $bumpPath      = Join-Path $TestRoot 'bump.json'

            $configJson = @"
{
    "release": {
        "dataFile": "$($rdPath -replace '\\', '\\')",
        "bumpConfigFile": "$($bumpPath -replace '\\', '\\')"
    },
    "build": {
        "outputPath":              "$($TestRoot -replace '\\', '\\')",
        "backupPath":              "$($TestRoot -replace '\\', '\\')",
        "templatePath":            "$($TestRoot -replace '\\', '\\')",
        "orderedComponentsKey":    "ORDERED_COMPONENTS",
        "backupEnabled":           false,
        "syntaxValidationEnabled": false
    }
}
"@
            [System.IO.File]::WriteAllText($configPath, $configJson, [System.Text.Encoding]::UTF8)
            return $configPath
        }

        Function New-ValidReleaseData {
            return [PSCustomObject] @{
                version = [PSCustomObject] @{
                    major         = 1
                    minor         = 2
                    patch         = 3
                    prerelease    = $null
                    buildmetadata = $null
                    full          = '1.2.3'
                }
                build = [PSCustomObject] @{
                    number    = 42
                    date      = '2026-03-19'
                    time      = '12:00:00'
                    timestamp = '2026-03-19T12:00:00Z'
                    year      = 2026
                    month     = 3
                    day       = 19
                    hour      = 12
                    minute    = 0
                    second    = 0
                }
                git = [PSCustomObject] @{
                    commit      = '3d98fc7aa57161661b75ada0d66ff9354326d99f'
                    commitShort = '3d98fc7'
                    branch      = 'main'
                    tag         = $null
                }
            }
        }

        Function New-ValidBumpConfig {
            return [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{
                        path   = 'some\file.ps1'
                        tokens = @('VERSION')
                    }
                )
            }
        }

        Function Write-JsonFile {
            param([string] $Path, [PSCustomObject] $Data)
            $json = $Data | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
        }

        Function Test-SameBytes {
            param([byte[]] $Left, [byte[]] $Right)
            return [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($Left, $Right)
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

        # Set project root so GetProjectRootedPath resolves relative paths from TestDrive
        $Global:PSScriptBuilderProjectRoot = $TestDrive

        # Inject a test-scoped configuration so the orchestrator constructor succeeds
        $script:ConfigPath = New-TestConfig -TestRoot $TestDrive
        $testConfig        = [PSScriptBuilderConfiguration]::new($script:ConfigPath)
        [PSScriptBuilderConfiguration]::Set($testConfig)
    }

    AfterAll {
        [PSScriptBuilderConfiguration]::Reset()
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'Constructor' {

        It 'Should initialise ReleaseDataFileManager with path from configuration' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            $orchestrator.ReleaseDataFileManager | Should -Not -BeNullOrEmpty
        }

        It 'Should initialise BumpConfigFileManager with path from configuration' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            $orchestrator.BumpConfigFileManager | Should -Not -BeNullOrEmpty
        }

        It 'Should leave processor properties as null after construction (lazy initialisation)' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            $orchestrator.ReleaseDataProcessor | Should -BeNullOrEmpty
            $orchestrator.BumpFilesProcessor   | Should -BeNullOrEmpty
        }

        It 'Should initialise validator properties eagerly after construction' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            $orchestrator.ReleaseDataValidator | Should -Not -BeNullOrEmpty
            $orchestrator.BumpFilesValidator   | Should -Not -BeNullOrEmpty
        }
    }

    Context 'GetReleaseDataTokenMap' {

        It 'Should throw ArgumentNullException when releaseData is null' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            { $orchestrator.GetReleaseDataTokenMap($null) } | Should -Throw
        }

        It 'Should return an OrderedDictionary' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result.GetType().Name | Should -Be 'OrderedDictionary'
        }

        It 'Should populate VERSION token correctly' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result['VERSION'] | Should -Be '1.2.3'
        }

        It 'Should populate VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH tokens correctly' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result['VERSION_MAJOR'] | Should -Be '1'
            $result['VERSION_MINOR'] | Should -Be '2'
            $result['VERSION_PATCH'] | Should -Be '3'
        }

        It 'Should populate BUILD_DATE token correctly' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result['BUILD_DATE'] | Should -Be '2026-03-19'
        }

        It 'Should populate BUILD_NUMBER token correctly' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result['BUILD_NUMBER'] | Should -Be '42'
        }

        It 'Should populate GIT_BRANCH token correctly' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result['GIT_BRANCH'] | Should -Be 'main'
        }

        It 'Should return empty string for null GIT_TAG token' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result['GIT_TAG'] | Should -BeNullOrEmpty
        }

        It 'Should zero-pad BUILD_DAY correctly' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result['BUILD_DAY'] | Should -Be '19'
        }

        It 'Should zero-pad BUILD_MONTH correctly' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result['BUILD_MONTH'] | Should -Be '03'
        }

        It 'Should zero-pad BUILD_HOUR correctly for single-digit hour' {
            $orchestrator    = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $releaseData     = New-ValidReleaseData
            $releaseData.build.hour = 5

            $result = $orchestrator.GetReleaseDataTokenMap($releaseData)

            $result['BUILD_HOUR'] | Should -Be '05'
        }
    }

    Context 'ValidateReleaseData' {

        It 'Should throw ArgumentNullException when releaseData is null' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            { $orchestrator.ValidateReleaseData($null) } | Should -Throw
        }

        It 'Should return $true for valid release data' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.ReleaseDataValidator = [PSScriptBuilderReleaseDataValidator]::new()
            $releaseData  = New-ValidReleaseData

            $result = $orchestrator.ValidateReleaseData($releaseData)

            $result | Should -BeTrue
        }
    }

    Context 'ValidateBumpConfiguration' {

        It 'Should throw ArgumentNullException when bumpConfig is null' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            { $orchestrator.ValidateBumpConfiguration($null) } | Should -Throw
        }

        It 'Should return $true for a valid bump configuration' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.BumpFilesValidator = [PSScriptBuilderBumpFilesValidator]::new()
            $bumpConfig   = New-ValidBumpConfig

            $result = $orchestrator.ValidateBumpConfiguration($bumpConfig)

            $result | Should -BeTrue
        }
    }

    Context 'LoadReleaseData' {

        It 'Should load and return release data when the file exists' {
            $rdPath = Join-Path $TestDrive 'releasedata.json'
            Write-JsonFile -Path $rdPath -Data (New-ValidReleaseData)

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $result       = $orchestrator.LoadReleaseData()

            $result               | Should -Not -BeNullOrEmpty
            $result.version.major | Should -Be 1
        }

        It 'Should throw when the release data file does not exist' {
            # Point config to a non-existent file by using a fresh config
            $missingPath    = Join-Path $TestDrive 'missing-rd.json'
            $bumpPath       = Join-Path $TestDrive 'bump.json'
            $missingCfgPath = Join-Path $TestDrive 'missing.config.json'

            $cfgJson = @"
{
    "release": {
        "dataFile": "$($missingPath -replace '\\', '\\')",
        "bumpConfigFile": "$($bumpPath -replace '\\', '\\')"
    },
    "build": {
        "outputPath":              "$($TestDrive -replace '\\', '\\')",
        "backupPath":              "$($TestDrive -replace '\\', '\\')",
        "templatePath":            "$($TestDrive -replace '\\', '\\')",
        "orderedComponentsKey":    "ORDERED_COMPONENTS",
        "backupEnabled":           false,
        "syntaxValidationEnabled": false
    }
}
"@
            [System.IO.File]::WriteAllText($missingCfgPath, $cfgJson, [System.Text.Encoding]::UTF8)
            $missingConfig = [PSScriptBuilderConfiguration]::new($missingCfgPath)
            [PSScriptBuilderConfiguration]::Set($missingConfig)

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            { $orchestrator.LoadReleaseData() } | Should -Throw

            # Restore normal test config
            $normalConfig = [PSScriptBuilderConfiguration]::new($script:ConfigPath)
            [PSScriptBuilderConfiguration]::Set($normalConfig)
        }
    }

    Context 'LoadBumpConfiguration' {

        It 'Should load and return bump config when the file exists' {
            $bumpPath = Join-Path $TestDrive 'bump.json'
            Write-JsonFile -Path $bumpPath -Data (New-ValidBumpConfig)

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $result       = $orchestrator.LoadBumpConfiguration()

            $result           | Should -Not -BeNullOrEmpty
            $result.bumpFiles | Should -Not -BeNullOrEmpty
        }
    }

    Context 'GetReleaseDataValidationErrors' {

        It 'Should return an array (empty when no validation has been run)' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.ReleaseDataValidator = [PSScriptBuilderReleaseDataValidator]::new()

            $errors = $orchestrator.GetReleaseDataValidationErrors()

            $errors | Should -BeNullOrEmpty
        }
    }

    Context 'GetBumpConfigurationValidationErrors' {

        It 'Should return an array (empty when no validation has been run)' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.BumpFilesValidator = [PSScriptBuilderBumpFilesValidator]::new()

            $errors = $orchestrator.GetBumpConfigurationValidationErrors()

            $errors | Should -BeNullOrEmpty
        }
    }

    Context 'ExecuteBumpFilesUpdate and PersistBumpFilesChanges (RFC 0026)' {

        BeforeEach {
            Write-JsonFile -Path (Join-Path $TestDrive 'releasedata.json') -Data (New-ValidReleaseData)
            Write-JsonFile -Path (Join-Path $TestDrive 'bump.json') -Data (New-ValidBumpConfig)
            $script:BumpFile = Join-Path $TestDrive 'some\file.ps1'
            $null = [Directory]::CreateDirectory((Split-Path $script:BumpFile))
            [File]::WriteAllText($script:BumpFile, "Version = '{{VERSION}}'", [System.Text.UTF8Encoding]::new($true))
        }

        AfterEach {
            (Get-Item $script:BumpFile).IsReadOnly = $false
        }

        It 'Should prepare the changes without writing a file or creating a backup' {
            $before      = [File]::ReadAllBytes($script:BumpFile)
            $tempBackups = @(Get-ChildItem ([Path]::GetTempPath()) -Directory -Filter 'PSScriptBuilder_Backup_*').Count

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $result       = $orchestrator.ExecuteBumpFilesUpdate()

            $result.TotalFilesModified | Should -Be 1
            Test-SameBytes ([File]::ReadAllBytes($script:BumpFile)) $before | Should -BeTrue
            @(Get-ChildItem $TestDrive -Recurse -Force -Filter '*.psscriptbuilder-backup').Count | Should -Be 0
            @(Get-ChildItem ([Path]::GetTempPath()) -Directory -Filter 'PSScriptBuilder_Backup_*').Count | Should -Be $tempBackups
        }

        It 'Should write the prepared change, leave no backup and clear the prepared changes' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.ExecuteBumpFilesUpdate()

            $warnings = $orchestrator.PersistBumpFilesChanges()

            [File]::ReadAllText($script:BumpFile) | Should -Be "Version = '1.2.3'"
            @(Get-ChildItem $TestDrive -Recurse -Force -Filter '*.psscriptbuilder-backup').Count | Should -Be 0
            $warnings.Count                               | Should -Be 0
            $orchestrator.PreparedBumpFileChanges.Count   | Should -Be 0
        }

        # A read-only target used to fail after other files were written, without any rollback
        It 'Should change no file when the bump file became read-only before writing' -Skip:($env:OS -ne 'Windows_NT' -and (& id -u) -eq '0') {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.ExecuteBumpFilesUpdate()
            $before       = [File]::ReadAllBytes($script:BumpFile)
            (Get-Item $script:BumpFile).IsReadOnly = $true

            $thrown = Get-ThrownException { $null = $orchestrator.PersistBumpFilesChanges() }

            $thrown | Should -BeOfType ([IOException])
            Test-SameBytes ([File]::ReadAllBytes($script:BumpFile)) $before | Should -BeTrue
        }

        It 'Should not overwrite a bump file changed after the preparation' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.ExecuteBumpFilesUpdate()
            [File]::WriteAllText($script:BumpFile, "Version = '{{VERSION}}' # edited")

            $thrown = Get-ThrownException { $null = $orchestrator.PersistBumpFilesChanges() }

            $thrown | Should -BeOfType ([InvalidOperationException])
            [File]::ReadAllText($script:BumpFile) | Should -Be "Version = '{{VERSION}}' # edited"
        }
    }

    Context 'ExecuteReleaseDataUpdate and PersistReleaseDataChanges (RFC 0026)' {

        BeforeEach {
            $script:ReleaseDataFile = Join-Path $TestDrive 'releasedata.json'
            Write-JsonFile -Path $script:ReleaseDataFile -Data (New-ValidReleaseData)
            Write-JsonFile -Path (Join-Path $TestDrive 'bump.json') -Data (New-ValidBumpConfig)
        }

        BeforeAll {
            Function New-VersionRequest {
                param([string] $Version)
                return [PSScriptBuilderReleaseDataOperationRequest]::new(
                    [PSScriptBuilderBumpType]::None,
                    $false, $false, $null, $null, $false, $false, $Version
                )
            }
        }

        # A failed preparation used to rewrite the file, also under -WhatIf
        It 'Should not touch the release data file when the preparation fails' {
            $data = New-ValidReleaseData
            $data.version.major = 'abc'
            Write-JsonFile -Path $script:ReleaseDataFile -Data $data
            $before = [File]::ReadAllBytes($script:ReleaseDataFile)

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            { $orchestrator.ExecuteReleaseDataUpdate((New-VersionRequest -Version '2.0.0')) } | Should -Throw
            Test-SameBytes ([File]::ReadAllBytes($script:ReleaseDataFile)) $before | Should -BeTrue
        }

        It 'Should write the updated release data and leave no backup' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.ExecuteReleaseDataUpdate((New-VersionRequest -Version '2.0.0'))

            $warnings = $orchestrator.PersistReleaseDataChanges()

            (Get-Content $script:ReleaseDataFile -Raw | ConvertFrom-Json).version.full | Should -Be '2.0.0'
            Test-Path ($script:ReleaseDataFile + '.psscriptbuilder-backup') | Should -BeFalse
            $warnings.Count | Should -Be 0
        }

        It 'Should not overwrite release data changed after the preparation' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.ExecuteReleaseDataUpdate((New-VersionRequest -Version '2.0.0'))
            Add-Content -Path $script:ReleaseDataFile -Value ' '
            $before = [File]::ReadAllBytes($script:ReleaseDataFile)

            $thrown = Get-ThrownException { $null = $orchestrator.PersistReleaseDataChanges() }

            $thrown | Should -BeOfType ([InvalidOperationException])
            Test-SameBytes ([File]::ReadAllBytes($script:ReleaseDataFile)) $before | Should -BeTrue
        }

        It 'Should report no change when the version is set to the current one' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.ExecuteReleaseDataUpdate((New-VersionRequest -Version '1.2.3'))

            $orchestrator.HasReleaseDataChanges() | Should -BeFalse
        }

        It 'Should report a change in letter case only' {
            $data = New-ValidReleaseData
            $data.version.prerelease = 'Beta'
            $data.version.full       = '1.2.3-Beta'
            Write-JsonFile -Path $script:ReleaseDataFile -Data $data

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.ExecuteReleaseDataUpdate((New-VersionRequest -Version '1.2.3-beta'))

            $orchestrator.HasReleaseDataChanges() | Should -BeTrue
        }

        It 'Should return the configured release data file path' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            $orchestrator.GetReleaseDataFilePath() | Should -Be $script:ReleaseDataFile
        }
    }

    Context 'CreateNewReleaseData and PersistReleaseDataChanges (RFC 0026)' {

        BeforeEach {
            $script:ReleaseDataFile = Join-Path $TestDrive 'releasedata.json'
            if (Test-Path $script:ReleaseDataFile) {
                Remove-Item $script:ReleaseDataFile -Force
            }
        }

        It 'Should create the release data file when none exists' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.CreateNewReleaseData($false)

            $null = $orchestrator.PersistReleaseDataChanges()

            (Get-Content $script:ReleaseDataFile -Raw | ConvertFrom-Json).version.full | Should -Be '0.1.0'
        }

        It 'Should overwrite an existing file with force' {
            Write-JsonFile -Path $script:ReleaseDataFile -Data (New-ValidReleaseData)
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.CreateNewReleaseData($true)

            $null = $orchestrator.PersistReleaseDataChanges()

            (Get-Content $script:ReleaseDataFile -Raw | ConvertFrom-Json).version.full | Should -Be '0.1.0'
        }

        It 'Should not overwrite a file that appeared after the preparation' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.CreateNewReleaseData($false)
            [File]::WriteAllText($script:ReleaseDataFile, 'created meanwhile')

            $thrown = Get-ThrownException { $null = $orchestrator.PersistReleaseDataChanges() }

            $thrown | Should -BeOfType ([IOException])
            [File]::ReadAllText($script:ReleaseDataFile) | Should -Be 'created meanwhile'
        }

        It 'Should not overwrite with force a file changed after the preparation' {
            Write-JsonFile -Path $script:ReleaseDataFile -Data (New-ValidReleaseData)
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $null         = $orchestrator.CreateNewReleaseData($true)
            [File]::WriteAllText($script:ReleaseDataFile, 'edited meanwhile')

            $thrown = Get-ThrownException { $null = $orchestrator.PersistReleaseDataChanges() }

            $thrown | Should -BeOfType ([InvalidOperationException])
            [File]::ReadAllText($script:ReleaseDataFile) | Should -Be 'edited meanwhile'
        }
    }

    Context 'ExecuteReleaseDataUpdate - Version parameter' {

        BeforeEach {
            $rdPath   = Join-Path $TestDrive 'releasedata.json'
            $bumpPath = Join-Path $TestDrive 'bump.json'
            Write-JsonFile -Path $rdPath   -Data (New-ValidReleaseData)
            Write-JsonFile -Path $bumpPath -Data (New-ValidBumpConfig)
        }

        It 'Should set version to the specified string' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, $null, $false, $false, '2.0.0'
            )

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.ExecuteReleaseDataUpdate($request) | Out-Null

            $orchestrator.ReleaseDataProcessor.ReleaseData.version.full | Should -Be '2.0.0'
        }

        It 'Should set major, minor, patch correctly from version string' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, $null, $false, $false, '3.1.4'
            )

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.ExecuteReleaseDataUpdate($request) | Out-Null

            $orchestrator.ReleaseDataProcessor.ReleaseData.version.major | Should -Be 3
            $orchestrator.ReleaseDataProcessor.ReleaseData.version.minor | Should -Be 1
            $orchestrator.ReleaseDataProcessor.ReleaseData.version.patch | Should -Be 4
        }

        It 'Should set prerelease from version string' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, $null, $false, $false, '1.0.0-beta.1'
            )

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.ExecuteReleaseDataUpdate($request) | Out-Null

            $orchestrator.ReleaseDataProcessor.ReleaseData.version.prerelease | Should -Be 'beta.1'
        }

        It 'Should count version setting as one operation performed' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, $null, $false, $false, '2.0.0'
            )

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $result = $orchestrator.ExecuteReleaseDataUpdate($request)

            $result.TotalOperationsPerformed | Should -Be 1
        }

        It 'Should not change version when Version is null' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, $null, $false, $false, $null
            )

            # Add an artificial operation so validation passes (at least one operation required)
            $request.UpdateBuildDetails = $true

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.ExecuteReleaseDataUpdate($request) | Out-Null

            $orchestrator.ReleaseDataProcessor.ReleaseData.version.full | Should -Be '1.2.3'
        }

        It 'Should apply explicit -Prerelease and -BuildMetadata over values from version string' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, 'alpha1', '2', $false, $false, '1.1.0-beta2+1'
            )

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.ExecuteReleaseDataUpdate($request) | Out-Null

            $orchestrator.ReleaseDataProcessor.ReleaseData.version.prerelease    | Should -Be 'alpha1'
            $orchestrator.ReleaseDataProcessor.ReleaseData.version.buildmetadata | Should -Be '2'
            $orchestrator.ReleaseDataProcessor.ReleaseData.version.full          | Should -Be '1.1.0-alpha1+2'
        }
    }

    Context 'ExecuteReleaseDataUpdate - null vs empty string normalization' {

        BeforeEach {
            # Write release data with empty strings for prerelease/buildmetadata (as produced by ConvertTo-Json on real files)
            $rdPath   = Join-Path $TestDrive 'releasedata.json'
            $bumpPath = Join-Path $TestDrive 'bump.json'
            $rdWithEmptyStrings = [PSCustomObject] @{
                version = [PSCustomObject] @{
                    major         = 1
                    minor         = 2
                    patch         = 3
                    prerelease    = ''
                    buildmetadata = ''
                    full          = '1.2.3'
                }
                build = [PSCustomObject] @{
                    number    = 42
                    date      = '2026-03-19'
                    time      = '12:00:00'
                    timestamp = '2026-03-19T12:00:00Z'
                    year      = 2026
                    month     = 3
                    day       = 19
                    hour      = 12
                    minute    = 0
                    second    = 0
                }
                git = [PSCustomObject] @{
                    commit      = '3d98fc7aa57161661b75ada0d66ff9354326d99f'
                    commitShort = '3d98fc7'
                    branch      = 'main'
                    tag         = 'v1.0.0'
                }
            }
            Write-JsonFile -Path $rdPath   -Data $rdWithEmptyStrings
            Write-JsonFile -Path $bumpPath -Data (New-ValidBumpConfig)
        }

        It 'Should not report prerelease as changed when original JSON has empty string and operation leaves it null' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::Patch,
                $false, $false, $null, $null, $false, $false, $null
            )

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $result = $orchestrator.ExecuteReleaseDataUpdate($request)

            $prereleaseChange = $result.Changes['Version'] | Where-Object { $_.Property -eq 'prerelease' }
            $prereleaseChange | Should -BeNullOrEmpty
        }

        It 'Should not report buildmetadata as changed when original JSON has empty string and operation leaves it null' {
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::Patch,
                $false, $false, $null, $null, $false, $false, $null
            )

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $result = $orchestrator.ExecuteReleaseDataUpdate($request)

            $buildmetadataChange = $result.Changes['Version'] | Where-Object { $_.Property -eq 'buildmetadata' }
            $buildmetadataChange | Should -BeNullOrEmpty
        }
    }

    Context 'ExecuteReleaseDataUpdate - Letter case (RFC 0027)' {

        It 'Should list the values of an update that change in letter case only' {
            $data = New-ValidReleaseData
            $data.version.prerelease = 'Beta'
            $data.version.full       = '1.2.3-Beta'
            Write-JsonFile -Path (Join-Path $TestDrive 'releasedata.json') -Data $data
            $request = [PSScriptBuilderReleaseDataOperationRequest]::new(
                [PSScriptBuilderBumpType]::None,
                $false, $false, $null, $null, $false, $false, '1.2.3-beta'
            )

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $result       = $orchestrator.ExecuteReleaseDataUpdate($request)

            $listed = foreach ($category in $result.Changes.Keys) {
                foreach ($change in $result.Changes[$category]) {
                    '{0}.{1}: {2} -> {3}' -f $category, $change.Property, $change.OldValue, $change.NewValue
                }
            }

            $listed | Should -BeExactly @('Version.prerelease: Beta -> beta', 'Version.full: 1.2.3-Beta -> 1.2.3-beta')
        }
    }
}

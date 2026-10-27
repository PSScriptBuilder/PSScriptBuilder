using namespace System
using namespace System.Collections.Specialized
using namespace System.IO

Describe 'PSScriptBuilderReleaseManagementOrchestrator' {

    BeforeAll {
        # Create a temporary config JSON pointing to test files inside TestDrive
        Function New-TestConfig {
            param([string] $TestRoot)
            $configPath    = Join-Path $TestRoot 'test.config.json'
            $rdPath        = Join-Path $TestRoot 'releasedata.json'
            $bumpPath      = Join-Path $TestRoot 'bump.json'

            $configJson = @"
{
    "release": {
        "dataFile": "$($rdPath -replace '\\', '\\\\')",
        "bumpConfigFile": "$($bumpPath -replace '\\', '\\\\')"
    },
    "build": {
        "outputPath":              "$($TestRoot -replace '\\', '\\\\')",
        "backupPath":              "$($TestRoot -replace '\\', '\\\\')",
        "templatePath":            "$($TestRoot -replace '\\', '\\\\')",
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
        "dataFile": "$($missingPath -replace '\\', '\\\\')",
        "bumpConfigFile": "$($bumpPath -replace '\\', '\\\\')"
    },
    "build": {
        "outputPath":              "$($TestDrive -replace '\\', '\\\\')",
        "backupPath":              "$($TestDrive -replace '\\', '\\\\')",
        "templatePath":            "$($TestDrive -replace '\\', '\\\\')",
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

    Context 'InitializeBumpFilesBackups' {

        It 'Should throw when a configured bump file does not exist' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $bumpConfig   = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = (Join-Path $TestDrive 'missing-file.ps1'); tokens = @('VERSION') }
                )
            }

            { $orchestrator.InitializeBumpFilesBackups($bumpConfig) } | Should -Throw
        }

        It 'Should create a backup copy of each configured bump file' {
            $filePath = Join-Path $TestDrive 'bumpme.ps1'
            Set-Content -Path $filePath -Value '# Version: 1.0.0' -Encoding UTF8

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $bumpConfig   = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $filePath; tokens = @('VERSION') }
                )
            }

            $orchestrator.InitializeBumpFilesBackups($bumpConfig)

            $orchestrator.BumpFilesBackups.Count                                          | Should -Be 1
            $orchestrator.BumpFilesBackups[0].originalPath                                | Should -Be $filePath
            Test-Path -Path $orchestrator.BumpFilesBackups[0].backupPath -PathType Leaf    | Should -BeTrue
        }

        It 'Should throw when creating a backup copy fails' {
            $filePath = Join-Path $TestDrive 'locked-bumpme.ps1'
            Set-Content -Path $filePath -Value '# Version: 1.0.0' -Encoding UTF8

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $bumpConfig   = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $filePath; tokens = @('VERSION') }
                )
            }

            # Lock the source file exclusively so Copy-Item cannot read it
            $fileStream = [File]::Open($filePath, 'Open', 'Read', 'None')
            try {
                { $orchestrator.InitializeBumpFilesBackups($bumpConfig) } | Should -Throw
            }
            finally {
                $fileStream.Close()
            }
        }
    }

    Context 'RollbackReleaseData' {

        It 'Should do nothing when no original release data was captured' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            { $orchestrator.RollbackReleaseData() } | Should -Not -Throw
        }

        It 'Should restore the release data file to the captured original state' {
            $rdPath       = Join-Path $TestDrive 'releasedata.json'
            $originalData = New-ValidReleaseData
            Write-JsonFile -Path $rdPath -Data $originalData

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.OriginalReleaseData = $originalData

            # Simulate an in-progress operation that modified the file and now needs rolling back
            $modifiedData = New-ValidReleaseData
            $modifiedData.version.full = '9.9.9'
            Write-JsonFile -Path $rdPath -Data $modifiedData

            $orchestrator.RollbackReleaseData()

            $restored = $orchestrator.ReleaseDataFileManager.Load()
            $restored.version.full | Should -Be '1.2.3'
        }

        It 'Should warn instead of throwing when persisting the rollback data fails' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $orchestrator.OriginalReleaseData = New-ValidReleaseData

            # Point the file manager at a path whose parent segment is itself an existing file,
            # so Save() cannot create the containing directory and must throw.
            $blockerFile = Join-Path $TestDrive 'rollback-blocker'
            Set-Content -Path $blockerFile -Value 'not a directory' -Encoding UTF8
            $orchestrator.ReleaseDataFileManager.ReleaseDataFilePath = Join-Path $blockerFile 'releasedata.json'

            $warnings = & { $orchestrator.RollbackReleaseData() } 3>&1

            $warnings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'RollbackBumpFiles' {

        It 'Should do nothing when no bump file backups exist' {
            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()

            { $orchestrator.RollbackBumpFiles() } | Should -Not -Throw
        }

        It 'Should restore an original file from its backup' {
            $filePath = Join-Path $TestDrive 'restore-target.ps1'
            Set-Content -Path $filePath -Value '# Version: 1.0.0' -Encoding UTF8

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $bumpConfig   = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $filePath; tokens = @('VERSION') }
                )
            }
            $orchestrator.InitializeBumpFilesBackups($bumpConfig)

            # Simulate the bump having modified the file
            Set-Content -Path $filePath -Value '# Version: 2.0.0' -Encoding UTF8

            $orchestrator.RollbackBumpFiles()

            Get-Content -Path $filePath -Raw | Should -Match 'Version: 1\.0\.0'
        }

        It 'Should warn instead of throwing when restoring a backup fails' {
            $targetDir = Join-Path $TestDrive 'unrestorable'
            $filePath  = Join-Path $targetDir 'target.ps1'
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            Set-Content -Path $filePath -Value '# Version: 1.0.0' -Encoding UTF8

            $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
            $bumpConfig   = [PSCustomObject] @{
                bumpFiles = @(
                    [PSCustomObject] @{ path = $filePath; tokens = @('VERSION') }
                )
            }
            $orchestrator.InitializeBumpFilesBackups($bumpConfig)

            # Remove the destination directory entirely so Copy-Item cannot restore into it
            Remove-Item -Path $targetDir -Recurse -Force

            $warnings = & { $orchestrator.RollbackBumpFiles() } 3>&1

            $warnings | Should -Not -BeNullOrEmpty
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

    Context 'BuildReleaseDataChanges - null vs empty string normalization' {

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
}

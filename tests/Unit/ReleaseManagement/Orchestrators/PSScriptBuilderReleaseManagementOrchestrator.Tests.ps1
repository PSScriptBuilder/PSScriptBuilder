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
    }
}

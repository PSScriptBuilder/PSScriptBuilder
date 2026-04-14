using namespace System
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.IO

#region Class PSScriptBuilderReleaseManagementOrchestrator
<#
.SYNOPSIS
    Orchestrates all release management operations.
.DESCRIPTION
    The PSScriptBuilderReleaseManagementOrchestrator class coordinates release management operations including 
    loading release data, validating changes, updating versions, applying bumps to files, and persisting changes 
    with support for automatic rollback in case of failures.
#>
class PSScriptBuilderReleaseManagementOrchestrator {
    #region Properties
    <#
    .SYNOPSIS
        Manages release data file I/O.
    .DESCRIPTION
        The ReleaseDataFileManager property holds an instance of PSScriptBuilderReleaseDataFileManager for handling 
        release data file operations.
    #>
    [PSScriptBuilderReleaseDataFileManager] $ReleaseDataFileManager

    <#
    .SYNOPSIS
        Manages bump configuration data.
    .DESCRIPTION
        The BumpConfigFileManager property holds an instance of PSScriptBuilderBumpConfigFileManager for handling 
        bump configuration file I/O operations.
    #>
    [PSScriptBuilderBumpConfigFileManager] $BumpConfigFileManager

    <#
    .SYNOPSIS
        Processes release data.
    .DESCRIPTION
        The ReleaseDataProcessor property holds an instance of PSScriptBuilderReleaseDataProcessor for processing release data 
        operations.
    #>
    [PSScriptBuilderReleaseDataProcessor] $ReleaseDataProcessor
    
    <#
    .SYNOPSIS
        Processes bump file data.
    .DESCRIPTION
        The BumpFilesProcessor property holds an instance of PSScriptBuilderBumpFilesProcessor for processing bump file 
        operations.
    #>
    [PSScriptBuilderBumpFilesProcessor] $BumpFilesProcessor

    <#
    .SYNOPSIS
        Validates release data.
    .DESCRIPTION
        The ReleaseDataValidator property holds an instance of PSScriptBuilderReleaseDataValidator for validating 
        release data before updates.
    #>
    [PSScriptBuilderReleaseDataValidator] $ReleaseDataValidator

    <#
    .SYNOPSIS
        Validates bump file configurations.
    .DESCRIPTION
        The BumpFilesValidator property holds an instance of PSScriptBuilderBumpFilesValidator for validating 
        bump file configurations before updates.
    #>
    [PSScriptBuilderBumpFilesValidator] $BumpFilesValidator

    <#
    .SYNOPSIS
        Snapshots of original release data for rollback.
    .DESCRIPTION
        The OriginalReleaseData property holds a snapshot of the release data before any operations are 
        performed. This snapshot is used to restore the original state in case of failures during the release 
        management process.
    #>
    hidden [PSCustomObject] $OriginalReleaseData

    <#
    .SYNOPSIS
        Collection of backup information for bump files rollback.
    .DESCRIPTION
        The BumpFilesBackups property holds a list of backup file mappings (originalPath, backupPath)
        created before applying tokens. Used to restore original files in case of failures.
    #>
    hidden [List[PSCustomObject]] $BumpFilesBackups

    <#
    .SYNOPSIS
        Collection of prepared bump file changes awaiting persistence.
    .DESCRIPTION
        The PreparedBumpFileChanges property holds a list of in-memory file changes (filePath, originalContent, newContent)
        prepared by UpdateBumpFilesInMemory(). These changes are persisted to disk only when confirmed via ShouldProcess.
    #>
    hidden [List[PSCustomObject]] $PreparedBumpFileChanges
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderReleaseManagementOrchestrator class.
    .DESCRIPTION
        The default constructor loads the PSScriptBuilder configuration automatically and initializes 
        the file managers with the configured paths. Processors and validators are created during 
        Execute() method execution with complete context (lazy initialization).
    .EXAMPLE
        $orchestrator = [PSScriptBuilderReleaseManagementOrchestrator]::new()
        $result = $orchestrator.ExecuteReleaseDataUpdate($request)
    #>
    PSScriptBuilderReleaseManagementOrchestrator() {
        # Load configuration
        $config = [PSScriptBuilderConfiguration]::GetCurrent()

        if ($null -eq $config.Release) {
            throw [InvalidOperationException]::new("Release management not configured in PSScriptBuilder configuration")
        }

        # Extract file paths from configuration
        $dataFilePath       = $config.Release.DataFile
        $bumpConfigFilePath = $config.Release.BumpConfigFile

        if ([string]::IsNullOrEmpty($dataFilePath)) {
            throw [InvalidOperationException]::new("ReleaseDataFile path not configured")
        }

        if ([string]::IsNullOrEmpty($bumpConfigFilePath)) {
            throw [InvalidOperationException]::new("BumpConfigFile path not configured")
        }

        # Initialize managers with paths from configuration
        $this.ReleaseDataFileManager = [PSScriptBuilderReleaseDataFileManager]::new($dataFilePath)
        $this.BumpConfigFileManager  = [PSScriptBuilderBumpConfigFileManager]::new($bumpConfigFilePath)

        # Validators are stateless schema validators with no external dependencies.
        # Initialized eagerly so the object is fully usable after construction
        # without requiring prior calls to Execute* methods.
        $this.ReleaseDataValidator = [PSScriptBuilderReleaseDataValidator]::new()
        $this.BumpFilesValidator   = [PSScriptBuilderBumpFilesValidator]::new()

        # Processors are stateful and require context data (release data, token map, bump config).
        # Initialized lazily via Initialize*Managers() before first use.
        $this.ReleaseDataProcessor = $null
        $this.BumpFilesProcessor   = $null

        # Initialize snapshot for original release data
        $this.OriginalReleaseData = $null

        # Initialize bump files backups collection
        $this.BumpFilesBackups = [List[PSCustomObject]]::new()

        # Initialize prepared bump file changes collection
        $this.PreparedBumpFileChanges = [List[PSCustomObject]]::new()
    }
    #endregion Constructors

    #region Methods
    #region Public Methods
    <#
    .SYNOPSIS
        Executes a release management operation with transactional semantics.
    .DESCRIPTION
        The ExecuteReleaseDataUpdate method orchestrates a complete release update operation including:
        1. Loading and snapshotting current release data
        2. Validating loaded release data
        3. Performing requested version updates in-memory
        4. Validating modified release data
        5. Building changes tracking information
        6. Automatic rollback on failure using original data snapshot
    .PARAMETER request
        PSScriptBuilderReleaseDataOperationRequest object specifying the operations to perform.
    .OUTPUTS
        Returns a PSScriptBuilderReleaseDataResult with operation result and details.
    #>
    [PSScriptBuilderReleaseDataResult] ExecuteReleaseDataUpdate([PSScriptBuilderReleaseDataOperationRequest] $request) {
        Write-Verbose "Executing release data update operation"
        $operationCount = 0

        try {
            # Step 1: Load and snapshot current data
            $this.OriginalReleaseData = $this.LoadReleaseData()

            # Initialize release data managers with original data (must be done before validation)
            $this.InitializeReleaseDataManagers($this.OriginalReleaseData)

            # Step 2: Validate loaded data
            if (-not $this.ReleaseDataValidator.Validate($this.OriginalReleaseData)) {
                $errors = $this.ReleaseDataValidator.GetErrors()
                $message = "Release data validation failed: $($errors -join ', ')"
                throw [InvalidOperationException]::new($message)
            }

            # Step 3: Perform the requested operations
            switch ($request.BumpType) {
                ([PSScriptBuilderBumpType]::Major) {
                    Write-Verbose "Bumping major version"
                    $this.ReleaseDataProcessor.BumpMajor()
                    $operationCount++
                }
                ([PSScriptBuilderBumpType]::Minor) {
                    Write-Verbose "Bumping minor version"
                    $this.ReleaseDataProcessor.BumpMinor()
                    $operationCount++
                }
                ([PSScriptBuilderBumpType]::Patch) {
                    Write-Verbose "Bumping patch version"
                    $this.ReleaseDataProcessor.BumpPatch()
                    $operationCount++
                }
            }

            if ($request.UpdateBuildDetails) {
                Write-Verbose "Updating build details"
                $this.ReleaseDataProcessor.UpdateBuildDetails()
                $operationCount++
            }

            if ($request.UpdateGitDetails) {
                Write-Verbose "Updating git details"
                $this.ReleaseDataProcessor.UpdateGitDetails()
                $operationCount++
            }

            if ($request.ClearPrerelease) {
                Write-Verbose "Clearing prerelease"
                $this.ReleaseDataProcessor.SetPrerelease($null)
                $operationCount++
            }
            elseif (-not [string]::IsNullOrEmpty($request.Prerelease)) {
                Write-Verbose "Setting prerelease: $($request.Prerelease)"
                $this.ReleaseDataProcessor.SetPrerelease($request.Prerelease)
                $operationCount++
            }

            if ($request.ClearBuildMetadata) {
                Write-Verbose "Clearing build metadata"
                $this.ReleaseDataProcessor.SetBuildMetadata($null)
                $operationCount++
            }
            elseif (-not [string]::IsNullOrEmpty($request.BuildMetadata)) {
                Write-Verbose "Setting build metadata: $($request.BuildMetadata)"
                $this.ReleaseDataProcessor.SetBuildMetadata($request.BuildMetadata)
                $operationCount++
            }

            if (-not [string]::IsNullOrEmpty($request.Version)) {
                Write-Verbose "Setting version: $($request.Version)"
                $this.ReleaseDataProcessor.SetVersion($request.Version)
                $operationCount++
            }

            # Get updated data from processor
            $releaseData = $this.ReleaseDataProcessor.ReleaseData

            # Step 4: Validate modified data
            Write-Verbose "Validating modified release data"

            if (-not $this.ReleaseDataValidator.Validate($releaseData)) {
                $errors  = $this.ReleaseDataValidator.GetErrors()
                $message = "Modified release data validation failed: $($errors -join ', ')"
                throw [InvalidOperationException]::new($message)
            }

            Write-Verbose "Modified release data validated successfully"

            # Step 5: Build changes tracking
            $changes = $this.BuildReleaseDataChanges($this.OriginalReleaseData, $releaseData)

            # Log operation summary with change counts
            $versionChangeCount = $changes['Version'].Count
            $buildChangeCount   = $changes['Build'].Count
            $gitChangeCount     = $changes['Git'].Count

            $versionText = [PSScriptBuilderTextHelper]::GetPluralForm($versionChangeCount, "change", "changes")
            $buildText   = [PSScriptBuilderTextHelper]::GetPluralForm($buildChangeCount, "change", "changes")
            $gitText     = [PSScriptBuilderTextHelper]::GetPluralForm($gitChangeCount, "change", "changes")

            $format  = "Release data update completed: {0} {1} in Version, {2} {3} in Build, {4} {5} in Git"
            $message = $format -f $versionChangeCount, $versionText, $buildChangeCount, $buildText, $gitChangeCount, $gitText
            Write-Verbose $message

            # Step 6: Build result (without persisting - caller decides when to persist)
            return [PSScriptBuilderReleaseDataResult]::new($operationCount, $changes)
        }
        catch {
            Write-Warning "ReleaseData update failed: $($_.Exception.Message)"

            # Attempt rollback
            $this.RollbackReleaseData()

            # Re-throw exception - caller handles via try-catch
            throw
        }
    }

    <#
    .SYNOPSIS
        Executes a bump files update operation with transactional semantics.
    .DESCRIPTION
        The ExecuteBumpFilesUpdate method orchestrates the bump files update operation including:
        1. Loading and validating bump configuration
        2. Initializing bump files processor with token map from current release data
        3. Creating backups of all configured bump files before modification
        4. Preparing token updates in-memory without persisting
        5. Building result with details of prepared changes
        6. Automatic rollback on failure using backups
    .OUTPUTS
        Returns a PSScriptBuilderBumpFilesResult with operation result and details.
    #>
    [PSScriptBuilderBumpFilesResult] ExecuteBumpFilesUpdate() {
        Write-Verbose "Executing bump files update operation"

        try {
            # Step 1: Load current bump configuration
            $bumpConfig = $this.LoadBumpConfiguration()

            # Initialize bump files managers (must be done with complete token map before validation)
            $this.InitializeBumpFilesManagers($bumpConfig)

            # Validate loaded bump configuration
            if (-not $this.BumpFilesValidator.Validate($bumpConfig)) {
                $errors  = $this.BumpFilesValidator.GetErrors()
                $message = "Bump files validation failed: $($errors -join ', ')"
                throw [InvalidOperationException]::new($message)
            }

            # Step 2: Perform bump files operations (in-memory only)
            # Create backups before preparing changes
            $this.InitializeBumpFilesBackups($bumpConfig)

            # Prepare token updates in-memory (no disk writes)
            $updateResult = $this.BumpFilesProcessor.UpdateBumpFilesInMemory()
            $this.PreparedBumpFileChanges = $updateResult.Changes

            # Build BumpDetails from prepared changes (only changed files are returned)
            $bumpDetails = @()

            foreach ($fileChange in $updateResult.Changes) {
                $bumpDetails += [PSCustomObject]@{
                    Path         = $fileChange.filePath
                    ChangedItems = $fileChange.changedItems
                }
            }

            # Log summary of prepared changes
            $processedCount = $updateResult.TotalProcessed
            $modifiedCount  = $updateResult.Changes.Count

            $processedText = [PSScriptBuilderTextHelper]::GetPluralForm($processedCount, "file", "files")
            $modifiedText  = [PSScriptBuilderTextHelper]::GetPluralForm($modifiedCount, "file", "files")

            $format  = "Bump files update completed: {0} {1} processed, {2} {3} modified"
            $message = [string]::Format($format, $processedCount, $processedText, $modifiedCount, $modifiedText)
            Write-Verbose $message

            # Step 3: Build result (without persisting - caller decides when to persist)
            return [PSScriptBuilderBumpFilesResult]::new(
                $updateResult.TotalProcessed,
                $updateResult.Changes.Count,
                $bumpDetails
            )
        }
        catch {
            Write-Warning "Bump files update failed: $($_.Exception.Message)"

            # Attempt rollback
            $this.RollbackBumpFiles()

            # Re-throw exception - caller handles via try-catch
            throw
        }
    }

    <#
    .SYNOPSIS
        Persists any pending release data changes to disk.
    .DESCRIPTION
        The PersistReleaseDataChanges method saves the modified release data from the ReleaseDataProcessor to 
        the release data file using the ReleaseDataFileManager. This method should only be called after either 
        ExecuteReleaseDataUpdate() or CreateNewReleaseData() has successfully computed the changes and the 
        caller has confirmed persistence via ShouldProcess. The method name reflects its generic purpose: 
        persisting any release data changes, regardless of their origin (update, create, or other operations).
    .EXAMPLE
        $orchestrator.ExecuteReleaseDataUpdate($request)
        $orchestrator.PersistReleaseDataChanges()
    .NOTES
        This method is a public wrapper/alias for the private PersistReleaseData() method, following the same 
        pattern as PersistBumpFilesChanges() for consistency in the public API.
    #>
    [void] PersistReleaseDataChanges() {
        $this.PersistReleaseData()
    }

    <#
    .SYNOPSIS
        Persists any pending bump files changes to disk.
    .DESCRIPTION
        The PersistBumpFilesChanges method completes the bump files operation by persisting prepared 
        changes to disk and cleaning up temporary backup files. This method should only be called after 
        ExecuteBumpFilesUpdate() has successfully prepared the changes and the caller has confirmed persistence 
        via ShouldProcess. The method name reflects its generic purpose: persisting any bump file changes, 
        regardless of their origin or context.
        After successful persistence, this method also cleans up any backup files created for rollback support.
    #>
    [void] PersistBumpFilesChanges() {
        $this.PersistBumpFiles()
        $this.CleanupBumpFileBackups()
    }

    <#
    .SYNOPSIS
        Loads release data from the configured file.
    .DESCRIPTION
        The LoadReleaseData method loads the release data from disk using the ReleaseDataFileManager.
        Throws an exception if the file cannot be loaded.
        This method is a wrapper around the ReleaseDataFileManager.Load() method.
    .OUTPUTS
        Returns the loaded release data as PSCustomObject.
    #>
    [PSCustomObject] LoadReleaseData() {
        $releaseData = $this.ReleaseDataFileManager.Load()

        if ($null -eq $releaseData) {
            throw [InvalidOperationException]::new("Failed to load release data")
        }

        return $releaseData
    }

    <#
    .SYNOPSIS
        Validates the release data using the ReleaseDataValidator.
    .DESCRIPTION
        The ValidateReleaseData method invokes the ReleaseDataValidator to check the integrity and correctness 
        of the provided release data object.
        This method is a wrapper around the ReleaseDataValidator.Validate() method.
    .PARAMETER releaseData
        The release data object to validate.
    .OUTPUTS
        Returns $true if the release data is valid, otherwise $false.
    #>
    [bool] ValidateReleaseData([PSCustomObject] $releaseData) {
        if ($null -eq $releaseData) {
            throw [ArgumentNullException]::new("releaseData", "Release data cannot be null for validation")
        }

        return $this.ReleaseDataValidator.Validate($releaseData)
    }

    <#
    .SYNOPSIS
        Gets validation errors from the release data validator.
    .DESCRIPTION
        The GetReleaseDataValidationErrors method retrieves the list of validation errors collected by the 
        ReleaseDataValidator during the last validation operation.
        This method is a wrapper around the ReleaseDataValidator.GetErrors() method.
    .OUTPUTS
        Returns an array of strings containing validation error messages.
    #>
    [string[]] GetReleaseDataValidationErrors() {
        return $this.ReleaseDataValidator.GetErrors()
    }

    <#
    .SYNOPSIS
        Loads bump configuration from the configured file.
    .DESCRIPTION
        The LoadBumpConfiguration method loads the bump configuration from disk using the BumpConfigFileManager.
        Throws an exception if the file cannot be loaded.
    .OUTPUTS
        Returns the loaded bump configuration as PSCustomObject.
    #>
    [PSCustomObject] LoadBumpConfiguration() {
        $bumpConfig = $this.BumpConfigFileManager.Load()

        if ($null -eq $bumpConfig) {
            throw [InvalidOperationException]::new("Failed to load bump configuration")
        }

        return $bumpConfig
    }

    <#
    .SYNOPSIS
        Validates the bump configuration using the BumpFilesValidator.
    .DESCRIPTION
        The ValidateBumpConfiguration method invokes the BumpFilesValidator to check the integrity and correctness 
        of the provided bump configuration object.
        This method is a wrapper around the BumpFilesValidator.Validate() method.
    .PARAMETER bumpConfig
        The bump configuration object to validate.
    .OUTPUTS
        Returns $true if the bump configuration is valid, otherwise $false.
    #>
    [bool] ValidateBumpConfiguration([PSCustomObject] $bumpConfig) {
        if ($null -eq $bumpConfig) {
            throw [ArgumentNullException]::new("bumpConfig", "Bump configuration cannot be null for validation")
        }

        return $this.BumpFilesValidator.Validate($bumpConfig)
    }

    <#
    .SYNOPSIS
        Gets validation errors from the bump files validator.
    .DESCRIPTION
        The GetBumpConfigurationValidationErrors method retrieves the list of validation errors collected by the 
        BumpFilesValidator during the last validation operation.
        This method is a wrapper around the BumpFilesValidator.GetErrors() method.
    .OUTPUTS
        Returns an array of strings containing validation error messages.
    #>
    [string[]] GetBumpConfigurationValidationErrors() {
        return $this.BumpFilesValidator.GetErrors()
    }

    <#
    .SYNOPSIS
        Gets the release data token map for bump file substitution.
    .DESCRIPTION
        The GetReleaseDataTokenMap method generates an ordered collection of tokens from the provided release data 
        that can be used for variable substitution in bump files. The caller is responsible for loading and 
        validating the release data before calling this method.
    .PARAMETER releaseData
        The release data object from which to generate tokens.
    .OUTPUTS
        Returns an ordered dictionary with version and metadata tokens, sorted alphabetically.
    #>
    [OrderedDictionary] GetReleaseDataTokenMap([PSCustomObject] $releaseData) {
        if ($null -eq $releaseData) {
            throw [ArgumentNullException]::new("releaseData", "Release data cannot be null for token generation")
        }

        $v = $releaseData.version
        $b = $releaseData.build
        $g = $releaseData.git

        # Use an ordered dictionary to maintain ordered keys
        # [ordered] creates an OrderedDictionary
        $tokenMap = [ordered] @{
            # Build Metadata Tokens
            'BUILD_DATE'            = $b.date
            'BUILD_TIME'            = $b.time
            'BUILD_DAY'             = $b.day.ToString().PadLeft(2, '0')
            'BUILD_MONTH'           = $b.month.ToString().PadLeft(2, '0')
            'BUILD_YEAR'            = $b.year.ToString()
            'BUILD_HOUR'            = $b.hour.ToString().PadLeft(2, '0')
            'BUILD_MINUTE'          = $b.minute.ToString().PadLeft(2, '0')
            'BUILD_SECOND'          = $b.second.ToString().PadLeft(2, '0')
            'BUILD_TIMESTAMP'       = $b.timestamp
            'BUILD_NUMBER'          = $b.number.ToString()

            # Git Metadata Tokens
            'GIT_COMMIT'            = [PSScriptBuilderTextHelper]::GetStringOrEmpty($g.commit)
            'GIT_COMMIT_SHORT'      = [PSScriptBuilderTextHelper]::GetStringOrEmpty($g.commitShort)
            'GIT_BRANCH'            = [PSScriptBuilderTextHelper]::GetStringOrEmpty($g.branch)
            'GIT_TAG'               = [PSScriptBuilderTextHelper]::GetStringOrEmpty($g.tag)

            # Version Tokens
            'VERSION'               = "$($v.major).$($v.minor).$($v.patch)"
            'VERSION_MAJOR'         = $v.major.ToString()
            'VERSION_MINOR'         = $v.minor.ToString()
            'VERSION_PATCH'         = $v.patch.ToString()
            'VERSION_FULL'          = [PSScriptBuilderTextHelper]::GetStringOrEmpty($v.full)
            'VERSION_PRERELEASE'    = [PSScriptBuilderTextHelper]::GetStringOrEmpty($v.prerelease)
            'VERSION_BUILDMETADATA' = [PSScriptBuilderTextHelper]::GetStringOrEmpty($v.buildmetadata)
        }

        return $tokenMap
    }

    <#
    .SYNOPSIS
        Creates new release data with default values.
    .DESCRIPTION
        The CreateNewReleaseData method creates a new release data object initialized with default values:
        - Version: 0.1.0
        - Build Number: 0
        - All timestamps and git information set to $null

        If a release data file already exists, throws an exception unless -Force is specified.
        The created data is validated before being returned.
    .PARAMETER force
        If $true, overwrites the release data file if it already exists.
    .OUTPUTS
        Returns the newly created release data in formatted form as PSCustomObject.
    #>
    [PSCustomObject] CreateNewReleaseData([bool] $force) {
        Write-Verbose "Creating new release data"

        # Check if file already exists
        $filePath = $this.ReleaseDataFileManager.ReleaseDataFilePath

        if (Test-Path $filePath -PathType Leaf) {
            if (-not $force) {
                $message = "Release data file already exists at '$filePath' - use -Force to overwrite"
                throw [InvalidOperationException]::new($message)
            }

            Write-Verbose "Release data file already exists - will be overwritten with -Force"
        }

        # Initialize release data managers with $null to create new processor with default data
        $this.InitializeReleaseDataManagers($null)

        # Get the new release data from the processor (initialized with defaults)
        $releaseData = $this.ReleaseDataProcessor.ReleaseData

        # Validate the new data
        Write-Verbose "Validating newly created release data"

        if (-not $this.ValidateReleaseData($releaseData)) {
            $errors = $this.GetReleaseDataValidationErrors()
            $message = "Validation failed for new release data: $($errors -join ', ')"
            throw [InvalidOperationException]::new($message)
        }

        Write-Verbose "New release data validated successfully"

        # Return the new release data in formatted form (caller decides when to persist)
        $formattedReleaseData = $this.ReleaseDataProcessor.GetReleaseDataFormatted()
        return $formattedReleaseData
    }
    #endregion Public Methods

    #region Private Helper Methods
    <#
    .SYNOPSIS
        Initializes the release data processor.
    .DESCRIPTION
        The InitializeReleaseDataManagers method sets up the ReleaseDataProcessor with the provided release data.
        This method should be called after loading release data and before any operations that depend on the processor.
        If releaseData is $null, the processor is initialized with the parameterless constructor (creating new
        default release data). If releaseData is provided, the processor is initialized with that data.
        Note: ReleaseDataValidator is initialized eagerly in the constructor and requires no setup here.
    .PARAMETER releaseData
        The loaded release data object, or $null to create a new processor with default data.
    #>
    hidden [void] InitializeReleaseDataManagers([PSCustomObject] $releaseData) {
        # Processor is stateful and must be recreated with current release data
        # to prevent stale data issues when orchestrator instance is reused
        if ($null -eq $releaseData) {
            # Create processor with default release data (parameterless constructor)
            $this.ReleaseDataProcessor = [PSScriptBuilderReleaseDataProcessor]::new()
        }
        else {
            # Initialize processor with provided release data
            $this.ReleaseDataProcessor = [PSScriptBuilderReleaseDataProcessor]::new($releaseData)
        }
    }

    <#
    .SYNOPSIS
        Initializes bump files-related processors and validators.
    .DESCRIPTION
        The InitializeBumpFilesManagers method sets up the BumpFilesProcessor with the provided bump configuration
        and the token map generated from the current release data. This method is responsible for ensuring that
        all dependencies are met (release data managers initialized) before creating the bump files processor,
        which relies on the token map for its operations. Should be called after loading the bump configuration
        and before any operations that depend on these managers.
        Note: BumpFilesValidator is initialized eagerly in the constructor and requires no setup here.
    .PARAMETER bumpConfig
        The loaded bump configuration object.
    #>
    hidden [void] InitializeBumpFilesManagers([PSCustomObject] $bumpConfig) {
        # Load release data once for manager initialization and token generation
        $releaseData = $this.LoadReleaseData()

        # Initialize release data managers with current data
        $this.InitializeReleaseDataManagers($releaseData)

        # BumpFilesValidator is initialized eagerly in the constructor — no setup needed here.
        if ($null -eq $this.BumpFilesProcessor) {
            # Validate release data
            if (-not $this.ValidateReleaseData($releaseData)) {
                $errors  = $this.GetReleaseDataValidationErrors()
                $message = "Release data validation failed: $($errors -join ', ')"
                throw [InvalidOperationException]::new($message)
            }

            # Create token map and processor with same release data
            $tokenMap = $this.GetReleaseDataTokenMap($releaseData)
            $this.BumpFilesProcessor = [PSScriptBuilderBumpFilesProcessor]::new($bumpConfig, $tokenMap)
        }
    }

    <#
    .SYNOPSIS
        Creates backups of all configured bump files before modification.
    .DESCRIPTION
        The InitializeBumpFilesBackups method creates backup copies of all files specified in the bumpFiles array 
        within the provided bump configuration. These backups are stored in a temporary directory, and the method 
        records the mapping between original files and their backups to facilitate potential rollback operations.
        If any of the configured files do not exist, the method throws an exception to prevent proceeding with 
        modifications without a backup. This method should be called before any in-memory preparation of bump 
        file changes to ensure that the original state can be restored if needed.
    .PARAMETER bumpConfig
        The bump files configuration containing the list of files to backup.
    #>
    hidden [void] InitializeBumpFilesBackups([PSCustomObject] $bumpConfig) {
        Write-Verbose "Initializing bump files backups"

        # Clear any previous backups
        $this.BumpFilesBackups.Clear()

        # Create backup directory with concise, unique name
        $backupDirName = [PSScriptBuilderFileSystemHelper]::NewBackupDirectoryName()
        $backupDir = Join-Path ([Path]::GetTempPath()) $backupDirName
        [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($backupDir)
        Write-Verbose "Created backup directory: $backupDir"

        # Group by file path to avoid duplicate backups (when same file configured multiple times)
        $groupedByPath = $bumpConfig.bumpFiles | Group-Object -Property path

        foreach ($group in $groupedByPath) {
            $filePath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($group.Name)

            if (-not (Test-Path -Path $filePath -PathType Leaf)) {
                $message = "Configured bump file not found: $filePath"
                throw [FileNotFoundException]::new($message)
            }

            $backupName = "$(Split-Path -Leaf $filePath).bak"
            $backupPath = Join-Path $backupDir $backupName

            Copy-Item -Path $filePath -Destination $backupPath -Force

            $format  = "Created backup for {0} at {1}"
            $message = [string]::Format(
                $format, 
                [PSScriptBuilderFileSystemHelper]::GetTruncatedPath($filePath, 80), 
                [PSScriptBuilderFileSystemHelper]::GetTruncatedPath($backupPath, 80)
            )
            Write-Verbose $message

            $backup = [PSCustomObject] @{
                originalPath = $filePath
                backupPath   = $backupPath
            }

            $this.BumpFilesBackups.Add($backup)
        }

        Write-Verbose "Bump files backups initialization completed with $($this.BumpFilesBackups.Count) files backed up"
    }

    <#
    .SYNOPSIS
        Rolls back release data to its pre-operation state.
    .DESCRIPTION
        The RollbackReleaseData method restores the release data to the state captured before operations began. 
        Includes error handling for robustness.
    #>
    hidden [void] RollbackReleaseData() {
        if ($null -eq $this.OriginalReleaseData) {
            Write-Verbose "No original release data available for rollback"
            return
        }

        Write-Verbose "Rolling back release data"

        try {
            $this.ReleaseDataFileManager.Save($this.OriginalReleaseData)
            Write-Verbose "Release data rollback completed successfully"
        }
        catch {
            Write-Warning "Rollback failed: $($_.Exception.Message)"
        }
    }

    <#
    .SYNOPSIS
        Rolls back bump files to their pre-operation state using backups.
    .DESCRIPTION
        The RollbackBumpFiles method restores all backup copies of modified files to their original locations, 
        effectively undoing the token application. Cleanup of backups is the responsibility of the caller.
    #>
    hidden [void] RollbackBumpFiles() {
        # No backups to restore
        if ($null -eq $this.BumpFilesBackups -or $this.BumpFilesBackups.Count -eq 0) {
            Write-Verbose "No bump files backups available for rollback"
            return
        }

        Write-Verbose "Rolling back bump files from backups"

        # Restore each file from its backup
        foreach ($backup in $this.BumpFilesBackups) {
            try {
                if (Test-Path -Path $backup.backupPath -PathType Leaf) {
                    Copy-Item -Path $backup.backupPath -Destination $backup.originalPath -Force

                    Write-Verbose "Restored backup for $($backup.originalPath)"
                }
            }
            catch {
                Write-Warning "Failed to restore backup for $($backup.originalPath): $($_.Exception.Message)"
            }
        }

        Write-Verbose "Bump files rollback completed for $($this.BumpFilesBackups.Count) files"
    }

    <#
    .SYNOPSIS
        Persists the modified release data to disk.
    .DESCRIPTION
        The PersistReleaseData method saves the modified release data from the ReleaseDataProcessor to the 
        release data file using the ReleaseDataFileManager. This method should only be called after 
        ExecuteReleaseDataUpdate() has successfully computed the changes and the caller has confirmed persistence 
        via ShouldProcess. In case of failures during persistence, the method will throw an exception which can 
        be handled by the caller.
    .NOTES
        This method is a wrapper around the ReleaseDataFileManager.Save() method, providing additional logging 
        for the persistence process. 
    #>
    hidden [void] PersistReleaseData() {
        Write-Verbose "Persisting release data to disk"

        $releaseData = $this.ReleaseDataProcessor.ReleaseData
        $this.ReleaseDataFileManager.Save($releaseData)

        Write-Verbose "Release data persisted successfully"
    }

    <#
    .SYNOPSIS
        Persists prepared bump file changes to disk.
    .DESCRIPTION
        The PersistBumpFiles method saves the prepared bump file changes from memory to disk. 
        Should only be called after ExecuteBumpFilesUpdate() has prepared the changes and ShouldProcess 
        validation has passed. Called internally by FinalizeBumpFilesUpdate().
    #>
    hidden [void] PersistBumpFiles() {
        if ($this.PreparedBumpFileChanges.Count -eq 0) {
            return
        }

        Write-Verbose "Persisting bump files changes to disk"

        # Write each prepared change to disk using FileIOHelper
        foreach ($change in $this.PreparedBumpFileChanges) {
            try {
                [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($change.filePath, $change.newContent)
                Write-Verbose "Persisted changes to $($change.filePath)"
            }
            catch {
                $message = "Failed to persist changes to $($change.filePath): $($_.Exception.Message)"
                throw [InvalidOperationException]::new($message)
            }
        }

        Write-Verbose "Bump files persisted successfully"

        # Clear prepared changes
        $this.PreparedBumpFileChanges.Clear()
    }

    <#
    .SYNOPSIS
        Cleans up backup files created during bump files operations.
    .DESCRIPTION
        The CleanupBumpFileBackups method removes the backup directory and clears the backup list. 
        Should be called after successful persistence or when the operation is cancelled to free resources.
    #>
    hidden [void] CleanupBumpFileBackups() {
        # Guard clause: nothing to cleanup
        if ($null -eq $this.BumpFilesBackups -or $this.BumpFilesBackups.Count -eq 0) {
            return
        }

        # Assumes all backups are in the same directory, so we can clean up the entire directory
        $backupDir = Split-Path -Parent $this.BumpFilesBackups[0].backupPath
        Write-Verbose "Cleaning up bump files backups in directory: $backupDir"

        # Remove backup directory and all its contents
        if (Test-Path -Path $backupDir -PathType Container) {
            Remove-Item -Path $backupDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Verify cleanup and log result
        if (Test-Path -Path $backupDir -PathType Container) {
            Write-Warning "Failed to remove backup directory: $backupDir"
        }
        else {
            Write-Verbose "Backup directory removed successfully: $backupDir"
        }

        # Clear backup list
        $this.BumpFilesBackups.Clear()
    }

    <#
    .SYNOPSIS
        Compares original and modified release data to track changes.
    .DESCRIPTION
        The BuildReleaseDataChanges method compares original and modified release data and returns 
        an OrderedDictionary with changes organized by category (Version, Build, Git).
    .PARAMETER originalData
        The original release data before modifications.
    .PARAMETER modifiedData
        The modified release data after operations.
    .OUTPUTS
        Returns OrderedDictionary with categories as keys and arrays of change objects as values.
    #>
    hidden [OrderedDictionary] BuildReleaseDataChanges([PSCustomObject] $originalData, [PSCustomObject] $modifiedData) {
        $changes = [ordered] @{
            Version = @()
            Build   = @()
            Git     = @()
        }

        # Track version changes
        $originalVersion = $originalData.version
        $modifiedVersion = $modifiedData.version

        $versionProperties = @('major', 'minor', 'patch', 'prerelease', 'build', 'full')

        foreach ($versionProperty in $versionProperties) {
            $originalValue = $originalVersion.$versionProperty
            $modifiedValue = $modifiedVersion.$versionProperty

            if ($originalValue -ne $modifiedValue) {
                $changes['Version'] += [ordered] @{
                    Property = $versionProperty
                    OldValue = $originalValue
                    NewValue = $modifiedValue
                }
            }
        }

        # Track build changes
        $originalBuild = $originalData.build
        $modifiedBuild = $modifiedData.build

        $buildProperties = @('number', 'date', 'time', 'timestamp', 'year', 'month', 'day', 'hour', 'minute', 'second')

        foreach ($buildProperty in $buildProperties) {
            $originalValue = $originalBuild.$buildProperty
            $modifiedValue = $modifiedBuild.$buildProperty

            if ($originalValue -ne $modifiedValue) {
                $changes['Build'] += [ordered] @{
                    Property = $buildProperty
                    OldValue = $originalValue
                    NewValue = $modifiedValue
                }
            }
        }

        # Track git changes
        $originalGit = $originalData.git
        $modifiedGit = $modifiedData.git

        $gitProperties = @('commit', 'commitshort', 'branch', 'tag')

        foreach ($gitProperty in $gitProperties) {
            $originalValue = $originalGit.$gitProperty
            $modifiedValue = $modifiedGit.$gitProperty

            if ($originalValue -ne $modifiedValue) {
                $changes['Git'] += [ordered] @{
                    Property = $gitProperty
                    OldValue = $originalValue
                    NewValue = $modifiedValue
                }
            }
        }

        return $changes
    }
    #endregion Private Helper Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderReleaseManagementOrchestrator

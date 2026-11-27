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
    loading release data, validating changes, updating versions and applying bumps to files. Changes are
    prepared in memory without side effects; the calling cmdlet confirms them, and they are then written as
    one transaction by PSScriptBuilderFileTransaction - all files are changed, or none (RFC 0026).
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
    hidden [PSScriptBuilderReleaseDataFileManager] $ReleaseDataFileManager

    <#
    .SYNOPSIS
        Manages bump configuration data.
    .DESCRIPTION
        The BumpConfigFileManager property holds an instance of PSScriptBuilderBumpConfigFileManager for handling 
        bump configuration file I/O operations.
    #>
    hidden [PSScriptBuilderBumpConfigFileManager] $BumpConfigFileManager

    <#
    .SYNOPSIS
        Processes release data.
    .DESCRIPTION
        The ReleaseDataProcessor property holds an instance of PSScriptBuilderReleaseDataProcessor for processing release data 
        operations.
    #>
    hidden [PSScriptBuilderReleaseDataProcessor] $ReleaseDataProcessor

    <#
    .SYNOPSIS
        Processes bump file data.
    .DESCRIPTION
        The BumpFilesProcessor property holds an instance of PSScriptBuilderBumpFilesProcessor for processing bump file 
        operations.
    #>
    hidden [PSScriptBuilderBumpFilesProcessor] $BumpFilesProcessor

    <#
    .SYNOPSIS
        Validates release data.
    .DESCRIPTION
        The ReleaseDataValidator property holds an instance of PSScriptBuilderReleaseDataValidator for validating 
        release data before updates.
    #>
    hidden [PSScriptBuilderReleaseDataValidator] $ReleaseDataValidator

    <#
    .SYNOPSIS
        Validates bump file configurations.
    .DESCRIPTION
        The BumpFilesValidator property holds an instance of PSScriptBuilderBumpFilesValidator for validating 
        bump file configurations before updates.
    #>
    hidden [PSScriptBuilderBumpFilesValidator] $BumpFilesValidator

    <#
    .SYNOPSIS
        Snapshot of the release data as it was loaded.
    .DESCRIPTION
        The OriginalReleaseData property holds the release data loaded by ExecuteReleaseDataUpdate() before
        any operation is applied. It is compared with the modified data to report the changes.
    #>
    hidden [PSCustomObject] $OriginalReleaseData

    <#
    .SYNOPSIS
        The bytes of the release data file the prepared change is based on.
    .DESCRIPTION
        The OriginalReleaseDataBytes property holds the content of the release data file read when the change
        was prepared - by ExecuteReleaseDataUpdate(), or by CreateNewReleaseData() when an existing file is
        overwritten. PersistReleaseDataChanges() passes it to the transaction, which refuses to write if the
        file changed in the meantime. $null when a new release data file is created.
    #>
    hidden [byte[]] $OriginalReleaseDataBytes

    <#
    .SYNOPSIS
        Collection of prepared bump file changes awaiting persistence.
    .DESCRIPTION
        The PreparedBumpFileChanges property holds the in-memory changes prepared by
        UpdateBumpFilesInMemory(), one PSScriptBuilderBumpFileChange per bump file whose content
        changes. These changes are persisted to disk only when confirmed via ShouldProcess.
    #>
    hidden [List[PSScriptBuilderBumpFileChange]] $PreparedBumpFileChanges
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

        # Initialize snapshot for original release data and the bytes it was read from
        $this.OriginalReleaseData      = $null
        $this.OriginalReleaseDataBytes = $null

        # Initialize prepared bump file changes collection
        $this.PreparedBumpFileChanges = [List[PSScriptBuilderBumpFileChange]]::new()
    }
    #endregion Constructors

    #region Methods
    #region Public Methods
    <#
    .SYNOPSIS
        Prepares a release data update in memory.
    .DESCRIPTION
        The ExecuteReleaseDataUpdate method prepares a release data update without writing anything:
        1. Reading the release data file once as bytes and parsing it
        2. Validating the loaded release data
        3. Performing the requested version updates in-memory
        4. Validating the modified release data
        5. Building the change tracking information
        A failure throws without any side effect; there is nothing to roll back. The change is written by
        PersistReleaseDataChanges() once the caller confirmed it.
    .PARAMETER request
        PSScriptBuilderReleaseDataOperationRequest object specifying the operations to perform.
    .OUTPUTS
        Returns a PSScriptBuilderReleaseDataResult with operation result and details.
    #>
    [PSScriptBuilderReleaseDataResult] ExecuteReleaseDataUpdate([PSScriptBuilderReleaseDataOperationRequest] $request) {
        Write-Verbose "Executing release data update operation"
        $operationCount = 0

        # Step 1: Read the file once - the bytes are the base of the change check when writing
        $filePath                      = $this.ReleaseDataFileManager.ReleaseDataFilePath
        $this.OriginalReleaseDataBytes = $this.ReleaseDataFileManager.ReadBytes()
        $this.OriginalReleaseData      = $this.ReleaseDataFileManager.Deserialize($this.OriginalReleaseDataBytes, $filePath)

        if ($null -eq $this.OriginalReleaseData) {
            throw [InvalidOperationException]::new("Failed to load release data")
        }

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

        if (-not [string]::IsNullOrEmpty($request.Version)) {
            Write-Verbose "Setting version: $($request.Version)"
            $this.ReleaseDataProcessor.SetVersion($request.Version)
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
        $changes = $this.ReleaseDataProcessor.GetReleaseDataChanges($this.OriginalReleaseData)

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

    <#
    .SYNOPSIS
        Prepares a bump files update in memory.
    .DESCRIPTION
        The ExecuteBumpFilesUpdate method prepares the bump files update without writing anything:
        1. Loading and validating the bump configuration
        2. Initializing the bump files processor with the token map from the current release data
        3. Preparing the token updates in-memory, reading each file once
        4. Building the result with details of the prepared changes
        A failure throws without any side effect; there is nothing to roll back. The changes are written by
        PersistBumpFilesChanges() once the caller confirmed them.
    .OUTPUTS
        Returns a PSScriptBuilderBumpFilesResult with operation result and details.
    #>
    [PSScriptBuilderBumpFilesResult] ExecuteBumpFilesUpdate() {
        Write-Verbose "Executing bump files update operation"

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

        # Step 2: Prepare token updates in-memory (no disk writes)
        $updateResult = $this.BumpFilesProcessor.UpdateBumpFilesInMemory()
        $this.PreparedBumpFileChanges = $updateResult.Changes

        # Build BumpDetails from prepared changes (only changed files are returned)
        $bumpDetails = @()

        foreach ($fileChange in $updateResult.Changes) {
            $bumpDetails += [PSCustomObject]@{
                Path         = $fileChange.FilePath
                ChangedItems = $fileChange.ChangedItems
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

    <#
    .SYNOPSIS
        Writes the prepared release data change.
    .DESCRIPTION
        The PersistReleaseDataChanges method serializes the release data of the ReleaseDataProcessor and writes it
        through PSScriptBuilderFileTransaction: as a replacement checked against OriginalReleaseDataBytes, or -
        when no file existed - as a new file that must still not exist. Must be called only after
        ExecuteReleaseDataUpdate() or CreateNewReleaseData() and after the caller confirmed the change via
        ShouldProcess. A failure leaves the release data file unchanged and throws.
    .OUTPUTS
        Returns the warnings of the transaction as string[] - e.g. a backup that could not be deleted after
        the file was written correctly; an empty array otherwise. The calling cmdlet writes them.
    .EXAMPLE
        $orchestrator.ExecuteReleaseDataUpdate($request)
        $warnings = $orchestrator.PersistReleaseDataChanges()
    #>
    [string[]] PersistReleaseDataChanges() {
        Write-Verbose "Persisting release data to disk"

        $filePath = $this.ReleaseDataFileManager.ReleaseDataFilePath
        $newBytes = $this.ReleaseDataFileManager.Serialize($this.ReleaseDataProcessor.ReleaseData)

        $transaction = [PSScriptBuilderFileTransaction]::new()
        if ($null -eq $this.OriginalReleaseDataBytes) {
            $transaction.AddCreate($filePath, $newBytes)
        }
        else {
            $transaction.AddReplace($filePath, $this.OriginalReleaseDataBytes, $newBytes)
        }

        $warnings = $transaction.Commit()
        Write-Verbose "Release data persisted successfully"
        return $warnings
    }

    <#
    .SYNOPSIS
        Writes the prepared bump file changes.
    .DESCRIPTION
        The PersistBumpFilesChanges method writes every prepared change through one PSScriptBuilderFileTransaction:
        each file is checked against the bytes it was prepared from, backed up next to itself and written; if
        writing fails, all files are restored. Must be called only after ExecuteBumpFilesUpdate() and after
        the caller confirmed the changes via ShouldProcess. The prepared changes are cleared once written.
    .OUTPUTS
        Returns the warnings of the transaction as string[] - e.g. a backup that could not be deleted after
        the files were written correctly; an empty array otherwise. The calling cmdlet writes them.
    #>
    [string[]] PersistBumpFilesChanges() {
        Write-Verbose "Persisting bump files changes to disk"

        $transaction = [PSScriptBuilderFileTransaction]::new()
        foreach ($change in $this.PreparedBumpFileChanges) {
            $newBytes = [PSScriptBuilderFileIOHelper]::EncodeUTF8WithBOM($change.NewContent)
            $transaction.AddReplace($change.FilePath, $change.OriginalBytes, $newBytes)
        }

        $warnings = $transaction.Commit()
        $this.PreparedBumpFileChanges.Clear()
        Write-Verbose "Bump files persisted successfully"
        return $warnings
    }

    <#
    .SYNOPSIS
        Checks whether the prepared release data update changes the release data.
    .DESCRIPTION
        The HasReleaseDataChanges method compares the serialized release data as loaded with the
        serialized prepared release data, byte by byte. It decides whether there is anything to confirm
        and write, independently of the change list in the result: that list holds changed values,
        while a file can also differ in formatting only. Such a difference makes the method return
        $true, which merely rewrites the file; a real change is never missed. Must be called only
        after ExecuteReleaseDataUpdate().
    .OUTPUTS
        Returns $true if the release data changes, $false otherwise, as bool.
    #>
    [bool] HasReleaseDataChanges() {
        $originalBytes = $this.ReleaseDataFileManager.Serialize($this.OriginalReleaseData)
        $preparedBytes = $this.ReleaseDataFileManager.Serialize($this.ReleaseDataProcessor.ReleaseData)

        $isEqual    = [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($originalBytes, $preparedBytes)
        $hasChanges = -not $isEqual
        return $hasChanges
    }

    <#
    .SYNOPSIS
        Gets the path of the release data file.
    .DESCRIPTION
        The GetReleaseDataFilePath method returns the absolute path of the release data file from the
        configuration, e.g. for a confirmation message.
    .OUTPUTS
        Returns the absolute path of the release data file as string.
    #>
    [string] GetReleaseDataFilePath() {
        $filePath = $this.ReleaseDataFileManager.ReleaseDataFilePath
        return $filePath
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
            'BUILD_DATE'            = [PSScriptBuilderTextHelper]::GetStringOrEmpty($b.date)
            'BUILD_TIME'            = [PSScriptBuilderTextHelper]::GetStringOrEmpty($b.time)
            'BUILD_DAY'             = if ($null -ne $b.day)    { $b.day.ToString().PadLeft(2, '0') }    else { '' }
            'BUILD_MONTH'           = if ($null -ne $b.month)  { $b.month.ToString().PadLeft(2, '0') }  else { '' }
            'BUILD_YEAR'            = if ($null -ne $b.year)   { $b.year.ToString() }                   else { '' }
            'BUILD_HOUR'            = if ($null -ne $b.hour)   { $b.hour.ToString().PadLeft(2, '0') }   else { '' }
            'BUILD_MINUTE'          = if ($null -ne $b.minute) { $b.minute.ToString().PadLeft(2, '0') } else { '' }
            'BUILD_SECOND'          = if ($null -ne $b.second) { $b.second.ToString().PadLeft(2, '0') } else { '' }
            'BUILD_TIMESTAMP'       = [PSScriptBuilderTextHelper]::GetStringOrEmpty($b.timestamp)
            'BUILD_NUMBER'          = if ($null -ne $b.number) { $b.number.ToString() }                 else { '' }

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
        When an existing file is overwritten with force, its bytes are kept so the write is checked against
        them; otherwise the file is created and must still not exist when it is written.
    .PARAMETER force
        If $true, overwrites the release data file if it already exists.
    .OUTPUTS
        Returns the newly created release data in formatted form as PSCustomObject.
    #>
    [PSCustomObject] CreateNewReleaseData([bool] $force) {
        Write-Verbose "Creating new release data"

        # Check if file already exists
        $filePath = $this.ReleaseDataFileManager.ReleaseDataFilePath
        $this.OriginalReleaseDataBytes = $null

        if (Test-Path $filePath -PathType Leaf) {
            if (-not $force) {
                $message = "Release data file already exists at '$filePath' - use -Force to overwrite"
                throw [InvalidOperationException]::new($message)
            }

            Write-Verbose "Release data file already exists - will be overwritten with -Force"
            $this.OriginalReleaseDataBytes = $this.ReleaseDataFileManager.ReadBytes()
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

        # BumpFilesValidator is initialized eagerly in the constructor - no setup needed here.
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
    #endregion Private Helper Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderReleaseManagementOrchestrator

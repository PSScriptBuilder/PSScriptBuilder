using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Diagnostics
using namespace System.Management.Automation.Language

#region Class PSScriptBuilderBuildOrchestrator
<#
.SYNOPSIS
    Orchestrates the complete script building workflow.
.DESCRIPTION
    The PSScriptBuilderBuildOrchestrator coordinates the complete build process: template loading,
    backup creation, dependency analysis (delegated to DependencyAnalyzer), template processing,
    and output writing. It returns a comprehensive BuildResult with execution time, component details,
    and file statistics.

    The orchestrator is config-independent and requires all paths and settings to be provided explicitly
    via constructor parameters. It manages the entire build lifecycle from template to final output file,
    using specialized managers for file operations (TemplateFileManager, BackupManager, OutputFileManager)
    and delegating dependency analysis to PSScriptBuilderDependencyAnalyzer.
#>
class PSScriptBuilderBuildOrchestrator {
    #region Properties
    <#
    .SYNOPSIS
        The content collector containing all component collectors.
    .DESCRIPTION
        The ContentCollector property holds a reference to the ContentCollector that manages all registered
        collectors (Using, Enum, Class, Function, File). The orchestrator uses this to execute collection and
        retrieve component data.
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector

    <#
    .SYNOPSIS
        The full path to the template file.
    .DESCRIPTION
        The TemplatePath property specifies the complete path to the template file to load.
        The file is loaded during Phase 1 (TemplateLoading).
    #>
    hidden [string] $TemplatePath

    <#
    .SYNOPSIS
        The output file path for the final script.
    .DESCRIPTION
        The OutputPath property specifies where the final built script will be written during Phase 9 (OutputWriting).
    #>
    hidden [string] $OutputPath

    <#
    .SYNOPSIS
        The directory where backup files are stored.
    .DESCRIPTION
        The BackupDirectoryPath property specifies where backup files are created during Phase 2 (BackupCreation).
        If empty or null, backups are created in the same directory as the output file.
    #>
    hidden [string] $BackupDirectoryPath

    <#
    .SYNOPSIS
        The template placeholder key for ordered components.
    .DESCRIPTION
        The OrderedComponentsKey property specifies the placeholder name in the template that will be replaced
        with the dependency-ordered components during Phase 8 (TemplateProcessing). Default is "ORDERED_COMPONENTS".
    #>
    hidden [string] $OrderedComponentsKey

    <#
    .SYNOPSIS
        Indicates whether to create a backup before overwriting the output file.
    .DESCRIPTION
        The BackupEnabled property determines whether Phase 2 (CreateBackup) should be executed.
        If false, no backup is created and Phase 2 is skipped. Default is false.
    #>
    hidden [bool] $BackupEnabled

    <#
    .SYNOPSIS
        Indicates whether output syntax validation is enabled.
    .DESCRIPTION
        The SyntaxValidationEnabled property determines whether the syntax validation step is
        executed after writing the output file. TypeNotFound errors caused by external assemblies
        not loaded at build time are automatically filtered and do not fail the validation.
        When false, syntax validation is skipped entirely. Default is true.
    #>
    hidden [bool] $SyntaxValidationEnabled

    <#
    .SYNOPSIS
        The loaded template content.
    .DESCRIPTION
        The TemplateContent property holds the template content loaded during Phase 1 (TemplateLoading).
        It is used in Phase 8 (TemplateProcessing) to generate the final script.
    #>
    hidden [string] $TemplateContent

    <#
    .SYNOPSIS
        The path to the created backup file.
    .DESCRIPTION
        The BackupPath property holds the path to the backup file created during Phase 2 (BackupCreation).
        If no backup was created (file didn't exist), this is null.
    #>
    hidden [string] $BackupPath
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderBuildOrchestrator.
    .DESCRIPTION
        Creates the orchestrator with the specified content collector, template path, output path,
        backup directory, sorted components key, and backup creation flag. Initializes the 
        BuildDataAggregator for statistics collection.
    .PARAMETER contentCollector
        The content collector with registered component collectors.
    .PARAMETER templatePath
        The full path to the template file to load. Cannot be null or empty.
    .PARAMETER outputPath
        The path where the final built script will be written. Cannot be null or empty.
    .PARAMETER backupPath
        The directory where backup files are stored. If empty, defaults to output file directory.
    .PARAMETER orderedComponentsKey
        The template placeholder key for dependency-ordered components. Defaults to "ORDERED_COMPONENTS".
    .PARAMETER backupEnabled
        Whether to create a backup of the output file before overwriting. Defaults to false.
    .PARAMETER syntaxValidationEnabled
        Whether to validate the syntax of the output file. Defaults to true.
    #>
    PSScriptBuilderBuildOrchestrator(
        [PSScriptBuilderContentCollector] $contentCollector,
        [string]                          $templatePath,
        [string]                          $outputPath,
        [string]                          $backupPath,
        [string]                          $orderedComponentsKey,
        [bool]                            $backupEnabled,
        [bool]                            $syntaxValidationEnabled
    ) {
        if ($null -eq $contentCollector) {
            $message = "Parameter 'contentCollector' cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        if ([string]::IsNullOrWhiteSpace($templatePath)) {
            $message = "Parameter 'templatePath' cannot be null or empty."
            throw [ArgumentException]::new($message, "templatePath")
        }

        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            $message = "Parameter 'outputPath' cannot be null or empty."
            throw [ArgumentException]::new($message, "outputPath")
        }

        $this.ContentCollector        = $contentCollector
        $this.TemplatePath            = $templatePath
        $this.OutputPath              = $outputPath
        $this.BackupDirectoryPath     = $backupPath
        $this.OrderedComponentsKey    = $orderedComponentsKey
        $this.BackupEnabled           = $backupEnabled
        $this.SyntaxValidationEnabled = $syntaxValidationEnabled

        # Default backupPath to output directory if backupPath is not provided but outputPath is provided
        if ([string]::IsNullOrWhiteSpace($this.BackupDirectoryPath) -and -not [string]::IsNullOrWhiteSpace($outputPath)) {
            $this.BackupDirectoryPath = [Path]::GetDirectoryName($outputPath)
        }

        # Default orderedComponentsKey if not provided
        if ([string]::IsNullOrWhiteSpace($this.OrderedComponentsKey)) {
            $this.OrderedComponentsKey = "ORDERED_COMPONENTS"
        }
    }
    #endregion Constructors

    #region Methods
    #region Phase Methods
    <#
    .SYNOPSIS
        Loads the template file.
    .DESCRIPTION
        Loads the template content from the specified TemplatePath.
    .OUTPUTS
        Returns the template content as string.
    #>
    [string] LoadTemplate() {
        if ([string]::IsNullOrWhiteSpace($this.TemplatePath)) {
            $message = "TemplatePath is not set. Cannot load template."
            throw [InvalidOperationException]::new($message)
        }

        return [PSScriptBuilderTemplateFileManager]::LoadTemplate($this.TemplatePath)
    }

    <#
    .SYNOPSIS
        Emits warnings for dependencies that cross collector boundaries.
    .DESCRIPTION
        Iterates all edges in the dependency graph. For each edge where the source and target
        component belong to different collectors, a Write-Warning is emitted advising the user
        to verify the template placeholder order.

        This does not prevent the build — it is an advisory warning only. The user is responsible
        for placing template placeholders in the correct order when cross-collector dependencies exist.
    .PARAMETER graph
        The dependency graph produced by the dependency analyzer.
    #>
    [void] WarnCrossCollectorDependencies([PSScriptBuilderDependencyGraph] $graph) {
        if ($null -eq $graph) { return }

        $map = $this.ContentCollector.BuildComponentCollectorMap()

        foreach ($entry in $graph.Dependencies.GetEnumerator()) {
            $from = $entry.Key

            foreach ($edge in $entry.Value) {
                $to = $edge.Target

                $isCrossCollectorDependency = 
                    $map.ContainsKey($from) -and 
                    $map.ContainsKey($to)   -and 
                    $map[$from] -ne $map[$to]

                if ($isCrossCollectorDependency) {
                    $format = 
                        "Cross-collector dependency: '{0}' (key '{1}') depends on '{2}' (key '{3}'). " + 
                        "Ensure '{{{{{3}}}}}' precedes '{{{{{1}}}}}' in the template."
                    $message = $format -f $from, $map[$from], $to, $map[$to]
                    Write-Warning $message
                }
            }
        }
    }

    <#
    .SYNOPSIS
        Processes the template and renders the final script.
    .DESCRIPTION
        Uses the TemplateProcessor to replace placeholders with sorted components.
    .PARAMETER orderedComponents
        The topologically sorted component names.
    .PARAMETER useOrderedMode
        True when the template uses {{ORDERED_COMPONENTS}} (Ordered or Hybrid mode), false for Free mode.
    .OUTPUTS
        Returns the rendered script content as string.
    #>
    [string] ProcessTemplate([string[]] $orderedComponents, [bool] $useOrderedMode) {
        if ([string]::IsNullOrWhiteSpace($this.TemplateContent)) {
            throw [InvalidOperationException]::new("TemplateContent is not set. Call LoadTemplate() first.")
        }

        $processor = [PSScriptBuilderTemplateProcessor]::new(
            $this.ContentCollector,
            $this.TemplateContent,
            $this.OrderedComponentsKey,
            $useOrderedMode
        )

        return $processor.Render($orderedComponents)
    }

    <#
    .SYNOPSIS
        Creates a backup of the existing output file.
    .DESCRIPTION
        Creates a backup file if the output file exists. Returns the backup path or null.
        The BackupManager handles existence checking and logging internally.
    .OUTPUTS
        Returns the backup file path as string, or null if no backup was created.
    #>
    [string] CreateBackup() {
        return [PSScriptBuilderBackupManager]::CreateBackup($this.OutputPath, $this.BackupDirectoryPath)
    }

    <#
    .SYNOPSIS
        Writes the final script to the output file.
    .DESCRIPTION
        Uses the OutputFileManager to write the rendered script to the specified path.
    .PARAMETER content
        The rendered script content to write.
    #>
    [void] WriteOutput([string] $content) {
        if ([string]::IsNullOrWhiteSpace($this.OutputPath)) {
            $message = "OutputPath is not set. Cannot write output file."
            throw [InvalidOperationException]::new($message)
        }

        [PSScriptBuilderOutputFileManager]::WriteScript($this.OutputPath, $content)
    }

    <#
    .SYNOPSIS
        Validates the syntax of the generated output file.
    .DESCRIPTION
        The ValidateSyntax method parses the generated output file as a PowerShell script to
        verify its syntactic correctness. TypeNotFound errors are filtered out and logged as
        verbose output — they occur when the script references types from external assemblies
        that are not loaded at build time, which is expected and valid.
    .OUTPUTS
        Returns $true if the output file is syntactically valid.
    #>
    hidden [bool] ValidateSyntax() {
        Write-Verbose "Validating output syntax (parse check)..."

        $tokens = $null
        $errors = $null
        [Parser]::ParseFile($this.OutputPath, [ref] $tokens, [ref] $errors) | Out-Null

        # TypeNotFound errors occur when the script references types from external assemblies
        # that are not loaded at build time. These are not syntax errors — filter them out.
        $typeNotFoundErrors = @($errors | Where-Object { $_.ErrorId -eq "TypeNotFound" })
        $syntaxErrors       = @($errors | Where-Object { $_.ErrorId -ne "TypeNotFound" })

        $reportedTypes = [HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($typeError in $typeNotFoundErrors) {
            if ($reportedTypes.Add($typeError.Message)) {
                Write-Verbose "  Ignored (external type not loaded at build time): $($typeError.Message)"
            }
        }

        if ($syntaxErrors.Count -gt 0) {
            $format  = "Output syntax validation failed: {0}"
            $message = $format -f $syntaxErrors[0].Message
            throw [InvalidOperationException]::new($message)
        }

        Write-Verbose "Output syntax is valid"
        return $true
    }
    #endregion Phase Methods

    #region Orchestration Methods
    <#
    .SYNOPSIS
        Executes the complete script building workflow.
    .DESCRIPTION
        The ExecuteBuild method orchestrates the complete build process:
        
        1. Load template file from the specified path
        2. Analyze dependencies (delegated to PSScriptBuilderDependencyAnalyzer)
        3. Warn about cross-collector dependencies (Free Mode only, advisory)
        4. Process template and replace placeholders with content
        5. Create backup of the existing output file (if enabled)
        6. Write final script to the output file
        7. Validate output syntax (parse check)
        8. Gather build statistics (component details, processed files, execution time)

        If any step fails, an exception is thrown with detailed context.
        Upon successful completion, returns a BuildResult with comprehensive build information.
    .OUTPUTS
        Returns a PSScriptBuilderBuildResult containing build metrics, component details,
        and file statistics.
    #>
    [PSScriptBuilderBuildResult] ExecuteBuild() {
        try {
            $stopwatch = [Stopwatch]::StartNew()
            Write-Verbose "Starting script build..."

            # Load template
            $this.TemplateContent = $this.LoadTemplate()

            # Analyze dependencies (delegated to DependencyAnalyzer)
            $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($this.ContentCollector)
            $analysisResult = $analyzer.Analyze()

            if ($analysisResult.HasCycles) {
                $cycleString = $analysisResult.CyclePath -join " -> "
                $message = "Circular dependency detected: $cycleString"
                throw [InvalidOperationException]::new($message)
            }

            # Process template
            $orderedPlaceholderToken       = "{{{{{0}}}}}" -f $this.OrderedComponentsKey
            $templateHasOrderedPlaceholder = $this.TemplateContent -match [Regex]::Escape($orderedPlaceholderToken)
            $useOrderedMode                = $analysisResult.HasCrossDependencies -or $templateHasOrderedPlaceholder

            # Warn about cross-collector dependencies only in Free Mode —
            # in Ordered/Hybrid Mode {{ORDERED_COMPONENTS}} handles global sorting automatically
            if (-not $useOrderedMode) {
                $this.WarnCrossCollectorDependencies($analysisResult.DependencyGraph)
            }

            $finalScript = $this.ProcessTemplate(
                $analysisResult.OrderedComponents,
                $useOrderedMode
            )

            # Create backup immediately before overwriting the output file (optional)
            if ($this.BackupEnabled) {
                $this.BackupPath = $this.CreateBackup()
            }
            else {
                $this.BackupPath = $null
            }

            # Write output
            $this.WriteOutput($finalScript)

            # Validate output syntax (parse check)
            $syntaxValid = $true
            if (-not $this.SyntaxValidationEnabled) {
                Write-Verbose "Skipping output syntax validation (SyntaxValidationEnabled is false)."
            }
            else {
                $syntaxValid = $this.ValidateSyntax()
            }

            $stopwatch.Stop()

            # Gather build statistics
            $aggregator = [PSScriptBuilderBuildDataAggregator]::new($this.ContentCollector)
            $componentDetails = $aggregator.GetComponentDetails()
            $processedFiles = $aggregator.GetProcessedFiles()

            $fileInfo = Get-Item $this.OutputPath

            Write-Verbose "Script build complete"

            return [PSScriptBuilderBuildResult]::new(
                $this.OutputPath,
                $fileInfo.Length,
                $this.BackupPath,
                $analysisResult.ComponentCounts,
                $stopwatch.Elapsed,
                $processedFiles,
                $componentDetails,
                $syntaxValid
            )
        }
        catch {
            $format = "Script building failed. Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [Exception]::new($message, $_.Exception)
        }
    }
    #endregion Orchestration Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderBuildOrchestrator

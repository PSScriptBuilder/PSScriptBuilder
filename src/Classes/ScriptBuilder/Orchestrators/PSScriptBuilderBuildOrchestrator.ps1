using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Diagnostics
using namespace System.Text

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
        Indicates whether to write a source map sidecar file after the build.
    .DESCRIPTION
        The WriteSourceMap property determines whether a .sourcemap.json sidecar file
        is generated alongside the output script. Default is false.
    #>
    hidden [bool] $WriteSourceMap

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
        The escape-sentinel-to-original-text map produced by masking the template content.
    .DESCRIPTION
        The TemplateEscapeMap property holds the map PSScriptBuilderTemplateEscapeHelper.Mask()
        returns when TemplateContent is loaded during Phase 1 (TemplateLoading). It is consumed
        once, during Phase 8 (TemplateProcessing), to unmask the rendered output back to literal,
        un-escaped text before it is written.
    #>
    hidden [hashtable] $TemplateEscapeMap

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
    .PARAMETER writeSourceMap
        Whether to write a source map sidecar file after the build. Defaults to false.
    #>
    PSScriptBuilderBuildOrchestrator(
        [PSScriptBuilderContentCollector] $contentCollector,
        [string]                          $templatePath,
        [string]                          $outputPath,
        [string]                          $backupPath,
        [string]                          $orderedComponentsKey,
        [bool]                            $backupEnabled,
        [bool]                            $syntaxValidationEnabled,
        [bool]                            $writeSourceMap
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
        $this.WriteSourceMap          = $writeSourceMap

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
    hidden [string] LoadTemplate() {
        if ([string]::IsNullOrWhiteSpace($this.TemplatePath)) {
            $message = "TemplatePath is not set. Cannot load template."
            throw [InvalidOperationException]::new($message)
        }

        return [PSScriptBuilderTemplateFileManager]::LoadTemplate($this.TemplatePath)
    }

    <#
    .SYNOPSIS
        Warns about source files that contain non-ASCII characters but lack a UTF-8 BOM.
    .DESCRIPTION
        The WarnEncodingIssues method checks all processed source files for UTF-8 encoding without
        BOM. PSScriptBuilder itself reads these files correctly regardless of BOM presence or the
        system's default codepage - this is advisory only, for the benefit of other tools in the
        user's workflow (editors, diff tools, linters) that may still assume the system codepage
        for a BOM-less file and misrender non-ASCII characters such as umlauts (ae, oe, ue, ss).

        The check is skipped when the system default encoding is UTF-8, since that is the most
        common environment this advice is relevant for.

        If files without BOM are detected, a summary warning is emitted. The full file list is
        written to the verbose output stream as project-relative paths.
        Files with only ASCII content are unaffected regardless of BOM and are not reported.
    #>
    hidden [void] WarnEncodingIssues() {
        # Skip check when system default encoding is UTF-8 (code page 65001)
        if ([Encoding]::Default.CodePage -eq 65001) {
            Write-Verbose "System encoding is UTF-8 (code page 65001). Encoding check skipped."
            return
        }

        $codePage = [Encoding]::Default.CodePage
        Write-Verbose "System encoding is not UTF-8 (code page $codePage). Checking file encodings..."

        $filesWithoutBom = [PSScriptBuilderFileIOHelper]::FindNonAsciiFilesWithoutBom(
            $this.ContentCollector.GetProcessedFiles()
        )

        if ($filesWithoutBom.Count -eq 0) {
            Write-Verbose "All files are UTF-8 with BOM or ASCII-only"
            return
        }

        $format  = "{0} source file(s) lack a UTF-8 BOM. PSScriptBuilder reads them correctly " +
                   "regardless, but other tools in your workflow (editors, diff tools, linters) " +
                   "may still assume the system codepage ({1}) without one present. Save as " +
                   "UTF-8 with BOM for maximum compatibility. Run with -Verbose for details."
        $message = $format -f $filesWithoutBom.Count, $codePage
        Write-Warning $message

        foreach ($file in $filesWithoutBom) {
            Write-Verbose "  $([PSScriptBuilderFileSystemHelper]::GetProjectRelativePath($file))"
        }
    }

    <#
    .SYNOPSIS
        Emits warnings for dependencies that cross collector boundaries.
    .DESCRIPTION
        Iterates all edges in the dependency graph and collects edges where the source and target
        component belong to different collectors. If any are found, a single summary Write-Warning
        is emitted with the total count, followed by per-dependency Verbose details advising the
        user to verify the template placeholder order.

        This does not prevent the build - it is an advisory warning only. The user is responsible
        for placing template placeholders in the correct order when cross-collector dependencies exist.
    .PARAMETER graph
        The dependency graph produced by the dependency analyzer.
    #>
    hidden [void] WarnCrossCollectorDependencies([PSScriptBuilderDependencyGraph] $graph) {
        if ($null -eq $graph) { return }

        $map     = $this.ContentCollector.BuildComponentCollectorMap()
        $details = [List[string]]::new()

        foreach ($entry in $graph.GetEdgeMap().GetEnumerator()) {
            $from = $entry.Key

            foreach ($edge in $entry.Value) {
                $to = $edge.Target

                $isCrossCollectorDependency =
                    $map.ContainsKey($from) -and
                    $map.ContainsKey($to)   -and
                    $map[$from] -ne $map[$to]

                if ($isCrossCollectorDependency) {
                    $format = "  '{0}' (key '{1}') depends on '{2}' (key '{3}'). Ensure '{{{{{3}}}}}' precedes '{{{{{1}}}}}' in the template."
                    $details.Add(($format -f $from, $map[$from], $to, $map[$to]))
                }
            }
        }

        if ($details.Count -eq 0) {
            Write-Verbose "No cross-collector dependencies detected."
            return
        }

        $format  = "{0} cross-collector dependency(s) detected. Verify template placeholder order. Run with -Verbose for details."
        $message = $format -f $details.Count
        Write-Warning $message

        foreach ($detail in $details) {
            Write-Verbose $detail
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
    hidden [string] ProcessTemplate([string[]] $orderedComponents, [bool] $useOrderedMode) {
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
    hidden [string] CreateBackup() {
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
    hidden [void] WriteOutput([string] $content) {
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
        verify its syntactic correctness. Non-structural parse errors (e.g. TypeNotFound) are
        filtered via PSScriptBuilderAstEngine.GetStructuralParseErrors and logged as verbose
        output. These occur when the script references types from external assemblies that are
        not loaded at build time, which is expected and valid.
    .OUTPUTS
        Returns $true if the output file is syntactically valid.
    #>
    hidden [bool] ValidateSyntax() {
        Write-Verbose "Validating output syntax (parse check)..."

        $parseResult  = [PSScriptBuilderAstEngine]::ParseFile($this.OutputPath)
        $parseErrors  = $parseResult.ParseErrors
        $syntaxErrors = [PSScriptBuilderAstEngine]::GetStructuralParseErrors($parseErrors)

        if ($syntaxErrors.Count -gt 0) {
            $format  = "Output syntax validation failed: {0}"
            $message = $format -f $syntaxErrors[0].Message
            throw [InvalidOperationException]::new($message)
        }

        $seenMessages = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($parseError in $parseErrors) {
            if ($seenMessages.Add($parseError.Message)) {
                Write-Verbose "  Ignored $($parseError.ErrorId): $($parseError.Message)"
            }
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
        2. Mask {{{{KEY}}}} escape sequences before any placeholder-matching step below sees the content
        3. Execute content collection
        4. Warn about encoding issues (advisory, skipped when system encoding is UTF-8)
        5. Analyze dependencies (delegated to PSScriptBuilderDependencyAnalyzer)
        6. Warn about cross-collector dependencies (Free Mode only, advisory)
        7. Process template and replace placeholders with content
        8. Unmask escape sequences, restoring literal, un-escaped text in the rendered output
        9. Create backup of the existing output file (if enabled)
        10. Write final script to the output file
        11. Validate output syntax (parse check)
        12. Gather build statistics (component details, processed files, execution time)

        If any step fails, an exception is thrown with detailed context.
        Upon successful completion, returns a BuildResult with comprehensive build information.
    .OUTPUTS
        Returns a PSScriptBuilderBuildResult containing build metrics, component details,
        and file statistics.
    #>
    [PSScriptBuilderBuildResult] ExecuteBuild() {
        try {
            $stopwatch  = [Stopwatch]::StartNew()
            $phaseWatch = [Stopwatch]::new()
            Write-Verbose "Starting script build..."

            # Load template
            $this.TemplateContent = $this.LoadTemplate()

            # Mask any {{{{KEY}}}} escape sequences before any placeholder-matching consumer
            # (mode detection, validation, rendering) sees the content
            $maskResult             = [PSScriptBuilderTemplateEscapeHelper]::Mask($this.TemplateContent)
            $this.TemplateContent   = $maskResult.MaskedContent
            $this.TemplateEscapeMap = $maskResult.EscapeMap

            # Execute content collection
            $phaseWatch.Restart()
            $this.ContentCollector.Execute()
            Write-Verbose "Collection completed in $([PSScriptBuilderTextHelper]::FormatDuration($phaseWatch.Elapsed))"

            # Advise on BOM-less source files (compatibility with other tools, not PSScriptBuilder itself)
            $this.WarnEncodingIssues()

            # Analyze dependencies
            $phaseWatch.Restart()
            $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($this.ContentCollector)
            $analysisResult = $analyzer.Analyze()
            Write-Verbose "Dependency analysis completed in $([PSScriptBuilderTextHelper]::FormatDuration($phaseWatch.Elapsed))"

            if ($analysisResult.HasCycles) {
                $cycleString = $analysisResult.CyclePath -join " -> "
                $message = "Circular dependency detected: $cycleString"
                throw [InvalidOperationException]::new($message)
            }

            # Process template
            $useOrderedMode = [PSScriptBuilderTemplateModeResolver]::IsOrderedModeRequired($analysisResult.HasCrossDependencies, $this.TemplateContent, $this.OrderedComponentsKey)

            # Warn about cross-collector dependencies only in Free Mode -
            # in Ordered/Hybrid Mode {{ORDERED_COMPONENTS}} handles global sorting automatically
            if (-not $useOrderedMode) {
                $this.WarnCrossCollectorDependencies($analysisResult.DependencyGraph)
            }

            $phaseWatch.Restart()
            $finalScript = $this.ProcessTemplate(
                $analysisResult.OrderedComponents,
                $useOrderedMode
            )
            Write-Verbose "Template processing completed in $([PSScriptBuilderTextHelper]::FormatDuration($phaseWatch.Elapsed))"

            # Restore escaped sequences as literal, un-escaped text - must happen before WriteOutput
            # and CreateSourceMap, both of which consume this same $finalScript
            $finalScript = [PSScriptBuilderTemplateEscapeHelper]::Unmask($finalScript, $this.TemplateEscapeMap)

            # Create backup immediately before overwriting the output file (optional)
            if ($this.BackupEnabled) {
                $this.BackupPath = $this.CreateBackup()
            }
            else {
                $this.BackupPath = $null
            }

            # Write output
            $phaseWatch.Restart()
            $this.WriteOutput($finalScript)
            Write-Verbose "Output written in $([PSScriptBuilderTextHelper]::FormatDuration($phaseWatch.Elapsed))"
            $phaseWatch.Stop()

            # Write source map sidecar (optional)
            $sourceMapPath = $null
            if ($this.WriteSourceMap) {
                $sourceMap = [PSScriptBuilderSourceMapGenerator]::CreateSourceMap($finalScript, $this.ContentCollector)
                [PSScriptBuilderSourceMapFileManager]::WriteSourceMapData($this.OutputPath, $sourceMap)
                $sourceMapPath = [PSScriptBuilderSourceMapFileManager]::GetSidecarPath($this.OutputPath)
            }

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

            Write-Verbose "Script build complete in $([PSScriptBuilderTextHelper]::FormatDuration($stopwatch.Elapsed))"

            return [PSScriptBuilderBuildResult]::new(
                $this.OutputPath,
                $fileInfo.Length,
                $this.BackupPath,
                $sourceMapPath,
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

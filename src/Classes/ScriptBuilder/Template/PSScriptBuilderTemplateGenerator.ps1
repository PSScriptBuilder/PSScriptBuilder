using namespace System
using namespace System.Collections.Generic
using namespace System.IO

#region Class PSScriptBuilderTemplateGenerator
<#
.SYNOPSIS
    Generates a PSScriptBuilder template file from a content collector configuration.
.DESCRIPTION
    The PSScriptBuilderTemplateGenerator class orchestrates the complete template generation workflow:

    1. Dependency Analysis: Runs PSScriptBuilderDependencyAnalyzer to detect cross-dependencies.
       The caller must execute the ContentCollector before calling Generate().
    2. Mode Determination: Determines Free, Ordered, or Hybrid mode based on analysis result
       and the OrderedMode flag.
    3. Placeholder Building: Builds the ordered list of placeholder tokens based on the mode
       and registered collectors.
    4. Content Generation: Assembles the template file content as a string.
    5. Output Path Validation: Checks if the output file already exists and respects the Force flag.
    6. File Writing: Writes the template content using UTF8 with BOM encoding.
    7. Result Construction: Returns a PSScriptBuilderTemplateGenerationResult.

    Mode determination rules:
    - HasCrossDependencies = true                        => Ordered (regardless of OrderedMode)
    - HasCrossDependencies = false AND OrderedMode = true  => Hybrid
    - HasCrossDependencies = false AND OrderedMode = false => Free

    Placeholder rules in Ordered/Hybrid mode:
    - {{<OrderedComponentsKey>}} is always included
    - {{<CollectionKey>}} for UsingCollector and FileCollector (if registered)
    - EnumCollector, ClassCollector, FunctionCollector placeholders are omitted
      (their content is rendered via the ORDERED_COMPONENTS placeholder)

    Placeholder rules in Free mode:
    - {{<CollectionKey>}} for every registered collector, in CollectorType order
#>
class PSScriptBuilderTemplateGenerator {
    #region Properties
    <#
    .SYNOPSIS
        The content collector containing all configured collectors.
    .DESCRIPTION
        The ContentCollector property holds a reference to the PSScriptBuilderContentCollector
        whose registered collectors define the placeholders of the generated template.
        The caller must execute the ContentCollector before calling Generate().
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector

    <#
    .SYNOPSIS
        The absolute output path for the generated template file.
    .DESCRIPTION
        The OutputPath property holds the resolved absolute path where the template file will be written.
    #>
    hidden [string] $OutputPath

    <#
    .SYNOPSIS
        The placeholder key used for dependency-ordered components.
    .DESCRIPTION
        The OrderedComponentsKey property holds the key used in the {{...}} token for the ordered
        components placeholder (e.g. "ORDERED_COMPONENTS" => {{ORDERED_COMPONENTS}}).
    #>
    hidden [string] $OrderedComponentsKey

    <#
    .SYNOPSIS
        Whether to force ordered/hybrid mode regardless of dependency analysis.
    .DESCRIPTION
        The OrderedMode property controls whether the generator uses ordered-mode placeholders
        even when no cross-dependencies are detected. When true, the resulting mode is Hybrid.
    #>
    hidden [bool] $OrderedMode

    <#
    .SYNOPSIS
        Whether to overwrite an existing output file.
    .DESCRIPTION
        The Force property controls whether an existing template file at the output path may be
        overwritten. When false, the generator throws if the file already exists.
    #>
    hidden [bool] $Force
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderTemplateGenerator.
    .DESCRIPTION
        Creates the generator with the specified configuration. All parameters are validated
        before assignment.
    .PARAMETER contentCollector
        The content collector with registered component collectors. Cannot be null.
    .PARAMETER outputPath
        The resolved absolute path for the output template file. Cannot be null or empty.
    .PARAMETER orderedComponentsKey
        The key used for the ordered-components placeholder. Cannot be null or empty.
    .PARAMETER orderedMode
        When true, forces Hybrid mode even if no cross-dependencies are detected.
    .PARAMETER force
        When true, allows overwriting an existing template file.
    #>
    PSScriptBuilderTemplateGenerator(
        [PSScriptBuilderContentCollector] $contentCollector,
        [string]                          $outputPath,
        [string]                          $orderedComponentsKey,
        [bool]                            $orderedMode,
        [bool]                            $force
    ) {
        if ($null -eq $contentCollector) {
            $message = "Parameter 'contentCollector' cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            $message = "Parameter 'outputPath' cannot be null or empty."
            throw [ArgumentException]::new($message, "outputPath")
        }

        if ([string]::IsNullOrWhiteSpace($orderedComponentsKey)) {
            $message = "Parameter 'orderedComponentsKey' cannot be null or empty."
            throw [ArgumentException]::new($message, "orderedComponentsKey")
        }

        $this.ContentCollector     = $contentCollector
        $this.OutputPath           = $outputPath
        $this.OrderedComponentsKey = $orderedComponentsKey
        $this.OrderedMode          = $orderedMode
        $this.Force                = $force
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Generates the template file and returns the generation result.
    .DESCRIPTION
        The Generate() method orchestrates the complete template generation workflow:

        1. Validates that output file does not already exist (unless Force is set)
        2. Runs dependency analysis (ContentCollector must have been executed by the caller)
        3. Determines mode (Free, Ordered, Hybrid)
        4. Retrieves collectors sorted by CollectorType
        5. Builds placeholder list based on mode
        6. Assembles template content
        7. Writes the template file using UTF8 with BOM
        8. Returns PSScriptBuilderTemplateGenerationResult

        Throws InvalidOperationException if the output file already exists and Force is false.
    .OUTPUTS
        Returns a PSScriptBuilderTemplateGenerationResult containing the generation details.
    #>
    [PSScriptBuilderTemplateGenerationResult] Generate() {
        Write-Verbose "Preparing template generation..."

        # Step 1: Validate output path (fail fast before expensive analysis)
        if ([File]::Exists($this.OutputPath) -and -not $this.Force) {
            $message = "The output file already exists: '{0}'. Use -Force to overwrite." -f $this.OutputPath
            throw [InvalidOperationException]::new($message)
        }

        # Step 2: Run dependency analysis (ContentCollector must have been executed by the caller)
        $analyzer       = [PSScriptBuilderDependencyAnalyzer]::new($this.ContentCollector)
        $analysisResult = $analyzer.Analyze()

        Write-Verbose "Starting template generation..."

        # Step 3: Determine mode
        $hasCrossDependencies = $analysisResult.HasCrossDependencies

        if ($hasCrossDependencies) {
            $mode = [PSScriptBuilderTemplateValidationMode]::Ordered
        }
        elseif ($this.OrderedMode) {
            $mode = [PSScriptBuilderTemplateValidationMode]::Hybrid
        }
        else {
            $mode = [PSScriptBuilderTemplateValidationMode]::Free
        }

        Write-Verbose "  Mode: $mode (HasCrossDependencies=$hasCrossDependencies, OrderedMode=$($this.OrderedMode))"

        # Step 4: Retrieve collectors sorted by CollectorType
        $collectors = $this.ContentCollector.GetCollectors()

        # Step 5: Build placeholder list based on mode
        $useOrderedMode = ($mode -ne [PSScriptBuilderTemplateValidationMode]::Free)
        $placeholders   = $this.BuildPlaceholders($useOrderedMode, $collectors)

        Write-Verbose "  Placeholders ($($placeholders.Count)):"
        foreach ($placeholder in $placeholders) {
            Write-Verbose "    $placeholder"
        }

        # Step 6: Assemble template content
        $content = $this.BuildTemplateContent($placeholders)

        # Step 7: Write template file
        $directory = [Path]::GetDirectoryName($this.OutputPath)

        if ($directory -and -not (Test-Path -Path $directory -PathType Container)) {
            try {
                [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($directory)
                Write-Verbose "  Created output directory: $directory"
            }
            catch {
                $format  = "Failed to create output directory: '{0}'. Error: {1}"
                $message = $format -f $directory, $_.Exception.Message
                throw [IOException]::new($message, $_.Exception)
            }
        }

        try {
            [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($this.OutputPath, $content)
            Write-Verbose "  Template written to: $($this.OutputPath)"
        }
        catch {
            $format  = "Failed to write template file: '{0}'. Error: {1}"
            $message = $format -f $this.OutputPath, $_.Exception.Message
            throw [IOException]::new($message, $_.Exception)
        }

        # Step 8: Return result
        $result = [PSScriptBuilderTemplateGenerationResult]::new(
            $this.OutputPath,
            $mode,
            $placeholders,
            $this.OrderedMode
        )

        Write-Verbose "Template generation complete"
        return $result
    }

    <#
    .SYNOPSIS
        Builds the ordered list of placeholder tokens based on mode and collectors.
    .DESCRIPTION
        The BuildPlaceholders() method constructs the list of {{...}} tokens to include in the
        generated template, following the same rules as PSScriptBuilderTemplateAnalyzer:

        Ordered/Hybrid mode:
        - {{<OrderedComponentsKey>}} is included
        - {{<CollectionKey>}} for UsingCollector is prepended (if registered)
        - {{<CollectionKey>}} for FileCollector is appended (if registered)
        - EnumCollector, ClassCollector, FunctionCollector are omitted

        Free mode:
        - {{<CollectionKey>}} for every collector, in CollectorType order
    .PARAMETER useOrderedMode
        True when mode is Ordered or Hybrid.
    .PARAMETER collectors
        All registered collectors, sorted by CollectorType.
    .OUTPUTS
        Returns an ordered string array of placeholder tokens.
    #>
    hidden [string[]] BuildPlaceholders([bool] $useOrderedMode, [PSScriptBuilderCollectorBase[]] $collectors) {
        $list = [List[string]]::new()

        if ($useOrderedMode) {
            # UsingCollector placeholder first (if registered)
            foreach ($collector in $this.ContentCollector.GetUsingCollectors()) {
                $list.Add("{{{{{0}}}}}" -f $collector.CollectionKey)
            }

            # OrderedComponents placeholder
            $list.Add("{{{{{0}}}}}" -f $this.OrderedComponentsKey)

            # FileCollector placeholder last (if registered)
            foreach ($collector in $this.ContentCollector.GetFileCollectors()) {
                $list.Add("{{{{{0}}}}}" -f $collector.CollectionKey)
            }
        }
        else {
            # Free mode: all collectors in CollectorType order
            foreach ($collector in $collectors) {
                $list.Add("{{{{{0}}}}}" -f $collector.CollectionKey)
            }
        }

        return $list.ToArray()
    }

    <#
    .SYNOPSIS
        Assembles the template file content from the placeholder list.
    .DESCRIPTION
        The BuildTemplateContent() method joins all placeholders with a blank line between each,
        producing the complete template file content.
    .PARAMETER placeholders
        The ordered list of placeholder tokens to include.
    .OUTPUTS
        Returns the template content as a string.
    #>
    hidden [string] BuildTemplateContent([string[]] $placeholders) {
        $newLine = [Environment]::NewLine
        return $placeholders -join "$newLine$newLine"
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderTemplateGenerator

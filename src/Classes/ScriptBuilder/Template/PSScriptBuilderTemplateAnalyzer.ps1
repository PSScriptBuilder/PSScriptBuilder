using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderTemplateAnalyzer
<#
.SYNOPSIS
    Analyzes PowerShell template files for validation, placeholders, and dependencies.
.DESCRIPTION
    The PSScriptBuilderTemplateAnalyzer performs comprehensive template analysis including:

    1. Template Loading:       Resolves and loads the template file
    2. Dependency Analysis:    Analyzes dependencies (determines HasCrossDependencies); the caller must execute the ContentCollector first
    3. Collector Access:       Retrieves collectors from the already-executed ContentCollector
    4. Placeholder Extraction: Finds all placeholders in the template
    5. Mode Derivation:        Derives $useOrderedMode and $validationMode (Free / Hybrid / Ordered)
    6. Expected Placeholders:  Calculates which placeholders should exist based on mode and collectors
    7. Placeholder Analysis:   Identifies missing (expected but not found) and unknown (found but not expected) placeholders
    8. Template Validation:    Validates template structure and content
    9. Result Building:        Constructs comprehensive analysis result

    The analyzer is separated from the cmdlet to follow the Single Responsibility Principle.
    It can be reused in different contexts (cmdlets, tests, validation workflows) and provides
    a clean, testable interface for template analysis.
#>
class PSScriptBuilderTemplateAnalyzer {
    #region Properties
    <#
    .SYNOPSIS
        The content collector containing all component collectors.
    .DESCRIPTION
        The ContentCollector property holds a reference to the ContentCollector that manages all registered
        collectors (Using, Enum, Class, Function, File). The analyzer uses this to retrieve already-collected
        component data for dependency analysis. The caller must execute the ContentCollector before calling Analyze().
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector

    <#
    .SYNOPSIS
        The path to the template file to analyze.
    .DESCRIPTION
        The TemplatePath property specifies the path to the template file. Can be absolute or relative
        to the project root. The path is resolved during analysis.
    #>
    hidden [string] $TemplatePath

    <#
    .SYNOPSIS
        The placeholder key for dependency-ordered components.
    .DESCRIPTION
        The OrderedComponentsKey property specifies the placeholder key used in the template for
        dependency-ordered components (e.g., "ORDERED_COMPONENTS" results in {{ORDERED_COMPONENTS}}).
    #>
    hidden [string] $OrderedComponentsKey
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderTemplateAnalyzer.
    .DESCRIPTION
        Creates the analyzer with the specified content collector, template path, and ordered components key.
        All parameters are validated during construction.
    .PARAMETER contentCollector
        The content collector with registered component collectors. Cannot be null.
    .PARAMETER templatePath
        The path to the template file to analyze. Cannot be null or empty.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components. Cannot be null or empty.
    #>
    PSScriptBuilderTemplateAnalyzer(
        [PSScriptBuilderContentCollector] $contentCollector,
        [string]                          $templatePath,
        [string]                          $orderedComponentsKey
    ) {
        if ($null -eq $contentCollector) {
            $message = "Parameter 'contentCollector' cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        if ([string]::IsNullOrWhiteSpace($templatePath)) {
            $message = "Parameter 'templatePath' cannot be null or empty."
            throw [ArgumentException]::new($message, "templatePath")
        }

        if ([string]::IsNullOrWhiteSpace($orderedComponentsKey)) {
            $message = "Parameter 'orderedComponentsKey' cannot be null or empty."
            throw [ArgumentException]::new($message, "orderedComponentsKey")
        }

        $this.ContentCollector     = $contentCollector
        $this.TemplatePath         = $templatePath
        $this.OrderedComponentsKey = $orderedComponentsKey
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Performs comprehensive template analysis.
    .DESCRIPTION
        The Analyze() method orchestrates the complete template analysis workflow:

        1. Resolves and loads the template file
        2. Analyzes dependencies (caller must have executed ContentCollector before calling Analyze())
        3. Retrieves collectors from the already-executed ContentCollector
        4. Extracts placeholders from template
        5. Derives $useOrderedMode (HasCrossDependencies OR template contains {{ORDERED_COMPONENTS}})
           and $validationMode (Free / Hybrid / Ordered) from code structure + template content
        6. Builds expected placeholders based on $useOrderedMode and collectors
        7. Calculates missing (expected but not found) and unknown (found but not expected) placeholders
        8. Validates template (collects validation errors if any)
        9. Constructs and returns focused result object

        Returns a strongly-typed PSScriptBuilderTemplateAnalysisResult object containing
        template-specific analysis results. For detailed dependency analysis, use
        Get-PSScriptBuilderDependencyAnalysis separately.
    .OUTPUTS
        Returns a PSScriptBuilderTemplateAnalysisResult containing template analysis results.
    #>
    [PSScriptBuilderTemplateAnalysisResult] Analyze() {
        Write-Verbose "Starting template analysis..."

        # Step 1: Resolve and load template
        $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($this.TemplatePath)
        $templateContent = [PSScriptBuilderTemplateFileManager]::LoadTemplate($resolvedPath)
        $templateSize = $templateContent.Length

        # Step 2: Analyze dependencies (ContentCollector must have been executed by the caller)
        $analyzer = [PSScriptBuilderDependencyAnalyzer]::new($this.ContentCollector)
        $dependencyResult = $analyzer.Analyze()

        # Step 3: Get collectors from the already-executed ContentCollector
        $collectors = $this.ContentCollector.GetCollectors()

        # Step 4: Extract placeholders from template
        $placeholdersFound = $this.ExtractPlaceholders($templateContent)

        # Step 5: Derive $useOrderedMode and $validationMode (placeholders must be known first)
        $orderedPlaceholderToken       = "{{{{{0}}}}}" -f $this.OrderedComponentsKey
        $templateHasOrderedPlaceholder = $placeholdersFound -contains $orderedPlaceholderToken
        $useOrderedMode                = $dependencyResult.HasCrossDependencies -or $templateHasOrderedPlaceholder

        if ($dependencyResult.HasCrossDependencies) {
            $validationMode = [PSScriptBuilderTemplateValidationMode]::Ordered
        }
        elseif ($templateHasOrderedPlaceholder) {
            $validationMode = [PSScriptBuilderTemplateValidationMode]::Hybrid
        }
        else {
            $validationMode = [PSScriptBuilderTemplateValidationMode]::Free
        }

        # Step 6: Build expected placeholders based on mode
        $placeholdersExpected = $this.BuildExpectedPlaceholders($useOrderedMode, $collectors)

        # Step 7: Calculate missing and unknown placeholders
        $missingPlaceholders = $this.CalculateMissingPlaceholders($placeholdersFound, $placeholdersExpected)
        $unknownPlaceholders = $this.CalculateUnknownPlaceholders($placeholdersFound, $placeholdersExpected)

        # Step 8: Validate template (TemplateValidator logs, may throw)
        $isValid = $false
        $validationErrors = @()

        try {
            [PSScriptBuilderTemplateValidator]::Validate(
                $templateContent,
                $this.OrderedComponentsKey,
                $useOrderedMode,
                $collectors
            )

            $isValid = $true
        }
        catch [InvalidOperationException] {
            # Validation failed - collect error message
            $validationErrors = @($_.Exception.Message)
            Write-Verbose "  $($_.Exception.Message)"
        }

        # Step 9: Create result object
        $result = [PSScriptBuilderTemplateAnalysisResult]::new(
            $isValid,
            $validationErrors,
            $resolvedPath,
            $templateSize,
            $validationMode,
            $this.OrderedComponentsKey,
            $dependencyResult.HasCrossDependencies,
            $placeholdersFound,
            $placeholdersExpected,
            $missingPlaceholders,
            $unknownPlaceholders
        )

        Write-Verbose "Template analysis complete"
        return $result
    }

    <#
    .SYNOPSIS
        Extracts all placeholders from template content.
    .DESCRIPTION
        The ExtractPlaceholders() method uses regex to find all {{...}} patterns in the template
        and returns them as a sorted array of unique placeholder strings.
    .PARAMETER templateContent
        The template content to extract placeholders from.
    .OUTPUTS
        Returns an array of unique placeholder strings found in the template, sorted alphabetically.
    #>
    hidden [string[]] ExtractPlaceholders([string] $templateContent) {
        $placeholderPattern = '\{\{([^}]+)\}\}'
        $regexMatches = [regex]::Matches($templateContent, $placeholderPattern)

        $result = @($regexMatches | ForEach-Object { $_.Value })
        return $result | Sort-Object -Unique
    }

    <#
    .SYNOPSIS
        Builds the list of expected placeholders based on rendering mode and collectors.
    .DESCRIPTION
        The BuildExpectedPlaceholders() method determines which placeholders should exist in the template
        based on the rendering mode and registered collectors:

        Ordered/Hybrid mode ($useOrderedMode = $true):
        - {{ORDERED_COMPONENTS}} placeholder is required
        - {{USING}} and {{FILE}} placeholders are allowed (if collectors registered)
        - {{ENUM}}, {{CLASS}}, {{FUNCTION}} placeholders are not expected (they render via ORDERED_COMPONENTS)

        Free mode ($useOrderedMode = $false):
        - Individual collector placeholders are required for all registered collectors
    .PARAMETER useOrderedMode
        True for Ordered/Hybrid mode, false for Free mode.
    .PARAMETER collectors
        Array of all registered collectors.
    .OUTPUTS
        Returns an array of expected placeholder strings, sorted alphabetically.
    #>
    hidden [string[]] BuildExpectedPlaceholders([bool] $useOrderedMode, [PSScriptBuilderCollectorBase[]] $collectors) {
        $expectedList = [List[string]]::new()

        if ($useOrderedMode) {
            # Ordered/Hybrid mode: ORDERED_COMPONENTS required, USING and FILE allowed, ENUM/CLASS/FUNCTION forbidden

            # ORDERED_COMPONENTS is mandatory
            $expectedList.Add("{{{{{0}}}}}" -f $this.OrderedComponentsKey)

            # Add allowed collector placeholders (Using, File)
            foreach ($collector in $collectors) {
                $collectorType = $collector.CollectorType

                # Using and File collectors are allowed
                if (
                    $collectorType -eq [PSScriptBuilderCollectorType]::UsingCollector -or
                    $collectorType -eq [PSScriptBuilderCollectorType]::FileCollector
                ) {
                    $expectedList.Add("{{{{{0}}}}}" -f $collector.CollectionKey)
                }
                # Enum/Class/Function are NOT expected (they're in ORDERED_COMPONENTS)
            }
        }
        else {
            # Free mode: individual collector placeholders expected
            foreach ($collector in $collectors) {
                $expectedList.Add("{{{{{0}}}}}" -f $collector.CollectionKey)
            }
        }

        return @($expectedList | Sort-Object)
    }

    <#
    .SYNOPSIS
        Calculates placeholders that are expected but not found in the template.
    .DESCRIPTION
        The CalculateMissingPlaceholders() method performs case-insensitive comparison between
        expected and found placeholders to identify which placeholders are missing.
    .PARAMETER placeholdersFound
        Placeholders found in the template.
    .PARAMETER placeholdersExpected
        Placeholders expected based on mode and collectors.
    .OUTPUTS
        Returns an array of missing placeholder strings, sorted alphabetically.
    #>
    hidden [string[]] CalculateMissingPlaceholders([string[]] $placeholdersFound, [string[]] $placeholdersExpected) {
        $foundSet = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($placeholder in $placeholdersFound) {
            $foundSet.Add($placeholder) | Out-Null
        }

        $result = @($placeholdersExpected | Where-Object { -not $foundSet.Contains($_) })
        return $result | Sort-Object
    }

    <#
    .SYNOPSIS
        Calculates placeholders that are found but not expected in the template.
    .DESCRIPTION
        The CalculateUnknownPlaceholders() method performs case-insensitive comparison between
        found and expected placeholders to identify which placeholders are unknown.
    .PARAMETER placeholdersFound
        Placeholders found in the template.
    .PARAMETER placeholdersExpected
        Placeholders expected based on mode and collectors.
    .OUTPUTS
        Returns an array of unknown placeholder strings, sorted alphabetically.
    #>
    hidden [string[]] CalculateUnknownPlaceholders([string[]] $placeholdersFound, [string[]] $placeholdersExpected) {
        $expectedSet = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($placeholder in $placeholdersExpected) {
            $expectedSet.Add($placeholder) | Out-Null
        }

        $result = @($placeholdersFound | Where-Object { -not $expectedSet.Contains($_) })
        return $result | Sort-Object
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderTemplateAnalyzer

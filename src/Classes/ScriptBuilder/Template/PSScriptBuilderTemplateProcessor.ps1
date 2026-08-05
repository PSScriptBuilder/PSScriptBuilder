using namespace System
using namespace System.Collections.Generic
using namespace System.Text

#region Class PSScriptBuilderTemplateProcessor
<#
.SYNOPSIS
    Processes build templates by replacing placeholders with component source code.
.DESCRIPTION
    The PSScriptBuilderTemplateProcessor class processes build templates containing placeholders.
    It supports two rendering strategies, selected by the $UseOrderedMode property:

    1. Ordered/Hybrid Mode ($UseOrderedMode = $true):
       - Replaces the {{ORDERED_COMPONENTS}} placeholder with dependency-ordered source code
       - Using and File placeholders are replaced individually

    2. Free Mode ($UseOrderedMode = $false):
       - Replaces individual collector placeholders with their respective content
       - No dependency ordering enforced

    Template validation is delegated to PSScriptBuilderTemplateValidator (Single Responsibility Principle).
    The processor uses the ContentCollector's GetComponentSourceCode() method to retrieve source code,
    implementing the Law of Demeter and Information Expert patterns.
#>
class PSScriptBuilderTemplateProcessor {
    #region Properties
    <#
    .SYNOPSIS
        Reference to the ContentCollector containing all collected components.
    .DESCRIPTION
        Used to retrieve component source code via GetComponentSourceCode() method.
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector

    <#
    .SYNOPSIS
        The ContentProcessor for content preparation and formatting.
    .DESCRIPTION
        Provides access to processed content from collectors, handles consolidation
        (Using statements) and content building.
    #>
    hidden [PSScriptBuilderContentProcessor] $ContentProcessor

    <#
    .SYNOPSIS
        The template content with placeholders.
    .DESCRIPTION
        Contains the template text with {{PLACEHOLDER}} markers to be replaced.
    #>
    hidden [string] $TemplateContent

    <#
    .SYNOPSIS
        The placeholder key for dependency-ordered components.
    .DESCRIPTION
        The key used in Ordered/Hybrid mode (e.g., "ORDERED_COMPONENTS").
        Template placeholder format: {{KEY}}
    #>
    hidden [string] $OrderedComponentsKey

    <#
    .SYNOPSIS
        Indicates whether the template uses Ordered or Hybrid rendering mode.
    .DESCRIPTION
        True routes rendering through RenderOrderedMode() (replaces {{ORDERED_COMPONENTS}}).
        False routes rendering through RenderFreeMode() (replaces individual collector placeholders).
        This value is set during construction and determines both validation and rendering behavior.
    #>
    hidden [bool] $UseOrderedMode
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderTemplateProcessor.
    .DESCRIPTION
        Creates a template processor with the specified content collector, template content, ordered components key,
        and rendering mode. Validates the template immediately during construction using PSScriptBuilderTemplateValidator
        (Fail-Fast Principle, Single Responsibility Principle).
    .PARAMETER contentCollector
        The ContentCollector instance containing all collected components.
    .PARAMETER templateContent
        The template content with placeholders to process.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components (e.g., "ORDERED_COMPONENTS").
    .PARAMETER useOrderedMode
        True for Ordered/Hybrid mode (uses {{ORDERED_COMPONENTS}}), false for Free mode.
    .EXAMPLE
        $processor = [PSScriptBuilderTemplateProcessor]::new($collector, $template, "ORDERED_COMPONENTS", $true)
    .NOTES
        Throws ArgumentNullException if contentCollector is null.
        Throws ArgumentException if templateContent or orderedComponentsKey is null or whitespace.
        Throws InvalidOperationException if template validation fails (via PSScriptBuilderTemplateValidator).
    #>
    PSScriptBuilderTemplateProcessor(
        [PSScriptBuilderContentCollector] $contentCollector,
        [string]                          $templateContent,
        [string]                          $orderedComponentsKey,
        [bool]                            $useOrderedMode
    ) {
        if ($null -eq $contentCollector) {
            $message = "ContentCollector cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        if ([string]::IsNullOrWhiteSpace($templateContent)) {
            $message = "Template content cannot be null or empty."
            throw [ArgumentException]::new($message, "templateContent")
        }

        if ([string]::IsNullOrWhiteSpace($orderedComponentsKey)) {
            $message = "Ordered components key cannot be null or empty."
            throw [ArgumentException]::new($message, "orderedComponentsKey")
        }

        $this.ContentCollector     = $contentCollector
        $this.ContentProcessor     = [PSScriptBuilderContentProcessor]::new($contentCollector)
        $this.TemplateContent      = $templateContent
        $this.OrderedComponentsKey = $orderedComponentsKey
        $this.UseOrderedMode       = $useOrderedMode

        Write-Verbose "TemplateProcessor initialized with ordered components key: $orderedComponentsKey (UseOrderedMode: $useOrderedMode)"

        # Validate template immediately (Fail-Fast Principle)
        $this.ValidateTemplate()
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Renders the template by replacing placeholders with source code.
    .DESCRIPTION
        The Render() method replaces placeholders with component source code according to the rendering mode
        configured during construction ($UseOrderedMode property).

        Ordered/Hybrid Mode ($UseOrderedMode = $true):
        - Replaces Using and File collector placeholders individually
        - Replaces {{ORDERED_COMPONENTS}} with dependency-sorted source code

        Free Mode ($UseOrderedMode = $false):
        - Replaces individual collector placeholders with their respective content

        Uses ContentCollector.GetComponentSourceCode() to retrieve component source code,
        following the Information Expert pattern.
    .PARAMETER orderedComponents
        Array of component names in dependency order. Used in both modes:
        - Ordered/Hybrid mode: Direct usage for output order
        - Free Mode: Used by Enum/Class collectors for dependency-aware ordering
    .OUTPUTS
        Returns the processed template content with placeholders replaced by source code.
    .EXAMPLE
        $result = $processor.Render($orderedComponents)
    .NOTES
        Template is already validated during construction.
        Throws InvalidOperationException if a component is not found.
    #>
    [string] Render([string[]] $orderedComponents) {
        Write-Verbose "Rendering template (UseOrderedMode: $($this.UseOrderedMode))..."

        $result = $this.TemplateContent

        if ($this.UseOrderedMode) {
            $result = $this.RenderOrderedMode($result, $orderedComponents)
        }
        else {
            $result = $this.RenderFreeMode($result, $orderedComponents)
        }

        Write-Verbose "Template rendering complete"
        return $result
    }

    <#
    .SYNOPSIS
        Renders template in ordered/hybrid mode.
    .DESCRIPTION
        In Ordered/Hybrid mode, the template is processed in three steps:
        1. Replace Using collector placeholders with consolidated Using statements
        2. Replace File collector placeholders with file content
        3. Replace {{ORDERED_COMPONENTS}} placeholder with dependency-sorted components

        This ensures Using statements appear first (PowerShell requirement), followed by
        file content, and then dependency-sorted source code.

        Both Ordered mode (HasCrossDependencies = true) and Hybrid mode (HasCrossDependencies = false,
        {{ORDERED_COMPONENTS}} explicit in template) follow this same three-step sequence.
    .PARAMETER template
        The template content to process.
    .PARAMETER orderedComponents
        Array of component names in dependency order.
    .OUTPUTS
        Returns template with all placeholders replaced.
    #>
    hidden [string] RenderOrderedMode([string] $template, [string[]] $orderedComponents) {
        Write-Verbose "  Mode: Ordered/Hybrid (flexible)"

        # Step 1: Replace Using collector placeholders
        $result = $this.ReplaceUsingCollectorPlaceholders($template)

        # Step 2: Replace File collector placeholders
        $result = $this.ReplaceFileCollectorPlaceholders($result)

        # Step 3: Replace ORDERED_COMPONENTS placeholder
        $result = $this.ReplaceOrderedComponentsPlaceholder($result, $orderedComponents)

        return $result
    }

    <#
    .SYNOPSIS
        Renders template in free mode using a two-phase approach.
    .DESCRIPTION
        The RenderFreeMode() method replaces collector placeholders with their content in two phases:

        Phase 1 - Discovery:
            All placeholder positions are located in the ORIGINAL, unmodified $template string.
            For each placeholder found, the replacement content is pre-computed via ContentProcessor.
            This phase produces a list of positional replacement entries (Start, Length, Replacement).

        Phase 2 - Assembly:
            AssembleFromReplacements() builds the final string by copying literal segments from
            the original $template and inserting replacements at the discovered positions.
            Replacement content is written directly into the output buffer and is NEVER re-scanned.

        This two-phase design prevents template injection: source code written into earlier
        replacements may contain {{Placeholder}} tokens (e.g., in PowerShell comment-based help),
        but these are never interpreted as placeholders because the scanner only reads from
        the original $template.
    .PARAMETER template
        The original template content to process. Must not be modified between phases.
    .PARAMETER orderedComponents
        Array of component names in dependency order. Passed to ContentProcessor for
        dependency-aware ordering of Enum/Class/Function content.
    .OUTPUTS
        Returns the assembled template with all collector placeholders replaced.
    #>
    hidden [string] RenderFreeMode([string] $template, [string[]] $orderedComponents) {
        Write-Verbose "  Mode: Free (individual collector keys)"

        # Phase 1: Discover all placeholder positions and pre-compute replacement content.
        $replacements = $this.DiscoverReplacements($template, $orderedComponents)

        if ($replacements.Count -eq 0) {
            Write-Verbose "  No placeholders found in template"
            return $template
        }

        # Phase 2: Assemble output - literal template segments and replacements are interleaved.
        $result = $this.AssembleFromReplacements($template, $replacements.ToArray())
        Write-Verbose "  Template rendered with $($replacements.Count) replacement(s)"
        return $result
    }

    <#
    .SYNOPSIS
        Discovers placeholder positions in the template and prepares replacement content.
    .DESCRIPTION
        The DiscoverReplacements() method implements Phase 1 of the two-phase rendering approach.
        It scans the ORIGINAL, unmodified $template for collector placeholders and computes
        the replacement content for each one found.

        For each registered collector, the method:
            1. Constructs the placeholder string from the collector's CollectionKey.
            2. Locates the placeholder in $template using IndexOf (ordinal, case-sensitive).
            3. If found, delegates content building to ContentProcessor.BuildCollectorContent().
            4. Records the position (Start), size (Length), and content (Replacement) as an entry.

        All position lookups are performed on the unmodified $template. The method never writes
        to $template - the returned entries are the sole output. This strict read-only contract
        is what makes Phase 2 (AssembleFromReplacements) injection-safe: replacement content
        containing {{...}} tokens is pre-computed here but never fed back into the scanner.

        Precondition: ValidateNoDuplicatePlaceholders() guarantees each placeholder appears at
        most once in $template, so IndexOf (which returns the first occurrence) is sufficient.
    .PARAMETER template
        The original, unmodified template string. Read-only - must not be modified by this method.
    .PARAMETER orderedComponents
        Array of component names in dependency order. Forwarded to ContentProcessor for
        dependency-aware content ordering of Enum/Class/Function collectors.
    .OUTPUTS
        Returns a List of PSCustomObject entries, each with:
            Start       [int]    - Zero-based start index of the placeholder in $template.
            Length      [int]    - Character length of the placeholder.
            Replacement [string] - Content to insert at this position.
        Returns an empty List if no placeholders were found.
    #>
    hidden [List[PSCustomObject]] DiscoverReplacements([string] $template, [string[]] $orderedComponents) {
        $replacements = [List[PSCustomObject]]::new()
        $collectors   = $this.ContentCollector.GetCollectors()

        foreach ($collector in $collectors) {
            $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey
            $index       = $template.IndexOf($placeholder, [StringComparison]::Ordinal)

            if ($index -ge 0) {
                Write-Verbose "  Processing placeholder: $placeholder"
                $collectorContent = $this.ContentProcessor.BuildCollectorContent($collector, $orderedComponents)
                $consumedLength   = $this.CalculateConsumedLength($template, $index, $placeholder.Length, $collectorContent)

                $replacements.Add([PSCustomObject] @{
                    Start       = $index
                    Length      = $consumedLength
                    Replacement = $collectorContent
                })

                Write-Verbose "    Content prepared: $($collectorContent.Length) character(s)"
            }
        }

        return $replacements
    }

    <#
    .SYNOPSIS
        Calculates the number of template characters consumed by a placeholder replacement.
    .DESCRIPTION
        The CalculateConsumedLength() method determines how many characters of $template should
        be skipped when the placeholder is replaced. Normally this equals the placeholder length,
        but when the replacement content already ends with a newline, the method also consumes
        the newline character(s) that follow the placeholder in the template.

        This prevents a double newline (blank line) from appearing in the output when a
        placeholder occupies its own line - a common template pattern:

            #region Enum Definitions
            {{ENUM_DEFINITIONS}}       <- placeholder + \r\n  (template)
            #endregion Enums

        Without consuming the trailing newline, the replacement content's own trailing \n and
        the template's \r\n would both appear in the output, creating an unwanted blank line.

        The method handles three cases:
            CRLF (\r\n) - consume 2 extra characters
            LF   (\n)   - consume 1 extra character
            None / no trailing newline in content - return placeholder length unchanged

        The guard on $replacementContent.EndsWith("`n") prevents consuming the template newline
        when the replacement is an early-exit fallback comment (e.g., "# No enums for ..."),
        which has no trailing newline. Without this guard the following line would be
        concatenated directly onto the comment, producing broken output.
    .PARAMETER template
        The original, unmodified template string.
    .PARAMETER index
        Zero-based start index of the placeholder in $template.
    .PARAMETER placeholderLength
        Character length of the placeholder token (e.g., length of "{{ENUM_DEFINITIONS}}").
    .PARAMETER replacementContent
        The content that will replace the placeholder. Its trailing newline determines
        whether the template's newline is consumed.
    .OUTPUTS
        Returns the total number of characters to consume from $template at $index:
        placeholderLength [+ 1 for LF | + 2 for CRLF].
    #>
    hidden [int] CalculateConsumedLength([string] $template, [int] $index, [int] $placeholderLength, [string] $replacementContent) {
        # Only consume the template's trailing newline when the replacement content
        # already ends with a newline - otherwise the next line would be concatenated.
        if (-not $replacementContent.EndsWith("`n")) {
            return $placeholderLength
        }

        $afterEnd = $index + $placeholderLength

        # CRLF (\r\n)
        if ($afterEnd + 1 -lt $template.Length -and $template[$afterEnd] -eq "`r" -and $template[$afterEnd + 1] -eq "`n") {
            return $placeholderLength + 2
        }

        # LF only (\n)
        if ($afterEnd -lt $template.Length -and $template[$afterEnd] -eq "`n") {
            return $placeholderLength + 1
        }

        return $placeholderLength
    }

    <#
    .SYNOPSIS
        Assembles a result string from a template and a set of positional replacements.
    .DESCRIPTION
        The AssembleFromReplacements() method builds a result string by walking the original
        $template left-to-right and interleaving literal segments with replacement content.

        Algorithm:
            1. Sort replacements by Start position (ascending) for left-to-right processing.
            2. For each replacement, copy the literal template segment that precedes it.
            3. Append the replacement content directly into the output buffer.
            4. Advance the read position past the placeholder (Start + Length).
            5. After all replacements, copy any remaining literal segment to the end.

        Key property: Replacement content is written to the output buffer and is NEVER re-scanned
        by the iterator. This guarantees that {{...}} tokens inside replacement content (e.g.,
        in PowerShell comment-based help) cannot be misinterpreted as template placeholders.

        Precondition: Each replacement entry must refer to a non-overlapping range within $template.
        This is guaranteed by ValidateNoDuplicatePlaceholders() during template construction.
    .PARAMETER template
        The original, unmodified template string. Used exclusively as a read source.
    .PARAMETER replacements
        Array of positional replacement entries. Each entry must have:
            Start       [int]    - Zero-based start index of the placeholder in $template.
            Length      [int]    - Character length of the placeholder.
            Replacement [string] - Content to insert at this position.
    .OUTPUTS
        Returns the assembled string with all replacements applied.
    #>
    hidden [string] AssembleFromReplacements([string] $template, [PSCustomObject[]] $replacements) {
        $sortedReplacements = $replacements | Sort-Object Start

        $stringBuilder = [StringBuilder]::new()
        $readPosition  = 0

        foreach ($replacement in $sortedReplacements) {
            # Copy literal template segment before this placeholder
            if ($replacement.Start -gt $readPosition) {
                [void] $stringBuilder.Append($template.Substring($readPosition, $replacement.Start - $readPosition))
            }

            # Insert replacement content - never re-scanned by this loop
            [void] $stringBuilder.Append($replacement.Replacement)
            $readPosition = $replacement.Start + $replacement.Length
        }

        # Copy remaining template content after the last replacement
        if ($readPosition -lt $template.Length) {
            [void] $stringBuilder.Append($template.Substring($readPosition))
        }

        return $stringBuilder.ToString()
    }

    <#
    .SYNOPSIS
        Replaces Using collector placeholders with consolidated Using statements.
    .DESCRIPTION
        The ReplaceUsingCollectorPlaceholders() method uses ContentProcessor to get consolidated
        Using statements from all UsingCollectors, then replaces only the FIRST Using placeholder
        found in the template.

        If multiple Using placeholders exist, a warning is issued for subsequent placeholders
        as they will be ignored (all Using statements are already in the first placeholder).
    .PARAMETER template
        The template content to process.
    .OUTPUTS
        Returns template with first Using placeholder replaced.
    #>
    hidden [string] ReplaceUsingCollectorPlaceholders([string] $template) {
        # Check if Using collectors are registered first (early exit optimization)
        $usingCollectors = $this.ContentCollector.GetUsingCollectors()

        if ($usingCollectors.Count -eq 0) {
            Write-Verbose "  No Using collectors registered"
            return $template
        }

        # Get consolidated Using statements from ContentProcessor
        $consolidatedUsings = $this.ContentProcessor.GetConsolidatedUsingStatements()

        # If no using statements collected, use comment instead of leaving placeholder
        $isComment = $false

        if ([string]::IsNullOrEmpty($consolidatedUsings)) {
            Write-Verbose "  No Using statements collected - using comment"
            $consolidatedUsings = "# No using statements"
            $isComment = $true
        }

        Write-Verbose "  Processing Using collector placeholders..."

        # Replace first placeholder, warn about others
        $firstReplaced = $false

        foreach ($collector in $usingCollectors) {
            $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey

            if ($template -match [Regex]::Escape($placeholder)) {
                if (-not $firstReplaced) {
                    $template = $template.Replace($placeholder, $consolidatedUsings)
                    $firstReplaced = $true

                    if ($isComment) {
                        $format = "  Replaced placeholder: {0} (no using statements - used comment)"
                        $message = $format -f $placeholder
                    }
                    else {
                        $format = "  Replaced placeholder: {0} (consolidated from {1} collector(s))"
                        $message = $format -f $placeholder, $usingCollectors.Count
                    }
                    Write-Verbose $message
                }
                else {
                    $format = 
                        "Multiple Using collector placeholders found in template. "          + 
                        "Only the first placeholder is replaced with all Using statements. " + 
                        "Ignoring placeholder: {0}"
                    $message = $format -f $placeholder
                    Write-Warning $message
                }
            }
        }

        return $template
    }

    <#
    .SYNOPSIS
        Replaces File collector placeholders with their respective content.
    .DESCRIPTION
        The ReplaceFileCollectorPlaceholders() method iterates through all FileCollectors
        and replaces each placeholder with the content from that specific collector.

        Unlike Using collectors (which are consolidated), File collectors are processed
        individually, allowing users to place file content at different positions in
        the template.
    .PARAMETER template
        The template content to process.
    .OUTPUTS
        Returns template with File placeholders replaced.
    #>
    hidden [string] ReplaceFileCollectorPlaceholders([string] $template) {
        $fileCollectors = $this.ContentCollector.GetFileCollectors()

        if ($fileCollectors.Count -eq 0) {
            Write-Verbose "  No File collectors registered"
            return $template
        }

        Write-Verbose "  Processing $($fileCollectors.Count) File collector(s)..."

        foreach ($collector in $fileCollectors) {
            $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey

            if ($template -match [Regex]::Escape($placeholder)) {
                # Use ContentProcessor to get formatted file content
                $content = $this.ContentProcessor.GetFileContent($collector)

                # If no content collected, use comment instead of leaving placeholder
                $isComment = $false

                if ([string]::IsNullOrWhiteSpace($content)) {
                    $content = "# No file content for collector: $($collector.CollectionKey)"
                    $isComment = $true
                }

                $template = $template.Replace($placeholder, $content)

                if ($isComment) {
                    Write-Verbose "  Replaced placeholder: $placeholder (no file content - used comment)"
                }
                else {
                    Write-Verbose "  Replaced placeholder: $placeholder (file content from collector)"
                }
            }
        }

        return $template
    }

    <#
    .SYNOPSIS
        Replaces ORDERED_COMPONENTS placeholder with dependency-sorted content.
    .DESCRIPTION
        The ReplaceOrderedComponentsPlaceholder() method builds concatenated source code
        from the sorted components array and replaces the ORDERED_COMPONENTS placeholder.
    .PARAMETER template
        The template content to process.
    .PARAMETER orderedComponents
        Array of component names in dependency order.
    .OUTPUTS
        Returns template with ORDERED_COMPONENTS placeholder replaced.
    #>
    hidden [string] ReplaceOrderedComponentsPlaceholder([string] $template, [string[]] $orderedComponents) {
        Write-Verbose "  Building ordered source code from $($orderedComponents.Count) component(s)..."

        $orderedSourceCode = [StringBuilder]::new()

        # Check if orderedComponents is empty
        if ($orderedComponents.Count -eq 0) {
            Write-Verbose "    No components to include"
            [void] $orderedSourceCode.AppendLine("# No components (enums, classes, functions)")
        }
        else {
            for ($i = 0; $i -lt $orderedComponents.Count; $i++) {
                $componentName = $orderedComponents[$i]
                $typeLabel     = [PSScriptBuilderTextHelper]::FormatCollectorType($this.ContentProcessor.GetComponentType($componentName))
                Write-Verbose "    Retrieving source for $typeLabel $componentName"

                try {
                    # Use ContentProcessor to get component source
                    $sourceCode = $this.ContentProcessor.GetComponentSourceCode($componentName)

                    if ($i -lt $orderedComponents.Count - 1) {
                        [void] $orderedSourceCode.AppendLine($sourceCode)
                        [void] $orderedSourceCode.AppendLine()  # Blank line separator between components
                    }
                    else {
                        [void] $orderedSourceCode.Append($sourceCode)  # No trailing newline for last component
                    }
                }
                catch {
                    $format = "Failed to retrieve source code for component '{0}'. Error: {1}"
                    $message = $format -f $componentName, $_.Exception.Message
                    throw [InvalidOperationException]::new($message, $_.Exception)
                }
            }
        }

        # Replace placeholder (use literal Replace to avoid $_ interpretation)
        $placeholder = "{{{{{0}}}}}" -f $this.OrderedComponentsKey
        $result = $template.Replace($placeholder, $orderedSourceCode.ToString())

        Write-Verbose "  Replaced placeholder: $placeholder ($($orderedSourceCode.Length) character(s))"

        return $result
    }

    <#
    .SYNOPSIS
        Validates the template configuration.
    .DESCRIPTION
        This hidden method delegates template validation to PSScriptBuilderTemplateValidator.
        It exists to work around a PowerShell 5.1 limitation where static method calls
        directly in constructors can cause parser errors.
    .NOTES
        Called automatically by the constructor.
        Throws InvalidOperationException if template validation fails.
    #>
    hidden [void] ValidateTemplate() {
        $collectors = $this.ContentCollector.GetCollectors()

        [PSScriptBuilderTemplateValidator]::Validate(
            $this.TemplateContent,
            $this.OrderedComponentsKey,
            $this.UseOrderedMode,
            $collectors
        )
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderTemplateProcessor

using namespace System
using namespace System.Collections.Generic
using namespace System.Text.RegularExpressions

#region Class PSScriptBuilderTemplateValidator
<#
.SYNOPSIS
    Static utility class for template validation.
.DESCRIPTION
    The PSScriptBuilderTemplateValidator class provides static methods for validating build templates
    against dependency mode requirements.

    Supports three validation modes:

    1. Ordered mode (strict) - $useOrderedMode = $true, HasCrossDependencies = $true:
       - Template MUST contain the ordered components placeholder (e.g., {{ORDERED_COMPONENTS}})
       - Template MUST NOT contain Enum/Class/Function collector placeholders
       - Template MAY contain Using/File collector placeholders

    2. Hybrid mode - $useOrderedMode = $true, HasCrossDependencies = $false:
       - Same validation rules as Ordered mode
       - Template explicitly contains the ordered components placeholder (e.g., {{ORDERED_COMPONENTS}}) despite no cross-dependencies
       - Useful for mode-agnostic templates that remain valid regardless of future dependency changes

    3. Free Mode - $useOrderedMode = $false:
       - Placeholder format validation (no whitespace)
       - All registered collectors must have placeholders
       - Using placeholders must appear first (if present)
       - Enum placeholders must appear before Class/Function placeholders
       - No duplicate placeholders allowed
       - No unknown placeholders allowed

    This validator implements the Single Responsibility Principle by separating validation logic
    from the TemplateProcessor's processing logic.
#>
class PSScriptBuilderTemplateValidator {
    #region Methods
    <#
    .SYNOPSIS
        Validates template content against dependency mode requirements.
    .DESCRIPTION
        The Validate() method checks that the template contains the appropriate placeholders
        for the specified mode. Throws an exception if validation fails.

        Applies regardless of mode, before the mode-specific checks below:
        - No collector CollectionKey, and no OrderedComponentsKey, collides with a name reserved
          for Release Management bump-file tokens

        Ordered/Hybrid Mode ($useOrderedMode = $true):
        - Template MUST contain the ordered components placeholder (e.g., {{ORDERED_COMPONENTS}})
        - Template MUST NOT contain Enum/Class/Function collector placeholders
        - Template MAY contain Using/File collector placeholders

        Free Mode ($useOrderedMode = $false):
        - Placeholder format validation (no whitespace)
        - All registered collectors must have placeholders
        - Using placeholders must appear first (if present)
        - Enum placeholders must appear before Class/Function placeholders
        - No duplicate placeholders allowed
        - No unknown placeholders allowed
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components (e.g., "ORDERED_COMPONENTS").
    .PARAMETER useOrderedMode
        True for Ordered/Hybrid mode (strict validation), false for Free mode.
    .PARAMETER collectors
        Array of all registered collectors (used to determine which individual placeholders are allowed).
    .EXAMPLE
        $collectors = $contentCollector.GetCollectors()
        [PSScriptBuilderTemplateValidator]::Validate($template, "ORDERED_COMPONENTS", $true, $collectors)
    #>
    static [void] Validate([string] $templateContent, [string] $orderedComponentsKey, [bool] $useOrderedMode, [PSScriptBuilderCollectorBase[]] $collectors) {
        [PSScriptBuilderTemplateValidator]::ValidateParameters($templateContent, $orderedComponentsKey, $collectors)

        Write-Verbose "Validating template (UseOrderedMode: $useOrderedMode)..."

        [PSScriptBuilderTemplateValidator]::ValidateNoCollectionKeyCollidesWithReleaseManagementToken($collectors)
        [PSScriptBuilderTemplateValidator]::ValidateOrderedComponentsKeyDoesNotCollideWithReleaseManagementToken($orderedComponentsKey)

        if ($useOrderedMode) {
            [PSScriptBuilderTemplateValidator]::ValidateInOrderedMode($templateContent, $orderedComponentsKey, $collectors)
        }
        else {
            [PSScriptBuilderTemplateValidator]::ValidateInFreeMode($templateContent, $orderedComponentsKey, $collectors)
        }

        Write-Verbose "Template validation successful"
    }

    <#
    .SYNOPSIS
        Validates method parameters.
    .DESCRIPTION
        The ValidateParameters() method checks that all required parameters are provided and valid.
        Throws ArgumentException or ArgumentNullException if validation fails.
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components.
    .PARAMETER collectors
        Array of all registered collectors.
    #>
    static hidden [void] ValidateParameters([string] $templateContent, [string] $orderedComponentsKey, [PSScriptBuilderCollectorBase[]] $collectors) {
        if ([string]::IsNullOrWhiteSpace($templateContent)) {
            $message = "Template content cannot be null or empty."
            throw [ArgumentException]::new($message, "templateContent")
        }

        if ([string]::IsNullOrWhiteSpace($orderedComponentsKey)) {
            $message = "Ordered components key cannot be null or empty."
            throw [ArgumentException]::new($message, "orderedComponentsKey")
        }

        if ($null -eq $collectors) {
            $message = "Collectors array cannot be null."
            throw [ArgumentNullException]::new("collectors", $message)
        }
    }

    <#
    .SYNOPSIS
        Validates that no registered collector's CollectionKey collides with a reserved
        Release Management token name.
    .DESCRIPTION
        The ValidateNoCollectionKeyCollidesWithReleaseManagementToken() method checks every
        registered collector against PSScriptBuilderBumpReplacementHelper's built-in vocabulary
        of Release Management token names (VERSION, GIT_BRANCH, BUILD_DATE, etc.). A colliding
        key is not a problem on its own, but becomes one the moment the same file is also
        bump-managed for that token: Release Management runs before the build and consumes the
        placeholder, producing a misleading "missing placeholder"/"typo" error that hides the
        real, cross-subsystem cause. Applies to all collector types, in both Free and
        Ordered/Hybrid Mode.
    .PARAMETER collectors
        Array of all registered collectors.
    #>
    static hidden [void] ValidateNoCollectionKeyCollidesWithReleaseManagementToken([PSScriptBuilderCollectorBase[]] $collectors) {
        Write-Verbose "  Validating no CollectionKey collides with a reserved Release Management token..."

        foreach ($collector in $collectors) {
            $isReserved = [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns.Contains($collector.CollectionKey)

            if ($isReserved) {
                $format  = "Template validation failed: Collector with CollectionKey '{0}' collides with a name reserved for Release Management bump-file tokens; rename the collector's key to avoid a confusing failure if this file is ever bump-managed."
                $message = $format -f $collector.CollectionKey
                throw [InvalidOperationException]::new($message)
            }
        }

        Write-Verbose "    No CollectionKey collision with a reserved Release Management token"
    }

    <#
    .SYNOPSIS
        Validates that the active ordered-components key does not collide with a reserved
        Release Management token name.
    .DESCRIPTION
        The ValidateOrderedComponentsKeyDoesNotCollideWithReleaseManagementToken() method checks
        the active -OrderedComponentsKey against the same reserved vocabulary as
        ValidateNoCollectionKeyCollidesWithReleaseManagementToken, for the same reason - the key
        is exactly as PSScriptBuilder-owned and exposed to the same cross-subsystem risk as a
        collector's own CollectionKey.
    .PARAMETER orderedComponentsKey
        The active ordered-components key for this build/validation call.
    #>
    static hidden [void] ValidateOrderedComponentsKeyDoesNotCollideWithReleaseManagementToken([string] $orderedComponentsKey) {
        Write-Verbose "  Validating OrderedComponentsKey does not collide with a reserved Release Management token..."

        $isReserved = [PSScriptBuilderBumpReplacementHelper]::DefaultRegexPatterns.Contains($orderedComponentsKey)

        if ($isReserved) {
            $format  = "Template validation failed: OrderedComponentsKey '{0}' collides with a name reserved for Release Management bump-file tokens; pass a different -OrderedComponentsKey to avoid a confusing failure if this file is ever bump-managed."
            $message = $format -f $orderedComponentsKey
            throw [InvalidOperationException]::new($message)
        }

        Write-Verbose "    No OrderedComponentsKey collision with a reserved Release Management token"
    }

    <#
    .SYNOPSIS
        Validates that the ordered components placeholder exists in the template.
    .DESCRIPTION
        The ValidateOrderedPlaceholderExists() method checks that the template contains the
        ORDERED_COMPONENTS placeholder. In cross-dependencies mode, this placeholder is mandatory
        as it will be replaced with the dependency-ordered components.
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components (e.g., "ORDERED_COMPONENTS").
    #>
    static hidden [void] ValidateOrderedPlaceholderExists([string] $templateContent, [string] $orderedComponentsKey) {
        $orderedPlaceholder = "{{{{{0}}}}}" -f $orderedComponentsKey

        if ($templateContent -notmatch [Regex]::Escape($orderedPlaceholder)) {
            $format  = "Template validation failed: In cross-dependencies mode, template MUST contain placeholder '{0}'."
            $message = $format -f $orderedPlaceholder
            throw [InvalidOperationException]::new($message)
        }

        Write-Verbose "    Ordered placeholder exists: $orderedPlaceholder"
    }

    <#
    .SYNOPSIS
        Validates that no forbidden placeholders exist when the ordered components placeholder is used.
    .DESCRIPTION
        The ValidateNoForbiddenPlaceholders() method checks that Enum/Class/Function collector placeholders
        do not appear in the template when the ordered components placeholder is used (Ordered or Hybrid mode). These
        components must be part of the ordered components placeholder instead. Using and File collector
        placeholders are allowed.
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components (e.g., "ORDERED_COMPONENTS").
    .PARAMETER collectors
        Array of all registered collectors.
    #>
    static hidden [void] ValidateNoForbiddenPlaceholders([string] $templateContent, [string] $orderedComponentsKey, [PSScriptBuilderCollectorBase[]] $collectors) {
        Write-Verbose "  Validating for forbidden placeholders..."

        $invalidPlaceholders = [List[string]]::new()

        foreach ($collector in $collectors) {
            $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey
            $placeholderExists = $templateContent -match [Regex]::Escape($placeholder)

            if (-not $placeholderExists) {
                continue
            }

            # Using placeholders are allowed
            if ($collector.CollectorType -eq [PSScriptBuilderCollectorType]::UsingCollector) {
                continue
            }

            # File placeholders are allowed
            if ($collector.CollectorType -eq [PSScriptBuilderCollectorType]::FileCollector) {
                continue
            }

            # Enum/Class/Function placeholders are forbidden (they are in ORDERED_COMPONENTS)
            if (
                $collector.CollectorType -eq [PSScriptBuilderCollectorType]::EnumCollector     -or
                $collector.CollectorType -eq [PSScriptBuilderCollectorType]::ClassCollector    -or
                $collector.CollectorType -eq [PSScriptBuilderCollectorType]::FunctionCollector
            ) {
                $invalidPlaceholders.Add($placeholder)
            }
        }

        if ($invalidPlaceholders.Count -gt 0) {
            $placeholderList = $invalidPlaceholders -join ", "
            $orderedPlaceholder = "{{{{{0}}}}}" -f $orderedComponentsKey
            $format =
                "Template validation failed: Enum/Class/Function placeholders are forbidden when " +
                "{0} is used (components must share the single ordered placeholder). Found: {1}"
            $message = $format -f $orderedPlaceholder, $placeholderList
            $message = $message + ". If any of these was meant as literal text, escape it as {{{{KEY}}}}."
            throw [InvalidOperationException]::new($message)
        }

        Write-Verbose "    No forbidden collector placeholders present"
    }

    <#
    .SYNOPSIS
        Validates that no registered collector's CollectionKey collides with the active
        ordered-components key.
    .DESCRIPTION
        The ValidateNoCollectionKeyCollidesWithOrderedKey() method checks every registered
        collector - Enum, Class, Function, File, and Using, without exception - against the
        active ordered-components key for this call. A colliding key is a configuration
        mistake: the collector's own placeholder text becomes indistinguishable from the
        reserved ordered-components placeholder, which either fails validation with a confusing
        message or, for File/Using collectors, silently corrupts or discards build output.
    .PARAMETER orderedComponentsKey
        The active ordered-components key for this build/validation call.
    .PARAMETER collectors
        Array of all registered collectors.
    #>
    static hidden [void] ValidateNoCollectionKeyCollidesWithOrderedKey([string] $orderedComponentsKey, [PSScriptBuilderCollectorBase[]] $collectors) {
        Write-Verbose "  Validating no CollectionKey collides with the ordered-components key..."

        foreach ($collector in $collectors) {
            $isColliding = [string]::Equals($collector.CollectionKey, $orderedComponentsKey, [StringComparison]::OrdinalIgnoreCase)

            if ($isColliding) {
                $format  = "Template validation failed: Collector with CollectionKey '{0}' collides with the reserved ordered-components placeholder key; rename the collector's key or pass a different -OrderedComponentsKey."
                $message = $format -f $collector.CollectionKey
                throw [InvalidOperationException]::new($message)
            }
        }

        Write-Verbose "    No CollectionKey collision with the ordered-components key"
    }

    <#
    .SYNOPSIS
        Validates template in ordered/hybrid mode.
    .DESCRIPTION
        The ValidateInOrderedMode() method performs all validations required for Ordered and Hybrid mode.
        Both modes are identical at the validation layer - the distinction (Ordered vs. Hybrid) is for
        reporting only and is carried by the ValidationMode enum in the result object.

        Validations performed:
        - No collector CollectionKey collides with the active ordered-components key
        - Placeholder format validation (no whitespace)
        - Ordered placeholder (e.g., {{ORDERED_COMPONENTS}}) must exist
        - No forbidden individual collector placeholders (Enum/Class/Function)
        - Using placeholders must appear first if present
        - Exactly one Using collector placeholder is present, if any Using collectors are registered
        - No duplicate placeholders
        - No unknown placeholders
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components.
    .PARAMETER collectors
        Array of all registered collectors.
    #>
    static hidden [void] ValidateInOrderedMode([string] $templateContent, [string] $orderedComponentsKey, [PSScriptBuilderCollectorBase[]] $collectors) {
        Write-Verbose "  Ordered/Hybrid mode: Validating template placeholders..."

        # 1. Validate no CollectionKey collides with the ordered-components key
        [PSScriptBuilderTemplateValidator]::ValidateNoCollectionKeyCollidesWithOrderedKey($orderedComponentsKey, $collectors)

        # 2. Validate placeholder format (no whitespace)
        [PSScriptBuilderTemplateValidator]::ValidateNoWhitespaceInPlaceholders($templateContent)

        # 3. Validate ordered placeholder exists
        [PSScriptBuilderTemplateValidator]::ValidateOrderedPlaceholderExists($templateContent, $orderedComponentsKey)

        # 4. Validate no forbidden placeholders
        [PSScriptBuilderTemplateValidator]::ValidateNoForbiddenPlaceholders($templateContent, $orderedComponentsKey, $collectors)

        # 5. Validate Using placeholder order (must be first if present)
        [PSScriptBuilderTemplateValidator]::ValidateUsingPlaceholderOrder($templateContent, $collectors, $orderedComponentsKey)

        # 6. Validate exactly one Using placeholder is present, if any Using collectors are registered
        [PSScriptBuilderTemplateValidator]::ValidateUsingPlaceholderCount($templateContent, $collectors)

        # 7. Validate no duplicate placeholders
        [PSScriptBuilderTemplateValidator]::ValidateNoDuplicatePlaceholders($templateContent, $collectors)

        # 8. Validate no unknown placeholders
        [PSScriptBuilderTemplateValidator]::ValidateNoUnknownPlaceholders($templateContent, $orderedComponentsKey, $collectors)
    }

    <#
    .SYNOPSIS
        Validates template in free mode.
    .DESCRIPTION
        The ValidateInFreeMode() method performs all validations required for free mode:
        - Placeholder format validation (no whitespace)
        - All registered collectors (other than Using) must have corresponding placeholders
        - Exactly one Using placeholder is present, if any Using collectors are registered
        - No duplicate placeholders
        - Using placeholders must appear first (if present)
        - Enum placeholders must appear before Class/Function placeholders
        - No unknown placeholders
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components. Always passed to ValidateNoUnknownPlaceholders
        so that the ordered components placeholder (e.g., {{ORDERED_COMPONENTS}}) is recognized as a known
        placeholder even in Free mode (preventing false-positive unknown-placeholder errors).
    .PARAMETER collectors
        Array of all registered collectors.
    #>
    static hidden [void] ValidateInFreeMode([string] $templateContent, [string] $orderedComponentsKey, [PSScriptBuilderCollectorBase[]] $collectors) {
        Write-Verbose "  Free mode: Validating collector placeholders..."

        # 1. Validate placeholder format (no whitespace)
        [PSScriptBuilderTemplateValidator]::ValidateNoWhitespaceInPlaceholders($templateContent)

        # 2. Validate that all collectors (other than Using) have corresponding placeholders
        [PSScriptBuilderTemplateValidator]::ValidateCollectorPlaceholdersExist($templateContent, $collectors)

        # 3. Validate exactly one Using placeholder is present, if any Using collectors are registered
        [PSScriptBuilderTemplateValidator]::ValidateUsingPlaceholderCount($templateContent, $collectors)

        # 4. Validate no duplicate placeholders
        [PSScriptBuilderTemplateValidator]::ValidateNoDuplicatePlaceholders($templateContent, $collectors)

        # 5. Validate Using placeholder order (must be first if present)
        [PSScriptBuilderTemplateValidator]::ValidateUsingPlaceholderOrder($templateContent, $collectors, $null)

        # 6. Validate Enum placeholder order (must be before Classes and Functions)
        [PSScriptBuilderTemplateValidator]::ValidateEnumPlaceholderOrder($templateContent, $collectors)

        # 7. Validate no unknown placeholders
        [PSScriptBuilderTemplateValidator]::ValidateNoUnknownPlaceholders($templateContent, $orderedComponentsKey, $collectors)
    }

    <#
    .SYNOPSIS
        Validates that Enum placeholders appear before Class and Function placeholders.
    .DESCRIPTION
        The ValidateEnumPlaceholderOrder() method ensures that if Enum collector placeholders exist in the 
        template, they ALL appear before Class and Function placeholders. This enforces the PowerShell requirement 
        that enum type definitions must be available before they can be used in class properties or function parameters.

        When multiple Enum collectors are registered (e.g., {{ENUM_DEFINITIONS}}, {{CustomEnums}}), the method 
        finds the LAST (rightmost) Enum placeholder and ensures that all Class and Function placeholders appear 
        after it. This guarantees that all enum definitions are declared before any component that might reference them.

        If a Class or Function placeholder is found before the last Enum placeholder, an exception is thrown with 
        details about the violation.

        Note: This validation only applies to Enum vs. Class/Function order. The relative order of Classes and 
        Functions is not validated, as dependencies between them can be bidirectional.
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER collectors
        Array of all registered collectors.
    .EXAMPLE
        [PSScriptBuilderTemplateValidator]::ValidateEnumPlaceholderOrder($template, $collectors)
    #>
    static hidden [void] ValidateEnumPlaceholderOrder([string] $templateContent, [PSScriptBuilderCollectorBase[]] $collectors) {
        Write-Verbose "  Validating Enum placeholder order..."

        # Find position of LAST (rightmost) Enum placeholder
        $lastEnumIndex = -1
        $lastEnumPlaceholder = $null

        foreach ($collector in $collectors) {
            if ($collector.CollectorType -eq [PSScriptBuilderCollectorType]::EnumCollector) {
                $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey
                $index = $templateContent.IndexOf($placeholder, [StringComparison]::OrdinalIgnoreCase)

                if ($index -ge 0 -and $index -gt $lastEnumIndex) {
                    $lastEnumIndex = $index
                    $lastEnumPlaceholder = $placeholder
                }
            }
        }

        # If no Enum placeholder found, nothing to validate
        if ($lastEnumIndex -eq -1) {
            Write-Verbose "    No Enum placeholders found"
            return
        }

        # Check that NO Class or Function placeholder appears before the LAST Enum placeholder
        foreach ($collector in $collectors) {
            # Only check Class and Function collectors
            if (
                $collector.CollectorType -ne [PSScriptBuilderCollectorType]::ClassCollector    -and
                $collector.CollectorType -ne [PSScriptBuilderCollectorType]::FunctionCollector
            ) {
                continue
            }

            $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey
            $index = $templateContent.IndexOf($placeholder, [StringComparison]::OrdinalIgnoreCase)

            if ($index -ge 0 -and $index -lt $lastEnumIndex) {
                $collectorTypeName = if ($collector.CollectorType -eq [PSScriptBuilderCollectorType]::ClassCollector) { "Class" } else { "Function" }
                $format = 
                    "Template validation failed: Enum collector placeholders must appear before Class and Function placeholders. " + 
                    "Found {0} placeholder '{1}' at position {2} before last Enum placeholder '{3}' at position {4}."
                $message = $format -f $collectorTypeName, $placeholder, $index, $lastEnumPlaceholder, $lastEnumIndex
                throw [InvalidOperationException]::new($message)
            }
        }

        Write-Verbose "    All Enum placeholders appear before Class and Function placeholders"
    }

    <#
    .SYNOPSIS
        Validates that Using placeholders appear before all other placeholders.
    .DESCRIPTION
        The ValidateUsingPlaceholderOrder() method ensures that if Using collector placeholders exist in the
        template, they appear before any other placeholder types (File placeholders or ORDERED_COMPONENTS).
        This enforces the PowerShell requirement that using statements must appear at the beginning of a script.

        If a non-Using placeholder is found before the first Using placeholder, an exception is thrown with
        details about the violation.
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER collectors
        Array of all registered collectors.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components (e.g., "ORDERED_COMPONENTS"), which is also
        considered a non-Using placeholder.
    .EXAMPLE
        [PSScriptBuilderTemplateValidator]::ValidateUsingPlaceholderOrder($template, $collectors, $orderedComponentsKey)
    #>
    static hidden [void] ValidateUsingPlaceholderOrder([string] $templateContent, [PSScriptBuilderCollectorBase[]] $collectors, [string] $orderedComponentsKey) {
        Write-Verbose "  Validating Using placeholder order..."

        $foundUsingPlaceholders = [PSScriptBuilderTemplateValidator]::FindUsingPlaceholderOccurrences($templateContent, $collectors)

        # If no Using placeholder found, nothing to validate
        if ($foundUsingPlaceholders.Count -eq 0) {
            Write-Verbose "    No Using placeholders found"
            return
        }

        # The first Using placeholder by TEMPLATE POSITION (not registration order) is what
        # matters here - everything else must appear after it.
        $first = $foundUsingPlaceholders | Sort-Object Index | Select-Object -First 1
        $firstUsingIndex       = $first.Index
        $firstUsingPlaceholder = $first.Placeholder

        # Check that NO other placeholder appears before the first Using placeholder
        foreach ($collector in $collectors) {
            # Skip Using collectors
            if ($collector.CollectorType -eq [PSScriptBuilderCollectorType]::UsingCollector) {
                continue
            }

            $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey
            $index = $templateContent.IndexOf($placeholder, [StringComparison]::OrdinalIgnoreCase)

            if ($index -ge 0 -and $index -lt $firstUsingIndex) {
                $format =
                    "Template validation failed: Using collector placeholders must appear before all other placeholders. " +
                    "Found '{0}' at position {1} before '{2}' at position {3}."
                $message = $format -f $placeholder, $index, $firstUsingPlaceholder, $firstUsingIndex
                throw [InvalidOperationException]::new($message)
            }
        }

        # Check that ORDERED_COMPONENTS placeholder does not appear before the first Using placeholder
        if (-not [string]::IsNullOrWhiteSpace($orderedComponentsKey)) {
            $orderedPlaceholder = "{{{{{0}}}}}" -f $orderedComponentsKey
            $index = $templateContent.IndexOf($orderedPlaceholder, [StringComparison]::OrdinalIgnoreCase)

            if ($index -ge 0 -and $index -lt $firstUsingIndex) {
                $format =
                    "Template validation failed: Using collector placeholders must appear before all other placeholders. " +
                    "Found '{0}' at position {1} before '{2}' at position {3}."
                $message = $format -f $orderedPlaceholder, $index, $firstUsingPlaceholder, $firstUsingIndex
                throw [InvalidOperationException]::new($message)
            }
        }

        Write-Verbose "    Using placeholders appear first"
    }

    <#
    .SYNOPSIS
        Validates that Using collectors have exactly one placeholder in the template.
    .DESCRIPTION
        The ValidateUsingPlaceholderCount() method checks that, when one or more Using
        collectors are registered, exactly one of their placeholders appears in the template -
        in every mode (Free, Ordered, and Hybrid). All registered Using collectors' statements
        are always consolidated into a single block and assigned to whichever one placeholder
        is found first (by registration order).

        Two failure cases:
        - Zero Using placeholders found, but Using collectors are registered: the consolidated
          statements would never be written anywhere in the build output.
        - More than one Using placeholder found: every placeholder but the first (by
          registration order) would be left as literal, unparsed text in the build output.

        This mirrors the rendering behavior in PSScriptBuilderTemplateProcessor's
        DiscoverUsingReplacement() method - catching the mismatch here, before a build runs,
        turns a silent, successful-looking build with missing or broken leftover placeholder
        text into a clear, actionable error.
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER collectors
        Array of all registered collectors.
    #>
    static hidden [void] ValidateUsingPlaceholderCount([string] $templateContent, [PSScriptBuilderCollectorBase[]] $collectors) {
        Write-Verbose "  Validating Using placeholder count..."

        $usingCollectorCount = ($collectors | Where-Object { $_.CollectorType -eq [PSScriptBuilderCollectorType]::UsingCollector }).Count

        if ($usingCollectorCount -eq 0) {
            Write-Verbose "    No Using collectors registered"
            return
        }

        $foundUsingPlaceholders = [PSScriptBuilderTemplateValidator]::FindUsingPlaceholderOccurrences($templateContent, $collectors)

        if ($foundUsingPlaceholders.Count -eq 0) {
            $format =
                "Template validation failed: {0} Using collector(s) registered, but no Using " +
                "placeholder found in the template. Add a placeholder for one of the registered " +
                "Using collectors to receive the consolidated statements."
            $message = $format -f $usingCollectorCount
            throw [InvalidOperationException]::new($message)
        }

        if ($foundUsingPlaceholders.Count -gt 1) {
            $winningPlaceholder = $foundUsingPlaceholders[0].Placeholder
            $ignoredList        = ($foundUsingPlaceholders | Select-Object -Skip 1 -ExpandProperty Placeholder) -join ", "
            $format =
                "Template validation failed: Found {0} Using collector placeholders. All " +
                "registered Using collectors are consolidated into a single block, assigned " +
                "to '{1}' (first by registration order); every other placeholder would be " +
                "left unreplaced in the build output: {2}. Use only '{1}' in the template."
            $message = $format -f $foundUsingPlaceholders.Count, $winningPlaceholder, $ignoredList
            throw [InvalidOperationException]::new($message)
        }

        Write-Verbose "    Exactly one Using placeholder present: $($foundUsingPlaceholders[0].Placeholder)"
    }

    <#
    .SYNOPSIS
        Validates that all provided collectors have corresponding placeholders in the template.
    .DESCRIPTION
        The ValidateCollectorPlaceholdersExist() method checks that each provided collector has a corresponding
        placeholder in the template. If a collector is provided but its placeholder is missing, an
        InvalidOperationException is thrown.

        Using collectors are skipped here - they're always consolidated into a single placeholder
        rather than needing one placeholder per collector; see ValidateUsingPlaceholderCount().

        This validation helps catch common mistakes like:
        - Typo in placeholder name ({{ENUM_DEFINITION}} instead of {{ENUM_DEFINITIONS}})
        - Forgotten placeholder in template
        - Mismatch between CollectionKey and template

        Rationale: If a collector is provided and collects data, but the template has no placeholder for it,
        the build output will be incomplete. This is a critical error that should fail the build immediately
        rather than producing broken output.
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER collectors
        Array of collectors to check. The caller decides which collectors to pass - this method iterates
        exactly what it receives.
    .EXAMPLE
        [PSScriptBuilderTemplateValidator]::ValidateCollectorPlaceholdersExist($template, $collectors)
    #>
    static hidden [void] ValidateCollectorPlaceholdersExist([string] $templateContent, [PSScriptBuilderCollectorBase[]] $collectors) {
        if ($collectors.Count -eq 0) {
            Write-Verbose "    No collectors registered"
            return
        }

        $missingPlaceholders = [List[string]]::new()

        foreach ($collector in $collectors) {
            # Using collectors don't each need their own placeholder - they're always
            # consolidated into a single placeholder, checked separately.
            if ($collector.CollectorType -eq [PSScriptBuilderCollectorType]::UsingCollector) {
                continue
            }

            $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey
            $placeholderExists = $templateContent -match [Regex]::Escape($placeholder)

            if (-not $placeholderExists) {
                $missingPlaceholders.Add($placeholder)
            }
            else {
                Write-Verbose "    Found placeholder: $placeholder"
            }
        }

        if ($missingPlaceholders.Count -gt 0) {
            $placeholderList = $missingPlaceholders -join ", "
            $format = 
                "Template validation failed: Template does not contain placeholders for {0} registered collector(s): {1}. " +
                "Check for typos in your template or CollectionKey configuration."
            $message = $format -f $missingPlaceholders.Count, $placeholderList
            throw [InvalidOperationException]::new($message)
        }
        else {
            Write-Verbose "    All collector placeholders found in template"
        }
    }

    <#
    .SYNOPSIS
        Validates that no placeholder appears multiple times in the template.
    .DESCRIPTION
        The ValidateNoDuplicatePlaceholders() method checks that each collector placeholder
        appears at most once in the template. Multiple occurrences of the same placeholder
        would cause the content to be duplicated in the output, which is typically unintended
        and results in invalid PowerShell scripts.

        Special handling:
        - ORDERED_COMPONENTS placeholder is excluded (handled separately)

        This validation prevents common mistakes like:
        - Accidentally copying a placeholder line
        - Template merge errors
        - Typos that create near-duplicates

        Rationale: Duplicate placeholders cause content duplication in the build output,
        resulting in syntax errors (duplicate class/enum/function definitions).
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER collectors
        Array of all registered collectors.
    .EXAMPLE
        [PSScriptBuilderTemplateValidator]::ValidateNoDuplicatePlaceholders($template, $collectors)
    #>
    static hidden [void] ValidateNoDuplicatePlaceholders([string] $templateContent, [PSScriptBuilderCollectorBase[]] $collectors) {
        Write-Verbose "  Validating for duplicate placeholders..."

        $duplicates = [List[string]]::new()

        foreach ($collector in $collectors) {
            $placeholder  = "{{{{{0}}}}}" -f $collector.CollectionKey
            $pattern      = [Regex]::Escape($placeholder)
            $regexMatches = [Regex]::Matches($templateContent, $pattern, [RegexOptions]::IgnoreCase)

            if ($regexMatches.Count -gt 1) {
                $duplicates.Add("$placeholder ($($regexMatches.Count) times)")
            }
        }

        if ($duplicates.Count -gt 0) {
            $duplicateList = $duplicates -join ", "
            $format = 
                "Template validation failed: Found duplicate placeholders in template: {0}. " +
                "Each placeholder should appear exactly once to avoid content duplication in the output."
            $message = $format -f $duplicateList
            throw [InvalidOperationException]::new($message)
        }

        Write-Verbose "    No duplicate placeholders found"
    }

    <#
    .SYNOPSIS
        Validates that all placeholders have correct format without whitespace.
    .DESCRIPTION
        The ValidateNoWhitespaceInPlaceholders() method scans the template for all {{...}} patterns
        and ensures that placeholder names do not contain leading or trailing whitespace.

        Correct format:   {{ENUM_DEFINITIONS}}
        Incorrect format: {{ ENUM_DEFINITIONS }}, {{  Key}}, {{Key  }}

        This validation enforces consistent placeholder formatting and prevents issues with
        placeholder recognition. Whitespace inside placeholders is considered a format error.
    .PARAMETER templateContent
        The template content to validate.
    .EXAMPLE
        [PSScriptBuilderTemplateValidator]::ValidateNoWhitespaceInPlaceholders($template)
    #>
    static hidden [void] ValidateNoWhitespaceInPlaceholders([string] $templateContent) {
        Write-Verbose "  Validating placeholder format (no whitespace)..."

        # Find all {{...}} patterns
        $placeholderPattern = '\{\{([^}]+)\}\}'
        $allMatches = [Regex]::Matches($templateContent, $placeholderPattern)

        if ($allMatches.Count -eq 0) {
            Write-Verbose "    No placeholders found in template"
            return
        }

        # Collect placeholders with whitespace
        $whitespaceIssues = [List[PSCustomObject]]::new()

        foreach ($regexMatch in $allMatches) {
            $fullPlaceholder = $regexMatch.Value # e.g., "{{ EnumDefinitions }}"
            $key = $regexMatch.Groups[1].Value   # e.g., " EnumDefinitions "
            $trimmedKey = $key.Trim()

            # Check if whitespace present
            if ($key -ne $trimmedKey) {
                $expectedPlaceholder = "{{{{{0}}}}}" -f $trimmedKey

                $whitespaceIssues.Add([PSCustomObject] @{
                    Found    = $fullPlaceholder
                    Expected = $expectedPlaceholder
                })
            }
        }

        # Throw exception if whitespace found
        if ($whitespaceIssues.Count -gt 0) {
            $details = $whitespaceIssues | ForEach-Object {
                "'{0}' should be '{1}'" -f $_.Found, $_.Expected
            }

            $issueList = $details -join ", "

            $format = 
                "Template validation failed: Found {0} placeholder(s) with incorrect whitespace: {1}. " +
                "Placeholder names must not have leading or trailing whitespace. Use format '{{{{Key}}}}' without spaces."
            $message = $format -f $whitespaceIssues.Count, $issueList
            throw [InvalidOperationException]::new($message)
        }
        
        Write-Verbose "    All $($allMatches.Count) placeholder(s) have correct format"
    }

    <#
    .SYNOPSIS
        Validates that all placeholders in the template correspond to known collectors or keys.
    .DESCRIPTION
        The ValidateNoUnknownPlaceholders() method scans the template for all {{...}} patterns
        and ensures that each one corresponds to either:
        - A registered collector's CollectionKey
        - The ordered components key (always recognized regardless of mode)

        This validation helps catch common mistakes:
        - Typos in placeholder names ({{ENUM_DEFINTION}} instead of {{ENUM_DEFINITIONS}})
        - Leftover placeholders from template editing
        - Custom placeholders without corresponding collectors

        Rationale: Unknown placeholders remain unreplaced in the output, potentially breaking
        the script or leaving unexpected content. This is a critical error that should fail
        the build immediately.
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components (e.g., "ORDERED_COMPONENTS").
        Always treated as a known placeholder regardless of mode.
    .PARAMETER collectors
        Array of all registered collectors.
    .EXAMPLE
        [PSScriptBuilderTemplateValidator]::ValidateNoUnknownPlaceholders($template, "ORDERED_COMPONENTS", $collectors)
    #>
    static hidden [void] ValidateNoUnknownPlaceholders(
        [string]                         $templateContent,
        [string]                         $orderedComponentsKey,
        [PSScriptBuilderCollectorBase[]] $collectors
    ) {
        Write-Verbose "  Validating for unknown placeholders..."

        # Find all {{...}} patterns in template
        $placeholderPattern = '\{\{([^}]+)\}\}'
        $allMatches = [Regex]::Matches($templateContent, $placeholderPattern)

        if ($allMatches.Count -eq 0) {
            Write-Verbose "    No placeholders found in template"
            return
        }

        # Build set of all known placeholders (case-insensitive, EXACT format)
        $knownPlaceholders = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        # Ordered components placeholder is always known
        $placeholder = "{{{{{0}}}}}" -f $orderedComponentsKey
        $knownPlaceholders.Add($placeholder) | Out-Null

        # Add all collector placeholders (EXACT format)
        foreach ($collector in $collectors) {
            $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey
            $knownPlaceholders.Add($placeholder) | Out-Null
        }

        # Collect unknown placeholders
        $unknownPlaceholders = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($regexMatch in $allMatches) {
            $fullPlaceholder = $regexMatch.Value  # e.g., "{{MyKey}}" or "{{ MyKey }}"

            if (-not $knownPlaceholders.Contains($fullPlaceholder)) {
                $unknownPlaceholders.Add($fullPlaceholder) | Out-Null
            }
        }

        # Throw exception if unknown placeholders found
        if ($unknownPlaceholders.Count -gt 0) {
            $unknownList = ($unknownPlaceholders | Sort-Object) -join ", "

            $knownKeysInfo = "a registered collector or '{0}'" -f ("{{{{{0}}}}}" -f $orderedComponentsKey)

            $format = 
                "Template validation failed: Found {0} unknown placeholder(s): {1}. " +
                "Each placeholder must correspond to {2}. Check for typos in placeholder names."
            $message = $format -f $unknownPlaceholders.Count, $unknownList, $knownKeysInfo
            $message = $message + " If any of these was meant as literal text, escape it as {{{{KEY}}}}."
            throw [InvalidOperationException]::new($message)
        }

        Write-Verbose "    All $($allMatches.Count) placeholder(s) are known"
    }

    <#
    .SYNOPSIS
        Finds every registered Using collector whose placeholder is present in the template.
    .DESCRIPTION
        The FindUsingPlaceholderOccurrences() method scans the template for each registered
        Using collector's placeholder and returns the ones actually present, in collector
        registration order - the same order PSScriptBuilderTemplateProcessor's
        DiscoverUsingReplacement() method uses at render time to decide which one "wins" when
        more than one is present.

        Shared by ValidateUsingPlaceholderOrder() (which needs template position) and
        ValidateUsingPlaceholderCount() (which needs the count and registration order), so both
        validate the same underlying fact - which Using placeholders are actually present -
        without each independently re-scanning the template.
    .PARAMETER templateContent
        The template content to scan.
    .PARAMETER collectors
        Array of all registered collectors.
    .OUTPUTS
        A list of PSCustomObject entries (Index, Placeholder), one per Using collector whose
        placeholder is present, in registration order. Empty if none are present.
    #>
    static hidden [List[PSCustomObject]] FindUsingPlaceholderOccurrences([string] $templateContent, [PSScriptBuilderCollectorBase[]] $collectors) {
        $found = [List[PSCustomObject]]::new()

        foreach ($collector in $collectors) {
            if ($collector.CollectorType -ne [PSScriptBuilderCollectorType]::UsingCollector) {
                continue
            }

            $placeholder = "{{{{{0}}}}}" -f $collector.CollectionKey
            $index       = $templateContent.IndexOf($placeholder, [StringComparison]::OrdinalIgnoreCase)

            if ($index -ge 0) {
                $found.Add([PSCustomObject] @{ Index = $index; Placeholder = $placeholder })
            }
        }

        return $found
    }

    <#
    .SYNOPSIS
        Checks if template content is valid without throwing exceptions.
    .DESCRIPTION
        The IsValid() method performs the same validation as Validate() but returns a boolean result instead of 
        throwing exceptions. Useful for non-critical validation checks or preview scenarios.
    .PARAMETER templateContent
        The template content to validate.
    .PARAMETER orderedComponentsKey
        The placeholder key for dependency-ordered components (e.g., "ORDERED_COMPONENTS").
    .PARAMETER useOrderedMode
        True for Ordered/Hybrid mode (strict validation), false for Free mode.
    .PARAMETER collectors
        Array of all registered collectors.
    .OUTPUTS
        Returns true if the template is valid, false otherwise.
    #>
    static [bool] IsValid([string] $templateContent, [string] $orderedComponentsKey, [bool] $useOrderedMode, [PSScriptBuilderCollectorBase[]] $collectors) {
        try {
            [PSScriptBuilderTemplateValidator]::Validate($templateContent, $orderedComponentsKey, $useOrderedMode, $collectors)
            return $true
        }
        catch {
            return $false
        }
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderTemplateValidator

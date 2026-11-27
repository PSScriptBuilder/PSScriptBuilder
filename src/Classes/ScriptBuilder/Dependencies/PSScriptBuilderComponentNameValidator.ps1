using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderComponentNameValidator
<#
.SYNOPSIS
    Validates that component names are unique across all of a ContentCollector's collectors.
.DESCRIPTION
    The PSScriptBuilderComponentNameValidator detects two categories of name conflicts across a
    ContentCollector's registered collectors: the same name defined by more than one collector of
    the same type (e.g. two Class collectors both defining "MyClass" from different source
    directories), and the same name defined as both a Class and a Function. In PowerShell, a class
    and a function can technically share the same name because they live in different namespaces,
    and each collector only guards against duplicates within its own scanned files - neither
    prevents a collision introduced by a second, independently-scanned collector. PSScriptBuilder
    uses names as graph node keys for dependency analysis, so either collision would silently drop
    one component's source code from the build output, or cause incorrect ordering.

    This validator implements the Single Responsibility Principle by separating name-uniqueness
    validation from the ContentCollector's own responsibility of orchestrating collection.
#>
class PSScriptBuilderComponentNameValidator {
    #region Properties
    <#
    .SYNOPSIS
        The content collector containing all component collectors.
    .DESCRIPTION
        The ContentCollector property provides access to all registered collectors, which is
        needed to compare their collected component names against each other.
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderComponentNameValidator.
    .DESCRIPTION
        Creates a new component name validator for the specified content collector.
    .PARAMETER contentCollector
        The content collector containing all component collectors.
    #>
    PSScriptBuilderComponentNameValidator([PSScriptBuilderContentCollector] $contentCollector) {
        if ($null -eq $contentCollector) {
            $message = "The parameter 'contentCollector' cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        $this.ContentCollector = $contentCollector
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Validates that no component name is defined as both a Class and a Function, and that no
        component name is defined by more than one collector of the same type.
    .DESCRIPTION
        If a conflict is detected, an InvalidOperationException is thrown with the name and source
        file paths of both conflicting components.

        The same-type check is a no-op for a type with fewer than two registered collectors. The
        Class-vs-Function check is skipped if no Class or no Function collectors are registered.
    #>
    [void] Validate() {
        $enumCollectors     = $this.ContentCollector.GetEnumCollectors()
        $classCollectors    = $this.ContentCollector.GetClassCollectors()
        $functionCollectors = $this.ContentCollector.GetFunctionCollectors()

        $this.ValidateNoCrossCollectorNameCollision($enumCollectors)
        $this.ValidateNoCrossCollectorNameCollision($classCollectors)
        $this.ValidateNoCrossCollectorNameCollision($functionCollectors)
        $this.ValidateNoClassFunctionNameCollision($classCollectors, $functionCollectors)
    }

    <#
    .SYNOPSIS
        Validates that no component name is defined by more than one collector of the same type.
    .DESCRIPTION
        The ValidateNoCrossCollectorNameCollision() method scans all collectors in the given group
        in a single pass, tracking each name's source file in a running dictionary as it goes, and
        throws as soon as a name already in that dictionary is seen again from a different
        collector. Each collector's own duplicate check only sees its own scanned files, so a name
        collision introduced by a second, independently-scanned collector of the same type is
        otherwise silently absorbed by ContentCollector.GetDefinedComponentNames()'s
        case-insensitive HashSet - one component's source code would be missing from the built
        output while the build reports success and the reported component count still counts both.

        If multiple independent collisions exist at once across three or more collectors, only the
        first one encountered during the scan is reported (an InvalidOperationException is thrown
        immediately) - which specific collision that is, is an implementation detail of scan order,
        not a documented guarantee. The same applies to the exact casing of the reported name when
        two collectors spell it differently (e.g. "MyClass" vs. "myclass") - the message always
        names both source files correctly, but which of the two spellings appears in the message
        text is scan-order-dependent, not a documented guarantee.
    .PARAMETER collectors
        The collectors to compare. All must be of the same CollectorType.
    #>
    hidden [void] ValidateNoCrossCollectorNameCollision([PSScriptBuilderCollectorBase[]] $collectors) {
        $seenSourceFileByName = [Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($collector in $collectors) {
            $data = $this.GetComponentDataForCollisionCheck($collector)

            foreach ($name in $data.Keys) {
                if ($seenSourceFileByName.ContainsKey($name)) {
                    $firstFile  = $seenSourceFileByName[$name]
                    $secondFile = $data[$name].SourceFile
                    $typeLabel  = [PSScriptBuilderTextHelper]::FormatCollectorType($collector.CollectorType)
                    $format =
                        "Component name conflict: '{0}' is defined as a {1} more than once - in '{2}' and '{3}'. " +
                        "Component names must be unique across all collectors of the same type within a PSScriptBuilder project."
                    $message = $format -f $name, $typeLabel, $firstFile, $secondFile
                    throw [InvalidOperationException]::new($message)
                }

                $seenSourceFileByName[$name] = $data[$name].SourceFile
            }
        }
    }

    <#
    .SYNOPSIS
        Validates that no component name is defined as both a Class and a Function.
    .DESCRIPTION
        The ValidateNoClassFunctionNameCollision() method detects name conflicts between Class and
        Function collectors. In PowerShell, a class and a function can technically share the same
        name because they live in different namespaces. However, PSScriptBuilder uses names as
        graph node keys for dependency analysis - a collision would cause silent incorrect
        ordering in the build output.

        Implementation note: all Class collectors are first merged into a single name-to-source-file
        dictionary via Dictionary.Add() (not indexer assignment) - by this point,
        ValidateNoCrossCollectorNameCollision() has already run for classCollectors (see Validate()),
        so no two Class collectors can share a name; Add() is a defensive backstop that fails loudly
        if that invariant is ever violated, rather than silently overwriting one class's source file
        with another's. The actual Class-vs-Function detection is the explicit ContainsKey() check
        against this merged dictionary while scanning Function collectors, same as before.

        This validation is skipped if no Class or no Function collectors are registered. If multiple
        independent Class-vs-Function collisions exist at once, only the first one encountered
        while scanning Function collectors is reported - which one that is, is an implementation
        detail of scan order, not a documented guarantee. The same applies to the exact casing of
        the reported name when the Class and Function definitions spell it differently - the
        message always names both source files correctly, but the reported name is always the
        Function collector's spelling (since that is the side being scanned when the match is
        found), not a documented guarantee.
    .PARAMETER classCollectors
        The Class collectors to check.
    .PARAMETER functionCollectors
        The Function collectors to check.
    #>
    hidden [void] ValidateNoClassFunctionNameCollision([PSScriptBuilderClassCollector[]] $classCollectors, [PSScriptBuilderFunctionCollector[]] $functionCollectors) {
        # Guard clause: no conflict possible without both collector types
        if ($classCollectors.Count -eq 0 -or $functionCollectors.Count -eq 0) {
            return
        }

        $classSourceFileByName = [Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($classCollector in $classCollectors) {
            foreach ($name in $classCollector.ClassData.Keys) {
                # Add(), not indexer assignment: ValidateNoCrossCollectorNameCollision() already
                # guarantees no two Class collectors share a name by the time Validate() gets here -
                # Add() throws instead of silently overwriting if that guarantee is ever violated.
                $classSourceFileByName.Add($name, $classCollector.ClassData[$name].SourceFile)
            }
        }

        foreach ($functionCollector in $functionCollectors) {
            foreach ($name in $functionCollector.FunctionData.Keys) {
                if ($classSourceFileByName.ContainsKey($name)) {
                    $classFile    = $classSourceFileByName[$name]
                    $functionFile = $functionCollector.FunctionData[$name].SourceFile
                    $format =
                        "Component name conflict: '{0}' is defined as both a Class (in '{1}') and a Function (in '{2}'). " +
                        "Classes and Functions must have unique names within a PSScriptBuilder project."
                    $message = $format -f $name, $classFile, $functionFile
                    throw [InvalidOperationException]::new($message)
                }
            }
        }
    }

    <#
    .SYNOPSIS
        Gets the component data dictionary of a collector, for same-type collision checks.
    .DESCRIPTION
        The GetComponentDataForCollisionCheck() method returns the EnumData, ClassData, or
        FunctionData dictionary of the given collector, keyed by component name. Used only by
        ValidateNoCrossCollectorNameCollision() so that method's single-pass scan does not have
        to be written once per collector type.
    .PARAMETER collector
        The collector whose component data dictionary to retrieve.
    .OUTPUTS
        Returns the collector's component data as an IDictionary, keyed by component name.
    #>
    hidden [System.Collections.IDictionary] GetComponentDataForCollisionCheck([PSScriptBuilderCollectorBase] $collector) {
        switch ($collector.CollectorType) {
            ([PSScriptBuilderCollectorType]::EnumCollector)     { return $collector.EnumData }
            ([PSScriptBuilderCollectorType]::ClassCollector)    { return $collector.ClassData }
            ([PSScriptBuilderCollectorType]::FunctionCollector) { return $collector.FunctionData }
        }

        $format  = "Unsupported collector type for same-type name collision check: {0}"
        $message = $format -f $collector.CollectorType
        throw [InvalidOperationException]::new($message)
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderComponentNameValidator

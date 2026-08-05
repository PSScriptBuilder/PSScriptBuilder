using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderContentCollector
<#
.SYNOPSIS
    Orchestrates multiple collectors for script component extraction.
.DESCRIPTION
    The PSScriptBuilderContentCollector class manages a collection of collectors and coordinates
    their execution by calling Collect() on all registered collectors in a defined order.
#>
class PSScriptBuilderContentCollector {
    #region Properties
    <#
    .SYNOPSIS
        Collection of collectors.
    .DESCRIPTION
        The Collectors property holds a collection of collectors managed by this content collector.
    #>
    hidden [PSScriptBuilderCollectorCollection] $Collectors
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderContentCollector.
    .DESCRIPTION
        Creates a new PSScriptBuilderContentCollector with empty collector collection.
    #>
    PSScriptBuilderContentCollector() {
        $this.Collectors = [PSScriptBuilderCollectorCollection]::new()
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Adds a collector to the collection.
    .DESCRIPTION
        The AddCollector() method adds a new collector to the collection.
    .PARAMETER collector
        The collector to add.
    #>
    [void] AddCollector([PSScriptBuilderCollectorBase] $collector) {
        $this.Collectors.Add($collector)
    }

    <#
    .SYNOPSIS
        Removes a collector from the collection.
    .DESCRIPTION
        The RemoveCollector() method removes a collector from the collection based on its CollectionKey.
    .PARAMETER key
        The CollectionKey of the collector to remove.
    .OUTPUTS
        Returns true if the collector was removed, false otherwise.
    #>
    [bool] RemoveCollector([string] $key) {
        return $this.Collectors.Remove($key)
    }

    <#
    .SYNOPSIS
        Gets a collector by its key.
    .DESCRIPTION
        The GetCollector() method retrieves a collector from the collection based on its CollectionKey.
    .PARAMETER key
        The CollectionKey of the collector to retrieve.
    .OUTPUTS
        Returns the collector associated with the specified key.
    #>
    [PSScriptBuilderCollectorBase] GetCollector([string] $key) {
        return $this.Collectors.GetCollector($key)
    }

    <#
    .SYNOPSIS
        Gets all collectors in the collection.
    .DESCRIPTION
        The GetCollectors() method retrieves all collectors from the collection sorted by their CollectorType.
        Collectors are returned in the following order: Using, Enum, Class, Function, File.
    .OUTPUTS
        Returns an array of all collectors in the collection.
    #>
    [PSScriptBuilderCollectorBase[]] GetCollectors() {
        return $this.Collectors.GetAll()
    }

    <#
    .SYNOPSIS
        Gets the number of collectors in the collection.
    .DESCRIPTION
        The GetCount() method returns the total number of collectors currently stored in the collection.
        This can be used to verify that collectors have been added or removed as expected.
    .OUTPUTS
        Returns the number of collectors in the collection.
    #>
    [int] GetCount() {
        return $this.Collectors.GetCount()
    }

    <#
    .SYNOPSIS
        Clears all collectors from the collection.
    .DESCRIPTION
        The Clear() method removes all collectors from the collection.
    #>
    [void] Clear() {
        $this.Collectors.Clear()
    }

    <#
    .SYNOPSIS
        Executes all registered collectors.
    .DESCRIPTION
        The Execute() method iterates through all registered collectors in the collection and calls their 
        Collect() method.
        Collectors are executed in a defined order based on their CollectorType. If any collector throws an 
        exception during execution, it is caught and rethrown with additional context about which collector failed.
    #>
    [void] Execute() {
        $count = $this.Collectors.GetCount()

        if ($count -eq 0) {
            Write-Verbose "No collectors registered. Nothing to execute."
            return
        }

        Write-Verbose "Executing content collectors..."

        $collectorList = $this.Collectors.GetAll()
        Write-Verbose "Starting content collection with $count collector(s)..."

        foreach ($collector in $collectorList) {
            $collectorInfo = "collector $($collector.CollectorType) with key '$($collector.CollectionKey)'"

            try {
                Write-Verbose "Executing $collectorInfo"
                $collector.Collect()
                Write-Verbose "Completed $collectorInfo successfully"
            }
            catch {
                $message = "Failed to execute $collectorInfo. Error: $($_.Exception.Message)"
                throw [Exception]::new($message, $_.Exception)
            }
        }

        Write-Verbose "Content collection complete"
    }

    <#
    .SYNOPSIS
        Validates that no component name is defined as both a Class and a Function.
    .DESCRIPTION
        The ValidateComponentNameUniqueness() method detects name conflicts between Class and Function
        collectors. In PowerShell, a class and a function can technically share the same name because
        they live in different namespaces. However, PSScriptBuilder uses names as graph node keys for
        dependency analysis - a collision would cause silent incorrect ordering in the build output.

        If a conflict is detected, an InvalidOperationException is thrown with the name and source
        file paths of both conflicting components.

        This validation is skipped if no Class or no Function collectors are registered.
        It is called by the orchestrating code before invoking PSScriptBuilderDependencyAnalyzer.
    #>
    [void] ValidateComponentNameUniqueness() {
        $classCollectors    = $this.Collectors.GetClassCollectors()
        $functionCollectors = $this.Collectors.GetFunctionCollectors()

        # Guard clause: no conflict possible without both collector types
        if ($classCollectors.Count -eq 0 -or $functionCollectors.Count -eq 0) {
            return
        }

        foreach ($classCollector in $classCollectors) {
            foreach ($name in $classCollector.ClassData.Keys) {
                foreach ($functionCollector in $functionCollectors) {
                    if ($functionCollector.FunctionData.ContainsKey($name)) {
                        $classFile    = $classCollector.ClassData[$name].SourceFile
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
    }

    <#
    .SYNOPSIS
        Gets all collection keys from registered collectors.
    .DESCRIPTION
        The GetCollectionKeys() method retrieves the CollectionKey from each registered collector
        and returns them as an array. This implements the Information Expert pattern by encapsulating
        access to collector internals.
    .OUTPUTS
        Returns an array of collection keys (strings).
    #>
    [string[]] GetCollectionKeys() {
        $collectorList = $this.Collectors.GetAll()
        $keys = [List[string]]::new()

        foreach ($collector in $collectorList) {
            $keys.Add($collector.CollectionKey)
        }

        return $keys.ToArray()
    }

    <#
    .SYNOPSIS
        Gets all file paths that were processed during collection.
    .DESCRIPTION
        The GetProcessedFiles() method aggregates all source file paths from all registered collectors
        and returns a deduplicated array. This includes source files from Using, Enum, Class, Function,
        and File collectors.
    .OUTPUTS
        Returns an array of unique file paths that were processed during collection.
    #>
    [string[]] GetProcessedFiles() {
        $files = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($collector in $this.Collectors.GetAll()) {
            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::UsingCollector) {
                    foreach ($usingData in $collector.UsingData.Values) {
                        foreach ($sourceFile in $usingData.SourceFiles) {
                            $files.Add($sourceFile) | Out-Null
                        }
                    }
                }
                ([PSScriptBuilderCollectorType]::EnumCollector) {
                    foreach ($enumData in $collector.EnumData.Values) {
                        $files.Add($enumData.SourceFile) | Out-Null
                    }
                }
                ([PSScriptBuilderCollectorType]::ClassCollector) {
                    foreach ($classData in $collector.ClassData.Values) {
                        $files.Add($classData.SourceFile) | Out-Null
                    }
                }
                ([PSScriptBuilderCollectorType]::FunctionCollector) {
                    foreach ($functionData in $collector.FunctionData.Values) {
                        $files.Add($functionData.SourceFile) | Out-Null
                    }
                }
                ([PSScriptBuilderCollectorType]::FileCollector) {
                    foreach ($fileData in $collector.FileData.Values) {
                        $files.Add($fileData.FullPath) | Out-Null
                    }
                }
            }
        }

        return [string[]] @($files)
    }

    <#
    .SYNOPSIS
        Gets all defined component names from all collectors.
    .DESCRIPTION
        The GetDefinedComponentNames() method aggregates the names of all defined components (enums, classes, 
        functions) collected by the various collectors. This is used for dependency analysis to determine which 
        components are defined across all collected source files.
        The method uses a case-insensitive HashSet to ensure that component names are unique and to match 
        PowerShell's type system behavior.

        Note: If a Class and a Function share the same name, only one entry will appear in the result - 
        the name collision is silently absorbed by the HashSet. Use ValidateComponentNameUniqueness() before
        calling this method to ensure the result is unambiguous.
    .OUTPUTS
        Returns a HashSet[string] of all defined component names.
    #>
    [HashSet[string]] GetDefinedComponentNames() {
        $componentNames = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $collectorList = $this.Collectors.GetAll()

        foreach ($collector in $collectorList) {
            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::EnumCollector) {
                    foreach ($name in $collector.EnumData.Keys) {
                        $componentNames.Add($name) | Out-Null
                    }
                }

                ([PSScriptBuilderCollectorType]::ClassCollector) {
                    foreach ($name in $collector.ClassData.Keys) {
                        $componentNames.Add($name) | Out-Null
                    }
                }

                ([PSScriptBuilderCollectorType]::FunctionCollector) {
                    foreach ($name in $collector.FunctionData.Keys) {
                        $componentNames.Add($name) | Out-Null
                    }
                }
            }
        }

        Write-Verbose "  Collected $($componentNames.Count) defined component name(s)"
        return $componentNames
    }

    <#
    .SYNOPSIS
        Retrieves the source code for a specific component by name.
    .DESCRIPTION
        Searches through all collector definitions (enums, classes, functions) to find
        the component with the specified name and returns its source code.

        This method implements the Information Expert pattern - the ContentCollector
        knows where to find component data and provides a clean API for accessing it.
    .PARAMETER componentName
        The name of the component to retrieve (case-insensitive).
    .OUTPUTS
        Returns the source code of the component as a string.
    #>
    [string] GetComponentSourceCode([string] $componentName) {
        if ([string]::IsNullOrWhiteSpace($componentName)) {
            $message = "Component name cannot be null or empty."
            throw [ArgumentException]::new($message, "componentName")
        }

        $collectorList = $this.Collectors.GetAll()

        foreach ($collector in $collectorList) {
            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::EnumCollector) {
                    if ($collector.EnumData.ContainsKey($componentName)) {
                        return $collector.EnumData[$componentName].SourceCode
                    }
                }

                ([PSScriptBuilderCollectorType]::ClassCollector) {
                    if ($collector.ClassData.ContainsKey($componentName)) {
                        return $collector.ClassData[$componentName].SourceCode
                    }
                }

                ([PSScriptBuilderCollectorType]::FunctionCollector) {
                    if ($collector.FunctionData.ContainsKey($componentName)) {
                        return $collector.FunctionData[$componentName].SourceCode
                    }
                }
            }
        }

        # Component not found
        $format  = "Component '{0}' not found in any collector (Enum, Class, Function)."
        $message = $format -f $componentName
        throw [InvalidOperationException]::new($message)
    }

    <#
    .SYNOPSIS
        Gets the collector type for a specific component by name.
    .DESCRIPTION
        The GetComponentType() method searches all registered Enum, Class, and Function collectors
        for the given component name and returns the CollectorType of the collector that owns it.
    .PARAMETER componentName
        The name of the component to look up.
    .OUTPUTS
        Returns the PSScriptBuilderCollectorType of the collector that owns the component.
    #>
    [PSScriptBuilderCollectorType] GetComponentType([string] $componentName) {
        if ([string]::IsNullOrWhiteSpace($componentName)) {
            $message = "Component name cannot be null or empty."
            throw [ArgumentException]::new($message, "componentName")
        }

        $collectorList = $this.Collectors.GetAll()

        foreach ($collector in $collectorList) {
            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::EnumCollector) {
                    if ($collector.EnumData.ContainsKey($componentName)) {
                        return [PSScriptBuilderCollectorType]::EnumCollector
                    }
                }

                ([PSScriptBuilderCollectorType]::ClassCollector) {
                    if ($collector.ClassData.ContainsKey($componentName)) {
                        return [PSScriptBuilderCollectorType]::ClassCollector
                    }
                }

                ([PSScriptBuilderCollectorType]::FunctionCollector) {
                    if ($collector.FunctionData.ContainsKey($componentName)) {
                        return [PSScriptBuilderCollectorType]::FunctionCollector
                    }
                }
            }
        }

        # Component not found
        $format  = "Component '{0}' not found in any collector (Enum, Class, Function)."
        $message = $format -f $componentName
        throw [InvalidOperationException]::new($message)
    }

    <#
    .SYNOPSIS
        Builds a map of component names to their collector keys.
    .DESCRIPTION
        Iterates all registered Class, Function, and Enum collectors and returns a case-insensitive
        hashtable mapping each component name to the CollectionKey of the collector it belongs to.
        This is used by dependency analysis to identify dependencies that cross collector boundaries.
    .OUTPUTS
        Returns a case-insensitive hashtable mapping component name to CollectionKey.
    #>
    [hashtable] BuildComponentCollectorMap() {
        $result = [hashtable]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($collector in $this.Collectors.GetAll()) {
            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::ClassCollector) {
                    foreach ($name in $collector.ClassData.Keys) {
                        $result[$name] = $collector.CollectionKey
                    }
                }

                ([PSScriptBuilderCollectorType]::FunctionCollector) {
                    foreach ($name in $collector.FunctionData.Keys) {
                        $result[$name] = $collector.CollectionKey
                    }
                }

                ([PSScriptBuilderCollectorType]::EnumCollector) {
                    foreach ($name in $collector.EnumData.Keys) {
                        $result[$name] = $collector.CollectionKey
                    }
                }
            }
        }

        return $result
    }

    #region Collector Grouping Methods
    <#
    .SYNOPSIS
        Gets all Using collectors.
    .DESCRIPTION
        The GetUsingCollectors() method retrieves all registered collectors of type UsingCollector.
        This is used for consolidating Using statements and template processing.
    .OUTPUTS
        Returns an array of PSScriptBuilderUsingCollector instances.
    .EXAMPLE
        $usingCollectors = $contentCollector.GetUsingCollectors()
    #>
    [PSScriptBuilderUsingCollector[]] GetUsingCollectors() {
        return $this.Collectors.GetUsingCollectors()
    }

    <#
    .SYNOPSIS
        Gets all File collectors.
    .DESCRIPTION
        The GetFileCollectors() method retrieves all registered collectors of type FileCollector.
        This is used for file content processing and template rendering.
    .OUTPUTS
        Returns an array of PSScriptBuilderFileCollector instances.
    .EXAMPLE
        $fileCollectors = $contentCollector.GetFileCollectors()
    #>
    [PSScriptBuilderFileCollector[]] GetFileCollectors() {
        return $this.Collectors.GetFileCollectors()
    }

    <#
    .SYNOPSIS
        Gets all Enum collectors.
    .DESCRIPTION
        The GetEnumCollectors() method retrieves all registered collectors of type EnumCollector.
    .OUTPUTS
        Returns an array of PSScriptBuilderEnumCollector instances.
    .EXAMPLE
        $enumCollectors = $contentCollector.GetEnumCollectors()
    #>
    [PSScriptBuilderEnumCollector[]] GetEnumCollectors() {
        return $this.Collectors.GetEnumCollectors()
    }

    <#
    .SYNOPSIS
        Gets all Class collectors.
    .DESCRIPTION
        The GetClassCollectors() method retrieves all registered collectors of type ClassCollector.
    .OUTPUTS
        Returns an array of PSScriptBuilderClassCollector instances.
    .EXAMPLE
        $classCollectors = $contentCollector.GetClassCollectors()
    #>
    [PSScriptBuilderClassCollector[]] GetClassCollectors() {
        return $this.Collectors.GetClassCollectors()
    }

    <#
    .SYNOPSIS
        Gets all Function collectors.
    .DESCRIPTION
        The GetFunctionCollectors() method retrieves all registered collectors of type FunctionCollector.
    .OUTPUTS
        Returns an array of PSScriptBuilderFunctionCollector instances.
    .EXAMPLE
        $functionCollectors = $contentCollector.GetFunctionCollectors()
    #>
    [PSScriptBuilderFunctionCollector[]] GetFunctionCollectors() {
        return $this.Collectors.GetFunctionCollectors()
    }
    #endregion Collector Grouping Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderContentCollector

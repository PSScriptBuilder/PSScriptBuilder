using namespace System
using namespace System.Collections.Generic
using namespace System.Text

#region Class PSScriptBuilderContentProcessor
<#
.SYNOPSIS
    Processes and formats content from collectors.
.DESCRIPTION
    The PSScriptBuilderContentProcessor class provides a facade for processing content
    from various collector types. It handles consolidation (Using statements), formatting,
    and preparation of content for template processing.

    This class implements the Facade pattern, providing a simplified interface to
    ContentCollector's complex collector management. It separates content processing
    concerns from template rendering concerns.
#>
class PSScriptBuilderContentProcessor {
    #region Properties
    <#
    .SYNOPSIS
        The ContentCollector containing all registered collectors.
    .DESCRIPTION
        Provides access to collectors for content processing operations.
    #>
    [PSScriptBuilderContentCollector] $ContentCollector
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderContentProcessor.
    .DESCRIPTION
        Creates a new ContentProcessor with the specified ContentCollector.
    .PARAMETER contentCollector
        The ContentCollector instance to process content from.
    #>
    PSScriptBuilderContentProcessor([PSScriptBuilderContentCollector] $contentCollector) {
        if ($null -eq $contentCollector) {
            $message = "ContentCollector cannot be null."
            throw [ArgumentNullException]::new("contentCollector", $message)
        }

        $this.ContentCollector = $contentCollector
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Gets consolidated Using statements from all Using collectors.
    .DESCRIPTION
        The GetConsolidatedUsingStatements() method collects Using statements from ALL
        registered UsingCollectors, deduplicates them, sorts them alphabetically, and
        returns them as a formatted string.

        If no UsingCollectors are registered or no Using statements were collected,
        returns an empty string.
    .OUTPUTS
        Returns a string with all consolidated Using statements (one per line), or empty string.
    .EXAMPLE
        $usingStatements = $processor.GetConsolidatedUsingStatements()
    #>
    [string] GetConsolidatedUsingStatements() {
        # Get all Using collectors from ContentCollector
        $usingCollectors = $this.ContentCollector.GetUsingCollectors()

        if ($usingCollectors.Count -eq 0) {
            Write-Verbose "No Using collectors registered"
            return [string]::Empty
        }

        Write-Verbose "  Consolidating Using statements from $($usingCollectors.Count) collector(s)..."

        # Collect all Using statements from all collectors
        $allUsings = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($collector in $usingCollectors) {
            foreach ($usingData in $collector.UsingData.Values) {
                $allUsings.Add($usingData.Statement) | Out-Null
            }
        }

        if ($allUsings.Count -eq 0) {
            Write-Verbose "No Using statements collected"
            return [string]::Empty
        }

        # Sort and format
        $sortedUsings = $allUsings | Sort-Object
        $result = $sortedUsings -join [Environment]::NewLine

        Write-Verbose "    Consolidated $($allUsings.Count) unique Using statement(s)"

        return $result
    }

    <#
    .SYNOPSIS
        Gets formatted file content from a File collector.
    .DESCRIPTION
        The GetFileContent() method retrieves all file data from the specified FileCollector
        and formats it as concatenated content with blank line separators.
    .PARAMETER collector
        The FileCollector to retrieve content from.
    .OUTPUTS
        Returns formatted file content as string.
    #>
    [string] GetFileContent([PSScriptBuilderFileCollector] $collector) {
        if ($null -eq $collector) {
            $message = "Collector cannot be null."
            throw [ArgumentNullException]::new("collector", $message)
        }

        $content = [StringBuilder]::new()

        foreach ($fileData in $collector.FileData.Values) {
            [void] $content.AppendLine($fileData.Content)
            [void] $content.AppendLine()  # Blank line separator
        }

        return $content.ToString()
    }

    <#
    .SYNOPSIS
        Builds formatted content for any collector type.
    .DESCRIPTION
        The BuildCollectorContent() method is a factory method that builds formatted content
        based on the collector's type. It handles dependency-aware ordering for Enums, Classes,
        and Functions when sortedComponents are provided.

        For Using and File collectors, sortedComponents are not used (no dependencies).
        For Enum, Class, and Function collectors, sortedComponents enable dependency-aware ordering.
    .PARAMETER collector
        The collector to build content from.
    .PARAMETER orderedComponents
        Array of component names in dependency order (used for Enum/Class/Function).
    .OUTPUTS
        Returns formatted content as string.
    #>
    [string] BuildCollectorContent([PSScriptBuilderCollectorBase] $collector, [string[]] $orderedComponents) {
        if ($null -eq $collector) {
            $message = "Collector cannot be null."
            throw [ArgumentNullException]::new("collector", $message)
        }

        $content = [StringBuilder]::new()

        switch ($collector.CollectorType) {
            ([PSScriptBuilderCollectorType]::UsingCollector) {
                # Early return if no using statements
                if ($collector.UsingData.Count -eq 0) {
                    Write-Warning "$($collector.CollectorType) with Key '$($collector.CollectionKey)': no using statements found - inserting fallback comment"
                    return "# No using statements for collector: $($collector.CollectionKey)"
                }

                # Using statements should use GetConsolidatedUsingStatements() instead
                # This is a fallback for individual Using collectors in Free Mode
                foreach ($usingData in $collector.UsingData.Values) {
                    [void] $content.AppendLine($usingData.Statement)
                }
            }

            ([PSScriptBuilderCollectorType]::EnumCollector) {
                # Early return if no enums
                if ($collector.EnumData.Count -eq 0) {
                    Write-Warning "$($collector.CollectorType) with Key '$($collector.CollectionKey)': no enums found - inserting fallback comment"
                    return "# No enums for collector: $($collector.CollectionKey)"
                }

                # Try dependency-aware ordering first
                $enumNamesInCollector = $collector.EnumData.Keys
                $sortedEnumNames = $orderedComponents | Where-Object { $_ -in $enumNamesInCollector }

                if ($sortedEnumNames.Count -gt 0) {
                    # Use dependency order
                    Write-Verbose "    Using component order for $($sortedEnumNames.Count) enum(s)"
                    $sortedEnumArray = @($sortedEnumNames)
                    for ($i = 0; $i -lt $sortedEnumArray.Count; $i++) {
                        Write-Verbose "      Retrieving source for Enum $($sortedEnumArray[$i])"
                        $enumData = $collector.EnumData[$sortedEnumArray[$i]]
                        [void] $content.AppendLine($enumData.SourceCode)
                        if ($i -lt $sortedEnumArray.Count - 1) {
                            [void] $content.AppendLine()  # Blank line separator between elements
                        }
                    }
                }
                else {
                    # Fallback: Dictionary order - used when orderedComponents is empty (e.g., direct calls in tests)
                    Write-Verbose "    Using dictionary order for $($collector.EnumData.Count) enum(s)"
                    $enumArray = @($collector.EnumData.Values)
                    for ($i = 0; $i -lt $enumArray.Count; $i++) {
                        Write-Verbose "      Retrieving source for Enum $($enumArray[$i].Name)"
                        [void] $content.AppendLine($enumArray[$i].SourceCode)
                        if ($i -lt $enumArray.Count - 1) {
                            [void] $content.AppendLine()  # Blank line separator between elements
                        }
                    }
                }
            }

            ([PSScriptBuilderCollectorType]::ClassCollector) {
                # Early return if no classes
                if ($collector.ClassData.Count -eq 0) {
                    Write-Warning "$($collector.CollectorType) with Key '$($collector.CollectionKey)': no classes found - inserting fallback comment"
                    return "# No classes for collector: $($collector.CollectionKey)"
                }

                # Try dependency-aware ordering first
                $classNamesInCollector = $collector.ClassData.Keys
                $sortedClassNames = $orderedComponents | Where-Object { $_ -in $classNamesInCollector }

                if ($sortedClassNames.Count -gt 0) {
                    # Use dependency order
                    Write-Verbose "    Using component order for $($sortedClassNames.Count) class(es)"
                    $sortedClassArray = @($sortedClassNames)
                    for ($i = 0; $i -lt $sortedClassArray.Count; $i++) {
                        Write-Verbose "      Retrieving source for Class $($sortedClassArray[$i])"
                        $classData = $collector.ClassData[$sortedClassArray[$i]]
                        [void] $content.AppendLine($classData.SourceCode)
                        if ($i -lt $sortedClassArray.Count - 1) {
                            [void] $content.AppendLine()  # Blank line separator between elements
                        }
                    }
                }
                else {
                    # Fallback: Dictionary order - used when orderedComponents is empty (e.g., direct calls in tests)
                    Write-Verbose "    Using dictionary order for $($collector.ClassData.Count) class(es)"
                    $classArray = @($collector.ClassData.Values)
                    for ($i = 0; $i -lt $classArray.Count; $i++) {
                        Write-Verbose "      Retrieving source for Class $($classArray[$i].Name)"
                        [void] $content.AppendLine($classArray[$i].SourceCode)
                        if ($i -lt $classArray.Count - 1) {
                            [void] $content.AppendLine()  # Blank line separator between elements
                        }
                    }
                }
            }

            ([PSScriptBuilderCollectorType]::FunctionCollector) {
                # Early return if no functions
                if ($collector.FunctionData.Count -eq 0) {
                    Write-Warning "$($collector.CollectorType) with Key '$($collector.CollectionKey)': no functions found - inserting fallback comment"
                    return "# No functions for collector: $($collector.CollectionKey)"
                }

                # Try dependency-aware ordering first
                $functionNamesInCollector = $collector.FunctionData.Keys
                $sortedFunctionNames = $orderedComponents | Where-Object { $_ -in $functionNamesInCollector }

                if ($sortedFunctionNames.Count -gt 0) {
                    # Use dependency order
                    Write-Verbose "    Using component order for $($sortedFunctionNames.Count) function(s)"
                    $sortedFunctionArray = @($sortedFunctionNames)

                    for ($i = 0; $i -lt $sortedFunctionArray.Count; $i++) {
                        Write-Verbose "      Retrieving source for Function $($sortedFunctionArray[$i])"
                        $functionData = $collector.FunctionData[$sortedFunctionArray[$i]]

                        [void] $content.AppendLine($functionData.SourceCode)

                        if ($i -lt $sortedFunctionArray.Count - 1) {
                            [void] $content.AppendLine()  # Blank line separator between elements
                        }
                    }
                }
                else {
                    # Fallback: Dictionary order - used when orderedComponents is empty (e.g., direct calls in tests)
                    Write-Verbose "    Using dictionary order for $($collector.FunctionData.Count) function(s)"
                    $functionArray = @($collector.FunctionData.Values)

                    for ($i = 0; $i -lt $functionArray.Count; $i++) {
                        Write-Verbose "      Retrieving source for Function $($functionArray[$i].Name)"
                        [void] $content.AppendLine($functionArray[$i].SourceCode)

                        if ($i -lt $functionArray.Count - 1) {
                            [void] $content.AppendLine()  # Blank line separator between elements
                        }
                    }
                }
            }

            ([PSScriptBuilderCollectorType]::FileCollector) {
                # Early return if no files
                if ($collector.FileData.Count -eq 0) {
                    Write-Warning "$($collector.CollectorType) with Key '$($collector.CollectionKey)': no files found - inserting fallback comment"
                    return "# No files for collector: $($collector.CollectionKey)"
                }

                # File collectors: simple concatenation in dictionary order
                $fileArray = @($collector.FileData.Values)
                Write-Verbose "    Including $($fileArray.Count) file(s)..."

                for ($i = 0; $i -lt $fileArray.Count; $i++) {
                    Write-Verbose "      Retrieving source for File $($fileArray[$i].FileName)"
                    [void] $content.AppendLine($fileArray[$i].Content)

                    if ($i -lt $fileArray.Count - 1) {
                        [void] $content.AppendLine()  # Blank line separator between elements
                    }
                }
            }
        }

        return $content.ToString()
    }

    <#
    .SYNOPSIS
        Gets source code for a specific component by name.
    .DESCRIPTION
        The GetComponentSourceCode() method is a convenience wrapper around
        ContentCollector.GetComponentSourceCode(). It provides a unified interface
        for component retrieval.
    .PARAMETER componentName
        The name of the component to retrieve.
    .OUTPUTS
        Returns the source code of the component.
    #>
    [string] GetComponentSourceCode([string] $componentName) {
        return $this.ContentCollector.GetComponentSourceCode($componentName)
    }

    <#
    .SYNOPSIS
        Gets the collector type for a specific component by name.
    .DESCRIPTION
        The GetComponentType() method is a convenience wrapper around
        ContentCollector.GetComponentType(). It provides a unified interface
        for component type retrieval.
    .PARAMETER componentName
        The name of the component to look up.
    .OUTPUTS
        Returns the PSScriptBuilderCollectorType of the collector that owns the component.
    #>
    [PSScriptBuilderCollectorType] GetComponentType([string] $componentName) {
        return $this.ContentCollector.GetComponentType($componentName)
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderContentProcessor

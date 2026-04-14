using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderBuildDataAggregator
<#
.SYNOPSIS
    Aggregates build statistics and component details from collectors.
.DESCRIPTION
    The PSScriptBuilderBuildDataAggregator class is responsible for aggregating data from all collectors
    managed by a ContentCollector. It provides methods to retrieve component counts, component details,
    and processed file lists. This class implements the Separation of Concerns principle by isolating
    statistics aggregation from collection orchestration.
#>
class PSScriptBuilderBuildDataAggregator {
    #region Properties
    <#
    .SYNOPSIS
        The ContentCollector to aggregate data from.
    .DESCRIPTION
        The ContentCollector property holds a reference to the ContentCollector instance that manages
        all collectors. This aggregator uses the ContentCollector to access collector data.
    #>
    hidden [PSScriptBuilderContentCollector] $ContentCollector
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderBuildDataAggregator.
    .DESCRIPTION
        Creates a new PSScriptBuilderBuildDataAggregator with the specified ContentCollector.
    .PARAMETER contentCollector
        The ContentCollector instance to aggregate data from.
    #>
    PSScriptBuilderBuildDataAggregator([PSScriptBuilderContentCollector] $contentCollector) {
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
        Gets the component counts from all collectors.
    .DESCRIPTION
        The GetComponentCounts() method retrieves the count of collected components from each collector
        and returns a PSScriptBuilderBuildComponentCounts object with the aggregated counts.
    .OUTPUTS
        Returns a PSScriptBuilderBuildComponentCounts object containing counts for all component types.
    #>
    [PSScriptBuilderBuildComponentCounts] GetComponentCounts() {
        $counts = [PSScriptBuilderBuildComponentCounts]::new()
        $collectors = $this.ContentCollector.GetCollectors()

        foreach ($collector in $collectors) {
            $count = $collector.GetCount()

            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::UsingCollector)    { $counts.UsingStatements     += $count }
                ([PSScriptBuilderCollectorType]::EnumCollector)     { $counts.EnumDefinitions     += $count }
                ([PSScriptBuilderCollectorType]::ClassCollector)    { $counts.ClassDefinitions    += $count }
                ([PSScriptBuilderCollectorType]::FunctionCollector) { $counts.FunctionDefinitions += $count }
                ([PSScriptBuilderCollectorType]::FileCollector)     { $counts.FileContents        += $count }
            }
        }

        $total = 
            $counts.UsingStatements     + 
            $counts.EnumDefinitions     + 
            $counts.ClassDefinitions    + 
            $counts.FunctionDefinitions + 
            $counts.FileContents

        $maxValueLength = "$total".Length

        Write-Verbose "Components collected from source files:"
        Write-Verbose ("  {0,-19}: {1}" -f "UsingStatements",     "$($counts.UsingStatements)".PadLeft($maxValueLength))
        Write-Verbose ("  {0,-19}: {1}" -f "EnumDefinitions",     "$($counts.EnumDefinitions)".PadLeft($maxValueLength))
        Write-Verbose ("  {0,-19}: {1}" -f "ClassDefinitions",    "$($counts.ClassDefinitions)".PadLeft($maxValueLength))
        Write-Verbose ("  {0,-19}: {1}" -f "FunctionDefinitions", "$($counts.FunctionDefinitions)".PadLeft($maxValueLength))
        Write-Verbose ("  {0,-19}: {1}" -f "FileContents",        "$($counts.FileContents)".PadLeft($maxValueLength))
        Write-Verbose ("  {0,-19}: {1}" -f "Total",               "$total".PadLeft($maxValueLength))

        return $counts
    }

    <#
    .SYNOPSIS
        Gets detailed information for all components.
    .DESCRIPTION
        The GetComponentDetails() method retrieves detailed information (type, name, source file, dependencies)
        for all components from EnumCollector, ClassCollector, and FunctionCollector.
    .OUTPUTS
        Returns an array of PSScriptBuilderBuildComponentDetail objects.
    #>
    [PSScriptBuilderBuildComponentDetail[]] GetComponentDetails() {
        $allNames = $this.GetAllComponentNames()
        return $this.GetComponentDetails($allNames)
    }

    <#
    .SYNOPSIS
        Gets detailed information for specified components.
    .DESCRIPTION
        The GetComponentDetails() method retrieves detailed information (type, name, source file, dependencies)
        for the specified components. Only components from EnumCollector, ClassCollector, and FunctionCollector
        are included in the details.
    .PARAMETER componentNames
        Array of component names to retrieve details for.
    .OUTPUTS
        Returns an array of PSScriptBuilderBuildComponentDetail objects.
    #>
    [PSScriptBuilderBuildComponentDetail[]] GetComponentDetails([string[]] $componentNames) {
        Write-Verbose "Gathering component details for $($componentNames.Count) component(s)..."

        # Build a lookup of all known project component names for dependency filtering
        $knownComponents = [HashSet[string]]::new($componentNames, [StringComparer]::OrdinalIgnoreCase)

        $details = [List[PSScriptBuilderBuildComponentDetail]]::new()
        $collectors = $this.ContentCollector.GetCollectors()

        foreach ($componentName in $componentNames) {
            foreach ($collector in $collectors) {
                $detail = $collector.TryGetComponentDetail($componentName, $knownComponents)

                if ($null -ne $detail) {
                    $details.Add($detail)
                    break
                }
            }
        }

        Write-Verbose "  Retrieved $($details.Count) component detail(s)"

        return $details.ToArray()
    }

    <#
    .SYNOPSIS
        Gets the list of all processed files.
    .DESCRIPTION
        The GetProcessedFiles() method extracts the source file paths from all Info objects in the collectors
        and returns a deduplicated array of file paths.
    .OUTPUTS
        Returns an array of unique file paths that were processed during collection.
    #>
    [string[]] GetProcessedFiles() {
        Write-Verbose "Gathering processed files..."

        $files = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $collectors = $this.ContentCollector.GetCollectors()

        foreach ($collector in $collectors) {
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

        Write-Verbose "  Processed $($files.Count) unique file(s)"

        # Convert HashSet to array before returning
        return [string[]] @($files)
    }
    #endregion Methods

    #region Helper Methods
    <#
    .SYNOPSIS
        Gets all component names from all collectors.
    .DESCRIPTION
        The GetAllComponentNames() method collects all component names from EnumCollector, ClassCollector,
        and FunctionCollector. UsingCollector and FileCollector are excluded as they don't provide
        component details.
    .OUTPUTS
        Returns an array of all component names.
    #>
    hidden [string[]] GetAllComponentNames() {
        $names = [List[string]]::new()
        $collectors = $this.ContentCollector.GetCollectors()

        foreach ($collector in $collectors) {
            $keys = $null

            switch ($collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::EnumCollector)     { $keys = $collector.EnumData.Keys     }
                ([PSScriptBuilderCollectorType]::ClassCollector)    { $keys = $collector.ClassData.Keys    }
                ([PSScriptBuilderCollectorType]::FunctionCollector) { $keys = $collector.FunctionData.Keys }
            }

            if ($null -ne $keys) {
                $keyArray = [string[]] @($keys)
                $names.AddRange($keyArray)
            }
        }

        return $names.ToArray()
    }
    #endregion Helper Methods
}
#endregion Class PSScriptBuilderBuildDataAggregator

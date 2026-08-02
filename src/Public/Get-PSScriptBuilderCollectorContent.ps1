#region Cmdlet Get-PSScriptBuilderCollectorContent
function Get-PSScriptBuilderCollectorContent {
    <#
    .SYNOPSIS
        Retrieves collected data from a collector.
    .DESCRIPTION
        The Get-PSScriptBuilderCollectorContent cmdlet retrieves the data that has been collected
        by a specific collector. This includes classes, functions, enums, using statements, or file
        contents, depending on the collector type.

        The cmdlet returns actual data objects (PSScriptBuilderClassData, PSScriptBuilderFunctionData, etc.)
        which contain detailed information about each collected item including source code, source files,
        and dependency information.

        Without the -ItemName parameter, all collected items are returned. With -ItemName, only the
        specified item is returned (case-insensitive match).

        If the collector has not been executed yet, a warning is displayed and an empty array is returned.
    .PARAMETER Collector
        The collector instance to retrieve data from. Must be a PSScriptBuilderCollectorBase or one
        of its derived types:
        - PSScriptBuilderClassCollector
        - PSScriptBuilderFunctionCollector
        - PSScriptBuilderEnumCollector
        - PSScriptBuilderUsingCollector
        - PSScriptBuilderFileCollector
    .PARAMETER ItemName
        Optional. The name of a specific item to retrieve. The match is case-insensitive.
        
        For ClassCollector: Class name
        For FunctionCollector: Function name
        For EnumCollector: Enum name
        For UsingCollector: Using statement (exact match)
        For FileCollector: File name
    .OUTPUTS
        PSCustomObject[]
    .EXAMPLE
        $classCollector | Get-PSScriptBuilderCollectorContent | 
            Where-Object { $_.BaseClass -eq "PSScriptBuilderBase" }

        Retrieves all classes that inherit from PSScriptBuilderBase using pipeline and Where-Object.
    .EXAMPLE
        $baseClass = Get-PSScriptBuilderCollectorContent -Collector $classCollector -ItemName "PSScriptBuilderBase"
        Write-Host $baseClass.SourceCode

        Retrieves a specific class by name and displays its source code.
    .EXAMPLE
        # Debugging: Which classes were collected?
        $cc.GetCollectors() | Where-Object { $_.CollectorType -eq 'Class' } | ForEach-Object {
            $items = Get-PSScriptBuilderCollectorContent -Collector $_
            Write-Host "$($_.CollectionKey): $($items.Count) classes"
            $items | Select-Object Name, SourceFile | Format-Table
        }

        Lists all class collectors and shows what each collected.
    .EXAMPLE
        # Validation: Are all expected components present?
        $functions = Get-PSScriptBuilderCollectorContent -Collector $funcCollector
        $expected = @("Get-Data", "Set-Data", "Remove-Data")
        $missing = $expected | Where-Object { $_ -notin $functions.Name }
        if ($missing) {
            throw "Missing functions: $($missing -join ', ')"
        }

        Validates that all expected functions were collected.
    .EXAMPLE
        # Dependency analysis: Which classes use PSScriptBuilderLogger?
        Get-PSScriptBuilderCollectorContent -Collector $classCollector |
            Where-Object { $_.TypeReferences -contains "PSScriptBuilderLogger" } |
            Select-Object Name, SourceFile

        Finds all classes that reference PSScriptBuilderLogger.
    .EXAMPLE
        # Collector status check
        $collector = Get-PSScriptBuilderCollector -ContentCollector $cc -CollectionKey "FUNCTIONS"
        $content = Get-PSScriptBuilderCollectorContent -Collector $collector
        if ($content.Count -eq 0) {
            Write-Warning "No functions collected. Check IncludePaths or execute ContentCollector."
        }

        Checks if collector has collected any data.
    .EXAMPLE
        # Find all source files that were scanned
        $classCollector | Get-PSScriptBuilderCollectorContent |
            Select-Object -ExpandProperty SourceFile -Unique |
            Sort-Object

        Lists all unique source files that contained class definitions.
    .EXAMPLE
        # Using statements with file tracking
        $usingData = Get-PSScriptBuilderCollectorContent -Collector $usingCollector
        foreach ($using in $usingData) {
            Write-Host "Statement: $($using.Statement)"
            Write-Host "  Found in $($using.SourceFiles.Count) file(s):"
            $using.SourceFiles | ForEach-Object { Write-Host "    - $_" }
        }

        Displays all using statements with the files where they were found.
    .NOTES
        The cmdlet accesses the data properties of collector objects:
        - ClassCollector.ClassData.Values
        - FunctionCollector.FunctionData.Values
        - EnumCollector.EnumData.Values
        - UsingCollector.UsingData.Values
        - FileCollector.FileData.Values

        All collectors use Dictionary[string, XxxData] structures internally, and this cmdlet
        retrieves the Values collection which contains the actual data objects.

        If the collector has not been executed, the data dictionaries will be empty. 
        The cmdlet detects this and displays a warning to guide the user.

        The -ItemName parameter performs a case-insensitive lookup. For Dictionary-based collectors,
        this is efficient. For collectors with many items, consider filtering the full result set
        with Where-Object for more complex queries.

        This cmdlet is designed for inspection and debugging during development. For production
        builds, the collected data is automatically processed by the build pipeline without needing
        to call this cmdlet.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderCollectorBase] $Collector,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ItemName
    )

    process {
        try {
            $format  = "Retrieving collected data from collector {0} with key '{1}'..."
            $message = $format -f $Collector.CollectorType, $Collector.CollectionKey
            Write-Verbose $message

            # Get data based on collector type
            switch ($Collector.CollectorType) {
                ([PSScriptBuilderCollectorType]::ClassCollector)    { $data = $Collector.ClassData.Values    }
                ([PSScriptBuilderCollectorType]::FunctionCollector) { $data = $Collector.FunctionData.Values }
                ([PSScriptBuilderCollectorType]::EnumCollector)     { $data = $Collector.EnumData.Values     }
                ([PSScriptBuilderCollectorType]::UsingCollector)    { $data = $Collector.UsingData.Values    }
                ([PSScriptBuilderCollectorType]::FileCollector)     { $data = $Collector.FileData.Values     }
                default {
                    $message = "Unknown collector type: {0}" -f $Collector.CollectorType
                    throw [InvalidOperationException]::new($message)
                }
            }

            # Check if collector has been executed
            if (-not $data -or $data.Count -eq 0) {
                Write-Warning "Collector has not been executed or no data was collected. Run collection first."
                return @()
            }

            Write-Verbose "  Found $($data.Count) item(s)"

            # Filter by ItemName if specified
            if ($ItemName) {
                Write-Verbose "  Filtering for item: $ItemName"

                $filtered = $data | Where-Object { 
                    # Handle different property names
                    if ($_.PSObject.Properties['Name']) {
                        $_.Name -eq $ItemName
                    }
                    elseif ($_.PSObject.Properties['FileName']) {
                        $_.FileName -eq $ItemName
                    }
                    elseif ($_.PSObject.Properties['Statement']) {
                        $_.Statement -eq $ItemName
                    }
                    else {
                        $false
                    }
                }

                if (-not $filtered) {
                    Write-Verbose "  No item found with name '$ItemName'"
                    return @()
                }

                Write-Verbose "  Found matching item"
                return @($filtered)
            }

            # Return all data
            return @($data)
        }
        catch {
            $format = "Failed to retrieve collector content from '{0}'. Error: {1}"
            $message = $format -f $Collector.CollectionKey, $_.Exception.Message
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderCollectorContent

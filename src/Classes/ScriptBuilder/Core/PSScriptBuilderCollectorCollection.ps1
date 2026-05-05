using namespace System
using namespace System.Collections.Generic

#region Class PSScriptBuilderCollectorCollection
<#
.SYNOPSIS
    Manages a collection of collectors.
.DESCRIPTION
    The PSScriptBuilderCollectorCollection class manages multiple collector instances indexed by CollectionKey.
    Provides methods for adding, removing, and querying collectors.
#>
class PSScriptBuilderCollectorCollection {
    #region Properties
    <#
    .SYNOPSIS
        Dictionary of collectors indexed by CollectionKey.
    .DESCRIPTION
        The Items property holds a dictionary mapping unique string keys to PSScriptBuilderCollectorBase 
        instances. The string keys represent the CollectionKey of each collector.
    #>
    [Dictionary[string, PSScriptBuilderCollectorBase]] $Items
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderCollectorCollection.
    .DESCRIPTION
        Creates a new PSScriptBuilderCollectorCollection with empty collection.
    #>
    PSScriptBuilderCollectorCollection() {
        $this.Items = [Dictionary[string, PSScriptBuilderCollectorBase]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Adds a collector to the collection.
    .DESCRIPTION
        The Add() method adds a new collector to the collection using its CollectionKey as the dictionary key.
        It checks for null values, validates the CollectionKey, and ensures that no duplicate keys are added.
        If a collector with the same key already exists, an InvalidOperationException is thrown to prevent 
        overwriting existing collectors.
    .PARAMETER collector
        The collector to add to the collection.
    #>
    [void] Add([PSScriptBuilderCollectorBase] $collector) {
        if ($null -eq $collector) {
            throw [ArgumentNullException]::new("collector", "Collector cannot be null.")
        }

        $key = $collector.CollectionKey

        if ([string]::IsNullOrWhiteSpace($key)) {
            throw [ArgumentException]::new("Collector must have a valid CollectionKey.", "collector")
        }

        if ($this.Exists($key)) {
            $message = "A collector with the key '$key' already exists in the collection."
            throw [InvalidOperationException]::new($message)
        }

        $this.Items[$key] = $collector
        Write-Verbose "Added collector $($collector.CollectorType) with key '$key' to collection"
    }

    <#
    .SYNOPSIS
        Removes a collector from the collection.
    .DESCRIPTION
        The Remove() method removes a collector from the collection based on its CollectionKey.
        It checks for null or whitespace keys and returns true if the collector was successfully removed, 
        or false if no collector with the specified key exists.
    .PARAMETER key
        The CollectionKey of the collector to remove.
    .OUTPUTS
        Returns true if the collector was successfully removed, false otherwise.
    #>
    [bool] Remove([string] $key) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw [ArgumentException]::new("Key cannot be null or whitespace.", "key")
        }

        if (-not $this.Exists($key)) {
            Write-Verbose "No collector with key '$key' exists in collection. Nothing to remove."
            return $false
        }

        $collectorType = $this.Items[$key].CollectorType

        $removed = $this.Items.Remove($key)

        if ($removed) {
            Write-Verbose "Removed collector $collectorType with key '$key' from collection"
        }

        return $removed
    }

    <#
    .SYNOPSIS
        Checks if a collector with the specified key exists.
    .DESCRIPTION
        Returns true if a collector with the specified key exists in the collection, otherwise false.
    .PARAMETER key
        The CollectionKey to check for.
    .OUTPUTS
        Returns true if the collector with the specified key exists, false otherwise.
    #>
    [bool] Exists([string] $key) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            return $false
        }

        return $this.Items.ContainsKey($key)
    }

    <#
    .SYNOPSIS
        Gets a collector by its key.
    .DESCRIPTION
        Returns the collector with the specified key.
        Throws an exception if the key is not found.
    .PARAMETER key
        The CollectionKey of the collector to retrieve.
    .OUTPUTS
        Returns the collector associated with the specified key.
    #>
    [PSScriptBuilderCollectorBase] GetCollector([string] $key) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw [ArgumentException]::new("Key cannot be null or whitespace.", "key")
        }

        if (-not $this.Exists($key)) {
            $message = "No collector with the key '$key' exists in the collection."
            throw [KeyNotFoundException]::new($message)
        }

        return $this.Items[$key]
    }

    <#
    .SYNOPSIS
        Gets all collectors in the collection.
    .DESCRIPTION
        Returns all collectors sorted by their CollectorType (Using, Enum, Class, Function, File).
        This ensures proper dependency order when processing collectors.
    .OUTPUTS
        Returns an array of all collectors in the collection.
    #>
    [PSScriptBuilderCollectorBase[]] GetAll() {
        $collectors = $this.Items.Values | Sort-Object -Property CollectorType
        return @($collectors)
    }

    <#
    .SYNOPSIS
        Gets all collectors as a dictionary.
    .DESCRIPTION
        The GetDictionary() method returns the internal dictionary of collectors, allowing direct access to 
        collectors by their CollectionKey.
        This can be useful for advanced scenarios where direct dictionary manipulation is needed, but should be 
        used with caution to avoid breaking encapsulation.
    .OUTPUTS
        Returns the dictionary of collectors.
    #>
    [Dictionary[string, PSScriptBuilderCollectorBase]] GetDictionary() {
        return $this.Items
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
        return $this.Items.Count
    }

    <#
    .SYNOPSIS
        Clears all collectors from the collection.
    .DESCRIPTION
        The Clear() method removes all collectors from the collection.
        It also writes a verbose message indicating that the collection has been cleared.
    #>
    [void] Clear() {
        $this.Items.Clear()
        Write-Verbose "Cleared all collectors from collection"
    }

    <#
    .SYNOPSIS
        Gets all UsingCollectors from the collection.
    .DESCRIPTION
        The GetUsingCollectors() method returns an array of all collectors that are of type UsingCollector.
    .OUTPUTS
        PSScriptBuilderUsingCollector[]
    #>
    [PSScriptBuilderUsingCollector[]] GetUsingCollectors() {
        return @($this.Items.Values | Where-Object { 
            $_.CollectorType -eq [PSScriptBuilderCollectorType]::UsingCollector 
        })
    }

    <#
    .SYNOPSIS
        Gets all FileCollectors from the collection.
    .DESCRIPTION
        The GetFileCollectors() method returns an array of all collectors that are of type FileCollector.
    .OUTPUTS
        PSScriptBuilderFileCollector[]
    #>
    [PSScriptBuilderFileCollector[]] GetFileCollectors() {
        return @($this.Items.Values | Where-Object { 
            $_.CollectorType -eq [PSScriptBuilderCollectorType]::FileCollector 
        })
    }

    <#
    .SYNOPSIS
        Gets all EnumCollectors from the collection.
    .DESCRIPTION
        The GetEnumCollectors() method returns an array of all collectors that are of type EnumCollector.
    .OUTPUTS
        PSScriptBuilderEnumCollector[]
    #>
    [PSScriptBuilderEnumCollector[]] GetEnumCollectors() {
        return @($this.Items.Values | Where-Object { 
            $_.CollectorType -eq [PSScriptBuilderCollectorType]::EnumCollector 
        })
    }

    <#
    .SYNOPSIS
        Gets all ClassCollectors from the collection.
    .DESCRIPTION
        The GetClassCollectors() method returns an array of all collectors that are of type ClassCollector.
    .OUTPUTS
        PSScriptBuilderClassCollector[]
    #>
    [PSScriptBuilderClassCollector[]] GetClassCollectors() {
        return @($this.Items.Values | Where-Object { 
            $_.CollectorType -eq [PSScriptBuilderCollectorType]::ClassCollector 
        })
    }

    <#
    .SYNOPSIS
        Gets all FunctionCollectors from the collection.
    .DESCRIPTION
        The GetFunctionCollectors() method returns an array of all collectors that are of type FunctionCollector.
    .OUTPUTS
        PSScriptBuilderFunctionCollector[]
    #>
    [PSScriptBuilderFunctionCollector[]] GetFunctionCollectors() {
        return @($this.Items.Values | Where-Object { 
            $_.CollectorType -eq [PSScriptBuilderCollectorType]::FunctionCollector 
        })
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderCollectorCollection

using namespace System.Collections.Generic

#region Cmdlet Get-PSScriptBuilderCollector
function Get-PSScriptBuilderCollector {
    <#
    .SYNOPSIS
        Retrieves collectors from a ContentCollector.
    .DESCRIPTION
        The Get-PSScriptBuilderCollector cmdlet retrieves one or more collectors from a ContentCollector
        instance. Without parameters, it returns all registered collectors. With optional filters,
        you can retrieve a specific collector by key or filter by collector type.

        The cmdlet returns actual PSScriptBuilderCollectorBase objects (not simplified PSCustomObjects),
        which enables:
        - Direct property access (IncludePaths, ExcludePaths, etc.)
        - Pipeline compatibility with Remove-PSScriptBuilderCollector
        - Use with Get-PSScriptBuilderCollectorContent for data inspection

        Collectors are returned sorted by their CollectorType (Using, Enum, Class, Function, File),
        which reflects their execution order during collection.

        CollectionKey and Type cannot be combined - they select collectors in two different ways
        and belong to separate parameter sets, so PowerShell itself rejects passing both together.
    .PARAMETER ContentCollector
        The ContentCollector instance to query for collectors. This is the orchestrator object
        that manages all registered collectors.
    .PARAMETER CollectionKey
        Optional. Retrieves only the collector with this specific key. The key is case-insensitive.

        If no collector with the specified key exists, an error is written and null is returned.
    .PARAMETER Type
        Optional. Filters collectors by their type. Valid values:
        - UsingCollector: Collects using statements
        - EnumCollector: Collects enumeration definitions
        - ClassCollector: Collects class definitions
        - FunctionCollector: Collects function definitions
        - FileCollector: Collects entire file contents

        Returns all collectors of the specified type.
    .OUTPUTS
        PSScriptBuilderCollectorBase[]
    .EXAMPLE
        $contentCollector | Get-PSScriptBuilderCollector

        Retrieves all collectors using pipeline input.
    .EXAMPLE
        Get-PSScriptBuilderCollector -ContentCollector $contentCollector -CollectionKey "CLASSES"

        Retrieves only the collector with the key "CLASSES". Returns null if not found.
    .EXAMPLE
        Get-PSScriptBuilderCollector -ContentCollector $contentCollector -Type ClassCollector

        Retrieves all ClassCollectors from the ContentCollector. This includes collectors
        with different keys (e.g., "CLASSES_DOMAIN", "CLASSES_UTILS").
    .EXAMPLE
        $classCollector = Get-PSScriptBuilderCollector -ContentCollector $contentCollector -CollectionKey "CLASSES"
        $classCollector.IncludePaths

        Retrieves a specific collector and accesses its properties directly.
    .EXAMPLE
        Get-PSScriptBuilderCollector -ContentCollector $contentCollector |
            Where-Object { -not $_.IncludePaths -or $_.IncludePaths.Count -eq 0 }

        Uses Where-Object to filter collectors based on their configuration.
    .NOTES
        The cmdlet delegates to PSScriptBuilderContentCollector methods:
        - GetCollectors() - Returns all collectors sorted by type
        - GetCollector(key) - Returns specific collector by key

        Keys are compared case-insensitively.

        When filtering by Type, the cmdlet uses GetCollectors() and filters the array.
        This is more efficient than iterating manually since GetCollectors() already sorts.

        If a CollectionKey is specified but not found, the underlying method throws
        KeyNotFoundException, which is caught and converted to a user-friendly error message.

        For inspecting the collected data (classes, functions, etc.), use
        Get-PSScriptBuilderCollectorContent which accepts the collector objects returned by this cmdlet.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSScriptBuilderCollectorBase[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'All')]
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByKey')]
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByType')]
        [PSScriptBuilderContentCollector] $ContentCollector,

        [Parameter(Mandatory, ParameterSetName = 'ByKey')]
        [ValidateNotNullOrEmpty()]
        [string] $CollectionKey,

        [Parameter(Mandatory, ParameterSetName = 'ByType')]
        [PSScriptBuilderCollectorType] $Type
    )

    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'All' {
                    Write-Verbose "Retrieving all collectors..."
                    return $ContentCollector.GetCollectors()
                }
                'ByKey' {
                    Write-Verbose "Retrieving collector with key '$CollectionKey'..."
                    return $ContentCollector.GetCollector($CollectionKey)
                }
                'ByType' {
                    Write-Verbose "Retrieving collectors of type '$Type'..."
                    $collectors = $ContentCollector.GetCollectors()
                    return @($collectors | Where-Object { $_.CollectorType -eq $Type })
                }
            }
        }
        catch [KeyNotFoundException] {
            $message = "No collector with key '{0}' found in ContentCollector" -f $CollectionKey
            Write-Error -Message $message -Category ObjectNotFound -TargetObject $CollectionKey
            return $null
        }
        catch {
            $format = "Failed to retrieve collector(s). Error: {0}"
            $message = $format -f $_.Exception.Message
            throw [InvalidOperationException]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Get-PSScriptBuilderCollector

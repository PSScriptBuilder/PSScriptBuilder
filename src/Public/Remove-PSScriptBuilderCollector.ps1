#region Cmdlet Remove-PSScriptBuilderCollector
function Remove-PSScriptBuilderCollector {
    <#
    .SYNOPSIS
        Removes a collector from a ContentCollector.
    .DESCRIPTION
        The Remove-PSScriptBuilderCollector cmdlet removes a collector from a ContentCollector instance
        based on its CollectionKey. The cmdlet supports pipeline input and returns the modified
        ContentCollector to enable fluent chaining.

        The removal is performed via the ContentCollector's RemoveCollector() method, which validates
        the key and logs the operation via Write-Verbose.

        If no collector with the specified key exists, a warning is displayed but no error is thrown.
        This allows the cmdlet to be used in cleanup scripts without failing if a collector has
        already been removed.

        This is a RAM-only operation that is fully reversible. Collectors can be re-added at any time
        using Add-PSScriptBuilderCollector.
    .PARAMETER ContentCollector
        The ContentCollector instance to remove the collector from. Accepts pipeline input to enable
        fluent chaining.
    .PARAMETER CollectionKey
        The unique identifier (CollectionKey) of the collector to remove. Must match exactly
        (case-insensitive).
    .OUTPUTS
        PSScriptBuilderContentCollector
    .EXAMPLE
        $cc | Remove-PSScriptBuilderCollector -CollectionKey "TEMP_FUNCTIONS"

        Removes the collector with key "TEMP_FUNCTIONS" using pipeline input.
    .EXAMPLE
        $cc = $cc | Remove-PSScriptBuilderCollector -CollectionKey "TEMP" |
                   Add-PSScriptBuilderCollector -Type Class -IncludePath "src/New"

        Removes a collector and adds a new one in a fluent pipeline chain.
    .EXAMPLE
        # Remove multiple collectors by pattern (requires Get-PSScriptBuilderCollector)
        $collectorsToRemove = Get-PSScriptBuilderCollector -ContentCollector $cc |
            Where-Object { $_.CollectionKey -like "TEMP_*" }
        foreach ($collector in $collectorsToRemove) {
            $cc = Remove-PSScriptBuilderCollector -ContentCollector $cc -CollectionKey $collector.CollectionKey
        }

        Removes all collectors whose keys start with "TEMP_".
    .NOTES
        The cmdlet delegates to PSScriptBuilderContentCollector.RemoveCollector(), which in turn
        calls PSScriptBuilderCollectorCollection.Remove(). The collection uses case-insensitive
        string comparison for keys.

        If the specified key is not found, Write-Warning is used (not an error) to allow the
        cmdlet to be used in cleanup/idempotent scripts.

        Verbose logging is provided by the underlying RemoveCollector() method and includes:
        - Collector type and key being removed
        - Success/failure status

        The ContentCollector is always returned, even if removal failed, to enable pipeline chaining.

        This is a RAM-only operation consistent with other in-memory collection management cmdlets
        (Add-PSScriptBuilderCollector does not have WhatIf support either). The operation is fully
        reversible - collectors can be re-added at any time.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderContentCollector])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderContentCollector] $ContentCollector,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $CollectionKey
    )

    process {
        try {
            Write-Verbose "Attempting to remove collector with key '$CollectionKey'..."

            $removed = $ContentCollector.RemoveCollector($CollectionKey)

            if (-not $removed) {
                Write-Warning "No collector with key '$CollectionKey' found. Nothing to remove."
            }
            else {
                Write-Verbose "Successfully removed collector with key '$CollectionKey'"
            }

            return $ContentCollector
        }
        catch {
            $format = "Failed to remove collector with key '{0}'. Error: {1}"
            $message = $format -f $CollectionKey, $_.Exception.Message
            throw [Exception]::new($message, $_.Exception)
        }
    }
}
#endregion Cmdlet Remove-PSScriptBuilderCollector

#region Cmdlet New-PSScriptBuilderContentCollector
function New-PSScriptBuilderContentCollector {
    <#
    .SYNOPSIS
        Creates a new content collector for managing multiple component collectors.
    .DESCRIPTION
        The New-PSScriptBuilderContentCollector cmdlet creates a ContentCollector instance that manages
        a collection of component collectors (Using, Enum, Class, Function, File collectors).

        The ContentCollector orchestrates the execution of all registered collectors and provides
        centralized access to collected components. It can be created empty and populated later via
        Add-PSScriptBuilderCollector, or initialized with pre-created collectors via the -Collector parameter.

        Duplicate CollectionKeys are automatically detected and will throw an error during creation.
    .PARAMETER Collector
        An optional array of pre-created collector instances to initialize the ContentCollector with.
        All collectors must have unique CollectionKeys. Duplicates will cause an error.

        Collectors can be created using New-PSScriptBuilderCollector.
    .OUTPUTS
        PSScriptBuilderContentCollector
    .EXAMPLE
        $cc = New-PSScriptBuilderContentCollector
        $cc.AddCollector((New-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES"))

        Creates empty ContentCollector and adds a collector using the direct method.
    .EXAMPLE
        $collectors = @(
            New-PSScriptBuilderCollector -Type Using -CollectionKey "USINGS" -IncludePath "src"
            New-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src/Classes"
            New-PSScriptBuilderCollector -Type Function -CollectionKey "FUNCTIONS" -IncludePath "src/Public"
        )
        $cc = New-PSScriptBuilderContentCollector -Collector $collectors

        Creates ContentCollector pre-populated with three collectors.
    .EXAMPLE
        New-PSScriptBuilderContentCollector -Collector @(
            New-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN" -IncludePath "src/Domain"
            New-PSScriptBuilderCollector -Type Class -CollectionKey "UTILS" -IncludePath "src/Utils"
        )

        Creates ContentCollector with multiple collectors of the same type but different keys.
    .NOTES
        The ContentCollector uses PSScriptBuilderCollectorCollection internally, which automatically:
        - Validates unique CollectionKeys (throws InvalidOperationException for duplicates)
        - Sorts collectors by CollectorType (Using, Enum, Class, Function, File)
        - Manages collector lifecycle

        Configuration is loaded automatically from the static PSScriptBuilderConfiguration instance.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderContentCollector])]
    param(
        [Parameter()]
        [PSScriptBuilderCollectorBase[]] $Collector
    )

    try {
        Write-Verbose "Creating ContentCollector..."

        # Create ContentCollector instance
        $contentCollector = [PSScriptBuilderContentCollector]::new()

        Write-Verbose "ContentCollector instance created"

        # Add collectors if provided
        if ($Collector) {
            $collectorCount = $Collector.Count
            Write-Verbose "Adding $collectorCount collector(s) to ContentCollector..."

            foreach ($currentCollector in $Collector) {
                if ($null -eq $currentCollector) {
                    Write-Warning "Null reference detected in Collector parameter array. Skipping null entry."
                    continue
                }

                try {
                    $contentCollector.AddCollector($currentCollector)
                    # The AddCollector method logs its own verbose messages, so no need to duplicate success logging here.
                }
                catch {
                    # Re-throw with additional context
                    $format  = "Failed to add collector '{0}' to ContentCollector. Error: {1}"
                    $message = $format -f $currentCollector.CollectionKey, $_.Exception.Message
                    throw [Exception]::new($message, $_.Exception)
                }
            }

            $addedCount = $contentCollector.GetCount()
            Write-Verbose "ContentCollector created with $addedCount collector(s)"
        }
        else {
            Write-Verbose "ContentCollector created empty (no collectors provided)"
        }

        return $contentCollector
    }
    catch {
        $format  = "Failed to create ContentCollector. Error: {0}"
        $message = $format -f $_.Exception.Message
        throw [Exception]::new($message, $_.Exception)
    }
}
#endregion Cmdlet New-PSScriptBuilderContentCollector

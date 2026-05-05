#region Cmdlet Add-PSScriptBuilderCollector
function Add-PSScriptBuilderCollector {
    <#
    .SYNOPSIS
        Adds a collector to a ContentCollector for fluent pipeline configuration.
    .DESCRIPTION
        The Add-PSScriptBuilderCollector cmdlet creates and adds a component collector to a ContentCollector
        instance in one operation. Specify the collector type and configuration parameters to create the
        collector on-the-fly.

        The cmdlet returns the ContentCollector to enable fluent chaining via pipeline, allowing
        multiple collectors to be added in a single pipeline expression.

        For initialization with pre-created collectors, use the -Collector parameter on
        New-PSScriptBuilderContentCollector instead.

        Duplicate CollectionKeys will cause an error during addition.
    .PARAMETER ContentCollector
        The ContentCollector instance to add the collector to. Accepts pipeline input to enable
        fluent chaining.
    .PARAMETER Type
        The type of collector to create and add. Valid values:
        - Using: Collects using statements
        - Enum: Collects enumeration definitions
        - Class: Collects class definitions
        - Function: Collects function definitions
        - File: Collects entire file contents
    .PARAMETER CollectionKey
        An optional unique identifier for the collector being created. If not specified, the collector uses
        its default key. Must be unique within the ContentCollector.

        Examples: "CLASSES_DOMAIN", "FUNCTIONS_PUBLIC", "ENUMS"
    .PARAMETER IncludePath
        One or more directory paths to scan for components. Paths are relative to the project root
        or can be absolute.
    .PARAMETER IncludeFile
        One or more specific files to include. Supports glob patterns. Takes precedence over ExcludeFile.
    .PARAMETER ExcludePath
        One or more directory paths to exclude from processing. Overrides IncludePath if a path matches both.
    .PARAMETER ExcludeFile
        One or more file patterns to exclude. Supports glob patterns.
    .PARAMETER FileExtension
        One or more file extensions to include during scanning. Defaults to @(".ps1").
        Use this to scan additional file types, for example @(".ps1", ".psm1") or @(".txt").

        Example: ".psm1", ".txt"
    .PARAMETER NoRecurse
        When specified, only the top-level directory of each IncludePath is scanned.
        By default, all subdirectories are scanned recursively.
    .OUTPUTS
        PSScriptBuilderContentCollector
    .EXAMPLE
        $cc = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src/Classes" |
            Add-PSScriptBuilderCollector -Type Function -CollectionKey "FUNCTIONS" -IncludePath "src/Public"

        Creates ContentCollector and adds two collectors with custom keys using fluent chaining.
    .EXAMPLE
        $cc = New-PSScriptBuilderContentCollector
        $cc | Add-PSScriptBuilderCollector -Type Using -IncludePath "src"

        Creates ContentCollector and adds a collector with default key using pipeline.
    .EXAMPLE
        $cc = New-PSScriptBuilderContentCollector |
            Add-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN" `
                -IncludePath "src/Classes/Domain" -ExcludeFile "*.Internal.ps1" |
            Add-PSScriptBuilderCollector -Type Class -CollectionKey "UTILS" `
                -IncludePath "src/Classes/Utils"

        Adds multiple collectors of the same type with different configurations and keys.
    .NOTES
        The cmdlet uses New-PSScriptBuilderCollector internally, ensuring consistent collector
        creation logic across the module.

        Path validation warnings from New-PSScriptBuilderCollector will be visible during execution.

        To initialize a ContentCollector with pre-created collectors, use the -Collector parameter
        on New-PSScriptBuilderContentCollector instead.

        Duplicate CollectionKeys are detected by PSScriptBuilderCollectorCollection and will throw
        an InvalidOperationException.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderContentCollector])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSScriptBuilderContentCollector] $ContentCollector,

        [Parameter(Mandatory)]
        [ValidateSet("Using", "Enum", "Class", "Function", "File")]
        [string] $Type,

        [Parameter()]
        [string] $CollectionKey,

        [Parameter()]
        [string[]] $IncludePath,

        [Parameter()]
        [string[]] $IncludeFile,

        [Parameter()]
        [string[]] $ExcludePath,

        [Parameter()]
        [string[]] $ExcludeFile,

        [Parameter()]
        [string[]] $FileExtension,

        [Parameter()]
        [switch] $NoRecurse
    )

    process {
        try {
            # Create collector using New-PSScriptBuilderCollector cmdlet
            $params = @{
                Type = $Type
            }

            if ($CollectionKey) { $params['CollectionKey'] = $CollectionKey }
            if ($IncludePath)   { $params['IncludePath']   = $IncludePath   }
            if ($IncludeFile)   { $params['IncludeFile']   = $IncludeFile   }
            if ($ExcludePath)   { $params['ExcludePath']   = $ExcludePath   }
            if ($ExcludeFile)   { $params['ExcludeFile']   = $ExcludeFile   }
            if ($FileExtension) { $params['FileExtension'] = $FileExtension }
            if ($NoRecurse)     { $params['NoRecurse']     = $NoRecurse     }

            $collector = New-PSScriptBuilderCollector @params

            if ($null -eq $collector) {
                throw [InvalidOperationException]::new("Collector creation failed. New-PSScriptBuilderCollector returned null.")
            }

            # Add collector to ContentCollector
            $ContentCollector.AddCollector($collector)

            # Return ContentCollector for chaining
            return $ContentCollector
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet Add-PSScriptBuilderCollector

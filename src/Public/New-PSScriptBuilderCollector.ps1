#region Cmdlet New-PSScriptBuilderCollector
function New-PSScriptBuilderCollector {
    <#
    .SYNOPSIS
        Creates a new collector for PowerShell script components.
    .DESCRIPTION
        The New-PSScriptBuilderCollector cmdlet creates a collector instance for extracting specific
        PowerShell components (Using statements, Enums, Classes, Functions, or Files) from source files.

        The collector can be used standalone for exploration and analysis, or added to a ContentCollector
        for build operations. Filter options allow precise control over which files and paths are processed.

        Path validation warnings are issued for non-existent paths, but the collector is still created
        to allow for scenarios where paths may be created later.
    .PARAMETER Type
        The type of collector to create. Valid values:
        - Using: Collects using statements
        - Enum: Collects enumeration definitions
        - Class: Collects class definitions
        - Function: Collects function definitions
        - File: Collects entire file contents
    .PARAMETER CollectionKey
        An optional unique identifier for this collector. If not specified, the collector uses its default key
        (e.g., "CLASS_DEFINITIONS" for Class type, "FUNCTION_DEFINITIONS" for Function type).

        Use custom keys to distinguish multiple collectors of the same type with different configurations.
        Must be unique within a ContentCollector.

        Examples: "CLASSES_DOMAIN", "CLASSES_UTILS", "FUNCTIONS_PUBLIC"
    .PARAMETER IncludePath
        One or more directory paths to scan for components. Paths are relative to the project root
        or can be absolute. All files in these paths will be processed unless excluded.

        Example: "src/Classes", "src/Classes/Domain"
    .PARAMETER IncludeFile
        One or more specific files to include. Supports glob patterns. Takes precedence over ExcludeFile.
        Paths are relative to the project root or can be absolute.

        Example: "*.ps1", "src/Classes/MyClass.ps1"
    .PARAMETER ExcludePath
        One or more directory paths to exclude from processing. Overrides IncludePath if a path matches both.

        Example: "src/Classes/Archive", "src/Classes/Deprecated"
    .PARAMETER ExcludeFile
        One or more file patterns to exclude. Supports glob patterns. Useful for excluding specific files
        like internal implementations or test files.

        Example: "*.Internal.ps1", "*.Tests.ps1"
    .PARAMETER FileExtension
        One or more file extensions to include during scanning. Defaults to @(".ps1").
        Use this to scan additional file types, for example @(".ps1", ".psm1") or @(".txt").

        Example: ".psm1", ".txt"
    .PARAMETER NoRecurse
        When specified, only the top-level directory of each IncludePath is scanned.
        By default, all subdirectories are scanned recursively.
    .OUTPUTS
        PSScriptBuilderCollectorBase
    .EXAMPLE
        New-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src/Classes"

        Creates a class collector with a custom key that scans all files in src/Classes directory.
    .EXAMPLE
        $collector = New-PSScriptBuilderCollector -Type Function -CollectionKey "PUBLIC" `
            -IncludePath "src/Functions" -ExcludeFile "*.Internal.ps1"
        $collector.Collect()
        $collector.FunctionData.Keys

        Creates a function collector, executes collection, and displays all found function names.
    .EXAMPLE
        New-PSScriptBuilderCollector -Type Enum -CollectionKey "ENUMS" `
            -IncludePath "src/Enums" -IncludeFile "*.ps1"

        Creates an enum collector with explicit file pattern filtering.
    .EXAMPLE
        $collector = New-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN" `
            -IncludePath "src/Classes" -ExcludePath "src/Classes/Legacy"

        Creates a class collector that includes src/Classes but excludes the Legacy subdirectory.
    .NOTES
        Collectors are designed to be used in two ways:
        1. Standalone: Create, call Collect(), inspect results directly
        2. Build Integration: Create and add to ContentCollector for build operations

        Path validation is performed with warnings but does not prevent collector creation,
        allowing flexibility for dynamic path scenarios.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderCollectorBase])]
    param(
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

    try {
        $keyInfo = if ($CollectionKey) { "with key '$CollectionKey'" } else { "with default key" }
        Write-Verbose "Creating $Type collector $keyInfo..."

        # Validate paths (warning only, doesn't prevent creation)
        # Use GetProjectRootedPath() so relative paths are resolved against $Global:PSScriptBuilderProjectRoot,
        # consistent with how CollectorBase.GetFilesToProcess() resolves them at collection time.
        if ($IncludePath) {
            foreach ($path in $IncludePath) {
                $resolvedPath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($path)

                if (-not (Test-Path -Path $resolvedPath -PathType Container)) {
                    Write-Warning "IncludePath does not exist: $path"
                }
            }
        }

        # Validate IncludeFile paths (only if they are specific files, not patterns)
        # This allows users to get warnings for typos in specific file names while still allowing patterns that 
        # may not match anything at the time of collector creation. 
        # For example, if someone specifies -IncludeFile "src/Classes/MyClass.ps1" but the file doesn't exist yet, 
        # they will get a warning. But if they specify -IncludeFile "*.ps1", they won't get a warning even if 
        # there are no .ps1 files at the moment, which is expected behavior for a pattern. 
        # This strikes a balance between helpful validation and flexibility for dynamic scenarios.
        if ($IncludeFile) {
            foreach ($file in $IncludeFile) {
                # Only warn if it's a specific file (not a pattern)
                if (-not ($file -match '[*?]')) {
                    $resolvedFile = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($file)

                    if (-not (Test-Path -Path $resolvedFile -PathType Leaf)) {
                        Write-Warning "IncludeFile does not exist: $file"
                    }
                }
            }
        }

        # Map collector types to their corresponding classes
        $collectorTypeMap = @{
            "Using"    = [PSScriptBuilderUsingCollector]
            "Enum"     = [PSScriptBuilderEnumCollector]
            "Class"    = [PSScriptBuilderClassCollector]
            "Function" = [PSScriptBuilderFunctionCollector]
            "File"     = [PSScriptBuilderFileCollector]
        }

        $collectorType = $collectorTypeMap[$Type]

        # Create collector instance with or without custom key
        if ($CollectionKey) {
            $collector = $collectorType::new($CollectionKey)
        }
        else {
            $collector = $collectorType::new()
        }

        # Set filter properties if provided
        if ($IncludePath) {
            $collector.IncludePaths = $IncludePath
            Write-Verbose "  IncludePaths: $($IncludePath -join ', ')"
        }

        if ($IncludeFile) {
            $collector.IncludeFiles = $IncludeFile
            Write-Verbose "  IncludeFiles: $($IncludeFile -join ', ')"
        }

        if ($ExcludePath) {
            $collector.ExcludePaths = $ExcludePath
            Write-Verbose "  ExcludePaths: $($ExcludePath -join ', ')"
        }

        if ($ExcludeFile) {
            $collector.ExcludeFiles = $ExcludeFile
            Write-Verbose "  ExcludeFiles: $($ExcludeFile -join ', ')"
        }

        if ($FileExtension) {
            $collector.FileExtensions = $FileExtension
            Write-Verbose "  FileExtensions: $($FileExtension -join ', ')"
        }

        if ($NoRecurse) {
            $collector.Recurse = $false
            Write-Verbose "  Recurse: false"
        }

        $format  = "Collector {0} with key '{1}' created successfully"
        $message = $format -f $collector.CollectorType, $collector.CollectionKey
        Write-Verbose $message

        return $collector
    }
    catch {
        $message = "Failed to create collector. Error: $($_.Exception.Message)"
        throw [Exception]::new($message, $_.Exception)
    }
}
#endregion Cmdlet New-PSScriptBuilderCollector

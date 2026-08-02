using namespace System.Collections.Generic
using namespace System.IO

#region Class PSScriptBuilderEnumCollector
<#
.SYNOPSIS
    Collector for enum definitions from PowerShell files.
.DESCRIPTION
    The PSScriptBuilderEnumCollector scans PowerShell files for enum definitions and aggregates them.
    Enum definitions are automatically deduplicated by name and sorted alphabetically for consistent output.
#>
class PSScriptBuilderEnumCollector : PSScriptBuilderCollectorBase {
    #region Properties
    <#
    .SYNOPSIS
        Collection of unique enum definitions.
    .DESCRIPTION
        The EnumData property holds a deduplicated collection of enum definitions found across all processed 
        files.
        Uses enum name as key to ensure uniqueness, storing PSScriptBuilderEnumData objects containing name, 
        source code, and source file.
    #>
    [Dictionary[string, PSScriptBuilderEnumData]] $EnumData
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderEnumCollector with default collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderEnumCollector with the default collection key "EnumData".
    #>
    PSScriptBuilderEnumCollector() : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::EnumCollector
        $this.CollectionKey = "ENUM_DEFINITIONS"
        $this.EnumData      = [Dictionary[string, PSScriptBuilderEnumData]]::new([StringComparer]::OrdinalIgnoreCase)
    }

    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderEnumCollector with custom collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderEnumCollector with the specified collection key.
    .PARAMETER collectionKey
        The unique identifier for this collector instance.
    #>
    PSScriptBuilderEnumCollector([string] $collectionKey) : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::EnumCollector
        $this.CollectionKey = $collectionKey
        $this.EnumData      = [Dictionary[string, PSScriptBuilderEnumData]]::new([StringComparer]::OrdinalIgnoreCase)
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Resets the collector's state.
    .DESCRIPTION
        Clears all collected enum definitions to prepare for a new collection run.
    #>
    [void] Reset() {
        $this.EnumData.Clear()
    }

    <#
    .SYNOPSIS
        Collects enum definitions from the provided files.
    .DESCRIPTION
        Parses each file using the AstEngine, finds all enum definitions, and stores them
        in a deduplicated collection by enum name. Duplicate enum names will overwrite previous
        definitions with a warning.
    .PARAMETER files
        The files to collect enum definitions from.
    #>
    hidden [void] CollectFromFiles([FileInfo[]] $files) {
        Write-Verbose "Collecting enum definitions from $($files.Count) file(s)..."
        $totalCollected = 0

        foreach ($file in $files) {
            try {
                Write-Verbose "  Parsing: $($file.Name)"

                $parseResult     = [PSScriptBuilderAstEngine]::ParseFile($file.FullName)
                $ast             = $parseResult.Ast
                $enumDefinitions = [PSScriptBuilderAstEngine]::FindEnumDefinitions($ast)

                $newInFile = 0

                foreach ($enumDefinition in $enumDefinitions) {
                    $enumName = $enumDefinition.Name

                    # Guard clause: Check for duplicates before processing
                    if ($this.EnumData.ContainsKey($enumName)) {
                        $format  = "Duplicate enum '{0}' found in file: {1}. An enum with this name was already collected from another file."
                        $message = $format -f $enumName, $file.FullName
                        throw [InvalidOperationException]::new($message)
                    }

                    $sourceCode = [PSScriptBuilderAstEngine]::ExtractSourceCode($enumDefinition)

                    # Create enum data object
                    $enumDataObject = [PSScriptBuilderEnumData]::new(
                        $enumName,
                        $sourceCode,
                        $file.FullName
                    )

                    $this.EnumData[$enumName] = $enumDataObject
                    $newInFile++

                    Write-Verbose "    Enum '$enumName'"
                }

                if ($enumDefinitions.Count -gt 0) {
                    Write-Verbose "    Found $($enumDefinitions.Count) enum definition(s), $newInFile new"
                }

                $totalCollected += $newInFile
            }
            catch {
                $format  = "Failed to collect enum definitions from file: {0}. Error: {1}"
                $message = $format -f $file.FullName, $_.Exception.Message
                throw [Exception]::new($message, $_.Exception)
            }

            $this.ThrowIfParseFailedSilently($parseResult, $newInFile, $file)
        }

        Write-Verbose "Collection complete: $($this.EnumData.Count) unique enum definition(s), $totalCollected new"
    }

    <#
    .SYNOPSIS
        Gets detailed information for a specific enum.
    .DESCRIPTION
        The TryGetComponentDetail method retrieves detailed information (type, name, source file, dependencies)
        for the specified enum if it exists in this collector. Enums have no dependencies, so the Dependencies
        array is always empty.
    .PARAMETER componentName
        The name of the enum to retrieve details for.
    .PARAMETER knownComponents
        A case-insensitive set of all known project component names (not used for enums, which have no dependencies).
    .OUTPUTS
        Returns a PSScriptBuilderBuildComponentDetail object if the enum exists, otherwise null.
    #>
    [PSScriptBuilderBuildComponentDetail] TryGetComponentDetail([string] $componentName, [HashSet[string]] $knownComponents) {
        if (-not $this.EnumData.ContainsKey($componentName)) {
            return $null
        }

        $enumDataObject = $this.EnumData[$componentName]

        # Enums have no dependencies
        $detail = [PSScriptBuilderBuildComponentDetail]::new(
            [PSScriptBuilderCollectorType]::EnumCollector,
            $componentName,
            $enumDataObject.SourceFile,
            @()
        )

        return $detail
    }

    <#
    .SYNOPSIS
        Gets the count of collected enums.
    .DESCRIPTION
        The GetCount method returns the total number of enum definitions collected by this collector.
    .OUTPUTS
        Returns the number of collected enums as an integer.
    #>
    [int] GetCount() {
        return $this.EnumData.Count
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderEnumCollector

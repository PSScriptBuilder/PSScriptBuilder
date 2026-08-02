using namespace System
using namespace System.Collections.Generic
using namespace System.IO

#region Class PSScriptBuilderFunctionCollector
<#
.SYNOPSIS
    Collects function definitions from PowerShell files.
.DESCRIPTION
    The PSScriptBuilderFunctionCollector extracts function definitions and tracks their dependencies.
    It collects the function name, source code, called functions, and type references for each function.
#>
class PSScriptBuilderFunctionCollector : PSScriptBuilderCollectorBase {
    #region Properties
    <#
    .SYNOPSIS
        Collection of function definitions with dependency information.
    .DESCRIPTION
        The FunctionData property holds a collection of function definitions found across all processed files. 
        Each entry contains: Name, SourceCode, CalledFunctions, and TypeReferences.
        Uses function name as key to ensure uniqueness.
    #>
    [Dictionary[string, PSScriptBuilderFunctionData]] $FunctionData
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderFunctionCollector with default collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderFunctionCollector with the default collection key "FunctionData".
    #>
    PSScriptBuilderFunctionCollector() : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::FunctionCollector
        $this.CollectionKey = "FUNCTION_DEFINITIONS"
        $this.FunctionData  = [Dictionary[string, PSScriptBuilderFunctionData]]::new([StringComparer]::OrdinalIgnoreCase)
    }

    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderFunctionCollector with custom collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderFunctionCollector with the specified collection key.
    .PARAMETER collectionKey
        The unique identifier for this collector instance.
    #>
    PSScriptBuilderFunctionCollector([string] $collectionKey) : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::FunctionCollector
        $this.CollectionKey = $collectionKey
        $this.FunctionData  = [Dictionary[string, PSScriptBuilderFunctionData]]::new([StringComparer]::OrdinalIgnoreCase)
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Resets the collector's state.
    .DESCRIPTION
        Clears all collected function definitions to prepare for a new collection run.
    #>
    [void] Reset() {
        $this.FunctionData.Clear()
    }

    <#
    .SYNOPSIS
        Collects function definitions from the provided files.
    .DESCRIPTION
        Parses each file using the AstEngine, finds all function definitions, and extracts their source code, 
        called functions, and type references. Duplicate function names will overwrite previous definitions with a warning.
    .PARAMETER files
        The files to collect function definitions from.
    #>
    hidden [void] CollectFromFiles([FileInfo[]] $files) {
        Write-Verbose "Collecting function definitions from $($files.Count) file(s)..."
        $totalCollected = 0

        foreach ($file in $files) {
            try {
                Write-Verbose "  Parsing: $($file.Name)"

                $parseResult         = [PSScriptBuilderAstEngine]::ParseFile($file.FullName)
                $ast                 = $parseResult.Ast
                $functionDefinitions = [PSScriptBuilderAstEngine]::FindFunctionDefinitions($ast)

                $newInFile = 0

                foreach ($functionDefinition in $functionDefinitions) {
                    $functionName = $functionDefinition.Name

                    # Guard clause: Check for duplicates before processing
                    if ($this.FunctionData.ContainsKey($functionName)) {
                        $format  = "Duplicate function '{0}' found in file: {1}. A function with this name was already collected from another file."
                        $message = $format -f $functionName, $file.FullName
                        throw [InvalidOperationException]::new($message)
                    }

                    $sourceCode = [PSScriptBuilderAstEngine]::ExtractSourceCode($functionDefinition)

                    # Get all called functions
                    $calledFunctions = [PSScriptBuilderAstEngine]::GetFunctionCalls($functionDefinition)

                    # Get all type references
                    $typeReferences = [PSScriptBuilderAstEngine]::GetTypeReferences($functionDefinition)

                    # Filter out built-in types
                    $filteredReferences = @($typeReferences | Where-Object { 
                        -not [PSScriptBuilderAstEngine]::IsBuiltInType($_) 
                    })

                    # Create function data object
                    $functionDataObject = [PSScriptBuilderFunctionData]::new(
                        $functionName,
                        $sourceCode,
                        $file.FullName,
                        $calledFunctions,
                        $filteredReferences
                    )

                    $this.FunctionData[$functionName] = $functionDataObject
                    $newInFile++

                    Write-Verbose "    Function '$functionName': CalledFunctions=$($calledFunctions.Count), TypeReferences=$($filteredReferences.Count)"
                }

                if ($functionDefinitions.Count -gt 0) {
                    Write-Verbose "    Found $($functionDefinitions.Count) function definition(s), $newInFile new"
                }

                $totalCollected += $newInFile
            }
            catch {
                $format  = "Failed to collect function definitions from file: {0}. Error: {1}"
                $message = $format -f $file.FullName, $_.Exception.Message
                throw [Exception]::new($message, $_.Exception)
            }

            $this.ThrowIfParseFailedSilently($parseResult, $newInFile, $file)
        }

        Write-Verbose "Collection complete: $($this.FunctionData.Count) unique function definition(s), $totalCollected new"
    }

    <#
    .SYNOPSIS
        Gets detailed information for a specific function.
    .DESCRIPTION
        The TryGetComponentDetail method retrieves detailed information (type, name, source file, dependencies)
        for the specified function if it exists in this collector. Dependencies include called functions and
        all type references.
    .PARAMETER componentName
        The name of the function to retrieve details for.
    .PARAMETER knownComponents
        A case-insensitive set of all known project component names. Used to filter dependencies
        to project-internal components only.
    .OUTPUTS
        Returns a PSScriptBuilderBuildComponentDetail object if the function exists, otherwise null.
    #>
    [PSScriptBuilderBuildComponentDetail] TryGetComponentDetail([string] $componentName, [HashSet[string]] $knownComponents) {
        if (-not $this.FunctionData.ContainsKey($componentName)) {
            return $null
        }

        $functionDataObject = $this.FunctionData[$componentName]

        # Collect dependencies: CalledFunctions + TypeReferences, filtered to known project components
        $dependencies = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($calledFunction in $functionDataObject.CalledFunctions) {
            if ($knownComponents.Contains($calledFunction) -and $calledFunction -ne $componentName) {
                $dependencies.Add($calledFunction) | Out-Null
            }
        }

        foreach ($typeReference in $functionDataObject.TypeReferences) {
            if ($knownComponents.Contains($typeReference) -and $typeReference -ne $componentName) {
                $dependencies.Add($typeReference) | Out-Null
            }
        }

        $detail = [PSScriptBuilderBuildComponentDetail]::new(
            [PSScriptBuilderCollectorType]::FunctionCollector,
            $componentName,
            $functionDataObject.SourceFile,
            [string[]] @($dependencies)
        )

        return $detail
    }

    <#
    .SYNOPSIS
        Gets the count of collected functions.
    .DESCRIPTION
        The GetCount method returns the total number of function definitions collected by this collector.
    .OUTPUTS
        Returns the number of collected functions as an integer.
    #>
    [int] GetCount() {
        return $this.FunctionData.Count
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderFunctionCollector

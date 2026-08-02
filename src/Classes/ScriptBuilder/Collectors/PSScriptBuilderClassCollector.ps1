using namespace System
using namespace System.Collections.Generic
using namespace System.IO

#region Class PSScriptBuilderClassCollector
<#
.SYNOPSIS
    Collects class definitions from PowerShell files.
.DESCRIPTION
    The PSScriptBuilderClassCollector extracts class definitions and tracks their dependencies.
    It collects the class name, source code, base class, and type references for each class.
#>
class PSScriptBuilderClassCollector : PSScriptBuilderCollectorBase {
    #region Properties
    <#
    .SYNOPSIS
        Collection of collected class data with dependency information.
    .DESCRIPTION
        The ClassData property holds collected class data found across all processed files.
        Each entry contains: Name, SourceCode, BaseClass, TypeReferences, StaticInitializerReferences, and CalledFunctions.
        Uses class name as key to ensure uniqueness.
    #>
    [Dictionary[string, PSScriptBuilderClassData]] $ClassData
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderClassCollector with default collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderClassCollector with the default collection key "ClassDefinitions".
    #>
    PSScriptBuilderClassCollector() : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::ClassCollector
        $this.CollectionKey = "CLASS_DEFINITIONS"
        $this.ClassData     = [Dictionary[string, PSScriptBuilderClassData]]::new([StringComparer]::OrdinalIgnoreCase)
    }

    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderClassCollector with custom collection key.
    .DESCRIPTION
        Creates a new PSScriptBuilderClassCollector with the specified collection key.
    .PARAMETER collectionKey
        The unique identifier for this collector instance.
    #>
    PSScriptBuilderClassCollector([string] $collectionKey) : base() {
        $this.CollectorType = [PSScriptBuilderCollectorType]::ClassCollector
        $this.CollectionKey = $collectionKey
        $this.ClassData     = [Dictionary[string, PSScriptBuilderClassData]]::new([StringComparer]::OrdinalIgnoreCase)
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Resets the collector's state.
    .DESCRIPTION
        Clears all collected class definitions to prepare for a new collection run.
    #>
    [void] Reset() {
        $this.ClassData.Clear()
    }

    <#
    .SYNOPSIS
        Collects class definitions from the provided files.
    .DESCRIPTION
        Parses each file using the AstEngine, finds all class definitions, and extracts their source code, base 
        class, and type references. Duplicate class names will overwrite previous definitions with a warning.
    .PARAMETER files
        The files to collect class definitions from.
    #>
    hidden [void] CollectFromFiles([FileInfo[]] $files) {
        Write-Verbose "Collecting class definitions from $($files.Count) file(s)..."
        $totalCollected = 0

        foreach ($file in $files) {
            try {
                Write-Verbose "  Parsing: $($file.Name)"

                $parseResult      = [PSScriptBuilderAstEngine]::ParseFile($file.FullName)
                $ast              = $parseResult.Ast
                $classDefinitions = [PSScriptBuilderAstEngine]::FindClassDefinitions($ast)

                $newInFile = 0

                foreach ($classDefinition in $classDefinitions) {
                    $className = $classDefinition.Name

                    # Guard clause: Check for duplicates before processing
                    if ($this.ClassData.ContainsKey($className)) {
                        $format  = "Duplicate class '{0}' found in file: {1}. A class with this name was already collected from another file."
                        $message = $format -f $className, $file.FullName
                        throw [InvalidOperationException]::new($message)
                    }

                    $sourceCode = [PSScriptBuilderAstEngine]::ExtractSourceCode($classDefinition)

                    # Get base class (single inheritance in PowerShell)
                    $baseClasses = [PSScriptBuilderAstEngine]::GetBaseClasses($classDefinition)
                    $baseClass = if ($baseClasses.Count -gt 0) { $baseClasses[0] } else { $null }

                    # Get all type references (excludes static property initializer expressions)
                    $typeReferences = [PSScriptBuilderAstEngine]::GetTypeReferences($classDefinition)

                    # Filter out built-in types
                    $filteredReferences = @($typeReferences | Where-Object { 
                        -not [PSScriptBuilderAstEngine]::IsBuiltInType($_) 
                    })

                    # Get type references from static property initializer expressions
                    $staticInitReferences = [PSScriptBuilderAstEngine]::GetStaticInitializerTypeReferences($classDefinition)

                    # Filter out built-in types
                    $filteredStaticInitReferences = @($staticInitReferences | Where-Object {
                        -not [PSScriptBuilderAstEngine]::IsBuiltInType($_)
                    })

                    # Get all function/command calls (filtering against defined names happens in GraphBuilder)
                    $calledFunctions = [PSScriptBuilderAstEngine]::GetFunctionCalls($classDefinition)

                    # Create class data object
                    $classDataObject = [PSScriptBuilderClassData]::new(
                        $className,
                        $sourceCode,
                        $file.FullName,
                        $baseClass,
                        $filteredReferences,
                        $filteredStaticInitReferences,
                        $calledFunctions
                    )

                    $this.ClassData[$className] = $classDataObject
                    $newInFile++

                    $baseClassText = if ([string]::IsNullOrEmpty($baseClass)) { "<none>" } else { $baseClass }
                    Write-Verbose "    Class '$className': BaseClass=$baseClassText, TypeReferences=$($filteredReferences.Count), StaticInitRefs=$($filteredStaticInitReferences.Count), CalledFunctions=$($calledFunctions.Count)"
                }

                if ($classDefinitions.Count -gt 0) {
                    Write-Verbose "    Found $($classDefinitions.Count) class definition(s), $newInFile new"
                }

                $totalCollected += $newInFile
            }
            catch {
                $format  = "Failed to collect class definitions from file: {0}. Error: {1}"
                $message = $format -f $file.FullName, $_.Exception.Message
                throw [Exception]::new($message, $_.Exception)
            }

            $this.ThrowIfParseFailedSilently($parseResult, $newInFile, $file)
        }

        Write-Verbose "Collection complete: $($this.ClassData.Count) unique class definition(s), $totalCollected new"
    }

    <#
    .SYNOPSIS
        Gets detailed information for a specific class.
    .DESCRIPTION
        The TryGetComponentDetail method retrieves detailed information (type, name, source file, dependencies)
        for the specified class if it exists in this collector. Dependencies include the base class and all
        type references.
    .PARAMETER componentName
        The name of the class to retrieve details for.
    .PARAMETER knownComponents
        A case-insensitive set of all known project component names. Used to filter dependencies
        to project-internal components only.
    .OUTPUTS
        Returns a PSScriptBuilderBuildComponentDetail object if the class exists, otherwise null.
    #>
    [PSScriptBuilderBuildComponentDetail] TryGetComponentDetail([string] $componentName, [HashSet[string]] $knownComponents) {
        if (-not $this.ClassData.ContainsKey($componentName)) {
            return $null
        }

        $classDataObject = $this.ClassData[$componentName]

        # Collect dependencies: BaseClass + TypeReferences, filtered to known project components
        $dependencies = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        if (-not [string]::IsNullOrWhiteSpace($classDataObject.BaseClass)) {
            if ($knownComponents.Contains($classDataObject.BaseClass) -and $classDataObject.BaseClass -ne $componentName) {
                $dependencies.Add($classDataObject.BaseClass) | Out-Null
            }
        }

        foreach ($typeRef in $classDataObject.TypeReferences) {
            if ($knownComponents.Contains($typeRef) -and $typeRef -ne $componentName) {
                $dependencies.Add($typeRef) | Out-Null
            }
        }

        $detail = [PSScriptBuilderBuildComponentDetail]::new(
            [PSScriptBuilderCollectorType]::ClassCollector,
            $componentName,
            $classDataObject.SourceFile,
            [string[]] @($dependencies)
        )

        return $detail
    }

    <#
    .SYNOPSIS
        Gets the count of collected classes.
    .DESCRIPTION
        The GetCount method returns the total number of class definitions collected by this collector.
    .OUTPUTS
        Returns the number of collected classes as an integer.
    #>
    [int] GetCount() {
        return $this.ClassData.Count
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderClassCollector

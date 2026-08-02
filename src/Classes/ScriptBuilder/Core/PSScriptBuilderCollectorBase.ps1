using namespace System
using namespace System.Collections.Generic
using namespace System.IO

#region Class PSScriptBuilderCollectorBase
<#
.SYNOPSIS
    Abstract base class for all collectors.
.DESCRIPTION
    The PSScriptBuilderCollectorBase class provides the foundation for implementing specific collectors
    (ClassCollector, FunctionCollector, etc.). Each collector extracts specific PowerShell AST elements.
#>
class PSScriptBuilderCollectorBase {
    #region Properties
    <#
    .SYNOPSIS
        Type of the collector.
    .DESCRIPTION
        The CollectorType property defines the type of collector (UsingCollector, EnumCollector, etc.).
        This is used for logical operations like sorting and determining execution order.
        The type is static for each collector class.
    #>
    [PSScriptBuilderCollectorType] $CollectorType

    <#
    .SYNOPSIS
        Unique key identifying the collector.
    .DESCRIPTION
        The CollectionKey property holds a unique string that identifies the collector. This key is used 
        to reference the collector within collections and results and is the name of the placeholder used 
        in templates. This key is customizable by the user.
    #>
    [string] $CollectionKey

    <#
    .SYNOPSIS
        Paths to include during collection.
    .DESCRIPTION
        The IncludePaths property defines which source file paths should be included during the collection 
        process.
    #>
    [string[]] $IncludePaths

    <#
    .SYNOPSIS
        Paths to exclude during collection.
    .DESCRIPTION
        The ExcludePaths property defines which source file paths should be excluded during the collection 
        process.
    #>
    [string[]] $ExcludePaths

    <#
    .SYNOPSIS
        Files to include during collection.
    .DESCRIPTION
        The IncludeFiles property defines specific source files to include during the collection process.
    #>
    [string[]] $IncludeFiles

    <#
    .SYNOPSIS
        Files to exclude during collection.
    .DESCRIPTION
        The ExcludeFiles property defines file name patterns or exact names to exclude during collection.
        Supports wildcards like *.Tests.ps1 or exact names like Legacy.ps1.
        Works on file names only, not paths. Use ExcludePaths for path-based exclusion.
    .EXAMPLE
        $collector.ExcludeFiles = @("*.Tests.ps1", "Legacy.ps1")
    #>
    [string[]] $ExcludeFiles

    <#
    .SYNOPSIS
        File extensions to include during collection.
    .DESCRIPTION
        The FileExtensions property defines which file extensions should be included during collection.
        Supports multiple extensions for scenarios like collecting from both .ps1 and .psm1 files.
        Default is @(".ps1") for standard PowerShell scripts.
    .EXAMPLE
        $collector.FileExtensions = @(".ps1", ".psm1")
    #>
    [string[]] $FileExtensions = @(".ps1")

    <#
    .SYNOPSIS
        Indicates whether to recurse into subdirectories.
    .DESCRIPTION
        The Recurse property determines if subdirectories should be scanned recursively.
        Default is $true. Only applies to IncludePaths, not to IncludeFiles (which are explicit).
    #>
    [bool] $Recurse = $true
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderCollectorBase.
    .DESCRIPTION
        Creates a new PSScriptBuilderCollectorBase.
    #>
    PSScriptBuilderCollectorBase() {
        if ($this.GetType().Name -eq "PSScriptBuilderCollectorBase") {
            throw [InvalidOperationException]::new("PSScriptBuilderCollectorBase is abstract and cannot be instantiated directly")
        }
    }
    #endregion Constructors

    #region Methods
    #region Public Methods
    <#
    .SYNOPSIS
        Collects components from source files.
    .DESCRIPTION
        The Collect method orchestrates the collection process following the Template Method pattern.
        It resets the collector state, discovers files based on include/exclude rules, then delegates 
        to CollectFromFiles() for the actual collection logic implemented by derived classes.
    #>
    [void] Collect() {
        $this.Reset()
        $filesToProcess = $this.GetFilesToProcess()
        $this.CollectFromFiles($filesToProcess)
    }
    #endregion Public Methods

    #region Helper Methods
    <#
    .SYNOPSIS
        Gets all files to process based on include/exclude rules.
    .DESCRIPTION
        Internal helper method that resolves paths, applies filters, and returns the final list of files.
        Combines IncludePaths (with filters) and IncludeFiles (without filters), then deduplicates.
    #>
    hidden [FileInfo[]] GetFilesToProcess() {
        Write-Verbose "Starting file discovery for collector $($this.CollectorType)..."

        # Validation: At least one include source required
        if (
            (-not $this.IncludePaths -or $this.IncludePaths.Count -eq 0) -and
            (-not $this.IncludeFiles -or $this.IncludeFiles.Count -eq 0)
        ) {
            $message = "At least one of IncludePaths or IncludeFiles must be specified"
            throw [InvalidOperationException]::new($message)
        }

        $allFiles = @()

        # PART 1: Process IncludePaths with all filters
        if ($this.IncludePaths) {
            Write-Verbose "Processing $($this.IncludePaths.Count) include path(s)..."

            foreach ($path in $this.IncludePaths) {
                Write-Verbose "  Scanning path: $path"

                # Resolve to absolute path
                $absolutePath = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($path)

                # Validate path exists
                if (-not (Test-Path $absolutePath)) {
                    $message = "Path not found: {0} (original: {1})" -f $absolutePath, $path
                    throw [IOException]::new($message)
                }

                # Build Get-ChildItem parameters
                $params = @{
                    Path = $absolutePath
                    File = $true
                }

                if ($this.Recurse) {
                    $params.Recurse = $true
                }

                if ($this.ExcludeFiles) {
                    $params.Exclude = $this.ExcludeFiles
                    Write-Verbose "    Excluding file patterns: $($this.ExcludeFiles -join ', ')"
                }

                # Get files
                $files = Get-ChildItem @params
                Write-Verbose "    Found $($files.Count) file(s) matching pattern"

                # Apply FileExtensions filter
                if ($this.FileExtensions) {
                    $beforeCount = $files.Count

                    $files = $files | Where-Object { 
                        $extension  = $_.Extension
                        $isIncluded = $this.FileExtensions -contains $extension

                        if (-not $isIncluded) {
                            Write-Verbose "      Skipping (wrong extension): $($_.Name)"
                        }

                        return $isIncluded
                    }

                    $excludedCount = $beforeCount - $files.Count

                    if ($excludedCount -gt 0) {
                        Write-Verbose "    Filtered out $excludedCount file(s) by extension (keeping only: $($this.FileExtensions -join ', '))"
                    }
                }

                $allFiles += $files
            }

            # Apply ExcludePaths filter
            if ($this.ExcludePaths) {
                Write-Verbose "Applying exclude path filter(s): $($this.ExcludePaths -join ', ')"

                $beforeCount   = $allFiles.Count
                $pathSeparator = [char] [Path]::DirectorySeparatorChar

                $allFiles = $allFiles | Where-Object {
                    $file    = $_
                    $exclude = $false

                    foreach ($excludePath in $this.ExcludePaths) {
                        $absoluteExclude = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($excludePath)

                        if (-not $absoluteExclude.EndsWith($pathSeparator)) {
                            $absoluteExclude += $pathSeparator
                        }

                        if ($file.FullName.StartsWith($absoluteExclude, [StringComparison]::OrdinalIgnoreCase)) {
                            Write-Verbose "  Excluding (path match): $($file.FullName)"
                            $exclude = $true
                            break
                        }
                    }

                    return -not $exclude
                }

                $excludedCount = $beforeCount - $allFiles.Count

                if ($excludedCount -gt 0) {
                    Write-Verbose "Excluded $excludedCount file(s) by path filter"
                }
            }
        }

        # PART 2: Process IncludeFiles without filters (explicit = highest priority)
        if ($this.IncludeFiles) {
            Write-Verbose "Processing $($this.IncludeFiles.Count) explicit include file(s)..."

            foreach ($file in $this.IncludeFiles) {
                Write-Verbose "  Adding explicit file: $file"
                $absoluteFile = [PSScriptBuilderFileSystemHelper]::GetProjectRootedPath($file)

                if (-not (Test-Path $absoluteFile -PathType Leaf)) {
                    $message = "File not found: {0} (original: {1})" -f $absoluteFile, $file
                    throw [FileNotFoundException]::new($message)
                }

                $allFiles += Get-Item $absoluteFile
            }
        }

        # PART 3: Deduplicate by FullName (case-insensitive)
        $beforeDedupe = $allFiles.Count
        $uniqueFiles = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $result = @()

        foreach ($file in $allFiles) {
            # HashSet.Add() returns $true if the item was added (i.e., it was unique), or $false if it was 
            # already present. This allows us to easily filter out duplicates while preserving the first 
            # occurrence. We consider files with the same FullName (case-insensitive) as duplicates, which can 
            # happen if the same file is included via different paths or patterns.
            # For example, "src\Module1\Script.ps1" and ".\Module1\Script.ps1" might resolve to the same file 
            # and should only be included once.
            if ($uniqueFiles.Add($file.FullName)) {
                $result += $file
            }
            else {
                Write-Verbose "  Skipping duplicate: $($file.FullName)"
            }
        }

        $duplicateCount = $beforeDedupe - $result.Count

        if ($duplicateCount -gt 0) {
            Write-Verbose "Removed $duplicateCount duplicate file(s)"
        }

        Write-Verbose "File discovery complete: $($result.Count) file(s) to process"

        return $result
    }
    #endregion Helper Methods

    #region Protected Methods
    <#
    .SYNOPSIS
        Throws if parse errors caused definitions to be silently dropped from the AST.
    .DESCRIPTION
        Checks whether a file produced parse errors but no definitions were collected from it.
        When both conditions are true, the parse errors prevented definitions from appearing
        in the AST, a silent failure that would otherwise go unnoticed.

        When definitions were collected despite parse errors, the errors are considered harmless
        (e.g. unresolved type references between files) and no exception is thrown.

        When no parse errors occurred and no definitions were found, the file simply contains
        no definitions of the expected type, which is valid.
    .PARAMETER parseResult
        The PSScriptBuilderParseResult from parsing the file.
    .PARAMETER definitionCount
        The number of definitions collected from the AST of this file.
    .PARAMETER file
        The file that was parsed. Used to provide context in the exception message.
    #>
    hidden [void] ThrowIfParseFailedSilently([PSScriptBuilderParseResult] $parseResult, [int] $definitionCount, [FileInfo] $file) {
        if ($parseResult.ParseErrors.Count -eq 0) { return }
        if ($definitionCount -gt 0)               { return }

        # Cross-file reference errors are never structural - delegate to AstEngine to filter them.
        $structuralErrors = [PSScriptBuilderAstEngine]::GetStructuralParseErrors($parseResult.ParseErrors)

        if ($structuralErrors.Count -eq 0) { return }

        $newLine    = [Environment]::NewLine
        $errorCount = $structuralErrors.Count
        $lineFormat = "  Line {0}, Col {1} [{2}]: {3}"
        $errorLines = @()

        foreach ($parseError in $structuralErrors) {
            $line = $lineFormat -f $parseError.Extent.StartLineNumber, $parseError.Extent.StartColumnNumber, $parseError.ErrorId, $parseError.Message
            $errorLines += $line
        }

        $format  = "File '{0}' has {1} parse error(s) that prevented definitions from being collected:{2}{3}"
        $message = $format -f $file.Name, $errorCount, $newLine, ($errorLines -join $newLine)

        throw [InvalidOperationException]::new($message)
    }
    #endregion Protected Methods

    #region Abstract Methods
    <#
    .SYNOPSIS
        Resets the collector's state.
    .DESCRIPTION
        The Reset method clears all collected data to prepare for a new collection run.
        This method must be implemented by derived classes to clear their specific collection properties.
    #>
    [void] Reset() {
        throw [NotImplementedException]::new("Reset() must be implemented by derived class")
    }

    <#
    .SYNOPSIS
        Collects components from the provided files.
    .DESCRIPTION
        The CollectFromFiles method is responsible for collecting specific components from the provided files.
        This method must be implemented by derived classes.
    .PARAMETER files
        Array of FileInfo objects representing the files to process.
    #>
    hidden [void] CollectFromFiles([FileInfo[]] $files) {
        throw [NotImplementedException]::new("CollectFromFiles() must be implemented by derived class")
    }

    <#
    .SYNOPSIS
        Gets detailed information for a specific component.
    .DESCRIPTION
        The TryGetComponentDetail method retrieves detailed information (type, name, source file, dependencies)
        for the specified component if it exists in this collector. Returns null if the component is not found
        or if this collector type does not provide component details (e.g., UsingCollector, FileCollector).
    .PARAMETER componentName
        The name of the component to retrieve details for.
    .PARAMETER knownComponents
        A case-insensitive set of all known project component names. Used to filter dependencies
        to project-internal components only.
    .OUTPUTS
        Returns a PSScriptBuilderBuildComponentDetail object if the component exists, otherwise null.
    #>
    [PSScriptBuilderBuildComponentDetail] TryGetComponentDetail([string] $componentName, [HashSet[string]] $knownComponents) {
        throw [NotImplementedException]::new("TryGetComponentDetail() must be implemented by derived class")
    }

    <#
    .SYNOPSIS
        Gets the count of collected components.
    .DESCRIPTION
        The GetCount method returns the total number of components collected by this collector.
        This method must be implemented by derived classes to return their specific collection count.
    .OUTPUTS
        Returns the number of collected components as an integer.
    #>
    [int] GetCount() {
        throw [NotImplementedException]::new("GetCount() must be implemented by derived class")
    }
    #endregion Abstract Methods
    #endregion Methods
}
#endregion Class PSScriptBuilderCollectorBase

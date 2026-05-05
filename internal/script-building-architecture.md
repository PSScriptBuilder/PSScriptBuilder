# Script Building Architecture - PSScriptBuilder Core

## Inhaltsverzeichnis

1. [Problemstellung](#problemstellung)
2. [Lösung: Collector Pattern](#lösung-collector-pattern)
3. [Architektur-Übersicht](#architektur-übersicht)
4. [Komponenten-Details](#komponenten-details)
5. [AST Analysis Engine](#ast-analysis-engine)
6. [Dependency Resolution](#dependency-resolution)
7. [Template System](#template-system)
8. [ScriptBuilder Orchestrator](#scriptbuilder-orchestrator)
9. [CLI Integration](#cli-integration)
10. [Workflows](#workflows)
11. [Error Handling](#error-handling)
12. [Best Practices](#best-practices)

---

## Problemstellung

### Die Herausforderung

Große PowerShell-Projekte bestehen typischerweise aus **mehreren PS1-Dateien**, die in verschiedenen Verzeichnissen organisiert sind:

```
src/
├── Enums/
│   ├── PSScriptBuilderLogType.ps1
│   └── PSScriptBuilderErrorType.ps1
├── Classes/
│   ├── Common/
│   │   ├── PSScriptBuilderBase.ps1
│   │   └── PSScriptBuilderLogger.ps1
│   ├── Configuration/
│   │   └── PSScriptBuilderConfiguration.ps1
│   └─ VersionManagement/
│       └── PSScriptBuilderVersionDataManager.ps1
└── Functions/
    ├── Public/
    │   ├── Update-PSScriptBuilderVersion.ps1
    │   └── Get-PSScriptBuilderInfo.ps1
    └── Private/
        └── Get-PSScriptBuilderProjectRoot.ps1
```

### Anforderungen

| Anforderung | Priorität | Grund |
|-------------|-----------|-------|
| **Zu einer Datei konsolidieren** | 🔴 Kritisch | Distribution als Modul (PSM1) |
| **Abhängigkeiten auflösen** | 🔴 Kritisch | Richtige Ladereihenfolge |
| **Zirkuläre Abhängigkeiten erkennen** | 🔴 Kritisch | Verhindert Fehler |
| **Granulare Kontrolle** | 🟠 Hoch | CLI-User steuert Prozess |
| **Komponentenanalyse** | 🟠 Hoch | Debugging, Dokumentation |
| **Erweiterbar** | 🟡 Mittel | Neue Komponententypen |
| **Performant** | 🟡 Mittel | Large Codebases |

### Naiver Ansatz (Problematisch)

```powershell
# ❌ Naiv: Alle Dateien einfach concatenate
Get-ChildItem "src" -Recurse -Filter "*.ps1" | 
    Get-Content | 
    Add-Content "consolidated.ps1"

# Probleme:
# 1. Classes vor ihren Dependencies?
# 2. Zirkuläre Abhängigkeiten?
# 3. Duplizierte using statements?
# 4. Private Functions in Public API?
```

**Lösung:** **Collector Pattern + Dependency Analysis**

---

## Lösung: Collector Pattern

### Core Konzept

Ein **Collector** ist eine spezialisierte Komponente, die:
1. PowerShell AST durchsucht
2. Spezifische Komponenten (Classes, Enums, Using, Functions) extrahiert
3. Metadaten (Dependencies, Scope) sammelt
4. Strukturierte Daten liefert

### Collector Hierarchy

```
Abstract Base Class: CollectorBase
├─ CollectionKey          # Eindeutiger Schlüssel (z.B. "CLASSES_DOMAIN")
├─ IncludePaths           # Zu durchsuchende Pfade
├─ ExcludePaths           # Auszuschließende Pfade
├─ ExcludeFiles           # Auszuschließende Dateien (Glob-Pattern)
│
├─ Collect()              # Sammelt Komponenten (virtual)
├─ GetCollectedData()     # Gibt Ergebnisse zurück (virtual)
├─ GetRenderedOutput()    # Gibt formatierte Ausgabe zurück (virtual)
└─ GetPlaceholder()       # Gibt {{COLLECTION_KEY}} zurück

Konkrete Implementierungen:
├─ UsingCollector : CollectorBase
├─ EnumCollector : CollectorBase
├─ ClassCollector : CollectorBase
└─ FunctionCollector : CollectorBase

Orchestrator (Composite Pattern):
└─ ContentCollector : CollectorBase
   ├─ RegisteredCollectors[]  # Alle hinzugefügten Collectors
   ├─ AddCollector(collector)
   ├─ Collect()               # Ruft Collect() aller Collectors auf
   └─ GetCollectedData()      # Mapping CollectionKey -> Rendered Output
```

---

## Architektur-Übersicht

### Schichtmodell

```
┌────────────────────────────────────────────────────┐
│         PowerShell CLI Cmdlets Layer               │
│  (Invoke-PSScriptBuilderBuild, etc.)               │
└────────────────────┬─────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────┐
│       Collector Orchestration Layer               │
│  - Manages collector lifecycle                    │
│  - Coordinates multi-pass analysis                │
└────────────────────┬─────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────┐
│       Collector Implementations                   │
│  ┌─────────────┐ ┌─────────────┐                │
│  │ Using       │ │ Class       │  ...           │
│  │ Collector   │ │ Collector   │                │
│  └─────────────┘ └─────────────┘                │
└────────────────────┬─────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────┐
│       AST Analysis Engine                        │
│  - Parse PowerShell files                        │
│  - Extract AST nodes                             │
│  - Identify dependencies                         │
└────────────────────┬─────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────┐
│     ScriptBuilder (Orchestrator)                 │
│  - Load & validate template                      │
│  - Run collectors in sequence                     │
│  - Analyze & sort dependencies                   │
│  - Replace placeholders                          │
│  - Generate final script                         │
└────────────────────┬─────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────┐
│    Dependency Resolution System                  │
│  ├─ DependencyGraphBuilder                       │
│  ├─ CycleDetector                                │
│  └─ KahnSorter (topological sort)                │
└────────────────────────────────────────────────┘
```

### Datenfluss

```
Input Files
    ↓
[Collectors sammeln Komponenten]
    ├─ Using Statements
    ├─ Enums
    ├─ Classes (mit Dependencies)
    └─ Functions (mit Dependencies)
    ↓
[Dependency Analysis]
    ├─ Build Dependency Graph
    ├─ Detect Cycles
    └─ Topologische Sortierung (Kahn)
    ↓
[Template Processing]
    ├─ Load Template
    ├─ Replace {{PLACEHOLDERS}}
    └─ Merge collected data
    ↓
Output: consolidated.ps1/psm1
```

---

## Komponenten-Details

### 1. CollectorResult Data Structure

```powershell
class CollectorResult {
    <#
    .SYNOPSIS
        Result of a collector execution
    .DESCRIPTION
        Contains all data returned by a single collector run,
        including metadata and status information. Provides type-safe
        access to collector results instead of using generic hashtables.
    #>
    
    # Eindeutiger Schlüssel für diese Collection (z.B. "CLASSES_DOMAIN")
    [string] $CollectionKey
    
    # Template-Platzhalter (z.B. "{{CLASSES_DOMAIN}}")
    [string] $Placeholder
    
    # Fertige Output-String für Template-Ersetzung
    [string] $RenderedOutput
    
    # Strukturierte gesammelte Daten
    [hashtable] $CollectedData
    
    # Anzahl der gesammelten Komponenten
    [int] $ComponentCount
    
    # Fehler die während Collection aufgetreten sind
    [string[]] $Errors
    
    # true wenn erfolgreich, false wenn Fehler
    [bool] $Success
    
    # Wie lange hat Collection gedauert
    [timespan] $ExecutionTime
    
    CollectorResult() {
        $this.Errors = @()
        $this.CollectedData = @{}
        $this.Success = $true
        $this.ComponentCount = 0
    }
    
    [void] AddError([string] $errorMessage) {
        $this.Errors += $errorMessage
        $this.Success = $false
    }
}
```

### 2. CollectorCollection Management Class

```powershell
class CollectorCollection {
    <#
    .SYNOPSIS
        Manages a collection of collectors
    .DESCRIPTION
        Handles add, remove, lookup operations with validation.
        Prevents duplicate CollectionKeys and manages lifecycle.
        ContentCollector delegates all collection management to this class.
    #>
    
    # Dictionary für O(1) Lookup nach CollectionKey
    [System.Collections.Generic.Dictionary[string, CollectorBase]] $Collectors
    
    CollectorCollection() {
        $this.Collectors = [System.Collections.Generic.Dictionary[string, CollectorBase]]::new()
    }
    
    <#
    .SYNOPSIS
        Adds a collector to the collection
    .PARAMETER collector
        CollectorBase instance (must have CollectionKey set)
    .THROWS
        InvalidOperationException if CollectionKey not set
        InvalidOperationException if CollectionKey already exists
    #>
    [void] Add([CollectorBase] $collector) {
        if ([string]::IsNullOrEmpty($collector.CollectionKey)) {
            throw [InvalidOperationException]::new("CollectionKey must be set")
        }
        
        if ($this.Collectors.ContainsKey($collector.CollectionKey)) {
            throw [InvalidOperationException]::new(
                "Collector with key '$($collector.CollectionKey)' already exists"
            )
        }
        
        $this.Collectors.Add($collector.CollectionKey, $collector)
    }
    
    <#
    .SYNOPSIS
        Removes a collector by CollectionKey
    #>
    [void] Remove([string] $collectionKey) {
        $this.Collectors.Remove($collectionKey) | Out-Null
    }
    
    <#
    .SYNOPSIS
        Checks if collector with key exists
    #>
    [bool] Exists([string] $collectionKey) {
        return $this.Collectors.ContainsKey($collectionKey)
    }
    
    <#
    .SYNOPSIS
        Gets specific collector by key
    .THROWS
        KeyNotFoundException if not found
    #>
    [CollectorBase] GetCollector([string] $collectionKey) {
        if (-not $this.Exists($collectionKey)) {
            throw [KeyNotFoundException]::new("Collector '$collectionKey' not found")
        }
        return $this.Collectors[$collectionKey]
    }
    
    <#
    .SYNOPSIS
        Gets all registered collectors
    #>
    [CollectorBase[]] GetAll() {
        return $this.Collectors.Values.ToArray()
    }
    
    <#
    .SYNOPSIS
        Gets count of registered collectors
    #>
    [int] GetCount() {
        return $this.Collectors.Count
    }
    
    <#
    .SYNOPSIS
        Clears all collectors
    #>
    [void] Clear() {
        $this.Collectors.Clear()
    }
}
```

### 3. CollectorBase Abstract Base Class

```powershell
class CollectorBase : PSScriptBuilderBase {
    <#
    .SYNOPSIS
        Abstract base class for all component collectors
    .DESCRIPTION
        Defines the contract for collectors via abstract methods.
        PowerShell uses inheritance instead of interfaces.
    #>
    
    # Eindeutiger Schlüssel für Template-Platzhalter (z.B. "CLASSES_DOMAIN")
    # Wird intern zu "{{CLASSES_DOMAIN}}"
    [string] $CollectionKey
    
    # Pfade zum Durchsuchen (Glob-Pattern möglich)
    [string[]] $IncludePaths
    
    # Pfade auszuschließen
    [string[]] $ExcludePaths
    
    # Dateien auszuschließen (Glob-Pattern)
    [string[]] $ExcludeFiles
    
    <#
    .SYNOPSIS
        Collects components (virtual method)
    .DESCRIPTION
        Derived classes implement specific collection logic.
        Uses IncludePaths, ExcludePaths, and ExcludeFiles properties
        set before calling this method.
    #>
    [void] Collect() {
        throw [NotImplementedException]::new("Derived class must implement Collect()"))
    }
    
    <#
    .SYNOPSIS
        Returns collected data in structured format (virtual method)
    .OUTPUTS
        Returns hashtable with component data and metadata
    #>
    [hashtable] GetCollectedData() {
        throw [NotImplementedException]::new("Derived class must implement GetCollectedData()")
    }
    
    <#
    .SYNOPSIS
        Gets collected components as string (ready for template) (virtual method)
    .DESCRIPTION
        Default implementation joins source code with newlines.
        Derived classes can override for custom formatting.
    #>
    [string] GetRenderedOutput() {
        throw [NotImplementedException]::new("Derived class must implement GetRenderedOutput()")
    }
    
    <#
    .SYNOPSIS
        Gets the template placeholder for this collector
    .OUTPUTS
        Returns placeholder in format {{COLLECTION_KEY}}
    #>
    [string] GetPlaceholder() {
        if ([string]::IsNullOrEmpty($this.CollectionKey)) {
            throw [InvalidOperationException]::new("CollectionKey must be set")
        }
        return "{{$($this.CollectionKey)}}"
    }
    
    <#
    .SYNOPSIS
        Executes collection with error handling and metrics
    .DESCRIPTION
        Orchestrates the collection process:
        1. Record start time
        2. Call Collect() method
        3. Capture results and metadata
        4. Record execution time
        5. Handle errors
        Returns CollectorResult with all information
    .OUTPUTS
        Returns CollectorResult object with collected data and metadata
    #>
    [CollectorResult] Execute() {
        $result = [CollectorResult]::new()
        $result.CollectionKey = $this.CollectionKey
        $result.Placeholder = $this.GetPlaceholder()
        
        $startTime = Get-Date
        
        try {
            # Call derived class implementation
            $this.Collect()
            
            # Capture results
            $result.CollectedData = $this.GetCollectedData()
            $result.RenderedOutput = $this.GetRenderedOutput()
            $result.ComponentCount = $result.CollectedData.Count
            $result.Success = $true
        }
        catch {
            $result.AddError($_.Exception.Message)
        }
        finally {
            $result.ExecutionTime = (Get-Date) - $startTime
        }
        
        return $result
    }
    
    <#
    .SYNOPSIS
        Determines if a file matches include/exclude criteria
    #>
    [bool] MatchesFilters([string] $filePath) {
        # Check exclude patterns first
        foreach ($exclude in $this.ExcludeFiles) {
            if ($filePath -like $exclude) {
                return $false
            }
        }
        return $true
    }
}
```

### 2. UsingCollector (Deduplizierung)

```powershell
class UsingCollector : CollectorBase {
    
    [System.Collections.Generic.HashSet[string]] $UsedNamespaces
    [PSScriptBuilderConfiguration] $Config
    
    UsingCollector([PSScriptBuilderConfiguration] $config) {
        $this.Config = $config
        $this.UsedNamespaces = [System.Collections.Generic.HashSet[string]]::new()
    }
    
    <#
    .SYNOPSIS
        Collects all using statements from PowerShell files
    .DESCRIPTION
        - Scans files matching IncludePaths and ExcludePaths
        - Extracts all "using namespace" and "using module" statements
        - Automatically deduplicates
        - Sorts for consistency
        - Handles both namespace and module usings
    #>
    [void] Collect() {
        foreach ($includePath in $this.IncludePaths) {
            $files = Get-ChildItem -Path $includePath -Filter "*.ps1" -Recurse
            
            foreach ($file in $files) {
                try {
                    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                        $file.FullName,
                        [ref]$null,
                        [ref]$null
                    )
                    
                    # Extract using statements
                    $usingStatements = $ast.UsingStatements
                    
                    foreach ($stmt in $usingStatements) {
                        # Format: "using namespace System" or "using module Something"
                        $line = $stmt.ToString()
                        $this.UsedNamespaces.Add($line) | Out-Null
                    }
                }
                catch {
                    # Log parsing error but continue
                }
            }
        }
    }
    
    [hashtable] GetCollectedData() {
        return @{
            Count = $this.UsedNamespaces.Count
            Namespaces = @($this.UsedNamespaces | Sort-Object)
            Raw = $this.UsedNamespaces
        }
    }
    
    [string] GetRenderedOutput() {
        $sorted = $this.UsedNamespaces | Sort-Object
        return ($sorted -join "`n") + "`n"
    }
}
```

### 3. EnumCollector

```powershell
class EnumCollector : CollectorBase {
    
    [hashtable[]] $CollectedEnums
    [PSScriptBuilderConfiguration] $Config
    
    EnumCollector([PSScriptBuilderConfiguration] $config) {
        $this.Config = $config
        $this.CollectedEnums = @()
    }
    
    <#
    .SYNOPSIS
        Collects all enum definitions from PowerShell files
    .DESCRIPTION
        - Extracts enum AST nodes
        - Captures: name, members, scope, file origin
        - Does NOT analyze dependencies (enums are leaf nodes)
    #>
    [void] Collect([string[]] $paths, [hashtable] $filters) {
        foreach ($path in $paths) {
            $files = Get-ChildItem -Path $path -Filter "*.ps1" -Recurse
            
            foreach ($file in $files) {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $file.FullName, [ref]$null, [ref]$null
                )
                
                # Find all enum definitions
                $finder = [PSScriptBuilderAstVisitor]::new([System.Management.Automation.Language.EnumDefinitionAst])
                $ast.Visit($finder)
                
                foreach ($enum in $finder.Results) {
                    $enumData = @{
                        Name       = $enum.Name
                        Members    = $enum.Members | ForEach-Object { $_.Name }
                        SourceFile = $file.FullName
                        SourceCode = $this.ExtractAstText($file.FullName, $enum)
                        Scope      = $this.DetermineScope($enum)
                    }
                    
                    $this.CollectedEnums += $enumData
                }
            }
        }
    }
    
    [hashtable] GetCollectedData() {
        return @{
            Count = $this.CollectedEnums.Count
            Enums = $this.CollectedEnums
        }
    }
    
    [string] GetRenderedOutput() {
        return ($this.CollectedEnums | ForEach-Object { $_.SourceCode }) -join "`n`n"
    }
}
```

### 4. ClassCollector (mit Dependency-Tracking)

```powershell
class ClassCollector : CollectorBase {
    
    [hashtable[]] $CollectedClasses
    [hashtable] $DependencyMap              # Class -> Dependencies
    [PSScriptBuilderConfiguration] $Config
    
    ClassCollector([PSScriptBuilderConfiguration] $config) {
        $this.Config = $config
        $this.CollectedClasses = @()
        $this.DependencyMap = @{}
    }
    
    <#
    .SYNOPSIS
        Collects all class definitions and analyzes dependencies
    .DESCRIPTION
        - Extracts class AST nodes
        - Analyzes base classes: class Admin : User { }
        - Analyzes property/parameter types: [User] $user
        - Analyzes method return types: [User] GetUser()
        - Builds complete dependency graph
    #>
    [void] Collect([string[]] $paths, [hashtable] $filters) {
        foreach ($path in $paths) {
            $files = Get-ChildItem -Path $path -Filter "*.ps1" -Recurse
            
            foreach ($file in $files) {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $file.FullName, [ref]$null, [ref]$null
                )
                
                $finder = [PSScriptBuilderAstVisitor]::new([System.Management.Automation.Language.TypeDefinitionAst])
                $ast.Visit($finder)
                
                foreach ($class in $finder.Results) {
                    if ($class.IsClass -eq $false) { continue }  # Skip if not a class
                    
                    $classData = @{
                        Name            = $class.Name
                        BaseClasses     = @()
                        Dependencies    = @()
                        Members         = @()
                        SourceFile      = $file.FullName
                        SourceCode      = $this.ExtractAstText($file.FullName, $class)
                        Scope           = $this.DetermineScope($class)
                    }
                    
                    # Analyze base class
                    if ($class.BaseTypes) {
                        foreach ($baseType in $class.BaseTypes) {
                            $baseClassName = $baseType.TypeName.Name
                            $classData.BaseClasses += $baseClassName
                            $classData.Dependencies += $baseClassName
                        }
                    }
                    
                    # Analyze properties and methods for type dependencies
                    $this.AnalyzeMemberDependencies($class, $classData)
                    
                    $this.CollectedClasses += $classData
                    $this.DependencyMap[$class.Name] = $classData.Dependencies
                }
            }
        }
    }
    
    [void] AnalyzeMemberDependencies([object] $class, [hashtable] $classData) {
        # Scan properties for type references
        foreach ($member in $class.Members) {
            # Extract type from property definitions
            if ($member.Attributes) {
                foreach ($attr in $member.Attributes) {
                    $typeName = $attr.TypeName
                    if ($typeName -and -not $this.IsBuiltinType($typeName)) {
                        $classData.Dependencies += $typeName
                    }
                }
            }
        }
    }
    
    [hashtable] GetCollectedData() {
        return @{
            Count         = $this.CollectedClasses.Count
            Classes       = $this.CollectedClasses
            Dependencies  = $this.DependencyMap
        }
    }
    
    [string] GetRenderedOutput() {
        return ($this.CollectedClasses | ForEach-Object { $_.SourceCode }) -join "`n`n"
    }
}
```

### 6. ContentCollector (Composite Pattern Orchestrator)

```powershell
class ContentCollector : PSScriptBuilderBase {
    <#
    .SYNOPSIS
        Orchestrates multiple collectors using Composite Pattern
    .DESCRIPTION
        ContentCollector is NOT a collector itself, but an orchestrator.
        It manages multiple CollectorBase instances and coordinates their
        execution. This enables flexible component organization and allows
        multiple collectors of the same type with different configurations.
        
        Uses CollectorCollection for lifecycle management and delegation.
    .EXAMPLE
        # Setup domain classes in one region
        $domainClasses = [ClassCollector]::new($config)
        $domainClasses.CollectionKey = "CLASSES_DOMAIN"
        $domainClasses.IncludePaths = @("src/Classes/Domain/**")
        $domainClasses.ExcludePaths = @("src/Classes/Domain/Deprecated/**")
        
        # Setup utility classes in another region
        $utilClasses = [ClassCollector]::new($config)
        $utilClasses.CollectionKey = "CLASSES_UTILS"
        $utilClasses.IncludePaths = @("src/Classes/Utils/**")
        
        # Orchestrate via ContentCollector
        $content = [ContentCollector]::new($config)
        $content.AddCollector($domainClasses)
        $content.AddCollector($utilClasses)
        
        # Single call runs all collectors and returns results
        $results = $content.Execute()
    #>
    
    # Manages collector lifecycle (add, remove, lookup)
    [CollectorCollection] $Collectors
    
    # Results indexed by placeholder for template processing
    [hashtable] $CollectedDataByPlaceholder
    
    # All results from last execution (for reporting, metrics, etc.)
    [CollectorResult[]] $LastExecutionResults
    
    ContentCollector([PSScriptBuilderConfiguration] $config) {
        $this.Collectors = [CollectorCollection]::new()
        $this.CollectedDataByPlaceholder = @{}
        $this.LastExecutionResults = @()
    }
    
    <#
    .SYNOPSIS
        Registers a collector for execution
    .PARAMETER collector
        CollectorBase instance to register (must have CollectionKey set)
    .THROWS
        InvalidOperationException if CollectionKey is not set or duplicate
    #>
    [void] AddCollector([CollectorBase] $collector) {
        $this.Collectors.Add($collector)
        $this.WriteInfo("Registered collector: $($collector.CommandName) [Key: $($collector.CollectionKey)]")
    }
    
    <#
    .SYNOPSIS
        Removes a collector by CollectionKey
    #>
    [void] RemoveCollector([string] $collectionKey) {
        $this.Collectors.Remove($collectionKey)
        $this.WriteInfo("Removed collector with key: $collectionKey")
    }
    
    <#
    .SYNOPSIS
        Checks if collector with key exists
    #>
    [bool] CollectorExists([string] $collectionKey) {
        return $this.Collectors.Exists($collectionKey)
    }
    
    <#
    .SYNOPSIS
        Executes all registered collectors
    .DESCRIPTION
        Calls Execute() on each registered collector in sequence.
        
        Execution flow per collector:
        1. Record start time
        2. Call Collect() method
        3. Capture rendered output by placeholder
        4. Record metrics (ComponentCount, ExecutionTime)
        5. Handle errors (continues with next collector)
        
        Results are stored by placeholder for template processing.
    .OUTPUTS
        Returns array of CollectorResult objects with execution details
    #>
    [CollectorResult[]] Execute() {
        $this.WriteInfo("=== Starting Content Collection ===")
        $this.WriteInfo("Running $($this.Collectors.GetCount()) collector(s)...")
        
        $results = @()
        
        foreach ($collector in $this.Collectors.GetAll()) {
            $this.WriteInfo("  Executing: $($collector.CommandName)")
            
            # Execute collector (returns result with metrics)
            $result = $collector.Execute()
            $results += $result
            
            if ($result.Success) {
                $this.CollectedDataByPlaceholder[$result.Placeholder] = $result.RenderedOutput
                $this.WriteInfo("  ✓ Success - Collected $($result.ComponentCount) component(s) in $($result.ExecutionTime.TotalMilliseconds)ms")
            }
            else {
                $this.WriteError("  ✗ Failed: $($result.Errors -join '; ')")
            }
        }
        
        $this.LastExecutionResults = $results
        
        $successCount = ($results | Where-Object { $_.Success }).Count
        $this.WriteInfo("Collection complete: $successCount/$($results.Count) successful")
        
        return $results
    }
    
    <#
    .SYNOPSIS
        Returns collected data indexed by placeholder
    .DESCRIPTION
        This is what ScriptBuilder uses to fill template placeholders.
    .OUTPUTS
        Returns hashtable with placeholder -> content mapping
        Example: @{
            "{{CLASSES_DOMAIN}}" = "class User { ... }"
            "{{CLASSES_UTILS}}" = "class Logger { ... }"
        }
    #>
    [hashtable] GetCollectedData() {
        return $this.CollectedDataByPlaceholder
    }
    
    <#
    .SYNOPSIS
        Gets execution results from last Execute() call
    .OUTPUTS
        Returns array of CollectorResult objects with metrics
    #>
    [CollectorResult[]] GetLastResults() {
        return $this.LastExecutionResults
    }
}
```
    
    [hashtable[]] $CollectedFunctions
    [hashtable] $DependencyMap
    [PSScriptBuilderConfiguration] $Config
    
    FunctionCollector([PSScriptBuilderConfiguration] $config) {
        $this.Config = $config
        $this.CollectedFunctions = @()
        $this.DependencyMap = @{}
    }
    
    <#
    .SYNOPSIS
        Collects all function definitions and analyzes dependencies
    .DESCRIPTION
        - Extracts function AST nodes
        - Analyzes called functions: Get-Item, Write-Host
        - Analyzes type references in parameters
        - Separates Public/Private functions
        - Builds dependency graph
    #>
    [void] Collect([string[]] $paths, [hashtable] $filters) {
        foreach ($path in $paths) {
            $files = Get-ChildItem -Path $path -Filter "*.ps1" -Recurse
            
            foreach ($file in $files) {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $file.FullName, [ref]$null, [ref]$null
                )
                
                $finder = [PSScriptBuilderAstVisitor]::new([System.Management.Automation.Language.FunctionDefinitionAst])
                $ast.Visit($finder)
                
                foreach ($function in $finder.Results) {
                    $funcData = @{
                        Name            = $function.Name
                        Dependencies    = @()
                        Parameters      = @()
                        SourceFile      = $file.FullName
                        SourceCode      = $this.ExtractAstText($file.FullName, $function)
                        Scope           = $this.DetermineScope($function, $file)
                        CalledFunctions = @()
                    }
                    
                    # Analyze called functions
                    $this.AnalyzeCalledFunctions($function, $funcData)
                    
                    # Analyze parameter types
                    $this.AnalyzeParameterTypes($function, $funcData)
                    
                    # Apply filters if specified
                    if ($filters -and -not $this.MatchesFilter($funcData, $filters)) {
                        continue
                    }
                    
                    $this.CollectedFunctions += $funcData
                    $this.DependencyMap[$function.Name] = $funcData.Dependencies
                }
            }
        }
    }
    
    [void] AnalyzeCalledFunctions([object] $function, [hashtable] $funcData) {
        # Find all command invocations within the function
        $visitor = [CommandInvocationVisitor]::new()
        $function.Visit($visitor)
        
        foreach ($command in $visitor.Commands) {
            if (-not $this.IsBuiltinCmdlet($command.Name)) {
                $funcData.CalledFunctions += $command.Name
                $funcData.Dependencies += $command.Name
            }
        }
    }
    
    [hashtable] GetCollectedData() {
        return @{
            Count         = $this.CollectedFunctions.Count
            Functions     = $this.CollectedFunctions
            Dependencies  = $this.DependencyMap
        }
    }
    
    [string] GetRenderedOutput() {
        return ($this.CollectedFunctions | ForEach-Object { $_.SourceCode }) -join "`n`n"
    }
}
```

---

## AST Analysis Engine

### Power der PowerShell AST

```powershell
# PowerShell Parser gibt uns vollständigen AST:
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    "path/to/file.ps1",
    [ref]$null,        # Tokens
    [ref]$null         # Errors
)

# AST Structure:
# ScriptBlockAst
#   ├─ UsingStatements
#   ├─ TypeDefinitionAst (Classes, Enums)
#   ├─ FunctionDefinitionAst
#   └─ Statements
#       └─ CommandInvocationAst
#           └─ Arguments (Pipelines, etc.)
```

### Custom AST Visitor

```powershell
class PSScriptBuilderAstVisitor : System.Management.Automation.Language.AstVisitor {
    [type] $TargetType
    [object[]] $Results
    
    PSScriptBuilderAstVisitor([type] $targetType) {
        $this.TargetType = $targetType
        $this.Results = @()
    }
    
    <#
    .SYNOPSIS
        Generic visitor that collects nodes of specific type
    #>
    [object] Visit([System.Management.Automation.Language.Ast] $ast) {
        if ($ast -is $this.TargetType) {
            $this.Results += $ast
        }
        return $ast.Visit($this)
    }
}
```

### Dependency Extraction aus AST

```powershell
# Beispiel: Class Definition analysieren
class Admin : User {
    [string] $Department
    
    [void] ValidateUser([User] $user) {
        # ...
    }
}

# AST zeigt uns:
# 1. BaseTypes: ["User"]
# 2. Property types: ["string"]
# 3. Parameter types: ["User"]

# Dependencies = alle nicht-builtin Types = ["User"]
```

---

## Dependency Resolution

### Dependency Graph

The graph uses a **natural edge direction**: an edge from `A` to `B` means "A depends on B".

```
Graph-Struktur als Adjacency List (A → B bedeutet: A hängt von B ab):
{
    "ClassA": ["ClassB", "ClassC"],
    "ClassB": ["ClassC"],
    "ClassC": [],
    "FuncX":  ["ClassA"],
    "FuncY":  []
}

Visualisierung (Pfeil = "hängt ab von"):
    FuncY   FuncX
              │
              ↓
    ClassA ←──┘
        │
        ↓
    ClassB   ClassA
        │       │
        └───┬───┘
            ↓
          ClassC
```

**Sort-Ausgabe** (Prerequisites first): `ClassC, ClassB, ClassA, FuncX, FuncY`

Weitere Details zur Kanten-Richtungsentscheidung: [ADR 0004](adr/0004-dependency-graph-edge-direction.md)

### Implementierte Klassen

| Klasse | Aufgabe |
|---|---|
| `PSScriptBuilderDependencyGraph` | Minimale Adjacency List (`Dictionary<string, HashSet<string>>`) |
| `PSScriptBuilderDependencyGraphBuilder` | Baut Graph aus Collectors — ruft `AddEdge(dependent, prerequisite)` |
| `PSScriptBuilderCycleDetector` | DFS mit 3-State-Tracking (Unvisited / InProgress / Visited) |
| `PSScriptBuilderTopologicalSorter` | Kahn's Algorithmus + `[Array]::Reverse()` für Prerequisites-First-Ausgabe |

### Cycle Detection

`PSScriptBuilderCycleDetector` verwendet DFS mit 3-State-Tracking:

- `0` = Unvisited
- `1` = InProgress (aktuell im DFS-Stack)
- `2` = Visited (vollständig verarbeitet)

Ein Knoten mit State `1` der erneut besucht wird = Back-Edge = Zyklus.

`GetCyclePath()` verfolgt zusätzlich den aktuellen Pfad und gibt den konkreten Zykluspfad zurück (z.B. `ClassA → ClassB → ClassA`).

### Topological Sort (Kahn's Algorithm)

1. In-Degree berechnen: Wie viele Kanten zeigen *auf* jeden Knoten?
2. Alle Knoten mit In-Degree 0 in die Queue (haben keine Abhängigkeiten)
3. Kahn-Loop: Knoten aus Queue entnehmen → In-Degree aller Abhängigkeiten (`GetDependencies`) dekrementieren → bei In-Degree 0 in Queue
4. `[Array]::Reverse()` — erzeugt Prerequisites-First-Reihenfolge
5. Wenn `result.Count < totalNodes` → Zyklus (nicht alle Knoten erreichbar)

### Enum Stabilization

Nach dem topologischen Sort werden Enums alphabetisch sortiert und an den Anfang gestellt (`StabilizeEnumsFirst`). Enums haben in PowerShell keine Abhängigkeiten untereinander, daher ist eine stabile alphabetische Reihenfolge deterministisch und reproduzierbar.

---

## Template System

### Template Format

```powershell
# consolidated.ps1.template

<#
.SYNOPSIS
    PSScriptBuilder Module
.DESCRIPTION
    Auto-generated consolidated PowerShell module
.VERSION
    {{VERSION_FULL}}
.BUILD_DATE
    {{BUILD_DATE}}
#>

#region Using Statements
{{USING_STATEMENTS}}
#endregion

#region Enums
{{ENUMS}}
#endregion

#region Classes
{{CLASSES}}
#endregion

#region Functions
{{FUNCTIONS}}
#endregion

#region Module Initialization
# Version info
$PSScriptBuilderVersion = "{{VERSION_FULL}}"
$PSScriptBuilderBuildNumber = "{{BUILD_NUMBER}}"
$PSScriptBuilderBuildDate = "{{BUILD_DATE}}"
$PSScriptBuilderGitCommit = "{{GIT_COMMIT_SHORT}}"
#endregion
```

### Placeholder Resolution

```powershell
class TemplateProcessor {
    [string] $TemplateContent
    [hashtable] $Placeholders
    
    <#
    .SYNOPSIS
        Processes template and replaces all {{PLACEHOLDER}} tokens
    #>
    [string] Process() {
        $result = $this.TemplateContent
        
        foreach ($key in $this.Placeholders.Keys) {
            $placeholder = "{{$key}}"
            $value = $this.Placeholders[$key]
            
            # Escape special regex characters in replacement
            $escapedValue = [regex]::Escape($value)
            
            $result = $result -replace $placeholder, $escapedValue
        }
        
        # Check for unresolved placeholders
        $unresolvedMatches = [regex]::Matches($result, "{{[A-Z_]+}}")
        if ($unresolvedMatches.Count -gt 0) {
            throw [InvalidOperationException]::new(
                "Unresolved placeholders: $($unresolvedMatches.Value -join ', ')"
            )
        }
        
        return $result
    }
}
```

### Design Decision: Dependency-First Template Validation

**Problem:** Cross-dependencies between Classes and Functions break separate placeholders

**Solution:**

**When NO cross-dependencies exist:**
- ✅ Use separate placeholders freely: `{{DATA_CLASSES}}`, `{{SERVICE_CLASSES}}`, `{{FUNCTIONS}}`
- Each group sorted internally by dependencies

**When cross-dependencies exist:**
- ✅ Must use: `{{ORDERED_COMPONENTS}}` (configurable key)
- ❌ Individual component keys forbidden (strict exclusivity)
- Build fails with clear error message if template violates this rule

**Configuration:**
- `orderedComponentsKey` in config (default: "ORDERED_COMPONENTS")
- Can be overridden via cmdlet parameter

**Rationale:** Fail-fast prevents incorrect build output, explicit over implicit

---

## ScriptBuilder Orchestrator

### Design Decision: Granular Architecture (SOLID)

**Previous:** Monolithic orchestrator class with all logic

**Finalized:** 5 separate classes, each with single responsibility

```
PSScriptBuilderOrchestrator (coordinator only)
├→ PSScriptBuilderDependencyGraphBuilder
├→ PSScriptBuilderCycleDetector
├→ PSScriptBuilderTopologicalSorter
└→ PSScriptBuilderTemplateProcessor
```

**Workflow:**
1. ContentCollector.Execute() - Collect all components
2. GraphBuilder.Build() - Build dependency graph
3. CycleDetector.Detect() - Check for circular dependencies
4. Sorter.Sort() - Topological sort (Kahn's algorithm)
5. TemplateProcessor.Process() - Validate template + replace placeholders
6. Write output file

**Rationale:**
- Single Responsibility Principle
- Independently testable
- Clear separation of concerns
- Easier to maintain and extend

**Implementation details:** See `orchestrator-implementation-spec.md` (to be created)

---

## Configuration

### Build Configuration (Minimal)

```json
{
  "build": {
    "outputPath": ".\\build\\Output",
    "templatesPath": ".\\build\\Templates",
    "orderedComponentsKey": "ORDERED_COMPONENTS"
  }
}
```

**New Setting:** `orderedComponentsKey`
- Placeholder name for dependency-ordered components
- Default: `"ORDERED_COMPONENTS"`
- Can be overridden via cmdlet parameter (hybrid approach)

**Rationale:** Minimal config (YAGNI), collectors created via CLI not config

---

## CLI Integration

### Cmdlet Design

```powershell
function New-PSScriptBuilderContentCollector {
    <#
    .SYNOPSIS
        Creates a new ContentCollector instance
    .DESCRIPTION
        Initializes a new ContentCollector for managing multiple collectors
    .EXAMPLE
        $content = New-PSScriptBuilderContentCollector
    #>
    [CmdletBinding()]
    param()
    
    $config = [PSScriptBuilderConfiguration]::Load()
    return [ContentCollector]::new($config)
}

function Add-PSScriptBuilderCollector {
    <#
    .SYNOPSIS
        Adds a collector to a ContentCollector
    .PARAMETER ContentCollector
        The ContentCollector instance to add to
    .PARAMETER CollectorType
        Type of collector: Using, Enum, Class, Function
    .PARAMETER CollectionKey
        Unique key for this collector (without {{}})
    .PARAMETER IncludePaths
        Paths to search (glob pattern supported)
    .PARAMETER ExcludePaths
        Paths to exclude
    .PARAMETER ExcludeFiles
        File patterns to exclude
    .EXAMPLE
        Add-PSScriptBuilderCollector -ContentCollector $content `
            -CollectorType Class `
            -CollectionKey "CLASSES_DOMAIN" `
            -IncludePaths "src/Classes/Domain/**"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Using", "Enum", "Class", "Function")]
        [string] $CollectorType,
        
        [Parameter(Mandatory = $true)]
        [string] $CollectionKey,
        
        [Parameter(Mandatory = $true)]
        [string[]] $IncludePaths,
        
        [Parameter(Mandatory = $false)]
        [string[]] $ExcludePaths = @(),
        
        [Parameter(Mandatory = $false)]
        [string[]] $ExcludeFiles = @()
    )
    
    $config = [PSScriptBuilderConfiguration]::Load()
    
    $collectorClass = "PSScriptBuilder{0}Collector" -f $CollectorType
    $collector = New-Object $collectorClass -ArgumentList $config
    
    $collector.CollectionKey = $CollectionKey
    $collector.IncludePaths = $IncludePaths
    $collector.ExcludePaths = $ExcludePaths
    $collector.ExcludeFiles = $ExcludeFiles
    
    $ContentCollector.AddCollector($collector)
    Write-Host "✓ Added $CollectorType collector with key '$CollectionKey'" -ForegroundColor Green
}

function Remove-PSScriptBuilderCollector {
    <#
    .SYNOPSIS
        Removes a collector from ContentCollector
    .PARAMETER ContentCollector
        The ContentCollector instance
    .PARAMETER CollectionKey
        Key of collector to remove
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $true)]
        [string] $CollectionKey
    )
    
    $ContentCollector.RemoveCollector($CollectionKey)
    Write-Host "✓ Removed collector with key '$CollectionKey'" -ForegroundColor Green
}

function Get-PSScriptBuilderCollector {
    <#
    .SYNOPSIS
        Lists collectors in a ContentCollector
    .PARAMETER ContentCollector
        The ContentCollector instance
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ContentCollector] $ContentCollector
    )
    
    $collectors = $ContentCollector.Collectors.GetAll()
    return $collectors | Select-Object CommandName, CollectionKey, @{
        Name = "IncludePaths"
        Expression = { $_.IncludePaths -join ", " }
    }
}

function Invoke-PSScriptBuilderContentCollector {
    <#
    .SYNOPSIS
        Executes all collectors in a ContentCollector
    .DESCRIPTION
        Runs the Execute() method on all registered collectors.
        Returns array of CollectorResult objects with metrics.
    .PARAMETER ContentCollector
        The ContentCollector instance to execute
    .EXAMPLE
        $results = Invoke-PSScriptBuilderContentCollector -ContentCollector $content
        $results | Format-Table CollectionKey, ComponentCount, ExecutionTime, Success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ContentCollector] $ContentCollector
    )
    
    $results = $ContentCollector.Execute()
    return $results
}

function Invoke-PSScriptBuilderBuild {
    <#
    .SYNOPSIS
        Builds a consolidated PowerShell script from collected components
    .DESCRIPTION
        Orchestrates the complete build process using ContentCollector.
    .PARAMETER ContentCollector
        Pre-configured ContentCollector with collectors
    .PARAMETER TemplatePath
        Path to template file (with {{PLACEHOLDERS}})
    .PARAMETER OutputPath
        Output path for consolidated script
    .PARAMETER UpdateVersion
        If specified, bumps version before building
    .EXAMPLE
        Invoke-PSScriptBuilderBuild -ContentCollector $content `
                                    -TemplatePath "templates/consolidated.ps1.template" `
                                    -OutputPath "dist/PSScriptBuilder.psm1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $true)]
        [string] $TemplatePath,
        
        [Parameter(Mandatory = $true)]
        [string] $OutputPath,
        
        [Parameter(Mandatory = $false)]
        [switch] $UpdateVersion
    )
    
    try {
        $config = [PSScriptBuilderConfiguration]::Load()
        $builder = [ScriptBuilder]::new($config, $ContentCollector, $TemplatePath, $OutputPath)
        
        if ($UpdateVersion) {
            Write-Verbose "Updating version..."
            # Version management integration
        }
        
        $builder.Build()
        Write-Host "✓ Script built successfully: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Build failed: $($_.Exception.Message)"
        throw
    }
}

function Test-PSScriptBuilderCollectors {
    <#
    .SYNOPSIS
        Tests and validates collectors in ContentCollector
    .DESCRIPTION
        Executes collectors and reports metrics, errors, etc.
    .PARAMETER ContentCollector
        The ContentCollector instance to test
    .EXAMPLE
        Test-PSScriptBuilderCollectors -ContentCollector $content
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ContentCollector] $ContentCollector
    )
    
    $results = $ContentCollector.Execute()
    
    Write-Host "\n=== Collector Test Results ===" -ForegroundColor Cyan
    
    foreach ($result in $results) {
        $status = if ($result.Success) { "✓" } else { "✗" }
        $color = if ($result.Success) { "Green" } else { "Red" }
        
        Write-Host "$status $($result.CollectionKey)" -ForegroundColor $color
        Write-Host "  Components: $($result.ComponentCount)" -ForegroundColor Gray
        Write-Host "  Time: $($result.ExecutionTime.TotalMilliseconds)ms" -ForegroundColor Gray
        
        if ($result.Errors.Count -gt 0) {
            Write-Host "  Errors:" -ForegroundColor Red
            $result.Errors | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        }
    }
}
```

---

## Workflows

### Workflow 1: Standard Build

```powershell
# User command:
Invoke-PSScriptBuilderBuild -SourcePath "src/**" `
                            -TemplatePath "templates/consolidated.ps1.template" `
                            -OutputPath "dist/PSScriptBuilder.psm1"

# Internal Flow:
1. Load config + template
2. UsingCollector:    Collect all using statements → Deduplicate
3. EnumCollector:     Collect all enums
4. ClassCollector:    Collect classes + dependencies
5. FunctionCollector: Collect functions + dependencies
6. CycleDetector:     Check for circular dependencies
7. KahnSorter:        Sort components by dependency order
8. TemplateProcessor: Replace {{PLACEHOLDERS}} with collected data
9. Write consolidated.psm1
```

### Workflow 2: Dependency Analysis

```powershell
# User command:
Test-PSScriptBuilderDependencies -Path "src/**"

# Internal Flow:
1. Run collectors to gather component info
2. Build complete dependency graph
3. Run cycle detection (DFS)
4. Check for missing dependencies
5. Report issues
6. Output sorted order for verification
```

### Workflow 3: Selective Collection

```powershell
# User command:
Invoke-PSScriptBuilderCollect -Collector "Class" -Path "src/Classes/**"

# Result:
# List of all classes found
# With their dependencies
# For manual verification/documentation
```

---

## Error Handling

### Error Scenarios

| Szenario | Fehler | Handling |
|----------|--------|----------|
| Template nicht gefunden | FileNotFound | Throw, Show path |
| Ungültige PS1 Syntax | ParseError | Skip file, Log, Continue |
| Zirkuläre Abhängigkeit | CycleDetected | List cycle, Throw, Stop |
| Fehlende Dependency | MissingDep | Report, Continue (Warning) |
| Unresolved Placeholder | TemplatePlaceholder | List placeholders, Throw |
| File Write Error | IOException | Report, Throw |

### Error Recovery

```powershell
try {
    $builder.Build()
}
catch [InvalidOperationException] {
    # Validation errors (cycles, missing deps)
    # Not recoverable - show and exit
    Write-Error $_.Exception.Message
    exit 1
}
catch [System.IO.FileNotFoundException] {
    # File-not-found errors
    # Show paths and suggest fixes
    Write-Error "File not found: $($_.Exception.Message)"
    exit 1
}
catch {
    # Unknown errors
    Write-Error "Unexpected error: $($_.Exception.Message)"
    exit 2
}
```

---

## Best Practices

### 1. Collector Design

✅ **DO:**
- Ein Collector = eine Komponententyp
- Unabhängig von anderen Collectorn
- Niemals andere Collector aufrufen
- Strukturierte Daten zurückgeben

❌ **DON'T:**
- Collectors verketten
- Hard-coded Pfade
- State zwischen Sammlungen

### 2. Dependency Tracking

✅ **DO:**
- Alle Dependencies deklarieren
- Built-in Types/Cmdlets ausschließen
- Cycles erkennen vor Build
- Missing Dependencies reporten

❌ **DON'T:**
- Implizite Dependencies
- Cycles ignorieren
- Typen raten

### 3. Template Usage

✅ **DO:**
- Clear placeholder names: `{{COMPONENT_TYPE}}`
- Comments für Sections
- Version info einjizieren
- Multi-line placeholders

❌ **DON'T:**
- Vage placeholder names
- Hardcoded values
- Unresolved placeholders bleiben

### 4. Performance

✅ **DO:**
- AST caching für große Projects
- Parallel collectors (wo möglich)
- Early validation
- Incremental builds (künftig)

❌ **DON'T:**
- Alle Dateien mehrfach parsen
- Unnecessary traversals
- Keine Early Exit bei Errors

---

## Conclusion

Die **Collector Pattern Architecture** ermöglicht PSScriptBuilder:
- 🔍 **Flexible Component Extraction**: Granulare Kontrolle über Sammlung
- 📊 **Complete Dependency Analysis**: Zirkular-Erkennung + Topologische Sortierung
- 🎯 **Accurate Ordering**: Komponenten in korrekter Reihenfolge
- 🔌 **CLI Integration**: Benutzer steuert jeden Schritt
- 🧪 **Testability**: Isolierbare Collectors und Analyzer
- 📈 **Extensible**: Neue Komponenten- und Collector-Typen einfach hinzufügbar

Nächste Schritte: Implementation der Collector-Klassen und ScriptBuilder Orchestrator

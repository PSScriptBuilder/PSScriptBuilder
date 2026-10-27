# PSScriptBuilder - AI Coding Agent Instructions

## Project Overview

PSScriptBuilder builds single deployable PowerShell scripts from multi-file projects using a **Collector Pattern** architecture. The module is designed for object-oriented PowerShell with classes, enumerations, and dependency hierarchies.

**Target Platform**: PowerShell 5.1 (no interfaces, no ternary operators)  
**Language Convention**: German for chat, English for all source code (including comments)  
**Build System**: Manual builds via `build.ps1` (never automate)

## Critical Architecture Patterns

### 1. Collector System (Core Pattern)

All collectors inherit from `PSScriptBuilderCollectorBase` using **Template Method Pattern**:

```powershell
// Execution flow:
Collect() → Reset() → GetFilesToProcess() → CollectFromFiles()
```

**Key Rules:**
- `CollectFromFiles([FileInfo[]])` is abstract - implements element-specific logic
- `Reset()` clears state for idempotent collection (called automatically by `Collect()`)
- `CollectorType` enum (Using=0, Enum=1, Class=2, Function=3, File=4) determines execution order
- `CollectionKey` is user-customizable for template tokens

**Example**: See `src/Classes/ScriptBuilder/Collectors/PSScriptBuilderClassCollector.ps1`

### 2. Type-Safe Data Classes (NOT PSCustomObject)

Use dedicated Data classes for structured data:

```powershell
[PSScriptBuilderClassData]::new($name, $sourceCode, $baseClass, $typeReferences)
[PSScriptBuilderFunctionData]::new($name, $sourceCode, $calledFunctions, $typeReferences)
```

**Location**: `src/Classes/ScriptBuilder/Data/`  
**Rationale**: IntelliSense support, compile-time checking, extensibility

### 3. AST Analysis (PSScriptBuilderAstEngine)

Static utility class for PowerShell AST parsing:

- `FindFunctionDefinitions()` - **excludes class methods** (filters TypeDefinitionAst parents)
- `FindClassDefinitions()`, `FindEnumDefinitions()`, `FindUsingStatements()`
- `GetTypeReferences()` - extracts dependencies, filtered via `IsBuiltInType()`
- `ExtractSourceCode()` - preserves exact formatting

**Location**: `src/Classes/ScriptBuilder/Helper/PSScriptBuilderAstEngine.ps1`

### 4. Fail-Fast with Guard Clauses

**Duplicate Detection**: Collectors throw `InvalidOperationException` on duplicate names (enum/class/function):

```powershell
if ($this.ClassData.ContainsKey($className)) {
    $message = "Duplicate class '{0}' found in file: {1}..." -f $className, $file.FullName
    throw [InvalidOperationException]::new($message)
}
```

**Rationale**: Build will fail anyway - fail early with clear error message.

### 5. Verbose Logging Pattern

Classes use `Write-Verbose` directly (respects `-Verbose` from calling cmdlet):

```powershell
Write-Verbose "Starting collection with $count file(s)..."
Write-Verbose "  Parsing: $($file.Name)"
Write-Verbose "Collection complete: $total items"
```

**Display Rules**:

- Null/empty strings: Use `<none>` (e.g., `BaseClass=<none>`)
- Counts: Show actual number including `0` (e.g., `TypeReferences=0`)

### 6. Module-Scoped State

Use `$Global:` scope for module state that must be accessible from PowerShell 5.1 class methods — class methods cannot access `$script:` variables:

```powershell
$Global:PSScriptBuilderProjectRoot = $null
```

Access only via dedicated cmdlets (`Set-PSScriptBuilderProjectRoot`, `Get-PSScriptBuilderProjectRoot`).

## Code Conventions

### Region Blocks (SACRED)

**Never** create, remove, move, or rename `#region` blocks. They are part of the file structure contract.

### Exception Handling

```powershell
// ✅ CORRECT
$format = "Failed to collect from: {0}. Error: {1}"
$message = $format -f $file.FullName, $_.Exception.Message
throw [Exception]::new($message, $_.Exception)

// ❌ WRONG
throw "Error: $($_.Exception.Message)"  // No context, no nesting
```

### Function Definitions

```powershell
// ✅ CORRECT
Function Get-PSScriptBuilderData {
    [CmdletBinding()]
    param()
}

// ❌ WRONG
[CmdletBinding()]
Function Get-PSScriptBuilderData { }  // CmdletBinding must be inside
```

### Comment-Based Help

Only use official PowerShell help keywords: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.OUTPUTS`, `.EXAMPLE`, `.NOTES`, `.LINK`.  
**Do not** use non-standard fields like `.DATECREATED`, `.DATEMODIFIED`, `.AUTHOR`, `.EDITOR`, `.VERSION` — Git tracks this information.

## Project Structure

```
src/
├── Enums/
│   ├── PSScriptBuilderBumpType.ps1
│   ├── PSScriptBuilderCollectorType.ps1
│   └── PSScriptBuilderTemplateValidationMode.ps1
├── Private/
│   └── Get-PSScriptBuilderProjectRoot.ps1
├── Public/                             # User-facing cmdlets (24 cmdlets)
├── Classes/
│   ├── Common/                         # FileIOHelper, FileSystemHelper, TextHelper
│   ├── Configuration/
│   │   ├── Options/                    # BuildOptions, ReleaseOptions, OptionsBase
│   │   ├── PSScriptBuilderConfigLoader.ps1
│   │   ├── PSScriptBuilderConfiguration.ps1
│   │   └── PSScriptBuilderConfigValidator.ps1
│   ├── ReleaseManagement/
│   │   ├── Helper/                     # BumpReplacementHelper
│   │   ├── Managers/                   # BumpConfigFileManager, BumpFilesProcessor, ReleaseDataFileManager, ReleaseDataProcessor
│   │   ├── Orchestrators/              # ReleaseManagementOrchestrator
│   │   ├── Requests/                   # ReleaseDataOperationRequest
│   │   ├── Results/                    # BumpFilesResult, ReleaseDataResult
│   │   └── Validators/                 # BumpFilesValidator, ReleaseDataValidator
│   └── ScriptBuilder/
│       ├── Collectors/                 # Using, Enum, Class, Function, File collectors
│       ├── Core/                       # CollectorBase, CollectorCollection, ContentCollector, ContentProcessor
│       ├── Data/                       # ClassData, EnumData, FileData, FunctionData, UsingData
│       ├── Dependencies/               # DependencyAnalyzer, DependencyGraph, GraphBuilder, CycleDetector, CrossDependencyDetector, TopologicalSorter
│       ├── Helper/                     # AstEngine, BuildDataAggregator
│       ├── Managers/                   # BackupManager, OutputFileManager, TemplateFileManager
│       ├── Orchestrators/              # BuildOrchestrator
│       ├── Results/                    # BuildResult, BuildComponentCounts, BuildComponentDetail, DependencyAnalysisResult, TemplateAnalysisResult
│       └── Template/                   # TemplateAnalyzer, TemplateProcessor, TemplateValidator
```

## Current Implementation Status

**✅ Completed:**

- All 5 collectors (Using, Enum, Class, Function, File) with Reset() and Guard Clauses
- AstEngine with method filtering (standalone functions vs. class methods)
- CollectorCollection with `Items` property (sorted by CollectorType)
- ContentCollector and ContentProcessor orchestration
- Type-safe Data classes (ClassData, EnumData, FunctionData, FileData, UsingData)
- Full dependency analysis pipeline (DependencyGraph, GraphBuilder, CycleDetector, CrossDependencyDetector, TopologicalSorter)
- Template system (TemplateAnalyzer, TemplateProcessor, TemplateValidator)
- Build orchestration (BuildOrchestrator)
- Full release management pipeline (ReleaseManagementOrchestrator)
- All public cmdlets including `Invoke-PSScriptBuilderBuild`

**🚧 In Progress / Planned:**

- Test suite (~75 tests planned, see `internal/test-strategy-planning.md`)
- CI/CD publishing to PSGallery (see `internal/cicd-publishing-strategy.md`)

## Workflow Rules

1. **Show First, Code Later**: On user questions/suggestions, show planned changes in chat before implementing
2. **Manual Builds**: Suggest `.\build.ps1` execution, never run it autonomously
3. **Error Analysis**: Use `get_errors` tool to validate changes after edits

## Key Files for Reference

- `AGENTS.md` - Detailed AI agent rules (authoritative)
- `internal/script-building-architecture.md` - Architecture decisions and rationale
- `src/Classes/ScriptBuilder/Core/PSScriptBuilderCollectorBase.ps1` - Template Method pattern
- `src/Classes/ScriptBuilder/Helper/PSScriptBuilderAstEngine.ps1` - AST traversal utilities
- `src/Classes/ScriptBuilder/Orchestrators/PSScriptBuilderBuildOrchestrator.ps1` - Build orchestration

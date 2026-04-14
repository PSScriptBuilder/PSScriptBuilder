# CLI Integration Planning

**Document Version:** 1.1  
**Created:** 2026-01-29  
**Last Modified:** 2026-03-13  
**Author:** Tim Hartling  

---

## Table of Contents

1. [Overview](#overview)
2. [Core Principles](#core-principles)
3. [WhatIf/ShouldProcess Pattern](#whatif-shouldprocess-pattern)
4. [Collector Management Cmdlets](#collector-management-cmdlets)
5. [Version Management Cmdlets](#version-management-cmdlets)
6. [Build & Execution Cmdlets](#build--execution-cmdlets)
7. [Workflows & Scenarios](#workflows--scenarios)
8. [Error Handling Strategy](#error-handling-strategy)
9. [Implementation Roadmap](#implementation-roadmap)
10. [Planned CLI Extensions](#planned-cli-extensions)

---

## Overview

The CLI layer provides the user-facing interface to PSScriptBuilder. It integrates two major architectural systems:

1. **Collector Pattern** - Script component extraction and composition
2. **Orchestrator Pattern** - Atomic version management with transactional semantics and rollback capability

### Design Goals

- **Discoverability** - PowerShell-idiomatic, intuitive naming (Verb-Noun pattern)
- **Safety** - WhatIf support for all destructive operations
- **Transparency** - Detailed execution feedback and dry-run capabilities
- **Composability** - Cmdlets can be piped and combined
- **Consistency** - Unified parameter conventions and error handling

### Cmdlet Naming Convention

All cmdlets follow PowerShell naming standards:

```
Verb-PSScriptBuilderNoun
```

**Approved Verbs (subset):**

- `New` - Create new instance
- `Add` - Add item to collection
- `Remove` - Remove item from collection
- `Get` - Retrieve item(s)
- `Invoke` - Execute operation
- `Test` - Test/validate operation
- `Set` - Configure/modify
- `Update` - Perform incremental change

---

## Core Principles

### 1. Static Configuration Access

All cmdlets automatically use the static cached configuration:

```powershell
# Configuration loads automatically on first cmdlet execution
$config = [PSScriptBuilderConfiguration]::GetCurrent()

# Cmdlets never require -Configuration parameter
Invoke-PSScriptBuilderContentCollector -CollectorType Class
```

### 2. Collections as Pipeline Objects

Collectors are managed through a CollectorCollection object that can be piped:

```powershell
New-PSScriptBuilderContentCollector | 
    Add-PSScriptBuilderCollector -CollectorType Class -CollectionKey "Domain" |
    Invoke-PSScriptBuilderContentCollector
```

### 3. WhatIf Default Behavior

All action cmdlets support `-WhatIf` (default: off)

```powershell
# Dry-run mode - shows what will happen without executing
Invoke-PSScriptBuilderBuild -WhatIf

# Execute with confirmation for destructive operations
Invoke-PSScriptBuilderBuild -Confirm
```

### 4. Consistent Error Handling

All cmdlets:

- Throw specific exceptions (not Write-Error)
- Provide detailed context in error messages
- Include remediation guidance where applicable

---

## WhatIf/ShouldProcess Pattern

### Implementation Strategy

All action cmdlets implement PowerShell's `ShouldProcess` pattern:

```powershell
function Invoke-PSScriptBuilderBuild {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [PSScriptBuilderContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $false)]
        [string] $OutputPath = $PWD
    )
    
    if ($PSCmdlet.ShouldProcess("Build script", "Invoke build process")) {
        # Actual execution here
    }
}
```

### WhatIf Output Format

WhatIf responses follow this pattern:

```
What if: Performing the operation "Invoke build process" on target "Build script".
  - Found 12 collectors (Class, Function, Using)
  - 156 components detected
  - Output: C:\output\PSScriptBuilder.psm1
  - Size estimate: ~245 KB
```

### DryRun for Complex Operations

For operations with multiple steps, provide detailed dry-run:

```powershell
# Bump version with dry-run
Update-PSScriptBuilderVersion -Major -DryRun

# Output:
# [DRY-RUN] Command Sequence:
#   1. LoadVersionCommand - Load current version
#   2. ValidateCommand - Validate version data
#   3. BumpVersionCommand - Bump major version: 1.2.3 -> 2.0.0
#   4. UpdateFilesCommand - Update 5 version files
#   5. SaveVersionCommand - Save to version.json
#
# [DRY-RUN] Rollback Stack (if error):
#   - Revert version files
#   - Revert version.json
```

---

## Collector Management Cmdlets

### New-PSScriptBuilderContentCollector

Creates a new ContentCollector instance for managing script components.

**Signature:**

```powershell
function New-PSScriptBuilderContentCollector {
    [CmdletBinding()]
    param()
    
    [PSScriptBuilderContentCollector] $NewObject
}
```

**Description:**

Initializes an empty ContentCollector with an internal CollectorCollection. This is the starting point for all collector-based workflows.

**Parameters:**

None - creates empty instance ready for collectors to be added.

**Returns:**

`[PSScriptBuilderContentCollector]` - New ContentCollector instance with empty CollectorCollection.

**Examples:**

```powershell
# Create a new content collector
$collector = New-PSScriptBuilderContentCollector

# Create and immediately add collectors
$collector = New-PSScriptBuilderContentCollector
$collector | Add-PSScriptBuilderCollector -CollectorType Class -CollectionKey "Domain"
```

**Notes:**

- Automatically loads configuration via `PSScriptBuilderBase::new()`
- Logger is initialized from cached configuration
- Internal CollectorCollection is instantiated empty

---

### Add-PSScriptBuilderCollector

Adds a configured collector to the ContentCollector's collection.

**Signature:**

```powershell
function Add-PSScriptBuilderCollector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSScriptBuilderContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Class", "Function", "Using", "Enum", "File")]
        [string] $CollectorType,
        
        [Parameter(Mandatory = $true)]
        [string] $CollectionKey,
        
        [Parameter(Mandatory = $false)]
        [string[]] $IncludePaths,
        
        [Parameter(Mandatory = $false)]
        [string[]] $IncludeFiles,
        
        [Parameter(Mandatory = $false)]
        [string[]] $ExcludePaths,
        
        [Parameter(Mandatory = $false)]
        [string[]] $ExcludeFiles
    )
    
    [PSScriptBuilderContentCollector] $ContentCollector
}
```

**Description:**

Adds a collector instance of the specified type to the ContentCollector's internal collection. Collectors are identified by CollectionKey, allowing multiple collectors of the same type with different configurations.

**Parameters:**

- **ContentCollector** (PSScriptBuilderContentCollector, mandatory, pipeline)
  - The ContentCollector to add the collector to
  
- **CollectorType** (string, mandatory)
  - Type of collector: Class, Function, Using, Enum, File
  - Determines which PowerShell AST elements are collected or how files are handled
  
- **CollectionKey** (string, mandatory)
  - Unique identifier for this collector configuration
  - Example: "CLASSES_DOMAIN", "CLASSES_UTILS", "FUNCTIONS_CORE"
  - Allows multiple collectors of same type with different configs
  - Used for dependency ordering
  
- **IncludePaths** (string[], optional)
  - Paths to scan for components
  - Relative to project root
  - Example: "src/Classes/Domain"

- **IncludeFiles** (string[], optional)
  - Specific files to include
  - Glob patterns supported
  - Takes precedence over ExcludeFiles
  
- **ExcludePaths** (string[], optional)
  - Paths to exclude from scanning
  - Overrides IncludePaths
  
- **ExcludeFiles** (string[], optional)
  - Specific files to exclude
  - Glob patterns supported

**Returns:**

`[PSScriptBuilderContentCollector]` - The modified ContentCollector (for pipelining).

**Examples:**

```powershell
# Add a Class collector for domain classes
$collector = New-PSScriptBuilderContentCollector
$collector | Add-PSScriptBuilderCollector `
    -CollectorType Class `
    -CollectionKey "CLASSES_DOMAIN" `
    -IncludePaths "src/Classes/Domain"

# Add multiple collectors with different configs
$collector | Add-PSScriptBuilderCollector `
    -CollectorType Class `
    -CollectionKey "CLASSES_UTILS" `
    -IncludePaths "src/Classes/Common"

# Add Function collector with exclusions
$collector | Add-PSScriptBuilderCollector `
    -CollectorType Function `
    -CollectionKey "FUNCTIONS_PUBLIC" `
    -IncludePaths "src/Functions" `
    -ExcludeFiles "*.Private.ps1"
```

**Error Handling:**

- Throws `ArgumentException` if CollectionKey already exists
- Throws `ArgumentException` if paths don't exist (if not WhatIf)
- Throws `InvalidOperationException` if ContentCollector is null

---

### Remove-PSScriptBuilderCollector

Removes a collector from the ContentCollector's collection.

**Signature:**

```powershell
function Remove-PSScriptBuilderCollector {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSScriptBuilderContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $CollectionKey
    )
    
    [PSScriptBuilderContentCollector] $ContentCollector
}
```

**Description:**

Removes a collector from the ContentCollector's internal collection by its CollectionKey.

**Parameters:**

- **ContentCollector** (PSScriptBuilderContentCollector, mandatory, pipeline)
  - The ContentCollector to remove the collector from
  
- **CollectionKey** (string, mandatory)
  - Key of collector to remove

**Returns:**

`[PSScriptBuilderContentCollector]` - The modified ContentCollector.

**Examples:**

```powershell
# Remove a specific collector
$collector | Remove-PSScriptBuilderCollector -CollectionKey "CLASSES_UTILS"

# Remove all collectors matching a pattern (pipeline)
Get-PSScriptBuilderCollector -ContentCollector $collector | 
    Where-Object { $_.CollectionKey -match "CLASSES_" } |
    Remove-PSScriptBuilderCollector
```

**WhatIf Support:**

```powershell
# Dry-run: see what would be removed
$collector | Remove-PSScriptBuilderCollector -CollectionKey "CLASSES_UTILS" -WhatIf

# Output:
# What if: Performing the operation "Remove collector" on target "CLASSES_UTILS".
#   Remaining collectors (3):
#   - CLASSES_DOMAIN
#   - FUNCTIONS_PUBLIC
#   - USING_STANDARD
```

---

### Get-PSScriptBuilderCollector

Retrieves collector information from the ContentCollector.

**Signature:**

```powershell
function Get-PSScriptBuilderCollector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSScriptBuilderContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $false)]
        [string] $CollectionKey,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Class", "Function", "Using", "Enum", "File")]
        [string] $CollectorType
    )
    
    [PSCustomObject[]] $Collectors
}
```

**Description:**

Lists collectors in the ContentCollector. Can filter by key or type. Output objects contain configuration details for each collector.

**Parameters:**

- **ContentCollector** (PSScriptBuilderContentCollector, mandatory)
  - The ContentCollector to query
  
- **CollectionKey** (string, optional)
  - Return only collector with this key
  
- **CollectorType** (string, optional)
  - Return only collectors of this type

**Returns:**

`[PSCustomObject[]]` Array of collector objects with properties:

- `CollectionKey` - Unique identifier
- `CollectorType` - Class, Function, Using, Enum, File
- `IncludePaths` - Paths being scanned
- `ExcludePaths` - Excluded paths
- `ExcludeFiles` - Excluded files
- `ComponentCount` - Number of components found (requires execution)

**Examples:**

```powershell
# List all collectors
Get-PSScriptBuilderCollector -ContentCollector $collector

# Get specific collector
Get-PSScriptBuilderCollector -ContentCollector $collector -CollectionKey "CLASSES_DOMAIN"

# List all Class collectors
Get-PSScriptBuilderCollector -ContentCollector $collector -CollectorType Class

# Display formatted
Get-PSScriptBuilderCollector -ContentCollector $collector | Format-Table -AutoSize
```

---

### Invoke-PSScriptBuilderContentCollector

Executes all collectors in the ContentCollector.

**Signature:**

```powershell
function Invoke-PSScriptBuilderContentCollector {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSScriptBuilderContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $false)]
        [switch] $IncludeMetrics
    )
    
    [PSScriptBuilderCollectorResult[]] $CollectorResults
}
```

**Description:**

Executes all configured collectors sequentially. Performs dependency analysis (cycle detection + topological sort) to ensure correct ordering. Returns array of CollectorResult objects with metrics.

**Parameters:**

- **ContentCollector** (PSScriptBuilderContentCollector, mandatory, pipeline)
  - The ContentCollector to invoke
  
- **IncludeMetrics** (switch, optional)
  - Include detailed execution metrics in results
  - Adds: ComponentCount, ExecutionTime, Memory usage

**Returns:**

`[PSScriptBuilderCollectorResult[]]` Array of results:

- `CollectionKey` - Which collector this result is from
- `ComponentCount` - Number of components collected
- `ExecutionTime` - TimeSpan of collection
- `Errors` - Any errors encountered
- `Success` - Boolean success indicator
- `Output` - Collected component data

**Examples:**

```powershell
# Execute collectors
$results = $collector | Invoke-PSScriptBuilderContentCollector

# Execute with metrics
$results = $collector | Invoke-PSScriptBuilderContentCollector -IncludeMetrics

# Dry-run to see execution plan
$collector | Invoke-PSScriptBuilderContentCollector -WhatIf

# Display results
$results | Format-Table -AutoSize
```

**WhatIf Support:**

```powershell
# Dry-run output:
# What if: Performing the operation "Invoke collectors" on target "ContentCollector".
#   Execution Plan:
#   1. [CLASSES_DOMAIN] ClassCollector - src/Classes/Domain
#   2. [CLASSES_UTILS] ClassCollector - src/Classes/Common
#   3. [FUNCTIONS_PUBLIC] FunctionCollector - src/Functions
#   4. [USING_STANDARD] UsingCollector - (project-wide)
#
#   Dependency Graph: USING_STANDARD -> CLASSES_DOMAIN -> FUNCTIONS_PUBLIC
#   Cycles: None detected ✓
#   Estimated components: ~120
```

**Error Handling:**

- Throws `InvalidOperationException` if cycle detected in dependencies
- Returns failed CollectorResult if individual collector fails
- Includes detailed error context in results

---

## Version Management Cmdlets

### Update-PSScriptBuilderVersion

Updates the project version using Command Pattern with rollback.

**Signature:**

```powershell
function Update-PSScriptBuilderVersion {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [switch] $Major,
        
        [Parameter(Mandatory = $false)]
        [switch] $Minor,
        
        [Parameter(Mandatory = $false)]
        [switch] $Patch,
        
        [Parameter(Mandatory = $false)]
        [string] $Prerelease,
        
        [Parameter(Mandatory = $false)]
        [string] $BuildMetadata,
        
        [Parameter(Mandatory = $false)]
        [switch] $DryRun
    )
    
    [PSCustomObject] $VersionResult
}
```

**Description:**

Executes atomic version update via Orchestrator Pattern. Loads configuration, validates, bumps version, updates all project files, and saves changes with automatic rollback on error.

**Parameters:**

- **Major** (switch, optional) - Increment major version
- **Minor** (switch, optional) - Increment minor version  
- **Patch** (switch, optional) - Increment patch version
- **Prerelease** (string, optional) - Set prerelease identifier
- **BuildMetadata** (string, optional) - Set build metadata
- **DryRun** (switch, optional) - Show command sequence without executing

**Returns:**

`[PSCustomObject]` with properties:

- `OldVersion` - Previous version string
- `NewVersion` - Updated version string
- `FilesUpdated` - Count of files modified
- `ExecutionTime` - TimeSpan of operation
- `Success` - Boolean success indicator
- `RollbackExecuted` - Boolean (true if error occurred and rollback ran)

**Examples:**

```powershell
# Bump major version
Update-PSScriptBuilderVersion -Major

# Bump minor version with prerelease
Update-PSScriptBuilderVersion -Minor -Prerelease "beta.1"

# Dry-run to see command sequence
Update-PSScriptBuilderVersion -Major -DryRun

# With confirmation prompt
Update-PSScriptBuilderVersion -Major -Confirm
```

**WhatIf/DryRun Output:**

```powershell
# Update-PSScriptBuilderVersion -Major -DryRun
# 
# [DRY-RUN] Version Update Sequence
# Current Version: 1.2.3
# 
# Command Execution Plan:
#   1. LoadVersionCommand
#      - Load version from: build/Version/psscriptbuilder.version.json
#   
#   2. ValidateCommand
#      - Validate version data structure
#      - Check git repository
#   
#   3. BumpVersionCommand
#      - Bump major: 1.2.3 -> 2.0.0
#      - Reset minor and patch
#   
#   4. UpdateFilesCommand
#      - Update: build/psscriptbuilder.bumpfiles.json (5 files)
#      - Update: PSScriptBuilder.psd1
#      - Update: README.md
#   
#   5. SaveVersionCommand
#      - Save to: build/Version/psscriptbuilder.version.json
#      - Update git metadata
#
# Rollback Stack (in case of error):
#   ✓ Revert version files
#   ✓ Revert version.json
#   ✓ Revert git metadata
#
# Estimated execution time: ~500ms
```

**Error Handling:**

- Any command failure triggers rollback sequence
- Detailed error includes: which command failed, state at failure, rollback status
- User can see what was reverted

---

### Get-PSScriptBuilderVersion

Retrieves current version information.

**Signature:**

```powershell
function Get-PSScriptBuilderVersion {
    [CmdletBinding()]
    param()
    
    [PSCustomObject] $VersionInfo
}
```

**Description:**

Returns current version data including version numbers, build info, and git metadata.

**Returns:**

`[PSCustomObject]` with properties:

- `VersionString` - Full version (e.g., "1.2.3-beta.1+build.123")
- `Major` - Major version number
- `Minor` - Minor version number
- `Patch` - Patch version number
- `Prerelease` - Prerelease identifier (if any)
- `Build` - Build number
- `BuildDate` - Date version was built
- `GitCommit` - Commit hash
- `GitBranch` - Current branch

**Examples:**

```powershell
# Get current version
Get-PSScriptBuilderVersion

# Display as formatted object
Get-PSScriptBuilderVersion | Format-List

# Use in pipeline
Get-PSScriptBuilderVersion | Select-Object -ExpandProperty VersionString
```

---

## Build & Execution Cmdlets

### Invoke-PSScriptBuilderBuild

Builds the final PSModule script from collected components.

**Signature:**

```powershell
function Invoke-PSScriptBuilderBuild {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [PSScriptBuilderContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $false)]
        [string] $OutputPath = $PWD,
        
        [Parameter(Mandatory = $false)]
        [string] $OutputFileName = "PSScriptBuilder.psm1",
        
        [Parameter(Mandatory = $false)]
        [switch] $Force
    )
    
    [PSCustomObject] $BuildResult
}
```

**Description:**

Executes collectors, combines output, applies templates, and writes final module file.

**Parameters:**

- **ContentCollector** (PSScriptBuilderContentCollector, mandatory)
  - Configured collector with collectors added
  
- **OutputPath** (string, optional, default: current directory)
  - Directory for output file
  
- **OutputFileName** (string, optional, default: PSScriptBuilder.psm1)
  - Name of output file
  
- **Force** (switch, optional)
  - Overwrite existing output file without warning

**Returns:**

`[PSCustomObject]` with properties:

- `OutputPath` - Full path to generated file
- `FileSize` - Size in bytes
- `ComponentCount` - Total components in output
- `ExecutionTime` - TimeSpan of build
- `Success` - Boolean success indicator

**Examples:**

```powershell
# Basic build
$collector | Invoke-PSScriptBuilderBuild

# Build to specific location
$collector | Invoke-PSScriptBuilderBuild -OutputPath "C:\Output" -OutputFileName "MyModule.psm1"

# Build with overwrite
$collector | Invoke-PSScriptBuilderBuild -Force

# Dry-run to see what will happen
$collector | Invoke-PSScriptBuilderBuild -WhatIf
```

**WhatIf Support:**

```powershell
# Dry-run output:
# What if: Performing the operation "Build PSModule" on target "PSScriptBuilder.psm1".
#   Build Plan:
#   - Execute 4 collectors (CLASSES_DOMAIN, CLASSES_UTILS, FUNCTIONS_PUBLIC, USING_STANDARD)
#   - Apply template: standard.template
#   - Output: C:\Output\PSScriptBuilder.psm1
#   - Estimated size: ~245 KB
#   - File will be overwritten: No (set -Force to override)
```

---

### Test-PSScriptBuilderCollectors

Tests and validates collectors without executing build.

**Signature:**

```powershell
function Test-PSScriptBuilderCollectors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSScriptBuilderContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $false)]
        [switch] $Verbose
    )
    
    [PSCustomObject] $TestResult
}
```

**Description:**

Validates collector configuration, checks for cycles, validates paths, and reports metrics without executing collection.

**Parameters:**

- **ContentCollector** (PSScriptBuilderContentCollector, mandatory)
  - ContentCollector to test
  
- **Verbose** (switch, optional)
  - Include detailed validation output

**Returns:**

`[PSCustomObject]` with properties:

- `CollectorCount` - Number of collectors
- `CyclesDetected` - Boolean
- `PathsValid` - Boolean
- `ValidationErrors` - Error array (if any)
- `EstimatedComponents` - Estimated component count
- `Success` - Overall validation result

**Examples:**

```powershell
# Test collectors
$testResult = Test-PSScriptBuilderCollectors -ContentCollector $collector

# Test with verbose output
Test-PSScriptBuilderCollectors -ContentCollector $collector -Verbose

# Check success
if ($testResult.Success) {
    Write-Host "Collectors are valid!"
}
```

---

## Workflows & Scenarios

### Scenario 1: Build PSModule from Scratch

```powershell
# Step 1: Create new ContentCollector
$collector = New-PSScriptBuilderContentCollector

# Step 2: Add collectors for each component type
$collector | Add-PSScriptBuilderCollector `
    -CollectorType Class `
    -CollectionKey "CLASSES_DOMAIN" `
    -IncludePaths "src/Classes/Domain"

$collector | Add-PSScriptBuilderCollector `
    -CollectorType Function `
    -CollectionKey "FUNCTIONS_PUBLIC" `
    -IncludePaths "src/Functions/Public"

# Step 3: Test configuration
Test-PSScriptBuilderCollectors -ContentCollector $collector

# Step 4: Build
$result = $collector | Invoke-PSScriptBuilderBuild -OutputPath "C:\Output"

Write-Host "Build complete: $($result.OutputPath) ($($result.FileSize) bytes)"
```

### Scenario 2: Dry-Run Before Production Build

```powershell
# Test without making changes
$collector | Invoke-PSScriptBuilderBuild -WhatIf

# Review output plan
$collector | Invoke-PSScriptBuilderContentCollector -WhatIf

# If satisfied, execute for real
$collector | Invoke-PSScriptBuilderBuild
```

### Scenario 3: Version Bump with Validation

```powershell
# Check current version
$current = Get-PSScriptBuilderVersion
Write-Host "Current: $($current.VersionString)"

# Dry-run version bump
Update-PSScriptBuilderVersion -Minor -DryRun

# Execute with confirmation
Update-PSScriptBuilderVersion -Minor -Confirm

# Verify
$new = Get-PSScriptBuilderVersion
Write-Host "Updated to: $($new.VersionString)"
```

### Scenario 4: Build and Release Workflow

```powershell
# Complete workflow: Build → Test → Version → Release

# Step 1: Build
$collector = New-PSScriptBuilderContentCollector
# ... add collectors ...
$buildResult = $collector | Invoke-PSScriptBuilderBuild -Force

# Step 2: Validate output
if (-not $buildResult.Success) {
    throw "Build failed"
}

# Step 3: Update version
Update-PSScriptBuilderVersion -Minor

# Step 4: Commit changes
git add .
git commit -m "Release v$((Get-PSScriptBuilderVersion).VersionString)"
git push
```

---

## Error Handling Strategy

### Error Categories

**1. Configuration Errors**

- Missing config file
- Invalid config format
- Missing required options

**Response:** Throw `InvalidOperationException` with detailed path/reason

```powershell
throw [InvalidOperationException]::new(
    "Configuration file not found at: C:\path\to\config.json"
)
```

**2. Validation Errors**

- Invalid paths
- Duplicate collection keys
- Cycle in dependencies

**Response:** Throw `ArgumentException` with resolution guidance

```powershell
throw [ArgumentException]::new(
    "Collector key 'CLASSES_DOMAIN' already exists. Use -Force to replace or choose different key."
)
```

**3. Execution Errors**

- File I/O failures
- Template errors
- Collector failures

**Response:** Capture in result object or throw with context

```powershell
# For collectors: Return failed CollectorResult
@{
    CollectionKey = "CLASSES_DOMAIN"
    Success = $false
    Errors = @("Failed to parse file: xyz.ps1")
    ComponentCount = 0
}

# For commands: Throw with rollback indication
throw [InvalidOperationException]::new(
    "Failed at BumpVersionCommand. Automatic rollback completed. " +
    "Manual review recommended: check version.json"
)
```

### User-Facing Error Messages

**Pattern:**
```
[ERROR] <Category>: <Message>
        <Additional Context>
        <Remediation Suggestion>
```

**Examples:**

```
[ERROR] Configuration: Missing required option 'LogPath'
        Current config: C:\PSScriptBuilder\psscriptbuilder.config.json
        
        Remediation:
        1. Add 'LogPath' to configuration JSON
        2. Use: [PSScriptBuilderConfiguration]::Reset() to reload
        3. Retry operation

[ERROR] Validation: Cycle detected in collector dependencies
        CLASSES_DOMAIN -> FUNCTIONS_PUBLIC -> CLASSES_DOMAIN
        
        Remediation:
        1. Review collector dependencies in configuration
        2. Break circular dependency
        3. Use Get-PSScriptBuilderCollector to inspect current setup
```

### WhatIf Error Detection

When `-WhatIf` is used, catch validation errors but don't fail:

```powershell
# WhatIf output with warnings
# What if: Performing the operation "Build PSModule" on target "PSScriptBuilder.psm1"
# 
# ⚠ WARNING: Collector 'CLASSES_UTILS' path does not exist
#   Path: src/Classes/Utils (not found)
#   Impact: No components collected from this collector
#   
# Build would proceed with 3 collectors instead of 4
```

---

## Implementation Roadmap

### Phase 1: Core Collector Cmdlets (Week 1)

Priority implementation order:

1. **New-PSScriptBuilderContentCollector**
   - Base cmdlet, no dependencies
   - Create empty CollectorCollection
   
2. **Add-PSScriptBuilderCollector**
   - Depends on: ContentCollector structure
   - Add path validation
   
3. **Get-PSScriptBuilderCollector**
   - Simple query operations
   - No state modification
   
4. **Remove-PSScriptBuilderCollector**
   - State modification
   - Add WhatIf support

5. **Invoke-PSScriptBuilderContentCollector**
   - Execute collectors
   - Dependency analysis
   - Result packaging

### Phase 2: Build Cmdlets (Week 2)

1. **Test-PSScriptBuilderCollectors**
   - Validation without execution
   - Cycle detection
   
2. **Invoke-PSScriptBuilderBuild**
   - Main build execution
   - Template application
   - Output generation

### Phase 3: Version Management Cmdlets (Week 2-3)

1. **Get-PSScriptBuilderVersion**
   - Simple query
   - No dependencies on Command Pattern yet
   
2. **Update-PSScriptBuilderVersion**
   - Depends on: VersionManagementOrchestrator implementation
   - Atomic execution with rollback
   - Full ShouldProcess support

### Phase 4: Integration & Testing (Week 3-4)

1. Integration tests between systems
2. End-to-end workflow validation
3. Performance optimization
4. Documentation

---

## Testing Strategy

### Unit Tests

```powershell
# Test collector management
Describe "Collector Management" {
    It "New-PSScriptBuilderContentCollector creates empty collector" { }
    It "Add-PSScriptBuilderCollector adds to collection" { }
    It "Get-PSScriptBuilderCollector retrieves collectors" { }
    It "Remove-PSScriptBuilderCollector removes from collection" { }
}

# Test execution
Describe "Collector Execution" {
    It "Invoke-PSScriptBuilderContentCollector runs all collectors" { }
    It "Handles cycle detection" { }
    It "Returns CollectorResult array" { }
}
```

### Integration Tests

```powershell
# Full workflow test
Describe "Build Workflow" {
    It "Complete workflow: Create -> Add -> Invoke -> Build" { }
    It "Version update with rollback on error" { }
    It "WhatIf prevents actual execution" { }
}
```

### Validation Tests

```powershell
# Error scenarios
Describe "Error Handling" {
    It "Throws on invalid config" { }
    It "Throws on duplicate keys" { }
    It "Throws on cycle detection" { }
    It "Provides meaningful error messages" { }
}
```

---

## Planned CLI Extensions

This section documents planned cmdlets to enhance user experience and workflow automation. These extensions build on the core cmdlets to provide higher-level workflows, better visibility, and improved onboarding.

### Extension Categories

1. **Workflow-Cmdlets** - High-level automation for common workflows
2. **Collector Management Extensions** - Enhanced collector inspection and debugging
3. **Project Setup & Onboarding** - Initialization and scaffolding tools
4. **Status & Overview** - Dashboard and visibility improvements
5. **Configuration Management** - Advanced configuration operations
6. **Build Variants** - Flexible build configurations

---

### 1. Workflow-Cmdlets

#### Invoke-PSScriptBuilderRelease

Complete release workflow combining version bump, file updates, and build.

**Priority:** HIGH  
**Impact:** Automates 90% of standard release workflow

**Signature:**

```powershell
function Invoke-PSScriptBuilderRelease {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Major", "Minor", "Patch")]
        [string] $BumpType,
        
        [Parameter(Mandatory = $false)]
        [string] $Prerelease,
        
        [Parameter(Mandatory = $false)]
        [switch] $SkipBuild,
        
        [Parameter(Mandatory = $false)]
        [switch] $GitTag,
        
        [Parameter(Mandatory = $false)]
        [switch] $GitPush
    )
}
```

**Description:**

Executes complete release workflow:
1. Bump version (Major/Minor/Patch)
2. Update BumpFiles
3. Build module (optional)
4. Create Git tag (optional)
5. Push to remote (optional)

**Examples:**

```powershell
# Standard minor release
Invoke-PSScriptBuilderRelease -BumpType Minor

# Major release with prerelease marker
Invoke-PSScriptBuilderRelease -BumpType Major -Prerelease "beta.1"

# Release with Git tagging
Invoke-PSScriptBuilderRelease -BumpType Patch -GitTag -GitPush

# Dry-run to see execution plan
Invoke-PSScriptBuilderRelease -BumpType Minor -WhatIf

# Output:
# What if: Performing release workflow with following steps:
#   1. Bump version: Minor (1.2.3 -> 1.3.0)
#   2. Update BumpFiles: 5 files
#   3. Build module: PSScriptBuilder.psm1
#   4. Git tag: v1.3.0 (skipped - not requested)
#   5. Git push: (skipped - not requested)
```

**Benefits:**
- Single command for complete release
- Consistent release process
- WhatIf support shows full plan
- Rollback on any step failure

---

#### Test-PSScriptBuilderProject

Comprehensive validation suite for entire project.

**Priority:** HIGH  
**Impact:** Catches issues before build, better error messages

**Signature:**

```powershell
function Test-PSScriptBuilderProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Quick", "Full", "Comprehensive")]
        [string] $ValidationLevel = "Full",
        
        [Parameter(Mandatory = $false)]
        [switch] $FixIssues
    )
}
```

**Description:**

Validates entire project setup:
- Configuration file (psscriptbuilder.config.json)
- Template files
- Dependency analysis (cycles, cross-dependencies)
- BumpFiles configuration
- Release data
- Directory structure

**Examples:**

```powershell
# Full validation
Test-PSScriptBuilderProject

# Quick validation (config and template only)
Test-PSScriptBuilderProject -ValidationLevel Quick

# Comprehensive (includes build simulation)
Test-PSScriptBuilderProject -ValidationLevel Comprehensive

# Fix common issues automatically
Test-PSScriptBuilderProject -FixIssues

# Output:
# ✓ Configuration: Valid
# ✓ Template: Valid (CrossDependencies mode)
# ✓ Dependencies: No cycles detected
# ✓ BumpFiles: 5 files configured, all exist
# ⚠ Release data: BuildDate token missing in template
# ✗ Directory: Output directory does not exist
#
# Issues Found: 2
# Fixable: 1 (use -FixIssues to auto-fix)
```

**Validation Levels:**

- **Quick** - Config + Template syntax only (~100ms)
- **Full** - Config + Template + Dependencies + Files (~500ms, default)
- **Comprehensive** - All checks + Build simulation (~2s)

---

### 2. Collector Management Extensions

#### Show-PSScriptBuilderCollectorContent

Displays collected content for debugging and inspection.

**Priority:** MEDIUM  
**Impact:** Improves debugging experience

**Signature:**

```powershell
function Show-PSScriptBuilderCollectorContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSScriptBuilderCollectorBase] $Collector,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Summary", "Detailed", "Raw")]
        [string] $Format = "Summary"
    )
}
```

**Description:**

Displays what a collector has collected (classes, functions, etc.) with formatting options.

**Examples:**

```powershell
# Show summary of collected items
$collector | Show-PSScriptBuilderCollectorContent

# Detailed view with source files
$collector | Show-PSScriptBuilderCollectorContent -Format Detailed

# Raw AST output
$collector | Show-PSScriptBuilderCollectorContent -Format Raw

# Summary Output:
# Collector: CLASSES_DOMAIN
# Type: ClassCollector
# Status: Executed
#
# Collected Items (12):
#   - PSScriptBuilderBase
#   - PSScriptBuilderLogger
#   - PSScriptBuilderConfiguration
#   ... (9 more)
#
# Source Files (8):
#   - src/Classes/Common/PSScriptBuilderBase.ps1
#   - src/Classes/Common/PSScriptBuilderLogger.ps1
#   ... (6 more)
```

---

#### Get-PSScriptBuilderCollector (Enhancement)

Extend existing cmdlet with better querying.

**Enhancement:**

```powershell
# Already exists, add these features:

# List collectors by multiple types
Get-PSScriptBuilderCollector -ContentCollector $cc -CollectorType Class,Function

# Filter by pattern
Get-PSScriptBuilderCollector -ContentCollector $cc -KeyPattern "CLASSES_*"

# Include execution status
Get-PSScriptBuilderCollector -ContentCollector $cc -IncludeStatus

# Output with status:
# CollectionKey    Type      Status      ComponentCount
# -------------    ----      ------      --------------
# CLASSES_DOMAIN   Class     Executed    12
# CLASSES_UTILS    Class     Not Run     0
# FUNCTIONS_PUBLIC Function  Executed    34
```

---

### 3. Project Setup & Onboarding

#### New-PSScriptBuilderProject

Interactive project setup wizard.

**Priority:** HIGH  
**Impact:** Massive onboarding improvement for new users

**Signature:**

```powershell
function New-PSScriptBuilderProject {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string] $Path = $PWD,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Module", "Script", "Library")]
        [string] $Type = "Module",
        
        [Parameter(Mandatory = $false)]
        [switch] $Interactive,
        
        [Parameter(Mandatory = $false)]
        [switch] $IncludeExamples
    )
}
```

**Description:**

Creates complete project structure with:
- Configuration file (psscriptbuilder.config.json)
- Template file (with appropriate placeholders)
- Directory structure (src/, build/, docs/)
- Example files (optional)
- .gitignore with PSScriptBuilder entries

**Examples:**

```powershell
# Interactive wizard
New-PSScriptBuilderProject -Interactive

# Wizard Flow:
# 
# PSScriptBuilder Project Setup
# =============================
# 
# Project Name: MyModule
# Project Type: [Module] Script Library
# Include Classes? [Y/n]: y
# Include Functions? [Y/n]: y
# Include Enums? [Y/n]: n
# Include Examples? [y/N]: y
# 
# Creating structure...
#   ✓ Created: psscriptbuilder.config.json
#   ✓ Created: build/templates/MyModule.psm1.template
#   ✓ Created: src/Classes/
#   ✓ Created: src/Public/
#   ✓ Created: examples/MyClass.ps1
#   ✓ Created: examples/MyFunction.ps1
# 
# Next Steps:
#   1. Review: psscriptbuilder.config.json
#   2. Add your code to: src/Classes/, src/Public/
#   3. Build: Invoke-PSScriptBuilderBuild
#   4. Learn: Get-PSScriptBuilderWorkflow -Scenario "FirstBuild"

# Non-interactive with defaults
New-PSScriptBuilderProject -Path "C:\Projects\MyModule" -Type Module -IncludeExamples
```

---

#### New-PSScriptBuilderTemplate

Interactive template creation wizard.

**Priority:** MEDIUM  
**Impact:** Simplifies template creation

**Signature:**

```powershell
function New-PSScriptBuilderTemplate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string] $OutputPath,
        
        [Parameter(Mandatory = $false)]
        [PSScriptBuilderContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $false)]
        [switch] $Interactive
    )
}
```

**Description:**

Creates template file based on registered collectors or interactive choices.

**Examples:**

```powershell
# From existing ContentCollector
New-PSScriptBuilderTemplate -ContentCollector $cc -OutputPath "template.psm1"

# Interactive wizard
New-PSScriptBuilderTemplate -Interactive

# Output (for collector with Class+Function):
# 
# # This template was auto-generated by PSScriptBuilder
# # Date: 2026-03-13
# 
# using namespace System
# 
# {{USING}}
# 
# {{ENUM}}
# 
# {{CLASS}}
# 
# {{FUNCTION}}
```

---

### 4. Status & Overview

#### Show-PSScriptBuilderStatus

Dashboard showing complete project status.

**Priority:** HIGH  
**Impact:** Huge visibility improvement, better UX

**Signature:**

```powershell
function Show-PSScriptBuilderStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch] $Detailed
    )
}
```

**Description:**

Displays comprehensive project status dashboard.

**Examples:**

```powershell
# Quick status
Show-PSScriptBuilderStatus

# Output:
# PSScriptBuilder Project Status
# ==============================
# 
# Configuration
#   ✓ Config file: psscriptbuilder.config.json
#   ✓ Project root: C:\Projects\PSScriptBuilder
#   ✓ Template: build/templates/PSScriptBuilder.psm1.template
# 
# Collectors (4 registered)
#   ✓ USING          (UsingCollector)    - Not executed
#   ✓ ENUM           (EnumCollector)     - Not executed
#   ✓ CLASS          (ClassCollector)    - Not executed
#   ✓ FUNCTION       (FunctionCollector) - Not executed
# 
# Dependencies
#   ⚠ Not analyzed yet (use Get-PSScriptBuilderDependencyAnalysis)
# 
# Template
#   ✓ Valid (CrossDependencies mode)
#   ✓ All placeholders present
# 
# Release
#   Version: 1.0.0
#   Build: 42
#   Last build: 2026-03-13 09:30:15
#   Git: main @ a1b2c3d
# 
# Last Build
#   ⚠ No build executed yet
#   Tip: Run Invoke-PSScriptBuilderBuild to create first build

# Detailed status with file counts
Show-PSScriptBuilderStatus -Detailed
```

---

#### Get-PSScriptBuilderWorkflow

Shows example code for common scenarios.

**Priority:** MEDIUM  
**Impact:** Improves discoverability, learning curve

**Signature:**

```powershell
function Get-PSScriptBuilderWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("FirstBuild", "Release", "Validation", "Debugging", "AllScenarios")]
        [string] $Scenario = "AllScenarios"
    )
}
```

**Description:**

Displays copy-pasteable example code for common workflows.

**Examples:**

```powershell
# Show first build workflow
Get-PSScriptBuilderWorkflow -Scenario FirstBuild

# Output:
# 
# First Build Workflow
# ====================
# 
# # 1. Set project root
# Set-PSScriptBuilderProjectRoot -Path "C:\Your\Project"
# 
# # 2. Create ContentCollector and add collectors
# $cc = New-PSScriptBuilderContentCollector
# $cc = $cc | Add-PSScriptBuilderCollector -Type Class -IncludePath "src/Classes"
# $cc = $cc | Add-PSScriptBuilderCollector -Type Function -IncludePath "src/Public"
# 
# # 3. Validate template
# Test-PSScriptBuilderTemplate -ContentCollector $cc -TemplatePath "template.psm1"
# 
# # 4. Execute build
# Invoke-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath "template.psm1"
# 
# Tip: Use -WhatIf on any cmdlet to see what would happen without executing

# Show all scenarios
Get-PSScriptBuilderWorkflow -Scenario AllScenarios
```

---

### 5. Configuration Management

#### Test-PSScriptBuilderConfiguration (Enhancement)

Validate configuration without loading.

**Priority:** MEDIUM  
**Impact:** Safer configuration changes

**Signature:**

```powershell
function Test-PSScriptBuilderConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $Path,
        
        [Parameter(Mandatory = $false)]
        [switch] $Detailed
    )
}
```

**Description:**

Validates configuration file structure and values without loading into static cache.

**Examples:**

```powershell
# Validate specific file
Test-PSScriptBuilderConfiguration -Path "custom.config.json"

# Validate current configuration
Test-PSScriptBuilderConfiguration -Detailed

# Output:
# ✓ JSON syntax: Valid
# ✓ Required properties: Present
# ✓ Log options: Valid
# ✓ Build options: Valid
# ✓ Release options: Valid
# ✓ File paths: All exist
# ⚠ Warning: OutputPath is relative (recommended: absolute path)
# 
# Overall: Valid (1 warning)
```

---

#### Backup-PSScriptBuilderConfiguration / Restore-PSScriptBuilderConfiguration

Configuration backup and restore.

**Priority:** LOW  
**Impact:** Safety net for configuration changes

**Signatures:**

```powershell
function Backup-PSScriptBuilderConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $BackupPath = ".\backups"
    )
}

function Restore-PSScriptBuilderConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $BackupId
    )
}
```

**Examples:**

```powershell
# Create backup
Backup-PSScriptBuilderConfiguration

# Output:
# Backup created: backups/config_20260313_093015.json
# Backup ID: 20260313_093015

# List backups
Get-ChildItem .\backups -Filter "config_*.json"

# Restore from backup
Restore-PSScriptBuilderConfiguration -BackupId "20260313_093015"
```

---

### 6. Build Variants

#### Test-PSScriptBuilderBuild

Dry-run build validation without output.

**Priority:** MEDIUM  
**Impact:** Catches build issues early

**Signature:**

```powershell
function Test-PSScriptBuilderBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSScriptBuilderContentCollector] $ContentCollector,
        
        [Parameter(Mandatory = $true)]
        [string] $TemplatePath
    )
}
```

**Description:**

Executes complete build process but discards output. Reports only success/failure with detailed error messages if build fails.

**Examples:**

```powershell
# Validate build without creating output
Test-PSScriptBuilderBuild -ContentCollector $cc -TemplatePath "template.psm1"

# Output on success:
# ✓ Build validation successful
#   Components: 156
#   Estimated size: 245 KB
#   Template: Valid

# Output on failure:
# ✗ Build validation failed
#   Error: Missing placeholder {{CLASS}} in template
#   Location: template.psm1
#   Collector: CLASSES_DOMAIN (12 classes collected)
```

---

#### Invoke-PSScriptBuilderBuild (Enhancement)

Add profile support for build configurations.

**Priority:** LOW  
**Impact:** Convenience for multi-environment builds

**Enhancement:**

```powershell
# Add -Profile parameter to existing cmdlet

Invoke-PSScriptBuilderBuild -Profile "Development"
Invoke-PSScriptBuilderBuild -Profile "Production"

# Configuration in psscriptbuilder.config.json:
# {
#   "profiles": {
#     "Development": {
#       "template": "templates/dev.template",
#       "outputPath": "build/dev",
#       "collectors": ["CLASS", "FUNCTION"]
#     },
#     "Production": {
#       "template": "templates/prod.template",
#       "outputPath": "build/release",
#       "collectors": ["USING", "ENUM", "CLASS", "FUNCTION", "FILE"]
#     }
#   }
# }
```

---

## Future Enhancements

1. **Cmdlet Aliases** - Shorter names for common operations

   ```powershell
   New-PSBContentCollector  # alias for New-PSScriptBuilderContentCollector
   ```

2. **Pipeline Chaining** - Full PowerShell pipelining

   ```powershell
   Get-PSScriptBuilderCollector | Where-Object { $_.Type -eq "Class" } | Remove-PSScriptBuilderCollector
   ```

3. **Batch Operations** - Process multiple modules

   ```powershell
   Get-PSScriptBuilderModule | Build-PSScriptBuilderModule
   ```

4. **Performance Profiling**

   ```powershell
   Invoke-PSScriptBuilderContentCollector -Profile
   ```

---

## References

- [Command Pattern Documentation](command-pattern-version-management.md)
- [Collector Pattern Documentation](script-building-architecture.md)
- [Static Configuration Pattern](../src/Classes/Configuration/PSScriptBuilderConfiguration.ps1)
- [PowerShell ShouldProcess Pattern](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute)

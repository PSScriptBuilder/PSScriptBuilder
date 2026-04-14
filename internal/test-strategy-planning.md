# PSScriptBuilder Test Strategy & Planning

**Version**: 1.0
**Date**: 2026-03-11
**Status**: Planning Phase

---

## Table of Contents

1. [Overview](#overview)
2. [Component Inventory](#component-inventory)
3. [Test Categorization](#test-categorization)
4. [Test Strategies by Component Type](#test-strategies-by-component-type)
5. [Best Practices](#best-practices)
6. [Prioritization Matrix](#prioritization-matrix)
7. [Implementation Phases](#implementation-phases)
8. [Effort Estimation](#effort-estimation)
9. [Risks & Challenges](#risks--challenges)
10. [Templates & Examples](#templates--examples)

---

## Overview

### Objectives

- **Comprehensive Coverage**: Test all critical components with focus on edge cases
- **Quality Assurance**: Ensure reliability of build system and release management
- **Regression Prevention**: Catch breaking changes early
- **Documentation**: Tests serve as living documentation of expected behavior

### Scope

PSScriptBuilder consists of **3 major subsystems**:

1. **Configuration System** - Config loading, validation, options management
2. **Script Builder System** - AST parsing, collectors, dependency analysis, template processing
3. **Release Management System** - Version bumping, release data management, file processing

### Current Status

✅ **Completed**:

- Test infrastructure directory structure established
- Custom matchers (4 matchers + 4 tests) - English translation complete
- Test organization: Hybrid approach (Unit/Configuration, Unit/ScriptBuilder, Unit/ReleaseManagement, Unit/Common, Integration)

⏳ **Pending**: ~75 test files to be created

---

## Component Inventory

### 1. Configuration System (8 Components)

#### 1.1 Core Configuration (3 Classes)

- `PSScriptBuilderConfigLoader` - Loads configuration from JSON
- `PSScriptBuilderConfiguration` - Main configuration container
- `PSScriptBuilderConfigValidator` - Validates configuration structure

#### 1.2 Options (3 Classes)

- `PSScriptBuilderOptionsBase` - Base class for options
- `PSScriptBuilderBuildOptions` - Build-specific options
- `PSScriptBuilderReleaseOptions` - Release-specific options

#### 1.3 Public Functions (2 Cmdlets)

- `Get-PSScriptBuilderConfiguration`
- `Set-PSScriptBuilderProjectRoot`

---

### 2. Script Builder System (31 Components)

#### 2.1 Helper Classes (3 Classes)

- ✅ `PSScriptBuilderAstEngine` - **TESTED** (AST parsing and analysis)
- `PSScriptBuilderFileSystemHelper` - File/directory operations
- `PSScriptBuilderFileIOHelper` - Read/write operations

#### 2.2 Data Classes (5 Classes)

- `PSScriptBuilderClassData` - Class information container
- `PSScriptBuilderFunctionData` - Function information container
- `PSScriptBuilderEnumData` - Enum information container
- `PSScriptBuilderUsingData` - Using statement container
- `PSScriptBuilderFileData` - File content container

#### 2.3 Core (4 Classes)

- `PSScriptBuilderCollectorBase` - Abstract base for collectors (Template Method)
- `PSScriptBuilderCollectorCollection` - Collection of collectors
- `PSScriptBuilderContentCollector` - Orchestrates collection process
- `PSScriptBuilderContentProcessor` - Processes collected content

#### 2.4 Collectors (5 Classes)

- `PSScriptBuilderEnumCollector` - Collects enumerations
- `PSScriptBuilderClassCollector` - Collects classes
- `PSScriptBuilderFunctionCollector` - Collects functions
- `PSScriptBuilderUsingCollector` - Collects using statements
- `PSScriptBuilderFileCollector` - Collects file content

#### 2.5 Dependencies (5 Classes)

- `PSScriptBuilderDependencyGraph` - Graph data structure
- `PSScriptBuilderDependencyGraphBuilder` - Builds dependency graph
- `PSScriptBuilderCycleDetector` - Detects circular dependencies
- `PSScriptBuilderCrossDependencyDetector` - Detects cross-file dependencies
- `PSScriptBuilderTopologicalSorter` - Sorts dependencies topologically

#### 2.6 Results (3 Classes)

- `PSScriptBuilderBuildResult` - Build operation result
- `PSScriptBuilderBuildComponentCounts` - Component statistics
- `PSScriptBuilderBuildComponentDetail` - Detailed component info

#### 2.7 Public Functions (6 Cmdlets)

- `Invoke-PSScriptBuilderBuild` - Main build cmdlet
- `Get-PSScriptBuilderDependencyAnalysis` - Analyze dependencies
- `Add-PSScriptBuilderCollector` - Add custom collector
- `New-PSScriptBuilderCollector` - Create collector instance
- `New-PSScriptBuilderContentCollector` - Create content collector
- `Format-PSScriptBuilderBuildResult` - Format build output

---

### 3. Release Management System (22 Components)

#### 3.1 Helper (1 Class)

- `PSScriptBuilderBumpReplacementHelper` - Token replacement logic

#### 3.2 Managers (4 Classes)

- `PSScriptBuilderBumpConfigFileManager` - Manages bump config files
- `PSScriptBuilderBumpFilesProcessor` - Processes version bumps
- `PSScriptBuilderReleaseDataFileManager` - Manages release data files
- `PSScriptBuilderReleaseDataProcessor` - Processes release data

#### 3.3 Orchestrators (1 Class)

- `PSScriptBuilderReleaseManagementOrchestrator` - Coordinates release operations

#### 3.4 Requests (1 Class)

- `PSScriptBuilderReleaseDataOperationRequest` - Request object for operations

#### 3.5 Results (2 Classes)

- `PSScriptBuilderBumpFilesResult` - Bump operation result
- `PSScriptBuilderReleaseDataResult` - Release data operation result

#### 3.6 Validators (2 Classes)

- `PSScriptBuilderBumpFilesValidator` - Validates bump configuration
- `PSScriptBuilderReleaseDataValidator` - Validates release data

#### 3.7 Public Functions (11 Cmdlets)

- `Get-PSScriptBuilderBumpConfiguration` - Retrieve bump config
- `Test-PSScriptBuilderBumpConfiguration` - Validate bump config
- `Update-PSScriptBuilderBumpFiles` - Execute version bump
- `Get-PSScriptBuilderReleaseData` - Retrieve release data
- `New-PSScriptBuilderReleaseData` - Create release data
- `Test-PSScriptBuilderReleaseData` - Validate release data
- `Update-PSScriptBuilderReleaseData` - Update release data
- `Get-PSScriptBuilderReleaseDataTokens` - Get available tokens
- `Format-PSScriptBuilderBumpResult` - Format bump output
- `Format-PSScriptBuilderReleaseDataResult` - Format release data output

---

### 4. Common/Support (5 Components)

#### 4.1 Common Classes (2 Classes)

- `PSScriptBuilderBase` - Base class for all components
- `PSScriptBuilderLogger` - Logging functionality

#### 4.2 Private Functions (1 Function)

- `Get-PSScriptBuilderProjectRoot` - Internal project root retrieval

#### 4.3 Enums (2 Enums)

- `PSScriptBuilderBumpType` - Major, Minor, Patch
- `PSScriptBuilderCollectorType` - Using, Enum, Class, Function, File

---

## Test Categorization

### Unit Tests (~75 test files)

**Focus**: Individual component behavior in isolation

**Categories**:

1. **Helper Classes** (3 files)
2. **Data Classes** (5 files)
3. **Core Classes** (4 files)
4. **Collectors** (5 files)
5. **Dependencies** (5 files)
6. **Results** (5 files)
7. **Configuration** (6 files)
8. **Release Management** (10 files)
9. **Public Functions** (19 files)
10. **Common/Enums** (6 files)

### Integration Tests (~15 test files)

**Focus**: Interaction between components

**Categories**:

1. **End-to-End Build** (3 scenarios)
2. **Dependency Resolution** (4 scenarios)
3. **Release Workflow** (5 scenarios)
4. **Configuration Loading** (3 scenarios)

---

## Test Strategies by Component Type

### Strategy 1: Helper Classes (FileSystem, FileIO, Ast)

**Characteristics**:

- Static methods or stateless operations
- Heavy I/O interaction
- Many edge cases (permissions, invalid paths, encoding)

**Test Approach**:

```powershell
Describe 'PSScriptBuilderFileSystemHelper' {
    BeforeAll {
        # Setup TestDrive structure
    }
    
    Context 'ValidatePath' {
        It 'Should accept valid absolute paths' {
            # AAA pattern
        }
        
        It 'Should reject null paths' -TestCases @(
            @{ Path = $null }
            @{ Path = '' }
            @{ Path = '   ' }
        ) {
            param($Path)
            # Test with Should -Throw
        }
        
        It 'Should handle path with invalid characters' {
            # Edge case
        }
    }
    
    Context 'File Operations' {
        It 'Should create directory recursively' {
            # Use TestDrive:
        }
        
        It 'Should handle locked files gracefully' {
            # Edge case with file lock
        }
    }
}
```

**Key Focus**:

- ✅ Null/empty/whitespace inputs
- ✅ Invalid characters
- ✅ Permission issues (read-only, locked)
- ✅ Large files
- ✅ Encoding edge cases (UTF8, UTF16, BOM)
- ✅ Path length limits

**Estimated Complexity**: Medium (many edge cases, I/O mocking)

---

### Strategy 2: Data Classes (ClassData, FunctionData, etc.)

**Characteristics**:

- Simple POCOs (Plain Old CLR Objects)
- Constructor validation
- Property getters
- Minimal logic

**Test Approach**:

```powershell
Describe 'PSScriptBuilderClassData' {
    Context 'Constructor' {
        It 'Should create instance with valid parameters' {
            # Arrange
            $name = 'TestClass'
            $sourceCode = 'class TestClass { }'
            $baseClass = 'BaseClass'
            $typeRefs = @('Type1', 'Type2')
            
            # Act
            $result = [PSScriptBuilderClassData]::new($name, $sourceCode, $baseClass, $typeRefs)
            
            # Assert
            $result | Should-HaveProperty 'ClassName'
            $result.ClassName | Should -Be $name
            $result.BaseClass | Should -Be $baseClass
            $result.TypeReferences.Count | Should -Be 2
        }
        
        It 'Should accept null BaseClass' {
            # Inheritance is optional
        }
        
        It 'Should handle empty TypeReferences' {
            # No dependencies
        }
        
        It 'Should throw on null ClassName' {
            # Constructor validation
        }
    }
    
    Context 'Properties' {
        BeforeEach {
            $script:testInstance = [PSScriptBuilderClassData]::new('Test', 'code', 'Base', @())
        }
        
        It 'Should have property <PropertyName> of type <ExpectedType>' -TestCases @(
            @{ PropertyName = 'ClassName'; ExpectedType = 'System.String' }
            @{ PropertyName = 'SourceCode'; ExpectedType = 'System.String' }
            @{ PropertyName = 'BaseClass'; ExpectedType = 'System.String' }
            @{ PropertyName = 'TypeReferences'; ExpectedType = 'System.String[]' }
        ) {
            param($PropertyName, $ExpectedType)
            $testInstance | Should-HavePropertyOfType $PropertyName $ExpectedType
        }
    }
}
```

**Key Focus**:

- ✅ Constructor parameter combinations
- ✅ Null/empty values (where allowed)
- ✅ Property types (use custom matcher)
- ✅ Immutability (if properties are read-only)
- ✅ Collection handling (arrays, hashtables)

**Estimated Complexity**: Low (straightforward, minimal logic)

---

### Strategy 3: Base Classes (CollectorBase, OptionsBase)

**Characteristics**:

- Abstract classes with Template Method pattern
- Protected/internal methods
- Inheritance hierarchy

**Test Approach**:

```powershell
Describe 'PSScriptBuilderCollectorBase' {
    BeforeAll {
        # Create concrete test implementation
        class TestCollector : PSScriptBuilderCollectorBase {
            TestCollector() : base([PSScriptBuilderCollectorType]::Class, 'TestKey') { }
            
            [void] CollectFromFiles([System.IO.FileInfo[]] $files) {
                # Minimal implementation for testing
                $this.ClassData.Add('TestClass', [PSScriptBuilderClassData]::new('TestClass', '', $null, @()))
            }
        }
    }
    
    Context 'Constructor' {
        It 'Should initialize with CollectorType and Key' {
            $collector = [TestCollector]::new()
            $collector.CollectorType | Should -Be ([PSScriptBuilderCollectorType]::Class)
            $collector.CollectionKey | Should -Be 'TestKey'
        }
    }
    
    Context 'Template Method - Collect()' {
        It 'Should execute in correct order: Reset → GetFilesToProcess → CollectFromFiles' {
            # Mock or spy on method calls to verify order
            # In PowerShell, this is tricky - use verbose output or state verification
        }
        
        It 'Should call Reset() before collection' {
            # Verify state is cleared
        }
    }
    
    Context 'Reset()' {
        It 'Should clear all data collections' {
            $collector = [TestCollector]::new()
            # Add some data
            $collector.ClassData.Add('Test', [PSScriptBuilderClassData]::new('Test', '', $null, @()))
            
            # Act
            $collector.Reset()
            
            # Assert
            $collector.ClassData.Count | Should -Be 0
        }
    }
}
```

**Key Focus**:

- ✅ Template Method execution order
- ✅ Abstract method implementation verification
- ✅ State management (Reset behavior)
- ✅ Protected member access (test through derived class)
- ✅ Inheritance behavior

**Estimated Complexity**: Medium-High (abstract classes, template pattern verification)

---

### Strategy 4: Collectors (EnumCollector, ClassCollector, etc.)

**Characteristics**:

- Inherit from CollectorBase
- AST-heavy (depend on AstEngine)
- Duplicate detection (Guard Clauses)
- File processing

**Test Approach**:

```powershell
Describe 'PSScriptBuilderClassCollector' {
    BeforeAll {
        # Helper to create test files in TestDrive
        function New-TestClassFile {
            param(
                [string]$FileName,
                [string]$Content
            )
            $path = Join-Path TestDrive: $FileName
            Set-Content -Path $path -Value $Content -Encoding UTF8
            Get-Item -Path $path
        }
    }
    
    Context 'Collection' {
        It 'Should collect single class from file' {
            # Arrange
            $file = New-TestClassFile 'Test.ps1' @'
class TestClass {
    [string] $Name
}
'@
            $collector = [PSScriptBuilderClassCollector]::new()
            
            # Act
            $collector.Collect(@($file))
            
            # Assert
            $collector.ClassData.Count | Should -Be 1
            $collector.ClassData.ContainsKey('TestClass') | Should -BeTrue
        }
        
        It 'Should collect multiple classes from multiple files' {
            # Test with 2+ files, 2+ classes each
        }
        
        It 'Should detect class inheritance (BaseClass)' {
            $file = New-TestClassFile 'Derived.ps1' 'class Derived : Base { }'
            $collector = [PSScriptBuilderClassCollector]::new()
            
            $collector.Collect(@($file))
            
            $collector.ClassData['Derived'].BaseClass | Should -Be 'Base'
        }
        
        It 'Should detect type references in properties' {
            $file = New-TestClassFile 'WithRefs.ps1' @'
class MyClass {
    [CustomType] $Property
    [System.Collections.Generic.List[string]] $List
}
'@
            $collector = [PSScriptBuilderClassCollector]::new()
            
            $collector.Collect(@($file))
            
            $typeRefs = $collector.ClassData['MyClass'].TypeReferences
            $typeRefs | Should -Contain 'CustomType'
            $typeRefs | Should -Contain 'System.Collections.Generic.List'
        }
    }
    
    Context 'Duplicate Detection' {
        It 'Should throw InvalidOperationException on duplicate class name' {
            $file1 = New-TestClassFile 'File1.ps1' 'class DuplicateClass { }'
            $file2 = New-TestClassFile 'File2.ps1' 'class DuplicateClass { }'
            $collector = [PSScriptBuilderClassCollector]::new()
            
            # Act & Assert
            { $collector.Collect(@($file1, $file2)) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
        
        It 'Should include filename in duplicate error message' {
            # Verify error message contains file path
        }
    }
    
    Context 'Reset Behavior' {
        It 'Should be idempotent - multiple Collect() calls produce same result' {
            $file = New-TestClassFile 'Test.ps1' 'class TestClass { }'
            $collector = [PSScriptBuilderClassCollector]::new()
            
            # First collection
            $collector.Collect(@($file))
            $firstCount = $collector.ClassData.Count
            
            # Second collection (should reset)
            $collector.Collect(@($file))
            $secondCount = $collector.ClassData.Count
            
            $secondCount | Should -Be $firstCount
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle empty file list' {
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.Collect(@())
            $collector.ClassData.Count | Should -Be 0
        }
        
        It 'Should handle file with no classes' {
            $file = New-TestClassFile 'NoClass.ps1' 'Write-Host "Just a script"'
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.Collect(@($file))
            $collector.ClassData.Count | Should -Be 0
        }
        
        It 'Should handle nested classes (should skip)' {
            # Nested classes not supported in PS 5.1, but test AST filtering
        }
        
        It 'Should preserve exact source code formatting' {
            # Verify SourceCode property matches original
        }
    }
    
    Context 'Verbose Output' {
        It 'Should write verbose messages during collection' {
            $file = New-TestClassFile 'Verbose.ps1' 'class VerboseClass { }'
            $collector = [PSScriptBuilderClassCollector]::new()
            
            # Capture verbose stream
            $verboseOutput = $collector.Collect(@($file)) 4>&1
            
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Should -Match 'Starting collection'
            $verboseOutput | Should -Match 'Parsing:'
            $verboseOutput | Should -Match 'Collection complete'
        }
    }
}
```

**Key Focus**:

- ✅ Single vs. multiple file collection
- ✅ Duplicate detection (Guard Clauses)
- ✅ Type reference extraction
- ✅ Base class detection
- ✅ Reset idempotency
- ✅ Empty file handling
- ✅ Source code preservation
- ✅ Verbose logging

**Estimated Complexity**: High (complex logic, AST interaction, many scenarios)

---

### Strategy 5: Dependency System (Graph, Builder, Sorter, Detectors)

**Characteristics**:

- Graph algorithms (cycle detection, topological sort)
- Complex data structures
- Algorithmic correctness critical

**Test Approach**:

```powershell
Describe 'PSScriptBuilderDependencyGraph' {
    Context 'Graph Construction' {
        It 'Should add nodes to graph' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddNode('ClassA')
            $graph.AddNode('ClassB')
            
            $graph.Nodes.Count | Should -Be 2
        }
        
        It 'Should add edges between nodes' {
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddNode('ClassA')
            $graph.AddNode('ClassB')
            $graph.AddEdge('ClassA', 'ClassB')  # ClassA depends on ClassB
            
            $graph.GetDependencies('ClassA') | Should -Contain 'ClassB'
        }
        
        It 'Should handle duplicate node additions gracefully' {
            # Idempotent behavior
        }
    }
}

Describe 'PSScriptBuilderCycleDetector' {
    Context 'Cycle Detection' {
        It 'Should detect simple cycle (A → B → A)' {
            # Arrange
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddNode('A')
            $graph.AddNode('B')
            $graph.AddEdge('A', 'B')
            $graph.AddEdge('B', 'A')
            $detector = [PSScriptBuilderCycleDetector]::new()
            
            # Act
            $result = $detector.DetectCycles($graph)
            
            # Assert
            $result.HasCycles | Should -BeTrue
            $result.CyclePaths.Count | Should -BeGreaterThan 0
        }
        
        It 'Should detect complex cycle (A → B → C → A)' {
            # 3+ node cycle
        }
        
        It 'Should report all cycles in graph' {
            # Multiple disconnected cycles
        }
        
        It 'Should return no cycles for acyclic graph' {
            # DAG (Directed Acyclic Graph)
        }
    }
}

Describe 'PSScriptBuilderTopologicalSorter' {
    Context 'Topological Sort' {
        It 'Should sort simple dependency chain (C → B → A)' {
            # Arrange
            $graph = [PSScriptBuilderDependencyGraph]::new()
            $graph.AddNode('A')
            $graph.AddNode('B')
            $graph.AddNode('C')
            $graph.AddEdge('C', 'B')  # C depends on B
            $graph.AddEdge('B', 'A')  # B depends on A
            $sorter = [PSScriptBuilderTopologicalSorter]::new()
            
            # Act
            $sorted = $sorter.Sort($graph)
            
            # Assert
            $sorted[0] | Should -Be 'A'  # No dependencies
            $sorted[1] | Should -Be 'B'  # Depends on A
            $sorted[2] | Should -Be 'C'  # Depends on B
        }
        
        It 'Should handle diamond dependency (D → B,C → A)' {
            # Multiple paths to same node
        }
        
        It 'Should throw on cyclic graph' {
            # Cannot sort cyclic graph
        }
        
        It 'Should handle disconnected components' {
            # Multiple independent subgraphs
        }
    }
}

Describe 'PSScriptBuilderDependencyGraphBuilder' {
    Context 'Graph Building from Collections' {
        It 'Should build graph from ClassData collection' {
            # Use mock ClassData with type references
        }
        
        It 'Should create edges based on TypeReferences' {
            # ClassA references ClassB → edge A→B
        }
        
        It 'Should handle classes with no dependencies' {
            # Isolated nodes
        }
        
        It 'Should ignore built-in types (not create edges)' {
            # TypeReferences to System.* should not create edges
        }
    }
}
```

**Key Focus**:

- ✅ Graph correctness (nodes, edges)
- ✅ Cycle detection accuracy (simple, complex, none)
- ✅ Topological sort correctness
- ✅ Edge cases (disconnected graphs, multiple cycles)
- ✅ Performance (large graphs)
- ✅ Error handling (invalid operations)

**Estimated Complexity**: Very High (algorithmic complexity, many edge cases)

---

### Strategy 6: Configuration System

**Characteristics**:

- JSON loading/validation
- Schema validation
- Options hierarchy

**Test Approach**:

```powershell
Describe 'PSScriptBuilderConfigLoader' {
    Context 'Loading Configuration' {
        It 'Should load valid configuration from JSON' {
            # Use TestDrive with sample config
        }
        
        It 'Should throw on invalid JSON syntax' {
            # Malformed JSON
        }
        
        It 'Should throw on missing required fields' {
            # Schema validation
        }
        
        It 'Should apply defaults for optional fields' {
            # Default values
        }
    }
}

Describe 'PSScriptBuilderConfigValidator' {
    Context 'Validation Rules' {
        It 'Should validate source paths exist' {
            # File system checks
        }
        
        It 'Should validate output directory is writable' {
            # Permission checks
        }
        
        It 'Should validate template file exists' {
            # Template validation
        }
    }
}
```

**Key Focus**:

- ✅ JSON parsing errors
- ✅ Schema validation
- ✅ Default values
- ✅ File system validation
- ✅ Options cascade (base → derived)

**Estimated Complexity**: Medium (JSON handling, validation logic)

---

### Strategy 7: Release Management System

**Characteristics**:

- File manipulation (read/write/replace)
- Version number logic
- Token replacement
- Multi-step workflows

**Test Approach**:

```powershell
Describe 'PSScriptBuilderBumpFilesProcessor' {
    Context 'Version Bumping' {
        It 'Should bump major version (1.2.3 → 2.0.0)' {
            # Test Major bump
        }
        
        It 'Should bump minor version (1.2.3 → 1.3.0)' {
            # Test Minor bump
        }
        
        It 'Should bump patch version (1.2.3 → 1.2.4)' {
            # Test Patch bump
        }
        
        It 'Should update all files specified in configuration' {
            # Multi-file update
        }
        
        It 'Should preserve file content except version token' {
            # Only replace version, nothing else
        }
    }
}

Describe 'PSScriptBuilderReleaseDataProcessor' {
    Context 'Token Replacement' {
        It 'Should replace {{VERSION}} token' { }
        It 'Should replace {{DATE}} token with current date' { }
        It 'Should replace {{AUTHOR}} token' { }
        It 'Should handle missing tokens gracefully' { }
        It 'Should preserve unknown tokens' { }
    }
}

Describe 'PSScriptBuilderBumpReplacementHelper' {
    Context 'String Replacement' {
        It 'Should replace version in simple format (Version = "1.0.0")' { }
        It 'Should replace version in PSD1 module manifest' { }
        It 'Should replace version in JSON' { }
        It 'Should handle multiple occurrences' { }
        It 'Should preserve surrounding whitespace' { }
    }
}
```

**Key Focus**:

- ✅ Version arithmetic correctness
- ✅ File I/O safety (backups, error recovery)
- ✅ Token replacement accuracy
- ✅ Multi-file consistency
- ✅ Date/time formatting
- ✅ Regex pattern matching

**Estimated Complexity**: High (file manipulation, regex, multi-step workflows)

---

### Strategy 8: Public Functions (Cmdlets)

**Characteristics**:

- User-facing APIs
- Parameter validation
- Pipeline support
- Help documentation

**Test Approach**:

```powershell
Describe 'Invoke-PSScriptBuilderBuild' {
    Context 'Parameter Validation' {
        It 'Should have mandatory SourcePath parameter' {
            (Get-Command Invoke-PSScriptBuilderBuild).Parameters['SourcePath'].Attributes.Mandatory | Should -BeTrue
        }
        
        It 'Should validate SourcePath exists (ValidateScript)' {
            # Test with non-existent path
        }
    }
    
    Context 'Pipeline Support' {
        It 'Should accept SourcePath from pipeline by value' {
            # Test ValueFromPipeline
        }
        
        It 'Should accept SourcePath from pipeline by property name' {
            # Test ValueFromPipelineByPropertyName
        }
    }
    
    Context 'Execution' {
        It 'Should execute build with valid parameters' {
            # Integration test with real files
        }
        
        It 'Should return BuildResult object' {
            # Type check
        }
        
        It 'Should write verbose output when -Verbose is specified' {
            # Test verbose stream
        }
    }
    
    Context 'Error Handling' {
        It 'Should throw on circular dependency' {
            # Error scenario
        }
        
        It 'Should provide meaningful error message' {
            # Error message quality
        }
    }
}

Describe 'Get-PSScriptBuilderConfiguration' {
    Context 'Loading Configuration' {
        It 'Should load default configuration from current directory' {
            # Default behavior
        }
        
        It 'Should accept custom config path parameter' {
            # -ConfigPath parameter
        }
        
        It 'Should throw if config file not found' {
            # File not found error
        }
    }
}
```

**Key Focus**:

- ✅ Parameter validation
- ✅ Pipeline support
- ✅ ShouldProcess support (if applicable)
- ✅ Error handling
- ✅ Return type correctness
- ✅ Verbose/Debug output
- ✅ Help documentation completeness

**Estimated Complexity**: Medium (parameter testing straightforward, integration overlap)

---

### Strategy 9: Integration Tests

**Characteristics**:

- Multi-component interaction
- Real file system usage
- End-to-end scenarios

**Test Approach**:

```powershell
Describe 'Build Pipeline Integration' {
    BeforeAll {
        # Setup complete test project in TestDrive
        # Include: Enums, Classes, Functions, Using statements
    }
    
    Context 'Complete Build Workflow' {
        It 'Should build simple project with single class' {
            # Minimal project
        }
        
        It 'Should build project with class inheritance' {
            # Base class must appear before derived
        }
        
        It 'Should build project with cross-file dependencies' {
            # ClassA in File1 depends on ClassB in File2
        }
        
        It 'Should handle all collector types (Using, Enum, Class, Function, File)' {
            # Comprehensive project
        }
        
        It 'Should produce valid PowerShell module' {
            # Output can be imported
            # Output contains all components
        }
    }
    
    Context 'Dependency Resolution' {
        It 'Should detect and report circular dependency' {
            # ClassA → ClassB → ClassA
        }
        
        It 'Should sort classes in topological order' {
            # Verify output order
        }
    }
    
    Context 'Template Processing' {
        It 'Should replace all placeholders in template' {
            # {{USING}}, {{ENUMS}}, {{CLASSES}}, {{FUNCTIONS}}, {{FILES}}
        }
        
        It 'Should preserve template structure' {
            # Only replace placeholders
        }
    }
}

Describe 'Release Workflow Integration' {
    Context 'Complete Bump Workflow' {
        It 'Should bump version in multiple files' {
            # Update CHANGELOG.md, module manifest, release data
        }
        
        It 'Should maintain version consistency across files' {
            # All files show same version
        }
    }
    
    Context 'Complete Release Data Workflow' {
        It 'Should create release data with all tokens' {
            # VERSION, DATE, AUTHOR, etc.
        }
        
        It 'Should update release notes file' {
            # Append to or overwrite release notes
        }
    }
}

Describe 'Example Projects Validation' {
    Context 'Example 1 - Simple Class' {
        It 'Should build example successfully' { }
        It 'Should produce importable module' { }
        It 'Should execute example script' { }
    }
    
    # Repeat for all 8 examples
}
```

**Key Focus**:

- ✅ Real-world scenarios
- ✅ Multi-component interaction
- ✅ File system operations
- ✅ Error propagation
- ✅ Output validity

**Estimated Complexity**: Very High (most complex, hardest to debug)

---

## Best Practices

### 1. Test Structure

**Use AAA Pattern (Arrange-Act-Assert)**:

```powershell
It 'Should do something' {
    # Arrange
    $input = 'test'
    $expected = 'TEST'
    
    # Act
    $result = Convert-ToUpperCase $input
    
    # Assert
    $result | Should -Be $expected
}
```

**Organize with Describe/Context/It**:

- `Describe`: Component name (class/function)
- `Context`: Feature or scenario group
- `It`: Single behavior/expectation

### 2. Test Isolation

**Use BeforeEach for Test-Specific Setup**:

```powershell
Describe 'MyComponent' {
    BeforeEach {
        $script:sut = [MyComponent]::new()  # System Under Test
    }
    
    AfterEach {
        # Cleanup if needed
    }
}
```

**Use TestDrive for File Operations**:

```powershell
It 'Should read file' {
    # TestDrive: is automatically cleaned up
    Set-Content -Path 'TestDrive:\test.txt' -Value 'content'
    $result = Read-MyFile 'TestDrive:\test.txt'
    $result | Should -Be 'content'
}
```

### 3. Edge Case Focus

**Always Test**:

- ✅ Null inputs
- ✅ Empty strings/arrays
- ✅ Whitespace-only strings
- ✅ Boundary values (0, -1, Int32.MaxValue)
- ✅ Invalid file paths
- ✅ Missing files/directories
- ✅ Permission errors
- ✅ Large inputs (performance)
- ✅ Special characters (Unicode, newlines, tabs)

### 4. Custom Matchers

**Use Existing Matchers**:

- `Should-HaveProperty` - Check property existence
- `Should-HaveMethod` - Check method existence
- `Should-HavePropertyOfType` - Check property type
- `Should-HavePropertyWithValue` - Check property value

**Example**:

```powershell
$result | Should-HaveProperty 'ClassName'
$result | Should-HavePropertyOfType 'ClassName' 'System.String'
$result | Should-HavePropertyWithValue 'ClassName' 'TestClass'
```

### 5. TestCases for Parametrized Tests

**Use for Multiple Similar Tests**:

```powershell
It 'Should handle <Description>' -TestCases @(
    @{ Input = $null; Expected = 'null' }
    @{ Input = ''; Expected = 'empty' }
    @{ Input = '   '; Expected = 'whitespace' }
) {
    param($Input, $Expected)
    $result = Get-InputType $Input
    $result | Should -Be $Expected
}
```

### 6. Mocking (When Needed)

**Mock External Dependencies**:

```powershell
BeforeAll {
    Mock Get-Content { return 'mocked content' }
}

It 'Should use Get-Content' {
    $result = Read-MyFile 'any-path.txt'
    $result | Should -Be 'mocked content'
    Should -Invoke Get-Content -Times 1
}
```

**Note**: Prefer real operations in TestDrive over mocking when possible.

### 7. Error Testing

**Test Exceptions**:

```powershell
It 'Should throw on invalid input' {
    { Do-Something -InvalidParam } | Should -Throw
}

It 'Should throw specific exception type' {
    { Do-Something -InvalidParam } | Should -Throw -ExceptionType ([ArgumentException])
}

It 'Should throw with meaningful message' {
    { Do-Something -InvalidParam } | Should -Throw -ExpectedMessage '*parameter*'
}
```

### 8. Verbose Output Testing

**Capture and Verify Verbose Stream**:

```powershell
It 'Should write verbose messages' {
    $verboseOutput = (Do-Something -Verbose) 4>&1
    $verboseOutput | Should -Not -BeNullOrEmpty
    $verboseOutput | Should -Match 'Processing'
}
```

### 9. Performance Considerations

**Add Performance Tests for Critical Paths**:

```powershell
It 'Should complete within acceptable time' {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Build-LargeProject
    $sw.Stop()
    $sw.ElapsedMilliseconds | Should -BeLessThan 5000  # 5 seconds
}
```

### 10. Test Naming

**Use Descriptive Names**:

- ✅ `Should return empty array when no files match pattern`
- ❌ `Test case 1`

**Use "Should" Consistently**:

- All `It` blocks start with "Should"

---

## Prioritization Matrix

### Axis 1: Criticality (Impact on System)

- **P0 - Critical**: Core functionality, used by everything
- **P1 - High**: Major features, significant impact
- **P2 - Medium**: Important but not critical
- **P3 - Low**: Nice-to-have, low impact

### Axis 2: Complexity (Test Difficulty)

- **C1 - Simple**: Straightforward, minimal logic
- **C2 - Moderate**: Some complexity, manageable
- **C3 - Complex**: Significant complexity, many scenarios
- **C4 - Very Complex**: Algorithmic, integration, many dependencies

### Axis 3: Dependencies (What Depends on This)

- **D3 - Foundation**: Many components depend on this
- **D2 - Intermediate**: Some components depend on this
- **D1 - Leaf**: No other components depend on this

### Priority Scoring

**Formula**: `Score = (Criticality * 3) + (Dependency * 2) - (Complexity * 1)`

Higher score = Higher priority

---

## Implementation Phases

### Phase 0: Infrastructure ✅ (COMPLETED)

**Status**: Complete

- Invoke-UnitTests.ps1
- Custom Matchers (4)
- PSScriptBuilderAstEngine.Tests.ps1 (50+ tests)

---

### Phase 1: Foundation Layer (Priority: Immediate)

**Duration**: 2-3 days
**Components** (5 test files):

1. **PSScriptBuilderFileSystemHelper.Tests.ps1** (P0, C2, D3) - Score: 14
   - Estimated Tests: 25
   - Focus: Path validation, directory operations, file operations
   
2. **PSScriptBuilderFileIOHelper.Tests.ps1** (P0, C2, D3) - Score: 14
   - Estimated Tests: 20
   - Focus: Read/write operations, encoding
   
3. **PSScriptBuilderBase.Tests.ps1** (P1, C1, D3) - Score: 12
   - Estimated Tests: 10
   - Focus: Base class functionality, common properties
   
4. **PSScriptBuilderLogger.Tests.ps1** (P1, C2, D2) - Score: 10
   - Estimated Tests: 15
   - Focus: Logging modes, output streams, file logging

5. **PSScriptBuilderCollectorType.Tests.ps1** (P0, C1, D3) - Score: 13
   - Estimated Tests: 8
   - Focus: Enum values (Using=0, Enum=1, Class=2, Function=3, File=4), ordering

6. **PSScriptBuilderBumpType.Tests.ps1** (P1, C1, D2) - Score: 10
   - Estimated Tests: 6
   - Focus: Enum values (Major, Minor, Patch)

**Total Estimated Tests**: ~74

---

### Phase 2: Data Classes (Priority: High)

**Duration**: 2 days
**Components** (5 test files):

1. **PSScriptBuilderClassData.Tests.ps1** (P0, C1, D3) - Score: 13
   - Estimated Tests: 20
   - Focus: Constructor, properties, null handling
   
2. **PSScriptBuilderFunctionData.Tests.ps1** (P0, C1, D3) - Score: 13
   - Estimated Tests: 15
   - Focus: Constructor, properties, function calls
   
3. **PSScriptBuilderEnumData.Tests.ps1** (P0, C1, D3) - Score: 13
   - Estimated Tests: 12
   - Focus: Constructor, properties
   
4. **PSScriptBuilderUsingData.Tests.ps1** (P1, C1, D2) - Score: 10
   - Estimated Tests: 10
   - Focus: Constructor, properties
   
5. **PSScriptBuilderFileData.Tests.ps1** (P1, C1, D2) - Score: 10
   - Estimated Tests: 10
   - Focus: Constructor, properties, content handling

**Total Estimated Tests**: ~67

---

### Phase 3: Core Classes (Priority: High)

**Duration**: 3-4 days
**Components** (4 test files):

1. **PSScriptBuilderCollectorBase.Tests.ps1** (P0, C3, D3) - Score: 12
   - Estimated Tests: 30
   - Focus: Template Method, Reset, abstract methods
   
2. **PSScriptBuilderCollectorCollection.Tests.ps1** (P0, C2, D2) - Score: 11
   - Estimated Tests: 20
   - Focus: Collection management, sorting, iteration
   
3. **PSScriptBuilderContentCollector.Tests.ps1** (P0, C3, D2) - Score: 11
   - Estimated Tests: 25
   - Focus: Orchestration, collector execution
   
4. **PSScriptBuilderContentProcessor.Tests.ps1** (P0, C2, D2) - Score: 11
   - Estimated Tests: 20
   - Focus: Content processing, template integration

**Total Estimated Tests**: ~95

---

### Phase 4: Collectors (Priority: High)

**Duration**: 4-5 days
**Components** (5 test files):

1. **PSScriptBuilderEnumCollector.Tests.ps1** (P0, C3, D2) - Score: 11
   - Estimated Tests: 35
   - Focus: Collection, duplicate detection, Reset
   
2. **PSScriptBuilderClassCollector.Tests.ps1** (P0, C3, D2) - Score: 11
   - Estimated Tests: 40
   - Focus: Collection, inheritance, type refs, duplicates
   
3. **PSScriptBuilderFunctionCollector.Tests.ps1** (P0, C3, D2) - Score: 11
   - Estimated Tests: 35
   - Focus: Collection, function calls, duplicates
   
4. **PSScriptBuilderUsingCollector.Tests.ps1** (P1, C2, D2) - Score: 10
   - Estimated Tests: 25
   - Focus: Collection, duplicate detection
   
5. **PSScriptBuilderFileCollector.Tests.ps1** (P1, C2, D2) - Score: 10
   - Estimated Tests: 20
   - Focus: File content collection

**Total Estimated Tests**: ~155

---

### Phase 5: Dependencies (Priority: High)

**Duration**: 5-6 days
**Components** (5 test files):

1. **PSScriptBuilderDependencyGraph.Tests.ps1** (P0, C3, D3) - Score: 12
   - Estimated Tests: 30
   - Focus: Graph construction, nodes, edges
   
2. **PSScriptBuilderDependencyGraphBuilder.Tests.ps1** (P0, C3, D2) - Score: 11
   - Estimated Tests: 35
   - Focus: Building from collections, edge creation
   
3. **PSScriptBuilderCycleDetector.Tests.ps1** (P0, C4, D2) - Score: 10
   - Estimated Tests: 25
   - Focus: Cycle detection algorithms, reporting
   
4. **PSScriptBuilderTopologicalSorter.Tests.ps1** (P0, C4, D2) - Score: 10
   - Estimated Tests: 30
   - Focus: Sorting correctness, edge cases
   
5. **PSScriptBuilderCrossDependencyDetector.Tests.ps1** (P1, C3, D1) - Score: 8
   - Estimated Tests: 20
   - Focus: Cross-file dependency detection

**Total Estimated Tests**: ~140

---

### Phase 6: Configuration System (Priority: Medium)

**Duration**: 2-3 days
**Components** (8 test files):

1. **PSScriptBuilderConfigLoader.Tests.ps1** (P1, C2, D2) - Score: 10
   - Estimated Tests: 25
   - Focus: JSON loading, error handling
   
2. **PSScriptBuilderConfiguration.Tests.ps1** (P1, C2, D2) - Score: 10
   - Estimated Tests: 20
   - Focus: Configuration properties, validation
   
3. **PSScriptBuilderConfigValidator.Tests.ps1** (P1, C3, D2) - Score: 9
   - Estimated Tests: 30
   - Focus: Validation rules, error messages
   
4. **PSScriptBuilderOptionsBase.Tests.ps1** (P2, C2, D2) - Score: 8
   - Estimated Tests: 15
   - Focus: Base options functionality
   
5. **PSScriptBuilderBuildOptions.Tests.ps1** (P1, C2, D1) - Score: 8
   - Estimated Tests: 20
   - Focus: Build-specific options
   
6. **PSScriptBuilderReleaseOptions.Tests.ps1** (P1, C2, D1) - Score: 8
   - Estimated Tests: 20
   - Focus: Release-specific options

7. **Get-PSScriptBuilderConfiguration.Tests.ps1** (P1, C2, D1) - Score: 8
   - Estimated Tests: 15
   - Focus: Cmdlet parameters, error handling

8. **Set-PSScriptBuilderProjectRoot.Tests.ps1** (P2, C1, D1) - Score: 6
   - Estimated Tests: 10
   - Focus: Setting project root

**Total Estimated Tests**: ~155

---

### Phase 7: Release Management System (Priority: Medium)

**Duration**: 5-6 days
**Components** (18 test files):

#### 7.1 Helper & Results (3 files)

1. **PSScriptBuilderBumpReplacementHelper.Tests.ps1** (P1, C3, D2) - Score: 9
   - Estimated Tests: 30
   - Focus: Token replacement, regex patterns
   
2. **PSScriptBuilderBumpFilesResult.Tests.ps1** (P2, C1, D1) - Score: 6
   - Estimated Tests: 15
   - Focus: Result properties
   
3. **PSScriptBuilderReleaseDataResult.Tests.ps1** (P2, C1, D1) - Score: 6
   - Estimated Tests: 15
   - Focus: Result properties

#### 7.2 Managers & Processors (4 files)

4. **PSScriptBuilderBumpConfigFileManager.Tests.ps1** (P1, C2, D2) - Score: 10
   - Estimated Tests: 25
   - Focus: Config file management
   
5. **PSScriptBuilderBumpFilesProcessor.Tests.ps1** (P0, C3, D2) - Score: 11
   - Estimated Tests: 35
   - Focus: Version bumping logic
   
6. **PSScriptBuilderReleaseDataFileManager.Tests.ps1** (P1, C2, D2) - Score: 10
   - Estimated Tests: 25
   - Focus: Release data file management
   
7. **PSScriptBuilderReleaseDataProcessor.Tests.ps1** (P1, C3, D2) - Score: 9
   - Estimated Tests: 30
   - Focus: Release data processing

#### 7.3 Validators (2 files)

8. **PSScriptBuilderBumpFilesValidator.Tests.ps1** (P1, C3, D2) - Score: 9
   - Estimated Tests: 30
   - Focus: Bump config validation
   
9. **PSScriptBuilderReleaseDataValidator.Tests.ps1** (P1, C3, D2) - Score: 9
   - Estimated Tests: 30
   - Focus: Release data validation

#### 7.4 Orchestrator & Request (2 files)

10. **PSScriptBuilderReleaseManagementOrchestrator.Tests.ps1** (P1, C3, D2) - Score: 9
    - Estimated Tests: 35
    - Focus: Orchestration logic
    
11. **PSScriptBuilderReleaseDataOperationRequest.Tests.ps1** (P2, C1, D1) - Score: 6
    - Estimated Tests: 15
    - Focus: Request properties

#### 7.5 Public Functions (7 files)

12. **Get-PSScriptBuilderBumpConfiguration.Tests.ps1** (P1, C2, D1) - Score: 8
    - Estimated Tests: 15
    
13. **Test-PSScriptBuilderBumpConfiguration.Tests.ps1** (P1, C2, D1) - Score: 8
    - Estimated Tests: 15
    
14. **Update-PSScriptBuilderBumpFiles.Tests.ps1** (P1, C2, D1) - Score: 8
    - Estimated Tests: 20
    
15. **Get-PSScriptBuilderReleaseData.Tests.ps1** (P1, C2, D1) - Score: 8
    - Estimated Tests: 15
    
16. **New-PSScriptBuilderReleaseData.Tests.ps1** (P1, C2, D1) - Score: 8
    - Estimated Tests: 20
    
17. **Test-PSScriptBuilderReleaseData.Tests.ps1** (P1, C2, D1) - Score: 8
    - Estimated Tests: 15
    
18. **Update-PSScriptBuilderReleaseData.Tests.ps1** (P1, C2, D1) - Score: 8
    - Estimated Tests: 20

**Total Estimated Tests**: ~395

---

### Phase 8: Build Results & Remaining Public Functions (Priority: Medium)

**Duration**: 3 days
**Components** (9 test files):

#### 8.1 Results (3 files)

1. **PSScriptBuilderBuildResult.Tests.ps1** (P1, C2, D1) - Score: 8
   - Estimated Tests: 20
   
2. **PSScriptBuilderBuildComponentCounts.Tests.ps1** (P2, C1, D1) - Score: 6
   - Estimated Tests: 15
   
3. **PSScriptBuilderBuildComponentDetail.Tests.ps1** (P2, C1, D1) - Score: 6
   - Estimated Tests: 15

#### 8.2 Public Functions (6 files)

4. **Invoke-PSScriptBuilderBuild.Tests.ps1** (P0, C3, D1) - Score: 9
   - Estimated Tests: 30
   
5. **Get-PSScriptBuilderDependencyAnalysis.Tests.ps1** (P1, C2, D1) - Score: 8
   - Estimated Tests: 20
   
6. **Add-PSScriptBuilderCollector.Tests.ps1** (P2, C2, D1) - Score: 7
   - Estimated Tests: 15
   
7. **New-PSScriptBuilderCollector.Tests.ps1** (P2, C2, D1) - Score: 7
   - Estimated Tests: 15
   
8. **New-PSScriptBuilderContentCollector.Tests.ps1** (P2, C2, D1) - Score: 7
   - Estimated Tests: 15
   
9. **Get-PSScriptBuilderReleaseDataTokens.Tests.ps1** (P2, C1, D1) - Score: 6
   - Estimated Tests: 10

**Total Estimated Tests**: ~155

---

### Phase 9: Format Functions (Priority: Low)

**Duration**: 1 day
**Components** (3 test files):

1. **Format-PSScriptBuilderBuildResult.Tests.ps1** (P3, C2, D1) - Score: 5
   - Estimated Tests: 15
   - Focus: Output formatting
   
2. **Format-PSScriptBuilderBumpResult.Tests.ps1** (P3, C2, D1) - Score: 5
   - Estimated Tests: 12
   - Focus: Output formatting
   
3. **Format-PSScriptBuilderReleaseDataResult.Tests.ps1** (P3, C2, D1) - Score: 5
   - Estimated Tests: 12
   - Focus: Output formatting

**Total Estimated Tests**: ~39

---

### Phase 10: Integration Tests (Priority: High)

**Duration**: 4-5 days
**Components** (5 test files):

1. **Build.Integration.Tests.ps1** (P0, C4, D1) - Score: 9
   - Estimated Tests: 40
   - Focus: End-to-end build scenarios
   
2. **DependencyResolution.Integration.Tests.ps1** (P0, C4, D1) - Score: 9
   - Estimated Tests: 30
   - Focus: Complex dependency scenarios
   
3. **ReleaseWorkflow.Integration.Tests.ps1** (P1, C3, D1) - Score: 8
   - Estimated Tests: 35
   - Focus: Complete release workflows
   
4. **Configuration.Integration.Tests.ps1** (P1, C3, D1) - Score: 8
   - Estimated Tests: 25
   - Focus: Configuration loading and validation
   
5. **Examples.Integration.Tests.ps1** (P0, C3, D1) - Score: 9
   - Estimated Tests: 50 (8 examples × multiple checks)
   - Focus: All 8 example projects

**Total Estimated Tests**: ~180

---

## Effort Estimation

### Summary

| Phase | Test Files | Est. Tests | Duration | Priority | Status |
|-------|-----------|------------|----------|----------|--------|
| 0 - Infrastructure | - | - | ✅ Complete | Immediate | ✅ Done |
| 1 - Foundation | 6 | 74 | 2-3 days | Immediate | ⏳ Ready |
| 2 - Data Classes | 5 | 67 | 2 days | High | ⏳ Ready |
| 3 - Core Classes | 4 | 95 | 3-4 days | High | ⏳ Ready |
| 4 - Collectors | 5 | 155 | 4-5 days | High | ⏳ Ready |
| 5 - Dependencies | 5 | 140 | 5-6 days | High | ⏳ Ready |
| 6 - Configuration | 8 | 155 | 2-3 days | Medium | ⏳ Ready |
| 7 - Release Mgmt | 18 | 395 | 5-6 days | Medium | ⏳ Ready |
| 8 - Build/Public | 9 | 155 | 3 days | Medium | ⏳ Ready |
| 9 - Format | 3 | 39 | 1 day | Low | ⏳ Ready |
| 10 - Integration | 5 | 180 | 4-5 days | High | ⏳ Ready |
| **TOTAL** | **73** | **~1,555** | **32-39 days** | - | - |

### Total Test Count: ~1,555 individual test cases

### Total Duration: 32-39 days (6.4-7.8 weeks) at full-time pace

### Adjusted for Part-Time: 13-16 weeks

---

## Risks & Challenges

### Risk 1: Test Maintenance Overhead

**Risk**: Large test suite requires ongoing maintenance
**Mitigation**: 

- Invest in reusable test helpers
- Use TestCases to reduce duplication
- Keep tests focused and simple

### Risk 2: Slow Test Execution

**Risk**: 1,600+ tests may take significant time to run
**Mitigation**:

- Optimize slow tests
- Consider test tagging (fast/slow, unit/integration)
- Use Pester's `-OutputFormat` and `-PassThru` for selective runs

### Risk 3: Integration Test Brittleness

**Risk**: Integration tests may be flaky
**Mitigation**:

- Isolate tests (TestDrive, cleanup)
- Avoid time-dependent assertions
- Clear error messages for debugging

### Risk 4: Coverage Gaps

**Risk**: Hard to ensure complete coverage
**Mitigation**:

- Use Pester Code Coverage feature
- Prioritize critical paths
- Review coverage reports regularly

### Risk 5: PowerShell 5.1 Limitations

**Risk**: No interface mocking, limited reflection
**Mitigation**:

- Use concrete test implementations
- Favor integration over heavy mocking
- Document known limitations

### Risk 6: Test Data Management

**Risk**: Complex test data setup
**Mitigation**:

- Create test data factories/builders
- Use realistic but minimal data
- Share test fixtures via BeforeAll

### Risk 7: Test Execution Time

**Risk**: Full suite may take 10-30+ minutes
**Mitigation**:

- Tag tests: `-Tag 'Unit'`, `-Tag 'Integration'`
- Run subsets during development
- Full suite in CI/CD only

---

## Templates & Examples

### Template 1: Simple Data Class Test

```powershell
Describe 'PSScriptBuilderClassData' {
    Context 'Constructor' {
        It 'Should create instance with all parameters' {
            # Arrange
            $name = 'TestClass'
            $source = 'class TestClass { }'
            $base = 'BaseClass'
            $refs = @('Type1', 'Type2')
            
            # Act
            $result = [PSScriptBuilderClassData]::new($name, $source, $base, $refs)
            
            # Assert
            $result | Should-HaveProperty 'ClassName'
            $result.ClassName | Should -Be $name
            $result.BaseClass | Should -Be $base
            $result.TypeReferences.Count | Should -Be 2
        }
        
        It 'Should accept null BaseClass' {
            $result = [PSScriptBuilderClassData]::new('Test', 'code', $null, @())
            $result.BaseClass | Should -BeNullOrEmpty
        }
        
        It 'Should throw on null ClassName' {
            { [PSScriptBuilderClassData]::new($null, 'code', $null, @()) } | Should -Throw
        }
    }
    
    Context 'Properties' {
        BeforeEach {
            $script:sut = [PSScriptBuilderClassData]::new('Test', 'code', 'Base', @('Ref1'))
        }
        
        It 'Should have property <Name> of type <Type>' -TestCases @(
            @{ Name = 'ClassName'; Type = 'System.String' }
            @{ Name = 'SourceCode'; Type = 'System.String' }
            @{ Name = 'BaseClass'; Type = 'System.String' }
            @{ Name = 'TypeReferences'; Type = 'System.String[]' }
        ) {
            param($Name, $Type)
            $sut | Should-HavePropertyOfType $Name $Type
        }
    }
}
```

### Template 2: Collector Test with TestDrive

```powershell
Describe 'PSScriptBuilderClassCollector' {
    BeforeAll {
        function New-TestFile {
            param([string]$Name, [string]$Content)
            $path = Join-Path TestDrive: $Name
            Set-Content -Path $path -Value $Content -Encoding UTF8
            Get-Item $path
        }
    }
    
    Context 'Collection' {
        It 'Should collect single class' {
            # Arrange
            $file = New-TestFile 'Test.ps1' 'class TestClass { [string] $Name }'
            $collector = [PSScriptBuilderClassCollector]::new()
            
            # Act
            $collector.Collect(@($file))
            
            # Assert
            $collector.ClassData.Count | Should -Be 1
            $collector.ClassData.ContainsKey('TestClass') | Should -BeTrue
        }
        
        It 'Should detect type references' {
            $file = New-TestFile 'WithRefs.ps1' @'
class MyClass {
    [CustomType] $Property
}
'@
            $collector = [PSScriptBuilderClassCollector]::new()
            
            $collector.Collect(@($file))
            
            $typeRefs = $collector.ClassData['MyClass'].TypeReferences
            $typeRefs | Should -Contain 'CustomType'
        }
    }
    
    Context 'Duplicate Detection' {
        It 'Should throw on duplicate class name' {
            $file1 = New-TestFile 'File1.ps1' 'class DuplicateClass { }'
            $file2 = New-TestFile 'File2.ps1' 'class DuplicateClass { }'
            $collector = [PSScriptBuilderClassCollector]::new()
            
            { $collector.Collect(@($file1, $file2)) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle empty file list' {
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.Collect(@())
            $collector.ClassData.Count | Should -Be 0
        }
        
        It 'Should handle file with no classes' {
            $file = New-TestFile 'Empty.ps1' '# Just a comment'
            $collector = [PSScriptBuilderClassCollector]::new()
            $collector.Collect(@($file))
            $collector.ClassData.Count | Should -Be 0
        }
    }
}
```

### Template 3: Integration Test

```powershell
Describe 'Build Pipeline Integration' {
    BeforeAll {
        # Setup complete test project
        $script:testProjectPath = Join-Path TestDrive: 'TestProject'
        New-Item -Path $testProjectPath -ItemType Directory -Force
        
        # Create Enums
        $enumPath = Join-Path $testProjectPath 'Enums'
        New-Item -Path $enumPath -ItemType Directory -Force
        Set-Content (Join-Path $enumPath 'MyEnum.ps1') 'enum MyEnum { Value1; Value2 }'
        
        # Create Classes
        $classPath = Join-Path $testProjectPath 'Classes'
        New-Item -Path $classPath -ItemType Directory -Force
        Set-Content (Join-Path $classPath 'MyClass.ps1') @'
class MyClass {
    [MyEnum] $Status
    [string] $Name
}
'@
        
        # Create Functions
        $funcPath = Join-Path $testProjectPath 'Public'
        New-Item -Path $funcPath -ItemType Directory -Force
        Set-Content (Join-Path $funcPath 'Get-MyData.ps1') @'
function Get-MyData {
    [MyClass]::new()
}
'@
        
        # Create template
        $templatePath = Join-Path $testProjectPath 'template.psm1'
        Set-Content $templatePath @'
{{USING}}

{{ENUMS}}

{{CLASSES}}

{{FUNCTIONS}}
'@
    }
    
    Context 'Complete Build' {
        It 'Should build project successfully' {
            # Act
            $result = Invoke-PSScriptBuilderBuild -SourcePath $testProjectPath -TemplatePath $templatePath -OutputPath (Join-Path TestDrive: 'Output.psm1')
            
            # Assert
            $result.Success | Should -BeTrue
            $result.ComponentCounts.ClassCount | Should -Be 1
            $result.ComponentCounts.EnumCount | Should -Be 1
            $result.ComponentCounts.FunctionCount | Should -Be 1
        }
        
        It 'Should produce importable module' {
            # Build first
            $outputPath = Join-Path TestDrive: 'Output.psm1'
            Invoke-PSScriptBuilderBuild -SourcePath $testProjectPath -TemplatePath $templatePath -OutputPath $outputPath
            
            # Try to import
            { Import-Module $outputPath -Force } | Should -Not -Throw
            
            # Verify exported functions
            Get-Command Get-MyData -Module (Split-Path $outputPath -Leaf -Replace '\.psm1$') | Should -Not -BeNullOrEmpty
        }
        
        It 'Should order components correctly (Enum → Class → Function)' {
            $outputPath = Join-Path TestDrive: 'Output.psm1'
            Invoke-PSScriptBuilderBuild -SourcePath $testProjectPath -TemplatePath $templatePath -OutputPath $outputPath
            
            $content = Get-Content $outputPath -Raw
            $enumPos = $content.IndexOf('enum MyEnum')
            $classPos = $content.IndexOf('class MyClass')
            $funcPos = $content.IndexOf('function Get-MyData')
            
            $enumPos | Should -BeLessThan $classPos
            $classPos | Should -BeLessThan $funcPos
        }
    }
}
```

### Template 4: Public Function/Cmdlet Test

```powershell
Describe 'Invoke-PSScriptBuilderBuild' {
    Context 'Parameter Validation' {
        It 'Should have mandatory SourcePath parameter' {
            $cmd = Get-Command Invoke-PSScriptBuilderBuild
            $cmd.Parameters['SourcePath'].Attributes.Mandatory | Should -BeTrue
        }
        
        It 'Should validate SourcePath exists' {
            { Invoke-PSScriptBuilderBuild -SourcePath 'C:\NonExistent\Path' } | Should -Throw
        }
    }
    
    Context 'Pipeline Support' {
        It 'Should accept SourcePath from pipeline by value' {
            $cmd = Get-Command Invoke-PSScriptBuilderBuild
            $cmd.Parameters['SourcePath'].Attributes.ValueFromPipeline | Should -BeTrue
        }
    }
    
    Context 'Execution' {
        BeforeAll {
            # Setup minimal project in TestDrive
            $script:testPath = Join-Path TestDrive: 'MinimalProject'
            New-Item $testPath -ItemType Directory -Force
            # ... create minimal files
        }
        
        It 'Should execute build successfully' {
            $result = Invoke-PSScriptBuilderBuild -SourcePath $testPath
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSScriptBuilderBuildResult]
        }
        
        It 'Should write verbose output when -Verbose' {
            $verboseOutput = (Invoke-PSScriptBuilderBuild -SourcePath $testPath -Verbose) 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Error Handling' {
        It 'Should throw on circular dependency' {
            # Setup project with circular dependency
            # Test that build fails with clear message
        }
    }
}
```

---

## Next Steps

### Immediate Actions

1. **Review this document** with stakeholders
2. **Adjust priorities** if needed
3. **Start with Phase 1** (Foundation Layer)
4. **Create test template files** for common patterns
5. **Setup code coverage** measurement

### Ongoing Process

1. **Write tests** according to phase plan
2. **Execute tests** frequently (daily recommended)
3. **Track progress** (update this document or use spreadsheet)
4. **Address failures** immediately (don't accumulate debt)
5. **Refine estimates** based on actual progress

### Decision Points

- **After Phase 1**: Validate approach, adjust if needed
- **After Phase 5**: Re-assess priorities (Configuration vs. Release Mgmt)
- **After Phase 10**: Review integration test coverage and adjust

---

## Appendix: Quick Reference

### Test File Naming Convention

**Pattern**: `<ComponentName>.Tests.ps1`

**Examples**:

- `PSScriptBuilderAstEngine.Tests.ps1`
- `PSScriptBuilderClassCollector.Tests.ps1`
- `Invoke-PSScriptBuilderBuild.Tests.ps1`

### Test Directory Structure

**Current Structure (Hybrid Approach):**

```
tests/
├── CustomMatcher/                  # ✅ Custom Pester matchers (infrastructure)
│   ├── Should-HaveProperty.ps1
│   ├── Should-HaveMethod.ps1
│   ├── Should-HavePropertyOfType.ps1
│   ├── Should-HavePropertyWithValue.ps1
│   └── Test/                       # Tests for custom matchers
│       ├── Should-HaveProperty.Tests.ps1
│       ├── Should-HaveMethod.Tests.ps1
│       ├── Should-HavePropertyOfType.Tests.ps1
│       └── Should-HavePropertyWithValue.Tests.ps1
├── Unit/                           # ✅ Fast, isolated unit tests
│   ├── Configuration/              # Configuration system tests (~8 files)
│   │   ├── PSScriptBuilderConfigLoader.Tests.ps1
│   │   ├── PSScriptBuilderConfiguration.Tests.ps1
│   │   ├── PSScriptBuilderConfigValidator.Tests.ps1
│   │   ├── PSScriptBuilderOptionsBase.Tests.ps1
│   │   ├── PSScriptBuilderBuildOptions.Tests.ps1
│   │   ├── PSScriptBuilderReleaseOptions.Tests.ps1
│   │   ├── Get-PSScriptBuilderConfiguration.Tests.ps1
│   │   └── Set-PSScriptBuilderProjectRoot.Tests.ps1
│   ├── ScriptBuilder/              # Script builder system tests (~38 files)
│   │   ├── PSScriptBuilderAstEngine.Tests.ps1
│   │   ├── PSScriptBuilderFileSystemHelper.Tests.ps1
│   │   ├── PSScriptBuilderFileIOHelper.Tests.ps1
│   │   ├── PSScriptBuilderClassData.Tests.ps1
│   │   ├── PSScriptBuilderFunctionData.Tests.ps1
│   │   ├── PSScriptBuilderEnumData.Tests.ps1
│   │   ├── PSScriptBuilderUsingData.Tests.ps1
│   │   ├── PSScriptBuilderFileData.Tests.ps1
│   │   ├── PSScriptBuilderCollectorBase.Tests.ps1
│   │   ├── PSScriptBuilderCollectorCollection.Tests.ps1
│   │   ├── PSScriptBuilderContentCollector.Tests.ps1
│   │   ├── PSScriptBuilderContentProcessor.Tests.ps1
│   │   ├── PSScriptBuilderEnumCollector.Tests.ps1
│   │   ├── PSScriptBuilderClassCollector.Tests.ps1
│   │   ├── PSScriptBuilderFunctionCollector.Tests.ps1
│   │   ├── PSScriptBuilderUsingCollector.Tests.ps1
│   │   ├── PSScriptBuilderFileCollector.Tests.ps1
│   │   ├── PSScriptBuilderDependencyGraph.Tests.ps1
│   │   ├── PSScriptBuilderDependencyGraphBuilder.Tests.ps1
│   │   ├── PSScriptBuilderCycleDetector.Tests.ps1
│   │   ├── PSScriptBuilderTopologicalSorter.Tests.ps1
│   │   ├── PSScriptBuilderCrossDependencyDetector.Tests.ps1
│   │   ├── PSScriptBuilderBuildResult.Tests.ps1
│   │   ├── PSScriptBuilderBuildComponentCounts.Tests.ps1
│   │   ├── PSScriptBuilderBuildComponentDetail.Tests.ps1
│   │   ├── Invoke-PSScriptBuilderBuild.Tests.ps1
│   │   ├── Get-PSScriptBuilderDependencyAnalysis.Tests.ps1
│   │   ├── Add-PSScriptBuilderCollector.Tests.ps1
│   │   ├── New-PSScriptBuilderCollector.Tests.ps1
│   │   ├── New-PSScriptBuilderContentCollector.Tests.ps1
│   │   ├── Format-PSScriptBuilderBuildResult.Tests.ps1
│   │   └── ... (more ScriptBuilder components)
│   ├── ReleaseManagement/          # Release management tests (~22 files)
│   │   ├── PSScriptBuilderBumpReplacementHelper.Tests.ps1
│   │   ├── PSScriptBuilderBumpConfigFileManager.Tests.ps1
│   │   ├── PSScriptBuilderBumpFilesProcessor.Tests.ps1
│   │   ├── PSScriptBuilderReleaseDataFileManager.Tests.ps1
│   │   ├── PSScriptBuilderReleaseDataProcessor.Tests.ps1
│   │   ├── PSScriptBuilderBumpFilesValidator.Tests.ps1
│   │   ├── PSScriptBuilderReleaseDataValidator.Tests.ps1
│   │   ├── PSScriptBuilderReleaseManagementOrchestrator.Tests.ps1
│   │   ├── PSScriptBuilderReleaseDataOperationRequest.Tests.ps1
│   │   ├── PSScriptBuilderBumpFilesResult.Tests.ps1
│   │   ├── PSScriptBuilderReleaseDataResult.Tests.ps1
│   │   ├── Get-PSScriptBuilderBumpConfiguration.Tests.ps1
│   │   ├── Test-PSScriptBuilderBumpConfiguration.Tests.ps1
│   │   ├── Update-PSScriptBuilderBumpFiles.Tests.ps1
│   │   ├── Get-PSScriptBuilderReleaseData.Tests.ps1
│   │   ├── New-PSScriptBuilderReleaseData.Tests.ps1
│   │   ├── Test-PSScriptBuilderReleaseData.Tests.ps1
│   │   ├── Update-PSScriptBuilderReleaseData.Tests.ps1
│   │   ├── Get-PSScriptBuilderReleaseDataTokens.Tests.ps1
│   │   ├── Format-PSScriptBuilderBumpResult.Tests.ps1
│   │   ├── Format-PSScriptBuilderReleaseDataResult.Tests.ps1
│   │   └── ... (more ReleaseManagement components)
│   └── Common/                     # Common/shared components (~6 files)
│       ├── PSScriptBuilderBase.Tests.ps1
│       ├── PSScriptBuilderLogger.Tests.ps1
│       ├── PSScriptBuilderCollectorType.Tests.ps1
│       ├── PSScriptBuilderBumpType.Tests.ps1
│       ├── Get-PSScriptBuilderProjectRoot.Tests.ps1
│       └── ... (other common components)
├── Integration/                    # ✅ Multi-component integration tests (~5 files)
│   ├── Build.Integration.Tests.ps1
│   ├── DependencyResolution.Integration.Tests.ps1
│   ├── ReleaseWorkflow.Integration.Tests.ps1
│   ├── Configuration.Integration.Tests.ps1
│   └── Examples.Integration.Tests.ps1
```

**Design Rationale:**

1. **Unit/** grouped by system (Configuration, ScriptBuilder, ReleaseManagement, Common)
   - Keeps related tests together
   - ~8-38 files per subdirectory (manageable)
   - Easy to run specific subsystem tests

2. **Flat structure within Unit/** subdirectories
   - All test files directly in subdirectory (no deeper nesting)
   - Simpler navigation for 73 files
   - Can refactor to deeper structure if needed

3. **Integration/ covers end-to-end scenarios**
   - Uses real example projects as test fixtures
   - Tests complete workflows from user perspective
   - CI/CD pipeline can run Unit and Integration separately

### Pester Command Quick Reference

```powershell
# Run all tests
Invoke-Pester -Path .\tests\

# Run specific folder
Invoke-Pester -Path .\tests\Unit\Helper\

# Run specific file
Invoke-Pester -Path .\tests\Unit\Helper\PSScriptBuilderAstEngine.Tests.ps1

# Run with code coverage
Invoke-Pester -Path .\tests\Unit\ -CodeCoverage .\src\**\*.ps1

# Run with detailed output
Invoke-Pester -Path .\tests\ -Output Detailed

# Run with tag filtering
Invoke-Pester -Path .\tests\ -Tag 'Unit'
Invoke-Pester -Path .\tests\ -ExcludeTag 'Slow'
```

---

**Document End**

# Collectors

A **collector** is responsible for scanning source files and extracting a specific type of
PowerShell component — classes, functions, enums, using statements, or raw file contents. Each
collector feeds its results into the build pipeline, which assembles the final output script
using the configured template.

The **Class** and **Function** collectors go a step further: they use PowerShell AST analysis
to extract dependency information — base classes, type references, and called functions. This
allows the build to determine the correct load order and produce a topologically ordered output
script.

Collectors scan files, not individual definitions. Every file matching the configured paths and
filters is read and all definitions of the relevant type it contains are extracted individually.
A single file may contain multiple class definitions, multiple function definitions, or multiple
enum definitions — the collector handles all of them transparently. There is no requirement to
keep one definition per file. A file may even mix definition types — a class and a function in
the same file are each picked up by their respective collectors. See
[Example 04](../examples.md#04-flexible-file-structure) for a demonstration.

Every build starts by configuring one or more collectors. The collectors define *what* gets
collected and *from where* — the [template](templates.md) defines *how* it is assembled.

## Collector Types

PSScriptBuilder provides five collector types:

| Type | Collects | Default Key | Default Token |
|---|---|---|---|
| `Using` | `using` statements | `USING_STATEMENTS` | `{{USING_STATEMENTS}}` |
| `Enum` | Enum definitions | `ENUM_DEFINITIONS` | `{{ENUM_DEFINITIONS}}` |
| `Class` | Class definitions (with dependency tracking) | `CLASS_DEFINITIONS` | `{{CLASS_DEFINITIONS}}` |
| `Function` | Standalone function definitions | `FUNCTION_DEFINITIONS` | `{{FUNCTION_DEFINITIONS}}` |
| `File` | Complete file contents as-is | `FILE_CONTENTS` | `{{FILE_CONTENTS}}` |

---

## Walkthrough

### 1. Your First Collector

Create a `ContentCollector` and add a collector for your class files:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes"
```

[`New-PSScriptBuilderContentCollector`](../cmdlets/New-PSScriptBuilderContentCollector.md) creates the container. [`Add-PSScriptBuilderCollector`](../cmdlets/Add-PSScriptBuilderCollector.md)
creates a collector and registers it in one fluent step. The result is a `ContentCollector`
ready for use in a build or dependency analysis.

For standalone use without a build — for example to explore collected data interactively —
use [`New-PSScriptBuilderCollector`](../cmdlets/New-PSScriptBuilderCollector.md) directly.

### 2. Combining Collectors

Most builds need multiple collectors — using statements, enums, classes, and functions:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Using    -IncludePath "src" |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath "src\Enums" |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath "src\Classes" |
    Add-PSScriptBuilderCollector -Type Function -IncludePath "src\Public"
```

Collectors are always executed in a fixed type order (Using → Enum → Class → Function → File),
regardless of the order you register them. See [Execution Order](#execution-order) in the
Reference section.

### 3. Custom Collection Keys

By default, each collector maps to a template placeholder using its type's default key
(e.g. `CLASS_DEFINITIONS` → `{{CLASS_DEFINITIONS}}`). Use `-CollectionKey` to assign a custom key —
this is required when you need multiple collectors of the same type for different source directories:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "CORE_CLASSES"   -IncludePath "src\Core" |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN_CLASSES" -IncludePath "src\Domain"
```

Your template would then reference:

```powershell
{{CORE_CLASSES}}
{{DOMAIN_CLASSES}}
```

Custom keys are case-insensitive at match time but preserved as written.

#### Cross-collector dependencies

When components in different collectors depend on each other — through inheritance, static
initializers, or type references — the **template placeholder order** determines the final load
sequence. PSScriptBuilder cannot reorder placeholders in your template automatically.

!!! warning "Template placeholder order is your responsibility across collector boundaries"
    If a class or function in one collector depends on a component in another collector, the
    corresponding template placeholders must appear in the correct order — dependencies first.
    A wrong placeholder order generates a script that fails at runtime with a `type-not-found`
    error. PSScriptBuilder will emit a build warning when it detects cross-collector dependencies.

    See the [Dependency Analysis Guide](dependency-analysis.md#cross-collector-dependencies) for
    a full explanation and examples.

### 4. Filtering Files

Control which files each collector processes using filter parameters.

**Exclude specific files by pattern:**

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" -ExcludeFile "*.Tests.ps1"
```

**Exclude entire subdirectories:**

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" -ExcludePath "src\Classes\Legacy"
```

**Scan additional file extensions:**

By default, only `.ps1` files are scanned. Use `-FileExtension` to include additional types:

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" -FileExtension ".ps1", ".psm1"
```

`-FileExtension` replaces the default — if specified, only the listed extensions are scanned.
To keep `.ps1` alongside additional types, always include it explicitly.

**Scan only the top-level directory (no subdirectories):**

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath "src\Classes" -NoRecurse
```

By default, collectors scan all `.ps1` files recursively. `-NoRecurse` limits scanning to the
immediate directory only.

**Include specific files explicitly:**

```powershell
$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludeFile "src\Classes\MyClass.ps1", "src\Classes\BaseClass.ps1"
```

`-IncludeFile` bypasses path exclusion filters — explicitly listed files are always processed.

!!! warning "-FileExtension does not apply to -IncludeFile"
    `-FileExtension` only filters files discovered via `-IncludePath`. Files specified with
    `-IncludeFile` are always included regardless of their extension.

### 5. Inspecting Results

After a build — or after calling `Collect()` directly — you can inspect what each collector
found. This is useful for debugging, verifying filter configurations, or exploring collected
data interactively before running a full build.

**List all registered collectors:**

```powershell
Get-PSScriptBuilderCollector -ContentCollector $contentCollector
```

**Get a specific collector by key:**

```powershell
$classCollector = Get-PSScriptBuilderCollector -ContentCollector $contentCollector -CollectionKey "CLASS_DEFINITIONS"
```

[`Get-PSScriptBuilderCollectorContent`](../cmdlets/Get-PSScriptBuilderCollectorContent.md)
returns the collected data items for a given collector. Each item is a typed data object
whose properties depend on the collector type — see [Collected Data Properties](#collected-data-properties)
in the Reference section:

```powershell
$classes = Get-PSScriptBuilderCollectorContent -Collector $classCollector

# Show name, base class, and source file for each collected class
$classes | Format-Table Name, BaseClass, SourceFile
```

**Get a single item by name:**

```powershell
$data = Get-PSScriptBuilderCollectorContent -Collector $classCollector -ItemName "MyBaseClass"
Write-Host $data.SourceCode
```

### 6. Updating Collector Configuration

A `ContentCollector` is mutable — collectors can be removed and replaced after the initial
setup. This is useful when build logic is conditional: for example, when a collector's path
or type depends on a parameter passed to the build script.

[`Remove-PSScriptBuilderCollector`](../cmdlets/Remove-PSScriptBuilderCollector.md) removes a
registered collector by key. The operation is idempotent — removing a non-existent key
produces a warning, not an error:

```powershell
$contentCollector = $contentCollector |
    Remove-PSScriptBuilderCollector -CollectionKey "OLD_FUNCTIONS" |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey "NEW_FUNCTIONS" -IncludePath "src\v2"
```

---

## Reference

### Parameters

All parameters are available on both `New-PSScriptBuilderCollector` and
`Add-PSScriptBuilderCollector`:

| Parameter | Type | Description |
|---|---|---|
| `-Type` | `string` | **Required.** One of: `Using`, `Enum`, `Class`, `Function`, `File` |
| `-CollectionKey` | `string` | Custom token key for use in templates. Defaults to the type's default key |
| `-IncludePath` | `string[]` | Directories to scan. Relative to project root or absolute |
| `-IncludeFile` | `string[]` | Specific files or glob patterns to include. Bypasses path exclusion filters |
| `-ExcludePath` | `string[]` | Directories to exclude. Takes precedence over `-IncludePath` |
| `-ExcludeFile` | `string[]` | File patterns to exclude (e.g. `"*.Tests.ps1"`) |
| `-FileExtension` | `string[]` | File extensions to scan. Defaults to `@(".ps1")`. Use to include additional types, e.g. `@(".ps1", ".psm1")` |
| `-NoRecurse` | `switch` | Scan only the top-level directory of each `-IncludePath`. Default is recursive |

### File Resolution Rules

- Relative paths are resolved against `$Global:PSScriptBuilderProjectRoot`
- `-IncludeFile` entries bypass all path exclusion filters
- A non-existent `-IncludePath` produces a **warning** at collector creation time — the
  collector is still created to support scenarios where the directory is generated later.
  At collection time (when the build runs), a still-missing path throws an `IOException`.
- `-NoRecurse` only affects `-IncludePath` scanning; `-IncludeFile` entries are always explicit

### Collected Data Properties

Each collector type exposes type-specific properties on its data objects:

| Collector Type | Data Properties |
|---|---|
| `Class`    | `Name`, `SourceCode`, `SourceFile`, `BaseClass`, `TypeReferences`, `StaticInitializerReferences`, `CalledFunctions` |
| `Function` | `Name`, `SourceCode`, `SourceFile`, `CalledFunctions`, `TypeReferences` |
| `Enum`     | `Name`, `SourceCode`, `SourceFile` |
| `Using`    | `Statement`, `SourceFiles` |
| `File`     | `FileName`, `FullPath`, `Content` |

`Name`, `SourceCode`, and `SourceFile` are present on all types except `Using` and `File` and
contain the component name, the exact source code as extracted from the file, and the path to
the file it was collected from. The following properties carry additional dependency and
structural information:

**`BaseClass`** (`Class` only)

The name of the class this class inherits from, or an empty string if the class has no base
class. PSScriptBuilder uses this to add an `Inheritance` edge in the dependency graph, which
creates a hard ordering constraint: the base class must appear before the derived class in the
output script.

**`TypeReferences`** (`Class`, `Function`)

All non-built-in types referenced in the component's body. For classes, this includes property
type annotations, method parameter types, return types, and type casts in method bodies. For
functions, it includes parameter types, return types, and type casts. Built-in .NET types
(`string`, `int`, `bool`, `System.*`, etc.) are automatically excluded. PSScriptBuilder uses
these references to add `TypeReference` edges in the dependency graph. Unlike `Inheritance` and
`StaticInitializer` edges, `TypeReference` edges do not create a hard ordering constraint —
methods only execute after all types are loaded — but they still influence the topological sort.

**`StaticInitializerReferences`** (`Class` only)

Types referenced in static property initializer expressions, for example
`static [MyClass] $Default = [MyClass]::new()`. PowerShell evaluates static initializers
immediately when a class definition is loaded, so any type referenced in an initializer must
already be defined at that point. This creates the same hard ordering constraint as inheritance.
PSScriptBuilder adds `StaticInitializer` edges for these references and treats them identically
to `Inheritance` edges when detecting fatal cycles.

**`CalledFunctions`** (`Class`, `Function`)

Names of other functions called within the component's body. PSScriptBuilder uses these to add
`FunctionCall` edges in the dependency graph. These edges do not create a hard ordering
constraint but can contribute to cross-dependencies when classes and functions reference each
other.

**`Statement`** (`Using` only)

The full `using namespace` or `using module` statement as a string. `SourceFiles` contains the
paths of all files where this statement was found — the Using collector deduplicates identical
statements across files.

**`FileName`**, **`FullPath`**, **`Content`** (`File` only)

The file name, absolute path, and complete raw content of the file. File collectors include
files as-is without any AST analysis.

### Execution Order

Collectors always execute in `CollectorType` enum order, regardless of registration order:

| Order | Type |
|---|---|
| 1 | `Using` |
| 2 | `Enum` |
| 3 | `Class` |
| 4 | `Function` |
| 5 | `File` |

This is the order of the *collection phase*. The position of each collector's output in the
final script is controlled by the template — see the [Templates Guide](templates.md).

### ContentCollector Methods

`New-PSScriptBuilderContentCollector` returns a `PSScriptBuilderContentCollector` object. Most
operations on it are covered by the collector cmdlets, but the object also exposes the following
methods directly:

| Method | Returns | Cmdlet equivalent | Description |
|---|---|---|---|
| `AddCollector(collector)` | `void` | `Add-PSScriptBuilderCollector` | Adds a collector to the collection |
| `RemoveCollector(key)` | `bool` | `Remove-PSScriptBuilderCollector` | Removes a collector by key. Returns `$true` if removed, `$false` if not found |
| `GetCollector(key)` | `PSScriptBuilderCollectorBase` | `Get-PSScriptBuilderCollector` | Returns the collector with the given key |
| `GetCollectors()` | `PSScriptBuilderCollectorBase[]` | `Get-PSScriptBuilderCollector` | Returns all collectors, sorted by `CollectorType` |
| `GetCount()` | `int` | — | Number of registered collectors |
| `Clear()` | `void` | — | Removes all collectors at once |

`GetCount()` and `Clear()` have no cmdlet equivalent. `GetCount()` is useful for asserting that
all expected collectors were registered before starting a build. `Clear()` resets the object for
reuse — for example in a script that dynamically rebuilds the collector configuration.

---

## Tips

!!! tip "Use fluent chaining for build scripts"
    `Add-PSScriptBuilderCollector` returns the `ContentCollector`, making it easy to chain
    multiple registrations in one expression. This keeps build scripts readable and compact.

!!! tip "Prefer `-IncludePath` over `-IncludeFile` for directories"
    `-IncludePath` handles new files automatically as your project grows. Use `-IncludeFile`
    only when you need precise control over a small, fixed set of files.

!!! tip "Use `-NoRecurse` for flat source layouts"
    If all your classes sit directly in one folder without subdirectories, `-NoRecurse` avoids
    accidentally picking up files in nested test or temporary directories.

!!! warning "Collection keys must be unique"
    Adding two collectors with the same `CollectionKey` throws an `InvalidOperationException`.
    Use distinct keys when registering multiple collectors of the same type.

!!! info "Class and Function collectors track dependencies"
    The `TypeReferences`, `StaticInitializerReferences`, and `CalledFunctions` properties are populated by the AST engine
    during collection and are used by the dependency analyzer to determine load order. You do
    not need to configure this — it happens automatically.

---

## See Also

- [Dependency Analysis Guide](dependency-analysis.md) — how class and function dependencies are resolved


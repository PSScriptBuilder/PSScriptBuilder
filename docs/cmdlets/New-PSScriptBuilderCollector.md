---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# New-PSScriptBuilderCollector

## SYNOPSIS
Creates a new collector for PowerShell script components.

## SYNTAX

```
New-PSScriptBuilderCollector [-Type] <String> [[-CollectionKey] <String>] [[-IncludePath] <String[]>]
 [[-IncludeFile] <String[]>] [[-ExcludePath] <String[]>] [[-ExcludeFile] <String[]>] [-NoRecurse]
 [<CommonParameters>]
```

## DESCRIPTION
The New-PSScriptBuilderCollector cmdlet creates a collector instance for extracting specific
PowerShell components (Using statements, Enums, Classes, Functions, or Files) from source files.

The collector can be used standalone for exploration and analysis, or added to a ContentCollector
for build operations.
Filter options allow precise control over which files and paths are processed.

Path validation warnings are issued for non-existent paths, but the collector is still created
to allow for scenarios where paths may be created later.

## EXAMPLES

### EXAMPLE 1
```
New-PSScriptBuilderCollector -Type Class -CollectionKey "CLASSES" -IncludePath "src/Classes"
```

Creates a class collector with a custom key that scans all files in src/Classes directory.

### EXAMPLE 2
```
$collector = New-PSScriptBuilderCollector -Type Function -CollectionKey "PUBLIC" `
    -IncludePath "src/Functions" -ExcludeFile "*.Internal.ps1"
$collector.Collect()
$collector.FunctionData.Keys
```

Creates a function collector, executes collection, and displays all found function names.

### EXAMPLE 3
```
New-PSScriptBuilderCollector -Type Enum -CollectionKey "ENUMS" `
    -IncludePath "src/Enums" -IncludeFile "*.ps1"
```

Creates an enum collector with explicit file pattern filtering.

### EXAMPLE 4
```
$collector = New-PSScriptBuilderCollector -Type Class -CollectionKey "DOMAIN" `
    -IncludePath "src/Classes" -ExcludePath "src/Classes/Legacy"
```

Creates a class collector that includes src/Classes but excludes the Legacy subdirectory.

## PARAMETERS

### -Type
The type of collector to create.
Valid values:

- Using: Collects using statements
- Enum: Collects enumeration definitions
- Class: Collects class definitions
- Function: Collects function definitions
- File: Collects entire file contents

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionKey
An optional unique identifier for this collector.
If not specified, the collector uses its default key
(e.g., "CLASS_DEFINITIONS" for Class type, "FUNCTION_DEFINITIONS" for Function type).

Use custom keys to distinguish multiple collectors of the same type with different configurations.
Must be unique within a ContentCollector.

Examples: "CLASSES_DOMAIN", "CLASSES_UTILS", "FUNCTIONS_PUBLIC"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludePath
One or more directory paths to scan for components.
Paths are relative to the project root
or can be absolute.
All files in these paths will be processed unless excluded.

Example: "src/Classes", "src/Classes/Domain"

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeFile
One or more specific files to include.
Supports glob patterns.
Takes precedence over ExcludeFile.
Paths are relative to the project root or can be absolute.

Example: "*.ps1", "src/Classes/MyClass.ps1"

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludePath
One or more directory paths to exclude from processing.
Overrides IncludePath if a path matches both.

Example: "src/Classes/Archive", "src/Classes/Deprecated"

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeFile
One or more file patterns to exclude.
Supports glob patterns.
Useful for excluding specific files
like internal implementations or test files.

Example: "*.Internal.ps1", "*.Tests.ps1"

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoRecurse
When specified, only the top-level directory of each IncludePath is scanned.
By default, all subdirectories are scanned recursively.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSScriptBuilderCollectorBase
## NOTES
Collectors are designed to be used in two ways:
1.
Standalone: Create, call Collect(), inspect results directly
2.
Build Integration: Create and add to ContentCollector for build operations

Path validation is performed with warnings but does not prevent collector creation,
allowing flexibility for dynamic path scenarios.

## RELATED LINKS

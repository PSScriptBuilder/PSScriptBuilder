---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Get-PSScriptBuilderCollectorContent

## SYNOPSIS
Retrieves collected data from a collector.

## SYNTAX

```
Get-PSScriptBuilderCollectorContent [-Collector] <PSScriptBuilderCollectorBase> [[-ItemName] <String>]
 [<CommonParameters>]
```

## DESCRIPTION
The Get-PSScriptBuilderCollectorContent cmdlet retrieves the data that has been collected
by a specific collector.
This includes classes, functions, enums, using statements, or file
contents, depending on the collector type.

The cmdlet returns actual data objects (PSScriptBuilderClassData, PSScriptBuilderFunctionData, etc.)
which contain detailed information about each collected item including source code, source files,
and dependency information.

Without the -ItemName parameter, all collected items are returned.
With -ItemName, only the
specified item is returned (case-insensitive match).

If the collector has not been executed yet, a warning is displayed and an empty array is returned.

## EXAMPLES

### EXAMPLE 1
```
$classCollector | Get-PSScriptBuilderCollectorContent | 
    Where-Object { $_.BaseClass -eq "PSScriptBuilderBase" }
```

Retrieves all classes that inherit from PSScriptBuilderBase using pipeline and Where-Object.

### EXAMPLE 2
```
$baseClass = Get-PSScriptBuilderCollectorContent -Collector $classCollector -ItemName "PSScriptBuilderBase"
Write-Host $baseClass.SourceCode
```

Retrieves a specific class by name and displays its source code.

### EXAMPLE 3
```
# Debugging: Which classes were collected?
$cc.GetCollectors() | Where-Object { $_.CollectorType -eq 'Class' } | ForEach-Object {
    $items = Get-PSScriptBuilderCollectorContent -Collector $_
    Write-Host "$($_.CollectionKey): $($items.Count) classes"
    $items | Select-Object Name, SourceFile | Format-Table
}
```

Lists all class collectors and shows what each collected.

### EXAMPLE 4
```
# Validation: Are all expected components present?
$functions = Get-PSScriptBuilderCollectorContent -Collector $funcCollector
$expected = @("Get-Data", "Set-Data", "Remove-Data")
$missing = $expected | Where-Object { $_ -notin $functions.Name }
if ($missing) {
    throw "Missing functions: $($missing -join ', ')"
}
```

Validates that all expected functions were collected.

### EXAMPLE 5
```
# Dependency analysis: Which classes use PSScriptBuilderLogger?
Get-PSScriptBuilderCollectorContent -Collector $classCollector |
    Where-Object { $_.TypeReferences -contains "PSScriptBuilderLogger" } |
    Select-Object Name, SourceFile
```

Finds all classes that reference PSScriptBuilderLogger.

### EXAMPLE 6
```
# Collector status check
$collector = Get-PSScriptBuilderCollector -ContentCollector $cc -CollectionKey "FUNCTIONS"
$content = Get-PSScriptBuilderCollectorContent -Collector $collector
if ($content.Count -eq 0) {
    Write-Warning "No functions collected. Check IncludePaths or execute ContentCollector."
}
```

Checks if collector has collected any data.

### EXAMPLE 7
```
# Find all source files that were scanned
$classCollector | Get-PSScriptBuilderCollectorContent |
    Select-Object -ExpandProperty SourceFile -Unique |
    Sort-Object
```

Lists all unique source files that contained class definitions.

### EXAMPLE 8
```
# Using statements with file tracking
$usingData = Get-PSScriptBuilderCollectorContent -Collector $usingCollector
foreach ($using in $usingData) {
    Write-Host "Statement: $($using.Statement)"
    Write-Host "  Found in $($using.SourceFiles.Count) file(s):"
    $using.SourceFiles | ForEach-Object { Write-Host "    - $_" }
}
```

Displays all using statements with the files where they were found.

## PARAMETERS

### -Collector
The collector instance to retrieve data from.
Must be a PSScriptBuilderCollectorBase or one
of its derived types:

- PSScriptBuilderClassCollector
- PSScriptBuilderFunctionCollector
- PSScriptBuilderEnumCollector
- PSScriptBuilderUsingCollector
- PSScriptBuilderFileCollector

```yaml
Type: PSScriptBuilderCollectorBase
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -ItemName
Optional.
The name of a specific item to retrieve.
The match is case-insensitive.

For ClassCollector: Class name
For FunctionCollector: Function name
For EnumCollector: Enum name
For UsingCollector: Using statement (exact match)
For FileCollector: File name

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSCustomObject[]
## NOTES
The cmdlet accesses the data properties of collector objects:

- ClassCollector.ClassData.Values
- FunctionCollector.FunctionData.Values
- EnumCollector.EnumData.Values
- UsingCollector.UsingData.Values
- FileCollector.FileData.Values

All collectors use Dictionary\[string, XxxData\] structures internally, and this cmdlet
retrieves the Values collection which contains the actual data objects.

If the collector has not been executed, the data dictionaries will be empty. 
The cmdlet detects this and displays a warning to guide the user.

The -ItemName parameter performs a case-insensitive lookup.
For Dictionary-based collectors,
this is efficient.
For collectors with many items, consider filtering the full result set
with Where-Object for more complex queries.

This cmdlet is designed for inspection and debugging during development.
For production
builds, the collected data is automatically processed by the build pipeline without needing
to call this cmdlet.

## RELATED LINKS

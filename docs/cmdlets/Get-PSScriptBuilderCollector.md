---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Get-PSScriptBuilderCollector

## SYNOPSIS
Retrieves collectors from a ContentCollector.

## SYNTAX

```
Get-PSScriptBuilderCollector [-ContentCollector] <PSScriptBuilderContentCollector> [[-CollectionKey] <String>]
 [[-Type] <PSScriptBuilderCollectorType>] [<CommonParameters>]
```

## DESCRIPTION
The Get-PSScriptBuilderCollector cmdlet retrieves one or more collectors from a ContentCollector
instance.
Without parameters, it returns all registered collectors.
With optional filters,
you can retrieve a specific collector by key or filter by collector type.

The cmdlet returns actual PSScriptBuilderCollectorBase objects (not simplified PSCustomObjects),
which enables:

- Direct property access (IncludePaths, ExcludePaths, etc.)
- Pipeline compatibility with Remove-PSScriptBuilderCollector
- Use with Get-PSScriptBuilderCollectorContent for data inspection

Collectors are returned sorted by their CollectorType (Using, Enum, Class, Function, File),
which reflects their execution order during collection.

## EXAMPLES

### EXAMPLE 1
```
$cc | Get-PSScriptBuilderCollector
```

Retrieves all collectors using pipeline input.

### EXAMPLE 2
```
Get-PSScriptBuilderCollector -ContentCollector $cc -CollectionKey "CLASSES"
```

Retrieves only the collector with the key "CLASSES".
Returns null if not found.

### EXAMPLE 3
```
Get-PSScriptBuilderCollector -ContentCollector $cc -Type ClassCollector
```

Retrieves all ClassCollectors from the ContentCollector.
This includes collectors
with different keys (e.g., "CLASSES_DOMAIN", "CLASSES_UTILS").

### EXAMPLE 4
```
$collectors = $cc | Get-PSScriptBuilderCollector
$collectors | Format-Table CollectorType, CollectionKey, @{N='Paths';E={$_.IncludePaths.Count}}
```

Retrieves all collectors and displays them in a formatted table with custom columns.

### EXAMPLE 5
```
$classCollector = Get-PSScriptBuilderCollector -ContentCollector $cc -CollectionKey "CLASSES"
$classCollector.IncludePaths
```

Retrieves a specific collector and accesses its properties directly.

### EXAMPLE 6
```
# Find collectors with no IncludePaths configured
Get-PSScriptBuilderCollector -ContentCollector $cc |
    Where-Object { -not $_.IncludePaths -or $_.IncludePaths.Count -eq 0 }
```

Uses Where-Object to filter collectors based on their configuration.

### EXAMPLE 7
```
# Remove all File collectors
Get-PSScriptBuilderCollector -ContentCollector $cc -Type File |
    ForEach-Object {
        Remove-PSScriptBuilderCollector -ContentCollector $cc -CollectionKey $_.CollectionKey
    }
```

Demonstrates pipeline compatibility with Remove-PSScriptBuilderCollector.

## PARAMETERS

### -ContentCollector
The ContentCollector instance to query for collectors.
This is the orchestrator object
that manages all registered collectors.

```yaml
Type: PSScriptBuilderContentCollector
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -CollectionKey
Optional.
Retrieves only the collector with this specific key.
The key is case-insensitive.

If no collector with the specified key exists, an error is written and null is returned.

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

### -Type
Optional.
Filters collectors by their type.
Valid values:

- UsingCollector: Collects using statements
- EnumCollector: Collects enumeration definitions
- ClassCollector: Collects class definitions
- FunctionCollector: Collects function definitions
- FileCollector: Collects entire file contents

Returns all collectors of the specified type.

```yaml
Type: PSScriptBuilderCollectorType
Parameter Sets: (All)
Aliases:
Accepted values: UsingCollector, EnumCollector, ClassCollector, FunctionCollector, FileCollector

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSScriptBuilderCollectorBase[]
## NOTES
The cmdlet delegates to PSScriptBuilderContentCollector methods:

- GetCollectors() - Returns all collectors sorted by type
- GetCollector(key) - Returns specific collector by key

The CollectorCollection uses case-insensitive string comparison for keys.

When filtering by Type, the cmdlet uses GetCollectors() and filters the array.
This is more efficient than iterating manually since GetCollectors() already sorts.

If a CollectionKey is specified but not found, the underlying method throws
KeyNotFoundException, which is caught and converted to a user-friendly error message.

For inspecting the collected data (classes, functions, etc.), use
Get-PSScriptBuilderCollectorContent which accepts the collector objects returned by this cmdlet.

## RELATED LINKS

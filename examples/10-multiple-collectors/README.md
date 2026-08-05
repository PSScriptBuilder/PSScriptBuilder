# Example 10 - Multiple Collectors

This example shows how to use **multiple collectors of the same type** to model a layered project
structure. A logging framework is split into a Core layer (`LogLevel`, `LogEntry`, `LogFormatter`,
`LoggerBase`) and an Extensions layer (`ConsoleLogger`, `FileLogger`). Each layer gets its own
`Class` collector and `Function` collector with a distinct `CollectionKey`. The template controls
the output order explicitly by naming all five keys.

## New in this example

- `Add-PSScriptBuilderCollector -CollectionKey` - assigns a custom key to a collector
- Multiple collectors of the same type (`Class`, `Function`) on one `ContentCollector`
- Template placeholders that match the custom keys: `{{CoreEnums}}`, `{{CoreClasses}}`, etc.
- Explicit layer ordering controlled entirely by the template

## Key concepts

**Multiple collectors of the same type** allow a project to be split into logical layers. Each
collector scans its own directory and produces content under its own key. PSScriptBuilder has no
built-in concept of layers - the template is the only thing that defines the output order.

**`CollectionKey`** is the name used both when registering the collector and in the template
placeholder. If a key is omitted, PSScriptBuilder uses a default based on the collector type
(`CLASS_DEFINITIONS`, `FUNCTION_DEFINITIONS`, etc.). When multiple collectors share a type, each
one needs a unique key.

**Why `[LogEntry]::new()` in `Write-Log`?** If `Write-Log` called `New-LogEntry` instead,
PSScriptBuilder would detect a function-to-function dependency and try to sort `New-LogEntry`
before `Write-Log` within the same `CoreFunctions` collector. Using the constructor directly
avoids this and keeps the two collectors independent. See
[Factory functions and cross-dependencies](../../docs/guides/dependency-analysis.md#factory-functions-and-cross-dependencies).

## Project structure

```
10-multiple-collectors/
+-- Run-Example.ps1                             Entry point
+-- Demo-Module.ps1                             Loads built module, demonstrates types
+-- README.md                                   This file
+-- psscriptbuilder.config.json                 Build configuration
+-- src/
|   +-- Core/
|   |   +-- Enums/
|   |   |   +-- LogLevel.ps1                   Enum: Trace, Debug, Info, Warning, Error, Critical
|   |   +-- Classes/
|   |   |   +-- LogEntry.ps1                   Class: Timestamp, Level, Message, Source
|   |   |   +-- LogFormatter.ps1               Class: Format() method
|   |   |   +-- LoggerBase.ps1                 Class: abstract Write() method
|   |   +-- Functions/
|   |       +-- New-LogEntry.ps1               Factory function, returns [LogEntry]
|   |       +-- Write-Log.ps1                  Dispatches a log entry to a logger
|   +-- Extensions/
|       +-- Classes/
|       |   +-- ConsoleLogger.ps1              Class: inherits LoggerBase, writes to console
|       |   +-- FileLogger.ps1                 Class: inherits LoggerBase, appends to file
|       +-- Functions/
|           +-- New-ConsoleLogger.ps1          Factory function, returns [ConsoleLogger]
|           +-- New-FileLogger.ps1             Factory function, returns [FileLogger]
+-- build/
    +-- Templates/
    |   +-- AppLogFramework.psm1.template      Template with five layer-specific placeholders
    +-- Output/
        +-- AppLogFramework.psd1               Module manifest (pre-existing, not generated)
```

## How to run

> **Warning:** Run in a fresh PowerShell session  
> The `using module` statement loads types into the current session.  
> Reloading or switching between examples in the same session can cause type conflicts.

```powershell
.\Run-Example.ps1
```

For detailed build output:

```powershell
.\Run-Example.ps1 -Verbose
```

## How it works

1. Five collectors are registered, each with its own `CollectionKey` and source directory
2. `Invoke-PSScriptBuilderBuild` runs all five collectors, analyzes dependencies within each layer, and replaces the five template placeholders in order
3. The Extensions layer classes (`ConsoleLogger`, `FileLogger`) depend on Core layer types - PSScriptBuilder resolves this correctly because the template places `{{CoreClasses}}` before `{{ExtensionClasses}}`
4. `Run-Example.ps1` calls `Demo-Module.ps1` as a child script via `&`
5. `Demo-Module.ps1` loads the built module with `using module` and uses typed `LogEntry`, `ConsoleLogger` objects

## Expected output

```
Build Summary
  Output: ...\build\Output\AppLogFramework.psm1
  Size  : 2.79 KB
  Time  : 1.35 s

Components
  Enums    :  1
  Classes  :  5
  Functions:  4
  Total    : 10

--- Running Demo-Module.ps1 ---
[03:21:24] [Info    ] [App] Application started
[03:21:24] [Debug   ] [Config] Loading configuration
[03:21:24] [Warning ] [Network] Retry limit approaching
[03:21:24] [Error   ] [Network] Connection timed out

Type of entry  : LogEntry
Type of logger : ConsoleLogger
```

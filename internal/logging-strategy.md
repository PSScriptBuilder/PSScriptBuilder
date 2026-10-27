# Logging Strategy

## Overview

PSScriptBuilder uses `Write-Verbose` for diagnostic output. This document defines the rules for consistent, maintainable logging across the codebase.

## Indentation Convention

Indentation reflects the nesting depth *within* a single operation:

| Depth | Indent | Example |
|---|---|---|
| Operation level | 0 spaces | `"Collecting class definitions from 5 file(s)..."` |
| Sub-step | 2 spaces | `"  Parsing: MyClass.ps1"` |
| Detail within sub-step | 4 spaces | `"    Found 1 class definition(s), 1 new"` |
| Detail within detail | 6 spaces | `"      Retrieving source for Class MyClass"` |

## Rules

### Rule 1 — Indentation reflects depth within an operation

The indent in a log message reflects how deeply nested a step is *within* that operation. It does not reflect the call-stack depth between callers.

### Rule 2 — Workers log their own actions

A worker (class method) logs its own start and completion at 0-space, and its own internal loops at 2-space. A worker does not log what its dependencies do.

### Rule 3 — Cmdlets provide the frame

Public cmdlets log `"What I am doing"` at 0-space. They do **not** log what workers below them do (no double-logging).

### Rule 4 — Utility methods do not log

Methods that can be called from multiple depths (e.g., shared helpers, factory methods) do **not** contain `Write-Verbose` calls. The caller owns the log message and places it at the correct indentation level.

*Rationale:* A utility method has no knowledge of its position in the call hierarchy. If it logs, the message will be incorrectly indented in at least one calling context.

### Rule 5 — All callers log the action

When a method falls under Rule 4, **every** caller must log the action at its own indentation level. No caller may silently omit it.

## Current Application: `PSScriptBuilderConfiguration.CreateDefault()`

`CreateDefault()` is a factory method called from two different depths:

| Caller | Depth | Expected indent |
|---|---|---|
| `New-PSScriptBuilderConfiguration` | Top-level (cmdlet) | 0 spaces |
| `PSScriptBuilderScaffolder.CreateConfigFile()` | Sub-step of Scaffolder | 2 spaces |

**Resolution (Rule 4 + Rule 5):**

- `CreateDefault()` — no `Write-Verbose`
- `New-PSScriptBuilderConfiguration` — logs `"Configuration file created: $configPath"` (0-space)
- `PSScriptBuilderScaffolder.CreateConfigFile()` — logs `"  Created configuration file: $configPath"` (2-space)


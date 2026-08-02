# ADR 0001: Exception Handling in PSScriptBuilderConfigValidator

## Status
**Accepted**

Date: 2026-02-01

## Context

The `PSScriptBuilderConfigValidator` class validates the PSScriptBuilder configuration structure during application initialization. When validation fails, two types of errors can occur:

1. **Unknown configuration option** - A property exists in the config that is not defined in the schema
2. **Required field missing** - A required property is missing from the configuration

The question was whether to use custom exceptions (e.g., `ConfigurationValidationException`) or standard .NET exceptions for these validation errors.

## Decision

Use standard `InvalidOperationException` for all config validation errors. Do NOT implement custom exception types at this time.

### Implementation Details

- Unknown option error → `[InvalidOperationException]`
- Required field missing error → `[InvalidOperationException]`
- Exception messages are descriptive and include the full property path (e.g., `"log.file.mode"`)

### Example

```powershell
$message = "Unknown configuration option: 'build.invalidOption'"
throw [InvalidOperationException]::new($message)
```

## Rationale

### Why Standard Exceptions

1. **Consistency** - The project already uses `InvalidOperationException` in `PSScriptBuilderReleaseValidator` for validation errors, establishing a project-wide pattern
2. **PowerShell Convention** - Standard .NET exceptions are conventional in PowerShell; custom exceptions are rarely needed
3. **Simplicity** - Fewer classes to maintain and document
4. **YAGNI** - Currently, the build process doesn't require granular error handling that would necessitate custom exception types

### Why Not Custom Exceptions

- Would add complexity without immediate benefit
- Build scripts currently don't differentiate between config errors and other errors
- Exception message itself provides sufficient context (full property path included)
- Easily refactorable later if requirements change

## Alternatives Considered

1. **Custom `ConfigurationValidationException`** - More semantic but unnecessary overhead for current use case
2. **ArgumentException** - Less appropriate; not about method arguments but about data validation
3. **Catch-by-message** - Less reliable; coupled to exception message format

## Consequences

### Positive
- Consistent with existing validator patterns in the codebase
- Low maintenance burden
- No additional learning curve for developers

### Negative
- Build scripts cannot differentiate config errors from other `InvalidOperationException` errors (though unlikely to be needed)
- Slightly less semantic than a custom exception type

### Mitigation
- If future requirements demand granular error handling, custom exceptions can be introduced with minimal code changes (only the `throw` statements need to be updated)

## When to Revisit

Reconsider this decision if:

1. The build process needs to handle config validation errors differently than other runtime errors
2. Multiple validator classes begin throwing exceptions and a unified error hierarchy becomes valuable
3. External integrations need to programmatically detect and handle config validation errors specifically
4. Error logging/monitoring requires distinguishing config errors from other `InvalidOperationException` cases

## Related Decisions

- Similar validation patterns are used in `PSScriptBuilderReleaseValidator`
- Config structure validation is centralized in `PSScriptBuilderConfigValidator` to avoid validation logic scattered across multiple `ValidateOptions()` methods

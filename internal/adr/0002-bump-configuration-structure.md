# ADR 0002: Bump Configuration Structure and Extensibility

## Status
**Accepted**

Date: 2026-02-04

## Context

The PSScriptBuilder Release Management system requires a bump configuration that specifies which files should be updated during version bumping and how tokens should be replaced. The initial implementation has a single root property `bumpFiles` containing an array of file configurations.

As the project evolves, additional global bump options may be needed:

1. **Process Control** - Enable/disable bumping, choose auto vs. manual mode
2. **File Handling** - Create backups before bumping, skip missing files
3. **Validation** - Validate after bumping, stop on error
4. **Token Behavior** - Case sensitivity, special character escaping, token delimiters
5. **Audit & Logging** - Log levels, change tracking

The question was whether to store only `bumpFiles` at the root level (flat array) or keep a `bumpFiles` wrapper property to accommodate future options.

## Decision

Keep the `bumpFiles` property as a root-level object with the following structure:

```json
{
  "bumpFiles": [
    {
      "path": "file/path",
      "tokens": ["TOKEN1", "TOKEN2"],
      // or
      "items": [
        {
          "pattern": "regex/pattern",
          "tokens": ["TOKEN"]
        }
      ]
    }
  ]
}
```

### Rationale for This Design

1. **Forward Compatibility** - The structure is ready to accept additional options without breaking the current API:
   ```json
   {
     "enabled": true,
     "backupFiles": true,
     "stopOnError": true,
     "bumpFiles": [...]
   }
   ```

2. **Semantic Clarity** - The `bumpFiles` key clearly indicates what the array contains
3. **Consistency** - Follows the pattern of other hierarchical configurations in PSScriptBuilder
4. **Extensibility** - New options can be added without renaming `bumpFiles` or restructuring existing code

## Alternatives Considered

1. **Root-Level Array** - JSON as direct array of files
   - **Pros:** Simpler initial structure
   - **Cons:** Cannot add global options later without breaking compatibility
   - **Rejected:** Inflexible for future requirements

2. **Deeply Nested Options** - Options under `bumpFiles.options`
   - **Pros:** Logically groups bumping-related settings
   - **Cons:** Awkward API (always must access via `.bumpFiles.options`)
   - **Rejected:** Less intuitive for CLI cmdlets

## Future Extensions

When adding global bump options, the following properties should be considered:

### Process Control
- `enabled` (boolean): Whether bumping is globally enabled
- `mode` (string): "auto" | "manual" | "dry-run"

### File Handling
- `backupFiles` (boolean): Create backup before modifying files
- `backupSuffix` (string): Backup file suffix (default: ".bak")
- `skipMissingFiles` (boolean): Continue if a file is not found

### Validation
- `validateAfter` (boolean): Validate files after bumping
- `stopOnError` (boolean): Stop on first error vs. collect all errors

### Token Behavior
- `caseSensitive` (boolean): Token matching case sensitivity
- `escapeSpecialChars` (boolean): Escape special regex characters in values
- `tokenPrefix` (string): Token prefix (default: "{{")
- `tokenSuffix` (string): Token suffix (default: "}}")

### Audit & Logging
- `logLevel` (string): "verbose" | "normal" | "quiet"
- `auditTrail` (boolean): Log all replacements for audit purposes

Example future structure:
```json
{
  "enabled": true,
  "backupFiles": true,
  "stopOnError": true,
  "validateAfter": false,
  "bumpFiles": [...]
}
```

## Implementation Details

### Cmdlet Behavior
- `Get-PSScriptBuilderBumpConfiguration` returns the complete configuration object
- Users access the array via PowerShell indexing: `$config.bumpFiles[0]`
- When global options are added, they will automatically be available: `$config.enabled`, `$config.backupFiles`, etc.

### Internal Processing
- The orchestrator loads the complete configuration
- Options are passed to the bump processor as parameters or configuration object
- No API changes required for cmdlet; only internal implementations update

## Consequences

### Positive
- Accommodates future requirements without breaking changes
- Clear separation between global options and file-level configurations
- Maintains backward compatibility when options are added
- Intuitive for users (root-level options affect all files by default)

### Negative
- Slightly more complex initial structure than a flat array
- Requires property access (`$config.bumpFiles`) rather than direct array indexing
- May feel over-engineered if options are never added (unlikely)

### Mitigation
- Documentation clearly explains the design rationale
- Cmdlet help demonstrates the structure and access patterns
- ADR exists for future maintainers to understand the extensibility intent

## When to Implement

Add global options only when:

1. **Business Need Exists** - A specific feature requires the option (not speculative)
2. **Consistency** - The option applies to all or most bump operations
3. **User Request** - Configuration is needed at user level, not just developer time

Add options in this order:
1. `enabled` / `mode` - Process control (highest priority)
2. `backupFiles` / `stopOnError` - File safety (second priority)
3. `validateAfter` / advanced token options - Nice-to-have (later)

## Related Decisions

- ADR 0001: Validator exception handling applies to bump configuration validation
- Two-mode BumpFiles design (tokens simple vs. items complex) is independent and documented separately
- Token map structure uses `OrderedDictionary` for consistency (documented in code comments)

## Review Criteria

This decision should be revisited if:

1. New use cases require options that don't fit at root level
2. Bump configuration needs to be nested under another category
3. Performance requirements change (unlikely for JSON configuration)
4. External tools need to understand bump configuration format

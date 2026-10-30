# RFC 0015: Release Management Custom Exceptions

- **Status:** Decided — deferred until after the 1.3.0 release
- **Type:** Feature
- **Created:** 2026-09-08
- **Branch:** none yet — deliberately not tied to `refactor/release-management-bump-mode`

## Summary

Introduce a small set of PSScriptBuilder-specific exception types for Release Management, piloting
the idea before considering it for the larger ScriptBuilder subsystem. Rather than one class per
error message, use a few broad types grouped by error *kind* (bad input vs. bad state), each
carrying structured properties (e.g. a `Reason` enum, the offending pattern) instead of relying
solely on a formatted message string. New custom types inherit from the semantically matching
built-in .NET exception (e.g. `ArgumentException`), so existing and future generic
`catch [System.ArgumentException]`-style consumer code keeps working.

## Motivation

Raised while discussing RFC 0012/0013's parked "improve the misleading exception message" item -
a custom exception with a `Reason` property (e.g. `MixedSyntax`, `UnrecognizedSyntax`) would let
`ValidateItemConfiguration` and `DetermineBumpPatternMode` produce both a good default message and
a value calling code can branch on programmatically, without string-matching.

**Surveyed the whole `src/` tree before designing anything** (241 `throw [...]` sites total):
`InvalidOperationException` 98, `ArgumentException` 65, `ArgumentNullException` 33,
`IOException` 20, `FileNotFoundException` 11, `NotImplementedException` 6, smaller counts for
`FormatException`/`KeyNotFoundException`/`EncoderFallbackException`/`DirectoryNotFoundException`.
Zero custom exception classes exist anywhere today - every throw site uses a built-in .NET type.
By subsystem: ScriptBuilder 137 throw sites, Release Management 64, Configuration 20, Scaffolding
2, Common 0.

**Checked whether any existing code depends on catching by built-in type, since that would
constrain the design - confirmed this constraint applies only to ScriptBuilder, not Release
Management.** Every `src/Public/*.ps1` file was checked: `Test-PSScriptBuilderTemplate.ps1` does
`catch [System.InvalidOperationException]` / `catch [System.ArgumentException], [System.ArgumentNullException]` /
`catch [System.IO.FileNotFoundException]` around `PSScriptBuilderTemplateAnalyzer`/
`PSScriptBuilderTemplateModeResolver`/`PSScriptBuilderTemplateValidator` calls, and
`Get-PSScriptBuilderCollector.ps1` does `catch [KeyNotFoundException]` - both ScriptBuilder-side.
`Update-PSScriptBuilderBumpFiles.ps1` (Release Management's actual public entry point) uses a fully
generic `catch { $PSCmdlet.ThrowTerminatingError($_) }` with no type discrimination at all - no
existing internal consumer would break from an independent exception base here. (An initial pass at
this analysis wrongly generalized the ScriptBuilder-side constraint onto Release Management too;
re-verified precisely after being asked to check again.)

**Decided to still inherit from built-in bases anyway, for a different reason than backward
compatibility: PSScriptBuilder is a published PowerShell Gallery module** (the artifact
`Build-Module.ps1` produces, not `build.ps1`'s bootstrap output). External, not-yet-written
consumer scripts commonly wrap arbitrary cmdlet calls in generic `catch [System.ArgumentException]`
blocks; an independent `PSScriptBuilderException : Exception` base would silently stop those from
catching PSScriptBuilder-specific errors. This is a forward-compatibility argument, not a
backward-compatibility one.

**Verified PowerShell-class-specific mechanics empirically before committing to this design**
(built a real `class TestBumpException : ArgumentException` and exercised it):
- Catching by the base type (`catch [ArgumentException]`) and by the specific custom type both work
  correctly; custom properties survive.
- `$PSCmdlet.ThrowTerminatingError($_)` (Release Management's existing pattern) preserves the
  custom type, message, and custom properties.
- Pester's `Should -Throw -ExceptionType` works with both the custom type and its base type; custom
  properties remain accessible on `$_.Exception` afterward.
- **Found two real, previously-unknown PowerShell-specific gotchas:**
  1. PowerShell classes do **not** automatically inherit the standard .NET exception constructor
     overloads (parameterless, `(message)`, `(message, innerException)`) - only the constructors
     explicitly defined on the class exist. Worse: calling the class's own constructor with an
     argument of the wrong type does not fail - PowerShell silently coerces it (e.g. passing an
     `Exception` object where a `[string]` parameter is declared calls `.ToString()` on it
     silently), which could produce confusing, hard-to-notice bugs if constructor signatures are
     not designed carefully.
  2. A custom exception's type identity does not survive crossing a runspace/job boundary -
     verified with `Start-Job`: the returned error's exception type becomes a generic
     `System.Management.Automation.PSObject`, so `catch [PSScriptBuilderXyzException]` would no
     longer match after such a boundary, though the message and custom properties remain accessible
     via property access. Not relevant to PSScriptBuilder's own internal (synchronous) execution,
     but relevant if a consumer wraps a PSScriptBuilder cmdlet call in their own background job or
     remoting session (e.g. a CI pipeline running parallel builds).

**Decided to defer rather than implement now:** the topic turned out larger than "a quick
addition" - granularity, rollout scope, and future-subsystem consistency (see Detailed Design) are
interdependent decisions each deserving careful thought, and 1.3.0's release has priority.
Documenting the completed analysis now (rather than only a memory note) means the next session
picks up a decided design, not a fresh investigation.

## Detailed Design

### Root Cause

Release Management's 64 throw sites all use built-in .NET exception types with only a formatted
message string to distinguish the specific failure - there is no way for calling code (or a future
richer error-reporting layer) to programmatically distinguish e.g. "pattern mixes syntaxes" from
"pattern is empty" without parsing message text.

### Decision

- **Granularity:** a small number of exception types grouped by error *kind*, not one class per
  message and not one class per subsystem. Concretely: `PSScriptBuilderValidationException :
  ArgumentException` (covers today's `ArgumentException`/`ArgumentNullException`/`FormatException`
  throw sites - "the input given was wrong") and `PSScriptBuilderOperationException :
  InvalidOperationException` (covers today's `InvalidOperationException` throw sites - "the
  operation cannot proceed given the current state"), each carrying a `[string] $Reason` (or a
  small enum once the concrete reasons are enumerated during implementation) plus whatever specific
  context properties make sense for the call site (e.g. `Pattern`, `TokenName`, `FilePath`).
  File-system-related throws (`IOException`/`FileNotFoundException`) are left as built-in types for
  now - they already carry sufficient built-in context (e.g. `FileNotFoundException.FileName`) and
  are not part of the motivating use case.
- **Rollout scope:** purely additive. Only new code (e.g. a future explicit `mode` field, if that
  idea is pursued) uses the new exception types; the existing 64 throw sites are left as built-in
  types unless a specific, separate follow-up decides to retrofit them. Retrofitting is a
  substantially larger undertaking (9 files) that should be judged on its own merits later, not
  bundled into introducing the types themselves.
- **PowerShell mechanics to apply:** design each new exception class's constructor signature
  carefully and deliberately (given the silent-coercion gotcha above) - prefer explicit, unambiguous
  parameter types and avoid overloads that differ only in a way PowerShell could silently coerce
  between. Document the runspace/job type-identity limitation in the class's own comment-based help
  so it is not rediscovered by surprise later.
- **Consistency for future subsystems:** adopt a naming convention now (`PSScriptBuilder<Subsystem><Kind>Exception`,
  e.g. `PSScriptBuilderReleaseManagementValidationException` if a subsystem prefix turns out to be
  needed once ScriptBuilder is considered) and a shared minimal property shape (a `Reason` value and
  freeform context), without introducing a shared base class *across* subsystems - ScriptBuilder has
  real existing built-in-type catch sites (see Motivation) that a cross-subsystem base could
  jeopardize, unlike Release Management.
- **File placement:** domain-based, matching the precedent set by `PSScriptBuilderBumpModeResolver`
  (which lives in `Helper/`, not a new folder, despite being a new *kind* of class). Place the new
  exception classes in `src/Classes/ReleaseManagement/Helper/` alongside it, not in a new
  `Exceptions/` folder, unless the count of exception classes grows enough later to justify one.

## Rationale and Alternatives

**Considered one exception class per specific error message** (e.g. a distinct class for each of
the ~10 distinct Release Management error messages found). Rejected - matches neither the .NET
Framework Design Guidelines' recommendation (prefer few exception types with rich properties over
many narrow ones) nor this project's own preference for simplicity; would also make the eventual
ScriptBuilder rollout (137 throw sites) unmanageable if the same granularity were followed there.

**Considered one exception class per subsystem** (a single `PSScriptBuilderReleaseManagementException`
for all 64 sites). Rejected - too coarse to serve the motivating use case (letting a caller
distinguish "pattern conflict" from "empty argument" from "missing token value" without string
matching); barely improves on today's built-in-type-only state.

**Considered a single, independent `PSScriptBuilderException : Exception` base for all future
custom exceptions.** Rejected for Release Management specifically per the forward-compatibility
argument in Motivation (external, generic `catch [ArgumentException]`-style consumer code should
keep working) - even though, unusually, nothing *internal* currently depends on this for Release
Management.

**Considered retrofitting all 64 existing throw sites immediately, alongside introducing the
types.** Rejected as this RFC's scope - see Decision's "Rollout scope." A worthwhile follow-up to
consider once the additive approach has proven itself in real use.

## Scope

**In scope (once un-deferred and implemented):** `PSScriptBuilderValidationException` and
`PSScriptBuilderOperationException` classes in
`src/Classes/ReleaseManagement/Helper/`; using them in whatever new Release Management code
motivates the effort at that time (e.g. the not-yet-drafted explicit `mode`-field idea, or another
new feature); documentation of the two known PowerShell gotchas in the classes' own comment-based
help.

**Out of scope:** retrofitting the existing 64 Release Management throw sites; any change to
ScriptBuilder's exception handling; a cross-subsystem shared exception base.

## Relationship to Other RFCs

Motivated by the exception-message limitation noted in RFC 0012/0013's Revision Logs (the
misleading `InvalidOperationException` for an unescaped-parenthesis/mixed-syntax bump pattern) -
this RFC would, once implemented, give that specific case a `PSScriptBuilderValidationException`
with a `Reason` of e.g. `MixedSyntax` instead of a generic `ArgumentException`, but does not itself
change any bump-pattern *behavior* RFC 0011/0012/0013 already fixed. Independent of the
separately-discussed idea of an optional, explicit `mode` field on bump config items (not yet its
own RFC) - the two could complement each other (an explicit `mode` field validation failure would
be a natural first consumer of the new exception types) but neither depends on the other.

## Test Plan

To be written at implementation time. At minimum: catching a new exception by both its own type and
its built-in base type; `Should -Throw -ExceptionType` coverage for both; a regression test locking
in that the two known PowerShell gotchas (constructor argument coercion, runspace type-identity
loss) behave as documented, so a future .NET/PowerShell version change that alters this behavior is
caught.

## Unresolved Questions

- Exact set of `Reason` values per exception type - to be enumerated by walking the concrete
  Release Management error messages once implementation starts, not guessed now.
- Whether `IOException`/`FileNotFoundException` sites should eventually get a custom type too, or
  permanently stay built-in (current lean: stay built-in, they are not part of the motivating case
  and already carry adequate built-in context).
- Final class names (`PSScriptBuilderValidationException`/`PSScriptBuilderOperationException` are a
  working proposal, not frozen, since implementation is deferred).

## Revision Log

- 2026-09-08 — Initial draft, written after a full-session design discussion (throw-site survey,
  precise verification of which subsystem's existing catch sites constrain the design, and real
  empirical testing of PowerShell-class exception mechanics including two previously-unknown
  gotchas). Decided to defer implementation until after the 1.3.0 release given the topic's actual
  scope, but captured the completed analysis and decisions now rather than only as an informal note.

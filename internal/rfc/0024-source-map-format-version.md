# RFC 0024: Source Map Format Version and Schema

- **Status:** Implemented (2026-11-04) — written alongside the implementation; see Revision Log
- **Type:** Design decision
- **Created:** 2026-11-04
- **Branch:** development

## Summary

The `.sourcemap.json` sidecar now records a `FormatVersion`, and the reader validates every field
against a declarative schema. A sidecar that uses a newer format version than the reading module
supports, is empty, is not a JSON object, lacks a required field or contains an invalid value is
rejected with an `InvalidDataException` that names the problem and how to recover — instead of
being read and silently misinterpreted. Sidecars written by 1.3.x (without `FormatVersion` and
without `ComponentLineCount`) remain readable, exactly as before.

## Motivation

A sidecar is written by one module version and may be read by another — e.g. a different
PSScriptBuilder version installed in CI than locally. If a later version changes the format in a
way an older reader would misinterpret (a field changing its meaning, line numbers becoming
0-based, a component gaining several line ranges), an older reader without a version check reads
the file anyway and returns wrong source locations without any warning: the same class of silent
mis-resolution that RFC 0023 fixed.

The check only protects readers that already know it. 1.3.x does not, and that cannot be changed
anymore; every further release without the check would enlarge the group of unprotected readers.
The release that first changes the sidecar format (adding `ComponentLineCount`, RFC 0023) is
therefore the point to introduce it.

Reviewing the reader for the version check showed the same problem for every other field: values
were converted leniently by PowerShell rather than validated. Reproduced on PS 5.1 and 7:
`ComponentLineCount: true` became 1, `1.5` became 2, `-1` was accepted (making the component
unbounded again), a missing `Components` array was read as a source map without entries, an empty
file likewise, and a `null` entry or a non-numeric value surfaced only as an obscure generic read
error.

## Detailed Design

**`PSScriptBuilderSourceMapFileManager`**

Since 2026-11-05, the format version, the schemas and the conversion described below live in
`PSScriptBuilderSourceMapSerializer` (`Serialize`, `Deserialize`); the file manager reads and
writes the file and delegates the format to it (see Revision Log). The design is otherwise
unchanged.

- New hidden static field `SourceMapFormatVersion = 1`: the version written by, and the highest
  version readable by, this module version.
- New hidden static fields `VersionSchema`, `SidecarSchema` and `ComponentSchema`: declarative
  rules for format version 1, one entry per field with `Required`, `Type`, and `Minimum`/`Default`
  where relevant. `FormatVersion` has its own `VersionSchema` because it is read before the other
  fields and decides whether `SidecarSchema` applies at all.

  | Field | Required | Rule |
  |---|---|---|
  | `FormatVersion` | no (absent → 1) | whole number ≥ 1 |
  | `OutputPath` | yes | non-empty string |
  | `OutputHash` | yes | 64 hexadecimal characters (any case) |
  | `OutputLineCount` | yes | whole number ≥ 0 |
  | `Components` | yes | array (may be empty); each entry a JSON object |
  | `Components[n].ComponentName`, `ComponentType`, `SourceFile` | yes | non-empty string |
  | `Components[n].OutputLineNumber`, `ComponentLineNumber`, `SourceLineNumber` | yes | whole number ≥ 1 |
  | `Components[n].Offset` | yes | whole number ≥ 0 |
  | `Components[n].ComponentLineCount` | no (absent → 0 = unknown) | whole number ≥ 1 |

  Fields not listed are ignored (Tolerant Reader).
- `WriteSourceMapData` writes `FormatVersion` as the first property, and writes a component's
  `ComponentLineCount` only if it is known (greater than 0). An unknown line count is expressed by
  the absence of the field, as the schema defines it.
- `ReadSourceMapData`: after parsing, it rejects an empty sidecar and one that is not a JSON
  object, reads `VersionSchema` and passes the format version to `ThrowIfUnsupportedFormatVersion`
  (named after the .NET `ThrowIf` pattern, e.g. `ArgumentOutOfRangeException.ThrowIfGreaterThan`),
  then reads `SidecarSchema` and converts each component entry via `ConvertToSourceLocation`.
- `ReadFields(container, schema, pathPrefix, sidecarPath)` runs once over a schema's rules and
  returns a hashtable with the converted value of every field, or the rule's default for an absent
  optional field. Properties are looked up via `PSObject.Properties` (a bare access to a missing
  property throws under StrictMode). Values are validated without converting between types: a
  string must be an actual string, a hash must match `^[0-9A-Fa-f]{64}$`, an array must be a JSON
  array, and a whole number must be a JSON whole number of at least `Minimum` that fits into an
  int, in any JSON notation (`1`, `1.0`, `1e0`) — booleans, strings, arrays, objects, fractions and
  out-of-range values are rejected. A plain `[int]` cast would silently turn `true` into 1, round
  `1.5` to 2 and accept `"2"`. An absent required field ("…is missing the required field
  'Components[3].SourceFile'…") or an invalid value ("…has an invalid value for
  'Components[3].OutputLineNumber' (true); expected a whole number of at least 1…") throws
  `InvalidDataException`; values are shown in JSON notation.
- `ConvertToSourceLocation(component, index, sidecarPath)` rejects an entry that is not a JSON
  object and reads all fields of the entry with one `ReadFields` call, so errors name the entry by
  its position in the array.
- Text that is empty or whitespace is rejected as empty before parsing; text that
  `ConvertFrom-Json` cannot parse — `ArgumentException` for malformed JSON,
  `InvalidOperationException` for valid JSON it cannot represent, e.g. keys differing only in
  letter case — is rejected as "could not be parsed as JSON" with the parser exception as
  `InnerException` and its message shortened to 200 characters, since Windows PowerShell 5.1
  appends the complete JSON text to it (added 2026-11-05, see Revision Log).
- Every `InvalidDataException` is passed through `ReadSourceMapData` unchanged, like the existing
  `FileNotFoundException`, instead of being wrapped into the generic "Failed to read source map"
  `IOException`. The verbose summary line included the format version until 2026-11-05 (see
  Revision Log).

**Cmdlets** — unchanged. `Resolve-PSScriptBuilderSourceLocation` and
`Get-PSScriptBuilderSourceCoverage` already wrap every failure into an `InvalidOperationException`
whose message contains the inner message, so the actionable text reaches the user.

**`PSScriptBuilderSourceMapData`** — unchanged apart from its description, which no longer claims
to hold "all fields" of the sidecar.

### When to increment the format version

Only for a change that an older reader would misinterpret: a removed or renamed field, a field
whose meaning changes, or a new field without which the existing fields would be misread (e.g.
additional line ranges for a component). Additive fields that an older reader can safely ignore —
such as `ComponentLineCount` — do not increment it.

Every reader translates each format version it supports into the current in-memory model inside
`ReadSourceMapData` ("upcasting" at the persistence boundary; since 2026-11-05 inside
`PSScriptBuilderSourceMapSerializer.Deserialize`), so no code outside the persistence layer ever
depends on the format version.

## Rationale and Alternatives

**Reject an unknown version rather than read what is possible.** ECMA-426 (the JavaScript source
map format) defines `"version": 3` and allows a consumer to reject any other value; npm's
`package-lock.json` (`lockfileVersion`) instead always tries to read whatever it can. For a source
map, reading an incompatible format leads to wrong locations nobody notices, while the sidecar can
be recreated at any time with `-WriteSourceMap` — so a clear error costs the user little and a
silent misreading costs a lot.

**Strict on known fields, tolerant of unknown ones.** Validating deserialized data once at the
boundary and rejecting what does not fit ("parse, don't validate") lets the rest of the module rely
on valid data. The Tolerant Reader applies to unknown *fields* — a newer version may add them, and
JSON Schema likewise allows additional properties by default — not to the values of known fields.
The module only ever writes valid values, so anything else means a damaged or hand-edited file.

**A declarative schema in code, not a JSON Schema file.** A machine-readable schema as the single
source of truth for a persisted format is established practice (SARIF, a format written and read
only by tools, publishes one). A JSON Schema file cannot be that single source here: PowerShell 5.1
has no `Test-Json -Schema`, so runtime validation would need separate code, i.e. two definitions
that drift apart. And a JSON Schema mainly helps people editing a file in an editor; the sidecar is
written and read only by the module. The in-code schema is the single source of truth on both
PowerShell versions.

**Not the existing configuration validators.** `PSScriptBuilderConfigValidator` (and its copies
for release data and bump files) reject unknown fields — correct for files people edit, where a
typo should surface, but wrong for the sidecar (see above) — and only know `string` and `boolean`.

**By value, not by notation.** JSON has a single number type (RFC 8259, section 6), so `1`, `1.0`
and `1e0` are the same value. JSON Schema states the same for its `integer` type: numbers with a
zero fractional part are integers, whichever representation is used. `ConvertFrom-Json` returns
Int32 or Int64 for `1`, but Double or Decimal for `1.0`, depending on the PowerShell version — so
the check accepts all four numeric types and tests for a zero fractional part.

**`OutputHash` strict.** Every writer produces a 64-character hash. The resolver's handling of an
empty hash as "unknown" applies to data created in memory, which the schema does not affect;
production validation is not loosened for test data.

**`ComponentType` as a free string.** Google's API design guidance (AIP-126) recommends a string
rather than an enum for value sets that are expected to grow. A newer module version may add a
collector type; a fixed list would break older readers exactly then. The known values (`Enum`,
`Class`, `Function`, `File`) are documented as not exhaustive.

**`ComponentLineCount`: absence means unknown.** Distinguishing "not set" from a value such as 0
(explicit field presence, as in Protobuf) keeps the meaning unambiguous: absent means unknown, a
present value is a real line count of at least 1. No writer ever produces 0; the writer was changed
to omit the field for an unknown count, so writer and reader agree.

**An integer format version, not a semantic version.** Readers only need to answer "can I read
this?"; the same choice as ECMA-426 and npm. **`FormatVersion`, not `Version`**, which would easily
be mistaken for the module version.

**The version stays in the file manager, not in `PSScriptBuilderSourceMapData`.** Considered and
rejected after weighing it explicitly:

- The format version describes how the data was *stored*, not the data itself. Data created in
  memory has no format version at all and would need a "not applicable" value — a sign the
  property does not belong to the type (weak cohesion).
- The data model should not know how it is persisted (Persistence Ignorance), and with upcasting
  no consumer may branch on the version anyway.
- Giving the data class a default from the file manager's constant would point a dependency from
  the model to the persistence layer and create a cycle (the file manager already depends on the
  data class); a literal default would duplicate the constant.

**Not deferred.** YAGNI explicitly does not apply to effort that makes software easier to modify;
a format version is exactly that, and it only protects readers released after it exists.

**No custom exception type.** `InvalidDataException` is the most specific standard exception for
data in an invalid format; the ScriptBuilder part of the module uses standard .NET exceptions
throughout.

**One validation pass per object, checks inline.** A first implementation validated each field
through a chain of methods (`ReadField` → `TryConvertFieldValue` → `TryConvertWholeNumber`, the
latter two with `[ref]` parameters). Measured on the largest real sidecar (133 components), reading
took about 77 ms on PS 7 and 95 ms on PS 5.1 instead of 16 and 18 ms without validation — a
PowerShell class method call costs about 10 µs, and about 20–25 µs with a `[ref]` parameter, while
the checks themselves cost 1–3 µs. `ReadFields` now runs once over a schema's rules with the checks
inline: 23 ms on PS 7 and 26 ms on PS 5.1, with identical validation and the schema still the single
source of truth. It also no longer needs `[ref]` parameters, which the .NET Framework Design
Guidelines advise against outside the Try pattern. The cost grows with the number of components
and is paid once per `Resolve-PSScriptBuilderSourceLocation` call, i.e. per resolved error, which
is why it was optimized rather than accepted.

**`[System.Management.Automation.PSCustomObject]`, not `[PSCustomObject]`.** The short form is a
type accelerator for `PSObject` and matched plain values such as numbers — in PS 7 even where PS
5.1 did not. The object checks use the full type name.

## Scope

**In scope:** `PSScriptBuilderSourceMapFileManager` (format version, schema, writer change for
unknown line counts, reader validation), the description of `PSScriptBuilderSourceMapData`, unit
tests for the file manager and the `Resolve-PSScriptBuilderSourceLocation` cmdlet, a note in
`docs/guides/source-maps.md`, `CHANGELOG.md` entries, this RFC.

**Out of scope:** Recording the module version that wrote a sidecar (not needed to decide
readability); reader-side support for format versions above 1, since none exist yet; checks that
relate several fields to each other (e.g. a component ending within `OutputLineCount`) — the schema
validates the form, the resolver interprets the content; consolidating the three copied
configuration validators into one generic schema validator, and a JSON Schema for the
configuration file (both noted as follow-ups).

**Moved later:** the format part of the in-scope work was moved from the file manager into the new
`PSScriptBuilderSourceMapSerializer` on 2026-11-05, together with its unit tests; see Revision Log.

## Relationship to Other RFCs

Builds on RFC 0023, which introduced the first change to the sidecar format (`ComponentLineCount`)
and listed this format version as a deferred follow-up.

## Test Plan

- **Real sidecars:** before implementing the schema, the four sidecars present in the repository
  were analyzed (the module's own build output with 133 components, examples 16 and 17, and a
  test fixture written before RFC 0023 without `ComponentLineCount` and `FormatVersion`): every
  field present, every number whole, every string non-empty. All four are read successfully with
  the schema under PS 5.1 and PS 7.
- **Unit, file manager:** a written sidecar contains `FormatVersion` 1 and omits an unknown
  `ComponentLineCount`, which is read back as 0; a valid sidecar, lowercase hexadecimal hashes and
  unknown fields at both levels are accepted; each missing required field (4 top-level, 7 per
  entry) and 16 invalid values across all fields are rejected with the field path in the message
  (data-driven); entries that are not objects (`null`, `1`, `"text"`) and a non-object sidecar
  (`5`, `"text"`, `[1]`) are rejected; an error names the position of the invalid entry;
  `ReadFields` accepts the whole numbers `1`, `1.0`, `1e0`, `2.0`, `2147483647` (and `0` with
  minimum 0) as int and rejects `null`, `true`, `false`, `0`, `-1`, `1.5`, `1e20`, `3000000000`,
  `"2"`, `"abc"`, `[1]` and `{}`, rejects type conversions (a number as string, a short or
  non-hexadecimal hash, an object as array), returns one entry per schema field including
  defaults, names field paths and shows values in JSON notation; a newer format version, an
  invalid one and an empty sidecar throw
  `InvalidDataException`, not a generic `IOException`. All edge cases were first verified
  empirically on PS 5.1 and PS 7, with and without StrictMode — this showed that
  `ConvertFrom-Json` yields Int32 in PS 5.1 but Int64 in PS 7, that `ConvertTo-Json` renders
  `$null` as an empty string in PS 5.1, and that `[PSCustomObject]` matches plain values.
- **Unit, serializer (added 2026-11-05):** malformed JSON (truncated, not JSON, text after the
  object) and keys differing only in letter case are rejected with `InvalidDataException` wrapping
  the parser exception; a text containing only `null` is reported as not a JSON object, not as
  empty; the error for a malformed sidecar of about 100 KB stays below 600 characters; a truncated
  sidecar file is rejected by `ReadSourceMapData` with `InvalidDataException`, not `IOException`.
  The parser behavior was first measured on PS 5.1 and PS 7 for 19 inputs, including duplicate
  keys, comments, trailing commas, a NUL character, `1e400` and a nesting depth above 1024.
- **Unit, cmdlet:** `Resolve-PSScriptBuilderSourceLocation` against a sidecar with format version 2
  fails with a message naming the format version.
- **Mutation checks:** each of these changes makes exactly the corresponding tests fail — the
  "newer version" check removed; whole-number validation by notation instead of value; the
  whole-number check or the minimum check removed; any value accepted as string or as array; no
  hash format check; no object check for entries; no object check for the sidecar; required fields
  not enforced; and the writer writing `ComponentLineCount` 0 (which also breaks the existing
  round-trip tests). Checked again after the performance optimization (see Rationale).
- **Not testable by the module tests:** the explicit `PSObject.Properties` lookup matters only when
  the class runs in a strict-mode scope; classes loaded from a module are not affected by the
  caller's strict mode, so removing it does not make a module test fail. It is covered by the
  prototype test described in RFC 0023.
- **Full suite** (after a regular build): 2181 passed under PS 5.1 (0 failed, 0 skipped), 2180
  passed under PS 7 (0 failed, 1 skipped — a pre-existing PS 5.1-only test). Smoke tests (22
  checks) and example tests (16 examples, including 16-source-maps and 17-code-coverage against
  real builds) passed under both versions.

## Unresolved Questions

None.

## Revision Log

- 2026-11-04 — Designed and implemented on `development` as a follow-up to RFC 0023, before that
  fix was released, so both ship together. The placement of the version (file manager vs. data
  class) was revised twice during design review; the version value was changed from a plain
  conversion to strict validation after an edge-case review, then from validation by notation to
  validation by value (JSON Schema); and the strict validation was extended from the version to
  every field via a declarative schema after the same lenient conversion was found for all of
  them; the per-field method chain was then replaced by one validation pass per object after
  measuring a fivefold read slowdown. The reasoning is kept above for future maintainers.
- 2026-11-05 — The sidecar format was moved out of `PSScriptBuilderSourceMapFileManager` into the
  new `PSScriptBuilderSourceMapSerializer`, following the Single Responsibility Principle: reading
  and writing the file and the format of its content change for different reasons, and the release
  data already separates its file manager from its validator. `Serialize` and `Deserialize` take and
  return `PSScriptBuilderSourceMapData`; `SourceMapFormatVersion`, the schemas, `ReadFields`,
  `DescribeRule`, `FormatJsonValue`, `ThrowIfUnsupportedFormatVersion` and `ConvertToSourceLocation`
  were moved unchanged, with their unit tests. The serializer writes no verbose output, as a pure
  conversion; the file manager reports reading and writing, so the format version no longer appears
  in the verbose summary line ("Source map read: N component(s)"). Behavior is otherwise unchanged,
  verified against a baseline captured before the move on PS 5.1 and PS 7 (sidecar bytes, the four
  real sidecars, ten damaged sidecars, verbose output). The unused `ReadOutputHash` and
  `ReadOutputLineCount` were removed; their round-trip tests now read the values via
  `ReadSourceMapData`.
- 2026-11-05 — A sidecar that `ConvertFrom-Json` cannot parse was still reported as the generic
  "Failed to read source map" `IOException`, without the rebuild hint and, in PS 5.1, with the
  complete file content in the message. It is now an `InvalidDataException` like every other
  damaged sidecar. The edge-case review behind it also found that `InvalidOperationException`
  (keys differing only in letter case; an empty key in PS 7) escaped the parse handling, and that
  a sidecar containing only `null` was reported as empty; both are fixed. Duplicate keys in the
  same letter case keep the last value, as common JSON parsers do (RFC 8259 only says names SHOULD
  be unique); left as is, since the module never writes them. PS 7 accepts some non-standard JSON
  (comments, trailing commas) that PS 5.1 rejects; this cannot produce a wrong result, because
  everything that is parsed is validated against the schema.

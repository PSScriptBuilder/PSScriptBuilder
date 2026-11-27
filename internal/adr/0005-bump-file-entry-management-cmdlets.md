# ADR 0005: Bump File Entry Management — Object Model and Add/Remove Cmdlets

## Status
**Proposed**

Date: 2026-08-25

## Context

Release management is built around two JSON files:

- `psscriptbuilder.releasedata.json` has a full cmdlet lifecycle: `New-PSScriptBuilderReleaseData`,
  `Get-PSScriptBuilderReleaseData`, `Update-PSScriptBuilderReleaseData`,
  `Test-PSScriptBuilderReleaseData`.
- `psscriptbuilder.bumpconfig.json` has only `Get-PSScriptBuilderBumpConfiguration` and
  `Test-PSScriptBuilderBumpConfiguration`. Creating the file and adding or removing individual
  `bumpFiles` entries is done entirely by hand-authoring JSON.

This asymmetry has a real cost. Hand-authoring `bumpconfig.json` entries means getting
backslash-escaped Windows paths and, for `items` mode, named-capture-group regex patterns
right in raw JSON — with no validation until the file is actually loaded. This was encountered
directly while writing the "Setting Up Release Management" tutorial: multiple bump-config
files had to be rewritten after invalid-JSON errors caused by backslash escaping mistakes made
while authoring the examples for that tutorial.

`Add-PSScriptBuilderCollector` is the closest existing precedent for what a fix could look
like. The cmdlet itself is small (147 lines) and mostly delegates to an already-existing,
tested object model: `PSScriptBuilderContentCollector`, `PSScriptBuilderCollectorCollection`,
and the individual collector classes together total roughly 2,162 lines of source and 2,518
lines of tests. No equivalent object model exists for bump file entries today —
`PSScriptBuilderBumpConfigFileManager` loads and saves a plain `[PSCustomObject]` produced by
`ConvertFrom-Json`, with no dedicated entry class and no collection class exposing add/remove
semantics.

ADR 0002 (Bump Configuration Structure and Extensibility) already fixed the JSON schema itself
— a root-level `bumpFiles` array, each entry carrying `path`, an optional `description`, and
either `tokens`, `items`, or both — and explicitly documented direct `PSCustomObject` indexing
(`$config.bumpFiles[0]`) as the current access pattern. This ADR does not revisit that schema.
It considers only whether an object-model and cmdlet layer should be added on top of it.

## Decision

Introduce a `PSScriptBuilderBumpFileEntry` object model, mirroring the Collector class
hierarchy's pattern, plus fluent pipeline cmdlets:

- **`New-PSScriptBuilderBumpConfiguration`** — creates an in-memory, empty bump configuration
  container. Mirrors `New-PSScriptBuilderContentCollector` rather than
  `New-PSScriptBuilderReleaseData`: there are no meaningful defaults to compute for an empty
  `bumpFiles` array, so its only real job is to serve as the pipeline's starting object.
- **`Add-PSScriptBuilderBumpFile`** — adds one entry (`tokens` mode, `items` mode, or both) to
  a bump configuration and returns it for chaining:

  ```powershell
  New-PSScriptBuilderBumpConfiguration |
      Add-PSScriptBuilderBumpFile -Path 'build\Templates\HRTools.ps1.template' `
          -Tokens 'VERSION', 'BUILD_DATE' |
      Add-PSScriptBuilderBumpFile -Path 'build\Templates\HRTools.ps1.template' `
          -Pattern '# Version: ({REGEX_VERSION})' -Token 'VERSION'
  ```

- **`Remove-PSScriptBuilderBumpFile`** — removes one or more entries.
- **`Save-PSScriptBuilderBumpConfiguration`** (exact name TBD) — persists the in-memory
  configuration to `psscriptbuilder.bumpconfig.json`, reusing the existing load/validate/write
  path already implemented in `PSScriptBuilderBumpConfigFileManager`.

### Open design questions to resolve before implementation

1. **Same-path handling.** Multiple entries can legitimately share a `path` — the tutorial's
   own Mixed-mode example uses a separate `tokens` entry and `items` entry for the same file,
   to cover a fresh project and every subsequent release respectively. `Add-` should default
   to *appending* a new array entry, with an explicit switch (e.g. `-Merge`) to fold into an
   existing entry for the same path instead, rather than silently choosing one behavior.
2. **Removal identity.** Because `path` is not unique, `Remove-PSScriptBuilderBumpFile` needs
   a disambiguation strategy: accepting the exact entry object back from the pipeline (as
   returned by `Add-`), an index, or a `-Path` plus `-Description`/mode combination. This needs
   to be decided before implementation, not discovered afterward.
3. **Validation timing.** Validate at `Add-` time (fail fast, before the entry is even added
   in memory), at `Save-` time (reusing the existing schema validator), or both.

## Alternatives Considered

1. **Do nothing — keep hand-authored JSON.**
   Pros: zero implementation cost; the schema is already documented, with worked examples in
   both the Release Management Guide and the Setting Up Release Management tutorial. Cons: the
   error-proneness is real, not hypothetical — it was hit directly while writing this
   project's own documentation. No tab-completion or `Get-Help` discoverability.
   Not rejected outright — this remains the fallback if the implementation cost below is
   judged disproportionate to how often the file is actually hand-edited in practice (typically
   once per tracked file, not on every release).

2. **Have `New-PSScriptBuilderBumpConfiguration` persist to disk immediately**, mirroring
   `New-PSScriptBuilderReleaseData`'s create-and-persist pattern.
   Rejected: the empty skeleton (`{"bumpFiles": []}`) has no meaningful defaults to compute, so
   there is nothing that benefits from being written before any entries exist. An in-memory
   container matching `PSScriptBuilderContentCollector`'s pattern fits the pipeline-building
   use case better and avoids writing an incomplete file to disk mid-pipeline.

3. **Skip the dedicated entry class; have `Add-PSScriptBuilderBumpFile` manipulate the loaded
   `[PSCustomObject]` directly.**
   Rejected: this would push duplicate-path detection and validation logic into the cmdlet
   itself rather than a testable class, and would depart from this project's own established
   pattern (the Collector family) for exactly this kind of pipeline-built configuration.

## Consequences

### Positive
- Removes a real, already-encountered source of user error (hand-typed JSON, backslash
  escaping, regex authoring) rather than a speculative one.
- Reuses this project's own established API idiom (`New-X | Add-X | Add-X` chaining) instead
  of introducing a new style.
- Adds cmdlet discoverability (tab-completion, `Get-Help`) in place of "copy this JSON from
  the guide."

### Negative
- Substantial implementation cost. Using the Collector hierarchy as a size reference (~2,162
  source lines, ~2,518 test lines), a comparable bump-file object model and cmdlet set is a
  multi-day-to-multi-week effort for a solo maintainer, not a small addition.
- Two to four new public cmdlets to document (comment-based help, PlatyPS reference pages) and
  maintain going forward.
- The same-path and removal-identity design questions must be resolved and tested thoroughly
  before release; getting either wrong would surface later as confusing runtime behavior
  rather than an upfront design error.

## Related Decisions

- ADR 0002 (Bump Configuration Structure and Extensibility) — this ADR proposes an optional
  object-model and cmdlet layer on top of the JSON schema ADR 0002 already fixed. It does not
  change that schema, and the `bumpFiles` root-array structure ADR 0002 anticipated for future
  global options should be accounted for by whatever object model results from this ADR.

## Review Criteria

Revisit or drop this proposal if:

1. Hand-authoring `psscriptbuilder.bumpconfig.json` proves rare enough in practice (a one-time
   setup per tracked file, not a recurring pain point) that the implementation cost isn't
   justified.
2. No concrete user request for this capability materializes — this ADR was written from a
   documentation-side observation, not a reported need.
3. ADR 0002's "Future Extensions" (global bump options such as `enabled`, `backupFiles`) are
   implemented first. The object model designed here should account for whatever
   global-options wrapper eventually lands, rather than being designed in isolation from it.

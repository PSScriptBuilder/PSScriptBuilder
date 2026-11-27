# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-11-27

### Added

- `Resolve-PSScriptBuilderSourceLocation`, `Get-PSScriptBuilderSourceCoverage` — source map format version  
  Source map sidecars now record a format version. A source map written in a newer, incompatible
  format is rejected with a clear error that names the format versions and how to recover, instead
  of being silently misread. Source maps written by earlier versions remain readable.

- `Resolve-PSScriptBuilderSourceLocation` — `ComponentLineCount` property  
  Resolved source locations and source map entries now report how many lines the component spans
  in the output script. It is `0` for source maps written by an earlier version, until the script
  is rebuilt with `-WriteSourceMap`.

### Changed

- `Update-PSScriptBuilderBumpFiles`, `Update-PSScriptBuilderReleaseData`, `New-PSScriptBuilderReleaseData` — writing files  
  All changes are prepared before any file is written, and a run either updates every file or
  leaves all of them unchanged: if a file cannot be written, every file already written is
  restored. A file that was changed since the changes were prepared is not overwritten; the command
  stops with an error instead. While writing, a backup of each file is kept next to it as
  `<file>.psscriptbuilder-backup` and removed afterwards, instead of in a directory in the system's
  temp folder. A backup left by an interrupted run stops the next run that would change the file,
  before anything is changed, since it may hold the only copy of the original content.

- `Update-PSScriptBuilderBumpFiles`, `Update-PSScriptBuilderReleaseData`, `New-PSScriptBuilderReleaseData` — `-WhatIf` and `-Confirm`  
  `-Confirm` asks once per run and names every file that will change; `-WhatIf` shows the same.
  When nothing would change, no confirmation is requested and nothing is written.

- `Update-PSScriptBuilderBumpFiles` — order and paths of the processed files  
  Bump files are processed and reported in the order they are configured, in PowerShell 7 as well,
  where they were sorted by path. `BumpDetails` reports each file's full, normalized path, e.g.
  without `.\` segments.

- `Update-PSScriptBuilderBumpFiles`, `Test-PSScriptBuilderBumpConfiguration` — a token listed more than once  
  A tokens list that names the same token more than once is now rejected as an invalid
  configuration before any file is processed, and `Test-PSScriptBuilderBumpConfiguration` reports
  it. So far only `Update-PSScriptBuilderBumpFiles` rejected it, with "Tokens array contains
  duplicates", and in Simple mode only when the file contained the placeholder. The message now
  names the token and where it is configured.

### Deprecated

- `Update-PSScriptBuilderBumpFiles`, `Update-PSScriptBuilderReleaseData`, `New-PSScriptBuilderReleaseData` — result after `-WhatIf` or a declined confirmation  
  With `-WhatIf`, and when the confirmation is answered with No, these cmdlets return the same
  result as after a run, although nothing was written. Version 2.0.0 will return nothing in these
  two cases, as PowerShell's own cmdlets do. A script that reads the result after `-WhatIf` or a
  declined confirmation should stop relying on it.

- `Update-PSScriptBuilderReleaseData` — `TotalOperationsPerformed`  
  The property of the result counts the operations requested by the parameters, not the values
  that changed. It will be removed in version 2.0.0.

### Fixed

- `Update-PSScriptBuilderBumpFiles` — one file configured with differently written paths  
  A file configured more than once with differently written paths (e.g. `CHANGELOG.md` and
  `.\CHANGELOG.md`) was processed as separate files, so only the changes of one entry were kept —
  silently, while the result reported both as modified. All entries for the same file are now
  applied together.

- `Update-PSScriptBuilderBumpFiles` — placeholder in another letter case  
  In Simple mode, a placeholder written in a different letter case than the token in the
  configuration (e.g. `{{version_prerelease}}` for `VERSION_PRERELEASE`) was replaced with nothing
  when the token had no value or its name did not exist — silently, unless the file also contained
  the configured spelling. The run now stops with the error that already applied to the configured
  spelling, and names the spellings found in the file. Conversely, a run no longer fails for a
  token without a value whose placeholder occurs only inside a value inserted for another token,
  where it is not replaced.

- `Update-PSScriptBuilderBumpFiles`, `Update-PSScriptBuilderReleaseData` — a value that changes in letter case only  
  In Regex mode, a bump file whose current value differed from the new one only in letter case
  (e.g. `Beta` and `beta`) was not written. `Update-PSScriptBuilderReleaseData` updated the file in
  that case but did not list the change in its result. Both now treat such a value as changed. The
  same applies to values that look alike but consist of different characters, such as `ß` and `ss`
  in Windows PowerShell 5.1 or the two Unicode forms of an accented letter.

- `Update-PSScriptBuilderBumpFiles` — same file name in different folders  
  When bump files with the same name in different folders were restored after an error, one of them
  could be overwritten with the content of the other. Each file now keeps its own content.

- `Update-PSScriptBuilderBumpFiles` — partially updated bump files  
  If a bump file could not be written, e.g. because it was read-only or locked, the files processed
  before it stayed updated, leaving the project partially bumped, and their backups remained in the
  temp folder. Now no file is changed.

- `Update-PSScriptBuilderBumpFiles` — a token listed in two spellings  
  A token listed twice in different letter case (e.g. `VERSION` and `version`) was not recognized
  as listed twice. With a placeholder pattern, and in Simple mode when the file contained the
  placeholder, the run failed with an internal error about `Substring`; in Regex mode the list was
  accepted and the value written into each capture group. Such a list is now rejected like any
  other duplicate. To write the same value into several capture groups, use one item per capture
  group.

- `Update-PSScriptBuilderReleaseData` — failed update  
  When an update failed, e.g. because of an invalid value in the release data file, the file was
  rewritten anyway — also under `-WhatIf`. It now stays untouched.

- `Update-PSScriptBuilderBumpFiles`, `New-PSScriptBuilderReleaseData` — `-WhatIf` and `-Confirm`  
  `-Confirm` asked several times per run for internal steps such as copying each file to a backup,
  and answering "No" to one of them left backups behind in the temp folder or, for
  `New-PSScriptBuilderReleaseData` in a project without a release directory, failed with "Failed to
  create directory". `-WhatIf` listed the same internal steps. Both now refer to the files that
  will change only.

- `Resolve-PSScriptBuilderSourceLocation`, `Get-PSScriptBuilderSourceCoverage` — missing or locked output script  
  When the output script was missing, locked or not accessible, both cmdlets reported an error
  that differed between PowerShell versions together with the misleading warning that the output
  script had changed. They now emit a single warning that staleness cannot be checked and continue,
  since resolving only needs the source map.

- `Resolve-PSScriptBuilderSourceLocation`, `Get-PSScriptBuilderSourceCoverage` — damaged source map  
  A damaged `.sourcemap.json` file was read without complaint: an empty file or one without
  components as a source map without entries, invalid values by silent conversion (e.g. `true` or
  `1.5` as a line number). A file that could not be parsed as JSON (e.g. a truncated file) was
  reported as a generic read failure — in Windows PowerShell 5.1 with the complete file content in
  the message. Such a file is now rejected with an error that names the affected field or the parse
  error and suggests rebuilding with `-WriteSourceMap`. Source maps written by earlier versions
  remain readable.

- `Resolve-PSScriptBuilderSourceLocation` — `-ErrorRecord`  
  An error raised in a different script than the output script (e.g. in the calling build or test
  script) was resolved using that script's line number, silently returning an unrelated component.
  An `ErrorRecord` is now only resolved if it originated in the output script or an unmodified copy
  of it; otherwise a warning is emitted and nothing is returned. This also applies to errors without
  a script file, e.g. raised interactively or in code loaded via `Invoke-Expression` - if the output
  script itself was loaded that way, use `-LineNumber` instead.

- `Resolve-PSScriptBuilderSourceLocation`, `Get-PSScriptBuilderSourceCoverage`  
  Lines of the output script outside any component - blank lines between components, or template
  code outside the placeholders - were attributed to the preceding component, returning a wrong
  source file and line without a warning. Such lines are now reported as not resolvable:
  `Resolve-PSScriptBuilderSourceLocation` emits a warning and returns nothing, and
  `Get-PSScriptBuilderSourceCoverage` includes them in its warning about coverage entries that could
  not be resolved to a source location. Source maps written by an earlier version keep the previous
  behavior until the script is rebuilt with `-WriteSourceMap`.

- `Invoke-PSScriptBuilderBuild` / `Watch-PSScriptBuilderProject` — `-WriteSourceMap`  
  For output scripts with CR-only line endings, or with an extra carriage return before a line
  break, the source map recorded line numbers that differed from the ones PowerShell reports, so
  resolving them returned the wrong line. The recorded line numbers now match PowerShell's.

- `New-PSScriptBuilderConfiguration`, `New-PSScriptBuilderProject` — `-Path`  
  A relative `-Path` was resolved against the process's working directory instead of the current
  PowerShell location, so after `Set-Location` the file or project could be created in an
  unexpected directory. The same happened on another provider's drive, such as `HKCU:`. A relative
  `-Path` is now resolved against the current PowerShell location, and a path on another provider's
  drive is rejected. A trailing space or dot in the folder name, which Windows ignores, no longer
  makes the call fail.

- `Set-PSScriptBuilderProjectRoot` — `-Path`  
  `-Path` was read as a wildcard pattern, so a directory such as `App[1]` silently set the project
  root to `App1`, and a pattern such as `src*` set it to several directories. The path is now used
  as it is. A path on another provider's drive, such as `HKCU:\Software`, or of white space only is
  now rejected. In Windows PowerShell 5.1, piping `Get-ChildItem` output now passes the full path
  instead of only the directory name. A trailing space or an 8.3 short name such as `RUNNER~1` no
  longer causes files below the project root to be missed or shown with their full path.

- Automatic project root discovery — current location on another provider's drive  
  With the current location on another provider's drive, such as `HKCU:`, the project root was
  searched from the process's working directory in PowerShell 7, and the search failed with an
  unclear error in Windows PowerShell 5.1. It now fails with an error that names the provider.

## [1.3.1] - 2026-10-29

### Fixed

- `Update-PSScriptBuilderBumpFiles`  
  `-WhatIf` always failed with "Failed to create directory: ... A file already exists at this
  path", even though nothing existed at that path - the same applied to any release script that
  reaches the bump files step under `-WhatIf`. A dry run now completes correctly instead of
  failing.

## [1.3.0] - 2026-10-27

### Added

- Template escape syntax — `{{{{KEY}}}}`  
  A template can now show `{{KEY}}`-shaped text as literal prose (e.g. in a documentation comment)
  without it being treated as a real placeholder or forcing Ordered/Hybrid Mode. Writing four braces
  on each side renders as literal, two-brace `{{KEY}}` text in the output. Validation errors for a
  forbidden or unknown placeholder now also hint at this syntax when the mention was likely meant as
  literal text.

- `Format-PSScriptBuilderSourceCoverage`  
  Formats and displays one or more `PSScriptBuilderSourceCoverageResult` objects as an
  aligned table showing each source file's coverage percentage and hit/total command count,
  with `SourceFile` shown relative to the project root; `-Detailed` additionally lists the
  source lines not covered by any test, collapsing consecutive lines into a range.

- `Get-PSScriptBuilderSourceCoverage`  
  Translates a Pester `CodeCoverage` result — reported against the built output script —
  back to per-source-file coverage aggregates, using the sidecar `.sourcemap.json` written
  by `-WriteSourceMap`; accepts a `PSScriptBuilderBuildResult` from the pipeline or an
  explicit `-OutputPath`; emits a warning when the source map is stale, and a consolidated
  warning for coverage entries that reference an unexpected file or fall outside any
  tracked component.

- `Resolve-PSScriptBuilderSourceLocation`  
  Resolves a line number or an `ErrorRecord` from the compiled output script back to its
  original source file and line; reads the sidecar `.sourcemap.json` written by
  `-WriteSourceMap`; emits a warning when the source map was generated from a different
  version of the output file.

- `Invoke-PSScriptBuilderBuild` / `Watch-PSScriptBuilderProject` — `-WriteSourceMap` switch  
  When specified, generates a sidecar `.sourcemap.json` file next to the output script after
  each successful build; the source map records the source file, line range, and output line
  for every Enum, Class, Function, and File component.

- Configuration (`psscriptbuilder.config.json`) — `build.writeSourceMap`  
  Optional boolean field (default: `false`); when set to `true`, a source map is written
  after every build triggered via configuration-based workflows.

- `Format-PSScriptBuilderTemplateAnalysis`  
  Formats and displays a `PSScriptBuilderTemplateAnalysisResult`; shows template path, size,
  validation mode, cross-dependency status, and validation status; the Key line is only shown
  in Hybrid and Ordered mode; conditional sections for validation errors, missing placeholders,
  and unknown placeholders are shown only when they contain entries.

- `Format-PSScriptBuilderDependencyAnalysis`  
  Formats and displays a `PSScriptBuilderDependencyAnalysisResult`; compact by default
  (analysis summary, component counts, cycle path if applicable); `-Detailed` adds the
  full ordered component list.

- Examples 16 and 17  
  New standalone runnable examples: **16 - Source Maps** (generating a `.sourcemap.json` sidecar
  during a build and resolving output line numbers or caught exceptions back to their original
  source file and line) and **17 - Code Coverage** (translating a Pester `CodeCoverage` result
  reported against the built, merged output script back to per-source-file coverage).

### Changed

- `Format-PSScriptBuilderBumpResult`  
  The `Pattern` line is now hidden when it is identical to `Old Value` (always the case for
  Simple and Placeholder Mode changes), removing a redundant duplicate line from the output.
  Regex Mode changes, where `Pattern` (the config template) and `Old Value` (the actual matched
  text) legitimately differ, are unaffected.

- `Invoke-PSScriptBuilderBuild`  
  Per-phase durations (Collection, DependencyAnalysis, TemplateProcessing, OutputWriting)
  are now reported via the verbose stream when `-Verbose` is specified.

- Configuration (`psscriptbuilder.config.json`) — `build` section  
  The fields `backupPath`, `orderedComponentsKey`, `backupEnabled`, and
  `syntaxValidationEnabled` are now optional; they can be omitted from the configuration
  file and will fall back to their built-in defaults. Existing configuration files with all
  fields present continue to work unchanged.

### Fixed

- `Format-PSScriptBuilderSourceCoverage`  
  On a non-Windows system, a source file path containing backslashes (e.g. from a
  Windows-authored project) was shown as its full absolute path instead of relative to the
  project root.

- `Invoke-PSScriptBuilderBuild` / `Update-PSScriptBuilderBumpFiles` / `Update-PSScriptBuilderReleaseData` / `New-PSScriptBuilderProject`  
  Several internal operations that create a directory or file automatically (e.g. an output or
  backup directory) silently did nothing if a file already existed where a directory was
  expected, or vice versa - the operation reported success even though the directory or file was
  never actually created, which could cause a confusing failure later on. This now fails clearly,
  at the point of the actual problem.

- `Invoke-PSScriptBuilderBuild` / `Watch-PSScriptBuilderProject`  
  In Free Mode, multiple Using collectors each wrote to their own separate placeholder instead
  of being consolidated, which could duplicate a `using` statement in the output and silently
  break the build. Using statements are now always consolidated into one deduplicated block,
  consistent with Ordered/Hybrid Mode; a missing or duplicate Using placeholder now fails
  validation before the build runs.

- `Update-PSScriptBuilderBumpFiles`  
  On PowerShell 7 (unlike PowerShell 5.1), a failure while creating a bump file's backup, or while
  restoring one during an automatic rollback, went undetected — the operation continued as if
  nothing had gone wrong instead of warning or failing clearly. This now behaves consistently on
  both PowerShell 5.1 and PowerShell 7.

- `Invoke-PSScriptBuilderBuild` / `Watch-PSScriptBuilderProject`  
  A source file without a UTF-8 byte order mark (BOM), containing non-ASCII characters (e.g.
  umlauts), was silently corrupted during the build on any system whose default codepage isn't
  UTF-8. Source files are now read explicitly as UTF-8 regardless of BOM presence or the system's
  codepage, and a file that genuinely isn't valid UTF-8 now fails clearly instead of producing
  corrupted output.

- `Compress-PSScriptBuilderScript`  
  `-RemoveBlankLines` and `-RemoveOutputStatements` rewrote every surviving line's ending to the
  system default, regardless of what the input actually used — for a script whose source files
  used a different convention, this could make the "compressed" output *larger* than the input
  despite lines being removed. Every surviving line now keeps its own original line ending
  untouched, so mixed line endings are preserved exactly as they were.

- `Update-PSScriptBuilderBumpFiles`  
  A configured bump file whose patterns matched nothing in its current content — e.g. a
  Placeholder-mode entry with no Regex fallback, already consumed by an earlier run — was silently
  skipped, with no warning, no error, and no indication in the result which file (if any) needed
  attention. This now emits a warning naming the file.

- `Invoke-PSScriptBuilderBuild` / `Watch-PSScriptBuilderProject`  
  In Ordered/Hybrid Mode, multiple registered Using collectors are consolidated into one merged
  block, but only the first `{{...}}` Using placeholder found in the template was replaced with it
  — every other one was silently left as literal, unreplaced text in an otherwise "successful"
  build. This now fails validation before a build runs, naming the placeholders involved.

- `Invoke-PSScriptBuilderBuild` / `Watch-PSScriptBuilderProject` / `Compress-PSScriptBuilderScript` /
  `Format-PSScriptBuilderBuildResult` / `Export-PSScriptBuilderBuildResult`  
  Verbose and formatted output for file sizes and durations used the system's regional settings
  for number formatting (e.g. `1,00 KB` with a comma instead of a period on non-English systems),
  producing inconsistent output across environments. Output is now formatted consistently
  regardless of the system's language or region.

- `Get-PSScriptBuilderCollector`  
  `-CollectionKey` and `-Type` could be passed together, with `-CollectionKey` silently taking
  precedence and `-Type` being ignored — no error, no indication the filter had no effect. The two
  parameters now belong to separate parameter sets, so PowerShell itself rejects the combination
  with a clear "parameter set cannot be resolved" error instead of silently discarding `-Type`.

- `Invoke-PSScriptBuilderBuild` / `Get-PSScriptBuilderDependencyAnalysis`  
  Two components of the same type (e.g. two classes) registered via different collectors and
  sharing the same name — whether spelled identically or differing only by case — were silently
  collapsed into one: one component's source code was completely missing from the build output,
  with the build reporting success and a misleading component count. This now raises an
  `InvalidOperationException` naming both source files, at dependency-analysis time, before a build
  can run.

- `Invoke-PSScriptBuilderBuild` / `Get-PSScriptBuilderDependencyAnalysis`  
  A project whose classes and functions have no dependency on each other could be incorrectly
  flagged as requiring Ordered Mode, depending on unspecified internal enumeration order rather
  than anything in the project. Against a Free Mode template, this failed the build outright
  (`Template validation failed: ... MUST contain placeholder '{{ORDERED_COMPONENTS}}'`); against
  an Ordered/Hybrid Mode template, the build still succeeded but was misclassified as Ordered
  instead of Hybrid, with an unpredictable component order in the merged output. Components with
  no dependency between them are now ordered deterministically in all three modes (Classes before
  Functions, alphabetically within each type).

- `Update-PSScriptBuilderBumpFiles`  
  A pattern item containing literal, non-token `{{...}}` text — e.g. another templating system's
  own syntax such as Helm's `{{ .Chart.Name }}` coexisting in the same file — was silently ignored
  when that text was escaped with `\{`/`\}` (no error, no replacement), even though escaping is the
  documented convention for a literal parenthesis in the same kind of pattern. Escaping literal
  braces this way now works correctly.

- `Update-PSScriptBuilderBumpFiles`  
  A pattern item accidentally combining a `{{TOKEN}}` placeholder with a regex capture group
  (e.g. `({REGEX_TOKEN})`) was silently ignored — no error, no replacement. Configuration
  with such a pattern now fails validation immediately with a clear error identifying the
  conflict, including a hint to escape a literal parenthesis with `\(`/`\)` if that was the
  actual intent.

- `Update-PSScriptBuilderBumpFiles`  
  A pattern item combining a `{{TOKEN}}` placeholder with a literal parenthesis — e.g. a
  copyright notice like `Copyright (c) {{YEAR}}` — could not be replaced, either failing
  silently or with an unrelated error depending on how the parenthesis was written. Escaping a
  literal parenthesis with `\(`/`\)` now works correctly in these patterns, matching the
  existing convention already used in regex patterns.

- `Update-PSScriptBuilderBumpFiles`  
  When multiple bump file entries (or multiple pattern items) target the same file, an earlier
  entry's inserted value could get silently corrupted by a later entry targeting a different
  token, if that value happened to resemble the later entry's target text. Replacements no
  longer overwrite a value that was already correctly inserted by an earlier entry.

- `Update-PSScriptBuilderBumpFiles`  
  Token matching (`{{TOKEN}}` and `{REGEX_TOKEN}`) is now case-insensitive, matching the Template
  system's existing behavior. Previously, a token whose casing didn't exactly match its configured
  name was silently left unreplaced, with no error or warning.

- `Update-PSScriptBuilderBumpFiles`  
  A bump token or pattern value that happened to contain another token's placeholder text (e.g. a
  git branch name like `feature/{{VERSION}}`) could get silently corrupted, with the outcome
  depending on the order tokens were processed in. Token and pattern replacement no longer depends
  on processing order.

- `Invoke-PSScriptBuilderBuild` / `Test-PSScriptBuilderTemplate`  
  Placeholder matching is now case-insensitive in every replacement path (Free Mode and all of
  Ordered/Hybrid Mode), matching the validator's existing behavior. Previously, a differently-cased
  placeholder passed validation but was left unreplaced in the build output. Template validation
  now also catches a duplicate placeholder that differs only in case, including for `Using`
  collectors.

- `Invoke-PSScriptBuilderBuild`  
  In Ordered/Hybrid Mode, a build could silently duplicate or corrupt content when a `File`
  collector's content, or the combined component block, happened to contain another
  placeholder's exact text. Inserted content is no longer re-scanned for further replacements.

- `Invoke-PSScriptBuilderBuild` / `Test-PSScriptBuilderTemplate` / `Get-PSScriptBuilderTemplateAnalysis`  
  A collector's `CollectionKey`, or the active `-OrderedComponentsKey`, matching a built-in
  Release Management bump-file token name (`VERSION`, `BUILD_DATE`, `GIT_BRANCH`, etc.) now fails
  validation immediately with a clear error, instead of passing validation and failing later with
  a misleading error. The comparison is case-insensitive.

- `Invoke-PSScriptBuilderBuild` / `Test-PSScriptBuilderTemplate` / `Get-PSScriptBuilderTemplateAnalysis`  
  A collector registered with a `-CollectionKey` matching the active `-OrderedComponentsKey`
  (default `ORDERED_COMPONENTS`) now fails validation immediately with a clear error identifying
  the colliding key, for every collector type. Previously this either produced a confusing error
  or passed validation while silently corrupting or discarding output. The comparison is
  case-insensitive.

- `Test-PSScriptBuilderTemplate`  
  No longer skips content collection before analyzing dependencies. Without it, cross-dependency
  detection always saw zero collected components and silently returned `$true` for a template
  that would have failed at build time whenever a class depended on a function.

- `New-PSScriptBuilderConfiguration`  
  No longer fails when the target directory (`-Path`, or a project root that has not been
  created yet) does not exist — the directory is now created automatically, reported via the
  verbose stream when `-Verbose` is specified.

- `New-PSScriptBuilderReleaseData`  
  No longer fails when the release data file's configured directory (`build\Release\` by
  default) does not exist yet — the directory is now created automatically, reported via the
  verbose stream when `-Verbose` is specified.

## [1.2.0] - 2026-08-02

### Added

- `Export-PSScriptBuilderBuildResult`  
  Exports a `PSScriptBuilderBuildResult` to a structured JSON file for use as a CI artifact;
  output always includes the build summary and component counts; `-Detailed` adds the list of
  processed files and per-component details; `-Force` overwrites an existing file.

- `New-PSScriptBuilderTemplate`  
  Generates a PSScriptBuilder template file from a content collector configuration; determines
  Free, Ordered, or Hybrid mode based on dependency analysis; supports a custom
  `OrderedComponentsKey` (default: `ORDERED_COMPONENTS`), `-OrderedMode` switch to force
  Hybrid mode, and `-Force` to overwrite an existing file.

- `Find-PSScriptBuilderUnusedComponent`  
  Analyzes a content collector configuration to identify unused Enum, Class, and Function
  components; without `-EntryPoint`, reports all components with no incoming dependency edges;
  with `-EntryPoint`, performs a transitive reachability analysis from components matching the
  specified glob patterns and reports everything not reachable; emits a warning if dependency
  cycles are detected, since components in cycles always have incoming edges and may not be
  reported as unused.

- `Watch-PSScriptBuilderProject`  
  Watches a PSScriptBuilder project for file changes and automatically triggers a build or a
  custom script; supports a configurable debounce interval to avoid redundant runs on rapid
  changes; `Build` mode accepts the same parameters as `Invoke-PSScriptBuilderBuild` and
  optionally runs a follow-up `-OnSuccess` script block after each successful build and a
  `-OnError` script block after each failed build; `Script` mode invokes
  a custom script block with the list of changed files instead of running a build.

- Example 15  
  New standalone runnable example: **15 - Watcher** (real-time file watching in Build mode
  and Script mode using `Watch-PSScriptBuilderProject`).

### Changed

- `PSScriptBuilderAstEngine`  
  `ParseFile` now returns a `PSScriptBuilderParseResult` containing both the AST and any
  parse errors reported by the PowerShell parser.

- Collectors (Class, Enum, Function, Using)  
  When a file yields zero definitions **and** the parser reported structural errors, an
  `InvalidOperationException` is thrown with the file name, line/column number, error ID, and
  message for each error. Non-structural errors (e.g. `TypeNotFound` caused by cross-file type
  references) are always ignored regardless of whether definitions were found, as they cannot
  cause definitions to disappear from the AST.

- `PSScriptBuilderConfigValidator`  
  Configuration values are now validated against the expected type defined in the schema.
  If a value has the wrong type (e.g. `"true"` instead of `true` for a boolean field), an
  `InvalidOperationException` is thrown with the field path and expected type.

- `Invoke-PSScriptBuilderBuild`  
  Cross-collector dependency warnings are now consolidated: instead of one `Write-Warning`
  per dependency edge, a single summary warning with the total count is emitted; per-edge
  details are written to the Verbose stream. Added an encoding pre-flight check for
  PowerShell 5.1 compatibility: source files that contain non-ASCII characters but lack a
  UTF-8 BOM are reported as a single summary `Write-Warning`; full file details are written
  to the Verbose stream as project-relative paths (full paths when no project root is set);
  the check is skipped on systems where the default encoding is already UTF-8 (code page 65001).

### Fixed

- `New-PSScriptBuilderProject`  
  The scaffolded build script no longer includes a session guard. The guard is only
  necessary when a build script loads its own output via `using module` — as
  `Build-Module.ps1` does for PSScriptBuilder itself. The scaffolded script does not
  load its own output, so running it multiple times in the same session is harmless.

- `PSScriptBuilderReleaseDataValidator`  
  Type names were not rendered correctly in validation error messages.

## [1.1.0] - 2026-05-05

### Added

- `New-PSScriptBuilderProject`  
  Scaffolds a complete PSScriptBuilder project structure including configuration file, template,
  build script, and source directories; sample source files demonstrating dependency resolution
  are created by default and can be suppressed with `-NoSampleFiles`; optional
  `-IncludeReleaseManagement` switch adds release data file, bump configuration, and a release
  script with `-Major`, `-Minor`, and `-Patch` switches.

- `Compress-PSScriptBuilderScript`  
  Post-processes a built PowerShell script by removing comments, blank lines, and/or output
  statements; `-RemoveOutputStatements` accepts any combination of `Write-Verbose`,
  `Write-Debug`, `Write-Host`, `Write-Warning`, and `Write-Information`; accepts pipeline
  input from `Invoke-PSScriptBuilderBuild` via the `OutputPath` property; optional `-Force`
  switch overwrites an existing output file.

- `Export-PSScriptBuilderDependencyGraph`  
  Exports the dependency graph as a Mermaid or Graphviz DOT diagram; Mermaid output is
  automatically wrapped in a fenced code block when writing to `.md` / `.markdown` files;
  optional `-Force` switch overwrites an existing output file.

- `Get-PSScriptBuilderComponentDependency`  
  Traverses the dependency graph from a named component and returns all reachable components
  as `PSScriptBuilderComponentDependencyEntry` objects, including depth and full dependency path;
  supports both `Dependencies` and `Dependents` direction; optional `-EdgeType` parameter
  restricts traversal to one or more specific relationship types (union).

- `ConvertTo-PSScriptBuilderComponentDependencyTree`  
  Converts `PSScriptBuilderComponentDependencyEntry` objects to a hierarchical tree string using
  Unicode box-drawing characters; accepts pipeline input from `Get-PSScriptBuilderComponentDependency`.

- `-FileExtension` parameter for `New-PSScriptBuilderCollector`  
  Filters scanned files by extension when using `-IncludePath` (default: `.ps1`).

- `-FileExtension` parameter for `Add-PSScriptBuilderCollector`  
  Filters scanned files by extension when using `-IncludePath` (default: `.ps1`).

- Examples 13 and 14  
  New standalone runnable examples: **13 - Dependency Analysis** (inspecting the dependency
  graph, cross-dependency detection, and cycle reporting) and **14 - Scaffolding** (cold-start
  workflow with `New-PSScriptBuilderProject` including release management).

### Changed

- `Format-PSScriptBuilderReleaseDataResult`  
  Null or empty values in `Old Value` and `New Value` are now displayed as `<none>` instead of
  a blank line; this makes it clear whether a property was unset before or after an operation
  (e.g., first update from new release data, or `-ClearPrerelease`).

- A Class and a Function with the same name within the same project are now explicitly forbidden — the build now fails with a clear error message; this was previously a silent error that could cause incorrect dependency ordering in the build output

### Fixed

- `Update-PSScriptBuilderReleaseData` — `Format-PSScriptBuilderReleaseDataResult` no longer reports
  properties as changed (showing `<none>` → `<none>`) when those fields are stored as empty strings
  in the release data JSON and the operation leaves them as `$null`; null and empty string are now
  treated as equivalent in change tracking.

- `Update-PSScriptBuilderReleaseData -Version` combined with `-Prerelease` / `-BuildMetadata`  
  Explicit `-Prerelease` and `-BuildMetadata` parameters now correctly override any prerelease
  or build metadata contained in the `-Version` string; previously `-Version` was applied last
  and silently overwrote the values set by the explicit parameters.

- `Update-PSScriptBuilderReleaseData -BuildMetadata` / `-ClearBuildMetadata`  
  Changes to `buildmetadata` are now correctly tracked and displayed by
  `Format-PSScriptBuilderReleaseDataResult`; previously the property name was misspelled
  (`build` instead of `buildmetadata`) in the change-tracking logic, causing it to always
  report no change.

- `Update-PSScriptBuilderReleaseData -Version`  
  Optional version components (`prerelease`, `buildmetadata`) are now correctly preserved as
  `$null` when absent from the version string; previously they were set to an empty string,
  causing `Format-PSScriptBuilderReleaseDataResult` to report them as changed.

- `Update-PSScriptBuilderBumpFiles`  
  Items-mode token validation now always runs regardless of whether the pattern matches the
  file content; previously, an empty token value combined with a non-matching pattern caused
  a silent skip instead of a clear error.

## [1.0.0] - 2026-04-14

First public release.

### Added

**Collector System**

- Five collector types: `Using`, `Enum`, `Class`, `Function`, `File`
- `New-PSScriptBuilderCollector` for standalone collector creation
- `New-PSScriptBuilderContentCollector` as the container for all collectors
- `Add-PSScriptBuilderCollector` for fluent pipeline-based collector registration
- `Remove-PSScriptBuilderCollector` to remove a registered collector by key
- `Get-PSScriptBuilderCollector` to inspect registered collectors
- `Get-PSScriptBuilderCollectorContent` to inspect collected data per collector
- Custom `CollectionKey` support for multiple collectors of the same type
- File filtering via `-IncludePath`, `-IncludeFile`, `-ExcludePath`, `-ExcludeFile`, `-NoRecurse`
- AST-based extraction — mixed-type source files (class and function in the same file) handled correctly

**Dependency Analysis**

- `Get-PSScriptBuilderDependencyAnalysis` for a full analysis without producing output
- Topological sorting using Kahn's algorithm to guarantee correct load order
- Circular dependency detection with full cycle path
- Cross-dependency detection (Function→Class transitions requiring interleaved output)
- Dependency graph with forward (`GetDependencies`) and reverse (`GetDependents`) queries
- Automatic Free Mode, Hybrid Mode, and Ordered Mode detection

**Template System**

- `{{Token}}` placeholder syntax mapped to collector `CollectionKey` values
- `Test-PSScriptBuilderTemplate` for pre-build template validation
- `Get-PSScriptBuilderTemplateAnalysis` for a detailed template analysis result object
- Free Mode, Hybrid Mode, and Ordered Mode with full validation rule enforcement
- `{{ORDERED_COMPONENTS}}` placeholder for dependency-ordered output across all component types (name configurable via `-OrderedComponentsKey` and `psscriptbuilder.config.json`, default: `ORDERED_COMPONENTS`)

**Build**

- `Invoke-PSScriptBuilderBuild` orchestrating the full build pipeline
- Optional output file backup via `-EnableBackup` and `-BackupPath`
- `Format-PSScriptBuilderBuildResult` for a formatted build summary

**Release Management**

- `New-PSScriptBuilderReleaseData` to create a release data file with default values
- `Update-PSScriptBuilderReleaseData` for SemVer bumping (`-Major`, `-Minor`, `-Patch`) and explicit version via `-Version`
- Prerelease identifier and build metadata support (`-Prerelease`, `-BuildMetadata`, `-ClearPrerelease`, `-ClearBuildMetadata`)
- `-UpdateBuildDetails` to re-stamp build timestamp and increment build number
- `-UpdateGitDetails` to capture current Git branch, commit hash, and tag
- `-WhatIf` support and automatic rollback on write errors
- `Get-PSScriptBuilderReleaseData` with hierarchical and flat (`-Flat`) output modes
- `Get-PSScriptBuilderReleaseDataTokens` to list all current token values
- `Format-PSScriptBuilderReleaseDataResult` for a formatted change summary
- `Update-PSScriptBuilderBumpFiles` to propagate release metadata to all configured project files
- Simple token mode, Regex pattern mode, and Mixed mode in bump file configuration
- Automatic backup and rollback on error in `Update-PSScriptBuilderBumpFiles`
- `Get-PSScriptBuilderBumpConfiguration` to read the bump configuration
- `Test-PSScriptBuilderReleaseData` and `Test-PSScriptBuilderBumpConfiguration` for pre-release validation
- `Format-PSScriptBuilderBumpResult` for a formatted bump change report

**Configuration**

- `psscriptbuilder.config.json` support for template paths, output paths, and release file locations
- `New-PSScriptBuilderConfiguration` to generate a default `psscriptbuilder.config.json` in the project root
- `Get-PSScriptBuilderConfiguration` to load project configuration
- `Set-PSScriptBuilderProjectRoot` to configure the project root

**Examples & Documentation**

- 12 standalone runnable examples covering the complete feature set
- Guides: Configuration, Collectors, Templates, Dependency Analysis, Release Management, Code Analysis
- Full cmdlet reference documentation

**Platform**

- Full compatibility with PowerShell 5.1 and PowerShell 7+
- Verbose logging throughout the full build and release pipeline

## [0.1.0] - 2026-01-21

Initial development milestone. Not publicly released.

[1.4.0]: https://github.com/PSScriptBuilder/PSScriptBuilder/releases/tag/v1.4.0
[1.3.1]: https://github.com/PSScriptBuilder/PSScriptBuilder/releases/tag/v1.3.1
[1.3.0]: https://github.com/PSScriptBuilder/PSScriptBuilder/releases/tag/v1.3.0
[1.2.0]: https://github.com/PSScriptBuilder/PSScriptBuilder/releases/tag/v1.2.0
[1.1.0]: https://github.com/PSScriptBuilder/PSScriptBuilder/releases/tag/v1.1.0
[1.0.0]: https://github.com/PSScriptBuilder/PSScriptBuilder/releases/tag/v1.0.0

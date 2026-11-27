# Findings

Open findings that are not part of the change or release being worked on, grouped by severity.
What is fixed and when is decided case by case; an entry is removed when its fix is released. This file
is a stopgap: whether findings move to an issue tracker is decided after 1.4.0.

Entries under "Structure" are not ranked by severity: they concern how the code is organized
and do not change the behavior of the module.

Severity follows the Debian definitions, used as a yardstick:

- **grave** — unusable for most users, or data loss
- **important** — a major effect on usability, without being unusable for everyone
- **normal** — a wrong result that fits neither of the above
- **minor** — no effect on usefulness
- **unrated** — not measured yet

## grave

- **The release cmdlets act on the previous project after a project switch.** In one session
  with two projects they update the previous project and write its version into the new
  project's files; `New-PSScriptBuilderConfiguration -Force` overwrites the previous project's
  configuration. Affected: anyone working with two projects in one session. State: RFC 0029,
  draft; observed again 2026-11-20.
- **`New-PSScriptBuilderProject` does not check the project name, and with `-Force` a name that
  is a path overwrites files outside `-Path`.** `-Name '..' -Force` replaced an existing
  `src\Classes\Employee.ps1` and `psscriptbuilder.config.json` in the parent directory of
  `-Path`. `-Name '..\..\y'` reports success and leaves only a configuration file two levels
  above `-Path`; `-Name '..\x'` and `-Name 'a\b'` fail with "Could not find a part of the
  path". A name of three spaces fails on Windows PowerShell 5.1 with "Exception calling
  "CreateDirectory"" and creates on PowerShell 7 on Windows a directory that `rmdir /s /q`
  does not remove. On Linux, names such as `x*y?` and `a"b` create a project whose build
  fails. Affected: anyone who passes a name with path parts, most severely `..` together with
  `-Force`; a name made of letters, digits, spaces, `$`, `;`, `&`, `,` or `-` builds. State:
  measured 2026-11-26 on Windows PowerShell 5.1 and PowerShell 7 in 1.3.1 and the development
  build, on Linux (WSL 1) in the development build.

## important

- **An extra capture group in a regex pattern writes the value to the wrong place.** Regex mode
  assigns tokens to capture groups by position: with the pattern
  `(Version|Ver)=({REGEX_VERSION_FULL})` and one token, `Version=1.0.0` becomes `2.0.0=1.0.0`.
  The configuration is accepted and the run reports no error; written as `(?:Version|Ver)` the
  group works as intended. Affected: anyone who groups with plain parentheses in a regex
  pattern. State: measured 2026-11-21. Possible fix, not built: reject a pattern whose number of
  capture groups does not fit its tokens. Whether regex mode should assign by group name instead
  of position is an open design question; other misuse of regex mode is not checked. The guide
  (`docs/guides/release-management.md`, step 8) calls `{REGEX_TOKEN}` a "named capture group",
  which it is not; that sentence is to be corrected with this finding.
- **A bump changes the encoding of the files it changes.** Such a file is written as UTF-8 with
  a byte order mark, also when it was UTF-8 without one or UTF-16; the content stays intact, and
  a file with nothing to replace is left untouched. Affected: files read by tools that reject a
  byte order mark, such as scripts starting with `#!`. State: measured 2026-11-20.
- **A branch name with non-ASCII characters is stored garbled.**
  `Update-PSScriptBuilderReleaseData -UpdateGitDetails` stores the branch `straße` as `stra├ƒe` in
  the release data file, from where it reaches the bump files. The run reports no error. Affected:
  anyone with such a branch name whose console output encoding is not UTF-8. State: measured
  2026-11-21 on PowerShell 5.1 and 7: garbled with the console output encoding `ibm850`, correct
  with UTF-8.
- **On Windows PowerShell 5.1, `-UpdateGitDetails` reads nothing in a repository without a tag when
  the caller has set `$ErrorActionPreference` to `Stop`.** Commit and branch keep their previous
  values in the release data file; only a verbose message tells. With a tag, with `Continue`, or on
  PowerShell 7 the details are read. `-ErrorAction Stop` on the cmdlet has the same effect.
  Affected: build scripts that set `Stop` and run before the first tag. State: measured
  2026-11-21 and 2026-11-24; hit in a real release of another project on 2026-11-23,
  whose release data kept the commit of the previous release. The report of that day
  proposes the fix: run each `git` call through one helper that judges by the exit code and sets
  `$ErrorActionPreference` to `Continue` locally, and warn instead of writing a verbose message.
  Decided 2026-11-24: fixed after 1.4.0, in one RFC on how the module calls Git, together with
  the entries on the garbled branch name and on the current location. Idea,
  2026-11-26, not built: instead of a helper method, a class of its own that wraps Git (Fowler,
  "Gateway": "An object that encapsulates access to an external system or resource"). It is
  created with the project directory, one method starts Git — setting directory and encoding
  and judging by the exit code — and a few methods return commit, short commit, branch and
  latest tag. The release data processor receives it, so a test can hand in a replacement;
  `UpdateGitDetails` has no test today, the four Git calls sit in it untested. Unlike the
  module's helper classes it holds state, so it is an object and not named "Helper".
- **`-UpdateGitDetails` asks Git in the current location, not in the project root.** With the
  project root set and the location outside the repository, no Git detail is read and the run
  reports no error. Affected: anyone who calls the cmdlet from another directory. State: measured
  2026-11-24 on PowerShell 5.1 and 7; a location inside another repository not measured.
- **A name containing `[` or `]` breaks the build**, and in one case the output is written
  without its components. Independently, `-NoRecurse` together with `-ExcludeFile` collects
  nothing. Affected: projects with such names; anyone combining the two parameters. State:
  RFC 0030, draft.
- **A token name that does not exist is not reported.** In Simple mode it is skipped without a
  message, and `Test-PSScriptBuilderBumpConfiguration` checks token names in no mode. The same
  holds for entries that are not text. Simple mode also does not check the form of a token name,
  which items mode does: `"VERSION "` with a trailing space passes. On Windows PowerShell 5.1 a
  name that differs from a known token only by a character that language rules ignore, such as
  a soft hyphen, is accepted as that token; PowerShell 7 treats it as unknown. Affected: anyone
  with a misspelled token. State: measured 2026-11-19, 2026-11-20 and 2026-11-21.
- **Release management depends on the system culture.** With the Turkish culture, Windows
  PowerShell 5.1 rejects every token containing an uppercase `I` in items mode, and prerelease,
  build metadata and version values containing one; PowerShell 7 fails or does nothing when
  pattern and token differ in letter case. Affected: systems with the Turkish culture. State:
  measured 2026-11-20; four places outside release management not checked.
- **Invalid versions are accepted and written to the release data file.**
  `Update-PSScriptBuilderReleaseData -Prerelease '..'` writes `0.1.0-..`, `'rc.'` writes
  `0.1.0-rc.` and `'01'` writes `0.1.0-01`; `-Version '01.2.3'` is stored as `1.2.3` without a
  message. `Test-PSScriptBuilderReleaseData` returns `True` afterwards. Semantic Versioning
  forbids all of them (item 9: "Identifiers MUST NOT be empty." and "Numeric identifiers MUST
  NOT include leading zeroes."; item 2 for the core version). A bump with the token
  `VERSION_FULL` writes the invalid version into the bump file, and
  `Test-PSScriptBuilderBumpConfiguration` returns `True`; the project that
  `New-PSScriptBuilderProject` generates bumps only `VERSION` and is not affected. Affected:
  anyone who mistypes a prerelease label or version. State: measured 2026-11-26 on Windows
  PowerShell 5.1 and PowerShell 7, in 1.3.1 and the development build.
- **A misspelled entry point makes `Find-PSScriptBuilderUnusedComponent` report every
  component as unused.** With `-EntryPoint Get-EmployeInfo` instead of `Get-EmployeeInfo` the
  cmdlet returns all three components of a generated project and writes no warning; spelled
  correctly it returns none. Whoever cleans up by that list removes code that is in use.
  Affected: anyone who mistypes an entry point. State: measured 2026-11-26 on Windows
  PowerShell 5.1 and PowerShell 7, in 1.3.1 and the development build.

## normal

- **Capture groups beyond the number of tokens stay unchanged without a message** in Regex mode.
  Affected: anyone with more groups than tokens. State: measured 2026-11-20.
- **In a generated project, the build fields of the configuration have no effect.**
  `New-PSScriptBuilderProject` writes a configuration with `backupEnabled`,
  `syntaxValidationEnabled`, `writeSourceMap` and the build paths, and a build script that
  passes fixed paths and none of these fields. With `writeSourceMap: true` no source map is
  written, with `backupEnabled: true` no backup, and with `syntaxValidationEnabled: false` a
  syntax error still fails the build; no message tells. Affected: anyone who changes a build
  field in a generated project. State: measured 2026-11-26 on Windows PowerShell 5.1 and
  PowerShell 7, in 1.3.1 and the development build, `writeSourceMap` also on Linux (WSL 1); the
  build paths not measured, only read in the generated script. The guides state since
  2026-11-26 that a field applies only when the build script passes it. Idea,
  2026-11-26, not built: `Invoke-PSScriptBuilderBuild` reads the configuration by default and an
  explicitly passed parameter wins, as the release cmdlets already read it and as clig.dev
  ("Configuration") and PSScriptAnalyzer ("Implicit search") describe. It changes the behavior
  of projects that hold a value they do not pass; `outputPath` and `templatePath` are
  directories while the parameters expect files; and it belongs after RFC 0029, because the
  release cmdlets take the configuration from a cache that returns the previous project after a
  project switch.
- **After an interrupted write of the release data file, the error does not name the backup.**
  A process killed while `Update-PSScriptBuilderReleaseData` writes can leave the file empty or
  cut off; its backup next to it holds the original. Every release cmdlet then fails with
  "Failed to load release data" (empty file: no file name, no reason) or an invalid JSON error,
  and none mentions the backup. Nothing is lost. RFC 0026 states for this case that "the next
  run refuses to continue until it is resolved"; for bump files it does, with an error naming
  the backup. The fix is the message — it has to name the backup when one lies next to the file
  (Nielsen Norman Group, "Error-Message Guidelines": "offer some potential remedies"); the
  warning in the release management guide only bridges the gap. Affected: anyone whose release
  run is killed in the few milliseconds of that write. State: seen 2026-11-26 in 1 of 14 kills
  on Windows PowerShell 5.1 with the development build; both states recreated and measured on
  Windows PowerShell 5.1 and PowerShell 7. The message for an empty file is the same in 1.3.1.
- **After `-WhatIf` or a declined confirmation, the release cmdlets return the same result as
  after a run.** `Update-PSScriptBuilderReleaseData` reports `TotalOperationsPerformed = 1` and
  `Update-PSScriptBuilderBumpFiles` `TotalFilesModified = 1` although nothing was written;
  `New-PSScriptBuilderReleaseData` returns the release data. A script cannot tell from the
  result whether the files changed. Built-in cmdlets return nothing when the action is not
  performed (10 cases measured; `Set-Date -WhatIf` is an exception), and so does
  `New-PSScriptBuilderTemplate`. Target decided 2026-11-26, run as a prototype on
  Windows PowerShell 5.1 and PowerShell 7, not built in the repository:
  (1) `-WhatIf` and a declined confirmation hold back only the writing: the text appears and
  nothing is returned. (2) Where nothing is to be written, the cmdlet runs as without `-WhatIf`
  and returns its result with no changes. (3) The text names the new version of the release
  data and mentions build and Git details only as a group, as built-in cmdlets name one short
  value (`Set-Variable`) but not several (`Set-Service`). (4) The release data result gets a
  count of its changes (working name `TotalChanges`); `TotalOperationsPerformed`, which counts
  the requested switches and tells a caller nothing, is hidden and later removed.
  Plan: deprecations announced in 1.4.0; (3) and (4) without the removal in a 1.x release;
  (1), (2) and the removal in 2.0.0, as they break scripts (Semantic Versioning, item 8).
  Dropped: a separate preview cmdlet (one example found, Azure PowerShell; none among about
  2100 installed commands) and a marker on the result. Open: scripts lose the preview as an
  object, and the `-WhatIf` text cannot be captured inside a session. Affected: scripts that
  evaluate the result after `-WhatIf` or a declined confirmation. State: measured 2026-11-26,
  in 1.3.1 and the development build; in 1.3.1, `Update-PSScriptBuilderBumpFiles -Confirm`
  answered with No failed instead.
- **An apostrophe in the project name breaks the generated build script.**
  `New-PSScriptBuilderProject -Name "a'b"` reports success; the build script it writes has
  three syntax errors and the build stops with a parser error. The name is valid on every
  platform. Affected: anyone whose project name contains an apostrophe. State: measured
  2026-11-26 on Windows PowerShell 5.1 and PowerShell 7 in 1.3.1 and the development build,
  on Linux (WSL 1) in the development build.

## minor

- **Invalid UTF-8 in the bump configuration or the release data is reported as invalid JSON.**
  State: measured 2026-11-20; the project configuration file not measured.
- **`ChangedItems.OldValue` shows the configured spelling in Simple mode**, not the text that
  was in the file. State: measured 2026-11-19.
- **An unknown token raises `KeyNotFoundException`** instead of an argument exception. State:
  part of RFC 0015.
- **Base classes throw `NotImplementedException` for methods a derived class must override**
  (six places: `PSScriptBuilderOptionsBase`, `PSScriptBuilderCollectorBase`). The .NET
  documentation reserves that type for a member "still in development" and names
  `NotSupportedException` for a base class member "that must be overridden by derived classes".
  State: noted 2026-11-24; places counted and documentation read, reachability
  through the cmdlets not measured.
- **Creating a base class directly raises `InvalidOperationException`** (two places:
  `PSScriptBuilderOptionsBase`, `PSScriptBuilderCollectorBase`). .NET itself raises a
  `MemberAccessException` when an abstract class is created through reflection —
  `ConstructorInfo.Invoke` that type, `Activator.CreateInstance` its subtype
  `MissingMethodException` ("Cannot create an abstract class") — which is the more specific
  type. State: noted 2026-11-24; places counted, .NET behavior measured on
  PowerShell 5.1 and 7, reachability through the cmdlets not measured. Pattern suggested for
  the fix: a hidden method `AssertDerivedClass()` that every constructor of the base
  class calls; it compares the type itself (`$this.GetType() -eq [Base]`) instead of its name,
  its message names the derived classes to use, and its help states the exception and that .NET
  raises the same one.
- **The bump configuration check stops an entry at its first structural error.** An item with an
  invalid pattern and a duplicate or badly written token name reports only the pattern; the other
  error appears on the next run. No file is touched before. Errors that do not depend on each
  other should be reported together (Fowler, "Replacing Throwing Exceptions with Notification in
  Validations"). The same holds while files are processed: of several tokens without a value or
  with an unknown name, only the first is reported, in Simple mode and with patterns. State:
  measured 2026-11-24 in 1.3.1 and the development build. Decided 2026-11-24: not part of
  RFC 0027; reporting all independent errors in both places is its own item after 1.4.0.
- **Several validation errors are joined into one line with commas.** With two errors in the bump
  configuration, `Update-PSScriptBuilderBumpFiles` reports "…in a tokens list,
  {bumpFiles[1].items[0]}: Pattern must contain…"; where one error ends and the next begins is
  hard to see. The same joining is used for the release data. The errors themselves are complete,
  and `Test-PSScriptBuilderBumpConfiguration` lists them one per line. State: measured 2026-11-25.
- **The release data file is formatted differently by PowerShell 5.1 and 7** (indentation and
  spaces after the colon, as `ConvertTo-Json` writes them). Releasing alternately with both
  versions changes nearly every line of the file. State: noted 2026-11-24, measured
  the same day.
- **The message for a missing bump file repeats itself:** "Failed to process bump file 'X':
  Failed to process bump file 'X' because it does not exist". The file is named correctly and the
  run stops as it should. State: measured 2026-11-24 on the development build; 1.3.1 says
  "Configured bump file not found".
- **A bump with nothing to change warns that no pattern matched.** When
  `Update-PSScriptBuilderBumpFiles` runs again with unchanged release data, it warns "Bump file
  'X' is configured for release data substitution, but none of its patterns matched the current
  content - nothing was updated" and advises a Regex-mode fallback entry. The patterns do match;
  the file already holds the current values, and the advised entry is in place. No file is
  changed and the result says "No changes were made". Affected: anyone who runs the bump twice,
  or runs a release script without a version switch twice within one second, as a project
  created by `New-PSScriptBuilderProject -IncludeReleaseManagement` allows. State: measured
  2026-11-26 with such a project on Windows PowerShell 5.1 and PowerShell 7, in 1.3.1 and the
  development build; seen first in a run on Linux (WSL 1).
- **The smoke test and example test scripts return 0 when checks fail.**
  `tests/Invoke-SmokeTests.ps1` printed "9 / 22 passed, 13 failed" and returned 0;
  `tests/Invoke-ExampleTests.ps1` printed "All 0 examples passed" after an error and returned 0.
  `tests/Invoke-Tests.ps1` returns 1. Nobody is affected today: no pipeline calls the two scripts,
  they are run by hand. Proposed order: correct the return value, then run the example script in
  the pipeline — no test executes a `Run-Example.ps1`, and the suite does not touch examples 6,
  8 to 10 and 12 to 17 at all — and name the scripts in `RELEASING.md`. The smoke script stays a
  manual check; the suite covers its cmdlets. State: measured 2026-11-25 on PowerShell 7 in a
  folder without the module; the examples ran on Windows PowerShell 5.1, PowerShell 7 and Linux
  (WSL 1), not in the pipeline's container and not on macOS.
- **`internal/rfc/` has no README**: process, index, numbering rule, how RFCs relate to the ADRs
  in `internal/adr/`, and the statuses of RFC 0014 and 0015, which still say "deferred until
  after the 1.3.0 release". Also missing: one place outside the RFCs for the order of work and
  the target release of each RFC. RFC 0029 names 1.4.0 in 28 lines and RFC 0030 in one, although
  1.4.0 was frozen without them on 2026-11-20; these mentions are outdated and are corrected
  when that place exists, by a header field instead of text. RFC numbers stay as they are — they
  are identifiers, not an order, and occur 129 times in code and tests. Proposed 2026-11-24 as
  the first work after 1.4.0, before RFC 0029.
- **The error for an unsupported version format lists the rejected value as supported.**
  `Update-PSScriptBuilderReleaseData -Version '1.2.3.4'` fails with "Invalid format:
  '1.2.3.4'. Supported examples: '1.2.3', '1.2', '1', '1.2.3.4', '1.2.3-beta'."
  `-Version '99999999999.0.0'` and a version written with full-width digits fail with
  "Cannot convert value … to type System.Int32". Nothing is written in either case.
  Affected: anyone who passes such a version. State: measured 2026-11-26 on Windows
  PowerShell 5.1 and PowerShell 7, in 1.3.1 and the development build.
- **Error messages start with a technical prefix.** Errors from writing files and creating
  directories read "Exception calling "WriteAllText" with "3" argument(s): …" or the same
  with "CreateDirectory"; the cause follows the prefix. Affected: anyone who reads such an
  error. State: counted 2026-11-26 in the development build with awkward parameter values:
  in the errors of 12 of 29 cmdlets on Windows PowerShell 5.1, and of 6 on PowerShell 7 and
  on Linux (WSL 1).

## unrated

- **Path comparison and letter case.** Decided 2026-11-18: compare paths as the platform does.
  Which places deviate today has not been measured.
- **An exclude path that does not exist.** Decided 2026-11-18: it should be an error. Today's
  behavior has not been measured.
- **Statuses of the older RFCs.** Some may be planned but never implemented, others implemented
  without their status being updated. Not checked yet; noted 2026-11-24. See also
  the entry on the missing README under minor, which names RFC 0014 and 0015.
- **The group "Security" in the CHANGELOG.** Noted 2026-11-24. The CHANGELOG uses
  only Added, Changed and Fixed so far, and the word "security" does not occur in it. Not
  checked yet: whether a released or unreleased entry belongs under Security.

## Structure

Code that sits in the wrong place, is unused, or is organized against a named practice. Nothing
the module does changes when an entry is done. It is proposed as a step of its own before the
next change that edits the same class or script.

- **Two places in release management where code sits in a class it does not belong to.**
  `ValidateTokenValues` is marked `hidden` in the replacement helper but is called only from the
  bump files processor. The rules for token names have no common home: validator and helper each
  ignore letter case on their own, and the allowed characters are checked only in the validator
  and only for items; this belongs to the entry on token names that do not exist. The two
  `Validate…` methods of the bump files processor only wrap that check with the context of the
  file; a class of its own for the rules on tokens (names and values) would give all three a
  home. `ValidateTokensForFile` has a parameter `$filePath` that it does not use. No wrong result
  follows. State: read in the source 2026-11-24 and 2026-11-25.
- **The module builds itself differently from what it scaffolds for users.** `Build-Module.ps1`
  is one script whose `-Release` switch adds the release steps, a flag that selects behavior.
  `New-PSScriptBuilderProject -IncludeReleaseManagement` creates two scripts instead, a build
  script and a release script that calls it. Splitting `Build-Module.ps1` the same way also
  touches `RELEASING.md` and `CONTRIBUTING.md`; how the session guard of the build script
  behaves when a release script calls it has not been measured. Noted 2026-11-25.
- **Cleanup.** `HasContentToReplace` is used only by tests; two comments cite "RFC 6391" for
  Semantic Versioning.

## Ideas

Not findings: nothing is wrong today.

- One schema validator instead of three copies (configuration, release data, bump files).
- A published JSON Schema for `psscriptbuilder.config.json`, for completion in editors.
- Rejecting a stale source map instead of warning; a breaking change, so only for 2.0.
- One search instead of two in Simple mode: the replacement validates a token at the moment it
  finds it, instead of the processor asking for the spellings first and replacing afterwards.
  Validation and replacement could then not disagree, and `FindPlaceholderSpellings` and
  `ValidateSimpleModeToken` would go. It needs an exception type of its own, so that the
  processor can tell a failed validation from another failure of the replacement; that is the
  subject of RFC 0015. Not built or measured.
- Initializing text properties with `[string]::Empty` instead of `$null` (noted
  2026-11-24; three places in `PSScriptBuilderReleaseDataOperationRequest`). Measured on
  PowerShell 5.1 and 7 on Windows: `$null` assigned to a `[string]` property, variable or
  parameter becomes an empty string, so both spellings give the same value — but a `[string]`
  class property without any initializer is `$null`. Open: whether this holds on Linux and
  macOS; not measurable here, PowerShell is not installed in the local WSL distributions.

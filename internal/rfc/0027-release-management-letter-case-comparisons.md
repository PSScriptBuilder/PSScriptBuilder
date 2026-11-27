# RFC 0027: Letter Case in Release Management Comparisons

- **Status:** Implemented (2026-11-25) — design measured on a patched copy of the module before
  the code was written, then verified against the built module; see Revision Log
- **Type:** Fix and design decision
- **Created:** 2026-11-24
- **Branch:** development

## Summary

Release Management compares two kinds of text, and treated letter case the wrong way round for
both. Values — file content, version parts, Git and build data — were compared without regard to
case, so a change such as `Beta` to `beta` was not written or not reported. Token names are meant
to match without regard to case (RFC 0008), but the checks around the replacement still compared
them exactly, so a placeholder written in another case was replaced without being validated, and
a token listed in two spellings crashed or passed unnoticed.

This RFC settles one rule: **values are compared character by character, token names without
regard to case** — and applies it at every place that decides either.

## Motivation

Every case was run through the cmdlets of the released version 1.3.1 on Windows PowerShell 5.1
and PowerShell 7, with identical results unless stated.

### 1. A change in letter case only is not written

`f.txt` contains `P=Beta`, the prerelease is `beta`, the bump configuration replaces it in Regex
mode. `Update-PSScriptBuilderBumpFiles` leaves the file as it is and raises the RFC 0019 warning
that nothing matched. The same holds for values that language rules treat as equal: `strasse` and
`straße` on 5.1, and the precomposed and the decomposed form of `é` on both versions.

### 2. The file changes, the result says it did not

`Update-PSScriptBuilderReleaseData -Prerelease beta` on release data holding `Beta` rewrites the
file — RFC 0026 compares the serialized data byte by byte — but the returned result lists no
change. The same holds for `-BuildMetadata`, for a Git branch renamed from `Main` to `main` with
`-UpdateGitDetails`, and for a Regex-mode bump item whose value changes in case only while
another entry changes the file: the file is written, the item is missing from `ChangedItems`.

### 3. A placeholder in another case is replaced without validation

`f.txt` contains `{{version_prerelease}}`, the configuration lists `VERSION_PRERELEASE`, and there
is no prerelease. The placeholder is replaced by nothing, silently. Written as
`{{VERSION_PRERELEASE}}` the same run fails with "Token 'VERSION_PRERELEASE' has no value (null or
empty)". The replacement finds placeholders without regard to case; the check that decided which
tokens to validate looked for the exact spelling.

The same happens for a token name that does not exist: with `FOO` in the configuration and
`{{foo}}` in the file, the placeholder is replaced by nothing, while `{{FOO}}` fails with "Token
'FOO' not found in TokenMap".

### 4. A token listed more than once

A duplicate has been rejected since version 1.0.0 with "Tokens array contains duplicates". The
check compared exactly and ran only while a file was processed, which left gaps:

| `tokens` | Situation | 1.3.1 |
|---|---|---|
| `VERSION`, `VERSION` | a pattern, or Simple mode with the placeholder in the file | "Tokens array contains duplicates" |
| `VERSION`, `version` | a placeholder pattern, or Simple mode with the placeholder in the file | "Exception calling "Substring" with "2" argument(s)" |
| `VERSION`, `version` | a regex pattern with two capture groups | writes the value into both groups |
| either | Simple mode, placeholder not in the file | runs without an error |

`Test-PSScriptBuilderBumpConfiguration` returns `True` in every row.

### 5. An error for a placeholder that would not be replaced

One file, two entries. The first inserts a Git branch named `x{{VERSION_PRERELEASE}}y`; the second
lists `VERSION_PRERELEASE`, which has no value. The run fails with "has no value", although the
replacement would leave that text alone (RFC 0009 protects inserted values). The check that looked
for a token in the file did not know about protected spans.

## Design Decision

1. **Values are compared character by character (ordinal).** Whether a file, a matched text or a
   release data value changed is decided by the characters alone, independent of letter case,
   language rules and system culture.
2. **Token names are compared without regard to case** — when looking for a token in a file, when
   looking for duplicates, and when naming a token in a message.
3. **A token may appear only once in a `tokens` list**, in every mode. The bump files validator
   rejects a duplicate before any file is processed, so `Test-PSScriptBuilderBumpConfiguration`
   reports it.
4. **A token is validated exactly when the replacement would replace it.** The check uses the
   replacement's own search, protected spans included.
5. **A message names the token as configured**, and in Simple mode adds how the file spells it
   when that differs.

## Detailed Design

### Values

Five comparisons change from `-ne` to
`-not [string]::Equals($a, $b, [StringComparison]::Ordinal)`:

| Place | Decides |
|---|---|
| `PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory` | whether a bump file changed |
| `PSScriptBuilderBumpReplacementHelper.ApplyMatchesWithCaptureGroups` | whether a Regex match is a change |
| `PSScriptBuilderReleaseDataProcessor.GetReleaseDataChanges` (three times) | whether a version, build or Git value changed |

`GetReleaseDataChanges` is the former `BuildReleaseDataChanges` of the orchestrator. It uses
nothing of the orchestrator and was moved unchanged to the release data processor in a separate
step before this change, so that the comparison and its tests sit with the class that holds the
release data.

`GetReleaseDataChanges` keeps treating `$null` and `''` as the same "no value". The two lines
per category that normalized them before the comparison are removed: measured, PowerShell passes
`$null` to `[string]::Equals` as an empty string, so the lines no longer decided the result. A
comment at the comparison states this.

The help of `HasReleaseDataChanges`, which described the change list as ignoring letter case, is
corrected, and the help of `GetReleaseDataChanges` now states how values are compared.

### Token names in Simple mode

For each configured token the processor asks the replacement helper in which spellings the token's
placeholder occurs in the current content (`FindPlaceholderSpellings`, new) — the same search the
replacement runs, without regard to case and skipping spans protected for another token. A token
with at least one spelling is validated on its own (`ValidateSimpleModeToken`, new); a token
without one is skipped, as before.

The validation stops at the first failing token of a file, as before and as the items modes do.
Reporting every failing token would be the better practice; that is recorded in the list of
findings and not changed here.

A failed validation is reported as before, in the configured spelling. When at least one occurrence
is spelled differently, the message lists every distinct spelling in the order found:

```text
Token validation failed - Token 'VERSION_PRERELEASE' has no value (null or empty); written in the
file as '{{version_prerelease}}', '{{VERSION_PRERELEASE}}'
```

The original exception is kept as inner exception. A token is handed to the validation as the
object it is: a nested array in a `tokens` list must not be flattened into a valid name on the
way; a first prototype did that and wrote `System.Object[]` into the file.

### Duplicates

The validator checks each `tokens` list — of a Simple-mode entry and of every item — with
`ValidateTokensAreUnique` (new). Names are compared in their text form without regard to case;
empty entries are skipped, they have their own message. Every duplicated token is reported once:

```text
{bumpFiles[0]}: Token 'VERSION' is listed more than once ('VERSION' and 'version'). A token may
appear only once in a tokens list
```

The two spellings are named only when they differ; for `VERSION` listed twice in the same
spelling the message reads "Token 'VERSION' is listed more than once. A token may appear only
once in a tokens list".

For an item in Regex mode the message continues: "To write the same value into several capture
groups, use one item per capture group". That form was measured to work in 1.3.1 and with this
change.

The same token in two entries or two items of one file stays valid; RFC 0009 defines what happens.

A duplicate is reported once its entry or item is valid in structure, like every other check of
the token names: the validator stops an entry at its first structural error, such as an invalid
pattern. That hides independent errors until the next run and deviates from reporting every
error; it is existing behavior and recorded in the list of findings, not changed here.

The old duplicate check in `ValidateTokenValues` is removed. It compared exactly, ran only for
tokens found in the file, and reported `["VERSION", true]` in an item as a duplicate. The
replacement helper gets no check of its own: the validator is the boundary, and no cmdlet reaches
the helper with a duplicate.

### Removed

`ConvertRegexPlaceholdersToTokens` and `BuildReplacementStringFromTokens` in the replacement helper
have no caller. Verified statically and by an instrumented run on both PowerShell versions.

## Backwards Compatibility

- **A duplicate token is rejected** where it ran before: two spellings in Regex mode, and any
  duplicate in Simple mode when the placeholder was not in the file.
  `Test-PSScriptBuilderBumpConfiguration` reports a duplicate it used to accept.
- **A change in letter case only** is written and reported.
- **A placeholder in another case for a token without a value or with an unknown name** fails
  instead of being replaced by nothing.
- **A token without a value whose placeholder occurs only inside an inserted value** no longer
  fails.
- **Direct callers of the replacement helper:** `ValidateTokenValues` no longer rejects a
  duplicate. `ApplySimpleReplacements` is unchanged. The classes are not part of the public
  interface, which consists of the cmdlets, their parameters and the objects they return.

**Versioning.** Rejecting the duplicates that ran before is a bug fix in the sense of Semantic
Versioning 2.0.0, item 6 ("an internal change that fixes incorrect behavior"), not an incompatible
change under item 8: the rule has existed since version 1.0.0, the documentation never stated
that a duplicate is allowed, and the rejection is loud and names the alternative. The changelog
lists it under Changed and Fixed.

## Rationale and Alternatives

- **Ordinal instead of `-cne`.** `-cne` regards letter case but still compares by language rules.
  Measured under the cultures en-US, de-DE and tr-TR: it treats `ss` and `ß` as equal on 5.1, and
  on both versions the two forms of `é` and a text with and without a soft hyphen. With `-cne`, a
  bump file whose pattern has a capture group of its own, such as `Branch=(.+);`, was still not
  written for such a change. Microsoft's "Best Practices for Comparing Strings in .NET"
  recommends: "Use StringComparison.Ordinal or StringComparison.OrdinalIgnoreCase for comparisons
  as your safe default for culture-agnostic string matching" (see also CA1309, "Use ordinal
  StringComparison", and CA1310, "Specify StringComparison for correctness").
- **No second duplicate check in the replacement helper.** An earlier design kept one as defense
  in depth. It was dropped: a check behind the boundary is needed only where a direct call would
  silently produce a wrong result, and a duplicate there fails as before or is replaced correctly.
- **Deprecating the duplicate first and rejecting it in the next major version** was considered
  for the Regex-mode case and dropped once the measurement showed that the rule is not new.
- **Allowing duplicates in Regex mode** was rejected: a copied `["VERSION", "VERSION"]` would
  overwrite silently, and one item per capture group expresses the intent.
- **Naming the file's spelling in the message** was the first decision and was withdrawn: a file
  can hold several spellings, so "the" spelling needs an ordering rule, and the modes would differ.
- **Carrying the failed token to the processor in `Exception.Data`** was built and rejected.
  Microsoft's documentation of `Exception.Data` warns that with a key conflict "lower-level
  exception handlers can inadvertently communicate with higher-level exception handlers", and
  "Best practices for exceptions" asks for additional exception properties "only when there's a
  programmatic scenario where the additional information is useful". Validating one token at a
  time needs no channel at all.
- **Reporting every duplicate, and a hint passed as text.** A validation reports all errors instead
  of the first (Fowler, "Replacing Throwing Exceptions with Notification in Validations"); the
  Regex-mode sentence is passed as text instead of a flag that selects behavior (Fowler,
  "FlagArgument").

## Scope

In scope: the five value comparisons, the Simple-mode validation, the duplicate check in the
validator, the removal of the old check and of the two unused methods, the help texts named
above, the tests, and the test helper `New-TokenMap`, which built a case-sensitive map where the
product uses a case-insensitive one.

Out of scope, recorded in the list of findings:

- **Unknown token names and entries that are not text.** A misspelled token in Simple mode is
  skipped without a message, and `Test-PSScriptBuilderBumpConfiguration` checks token names in no
  mode.
- **An extra capture group in a regex pattern** shifts the values, because Regex mode assigns
  tokens to capture groups by position; capture groups beyond the number of tokens stay unchanged
  without a message.
- **`ChangedItems.OldValue` in Simple mode** shows the configured spelling, not the text that was
  in the file.
- **The exception type for an unknown token** (`KeyNotFoundException`), part of RFC 0015.
- **`HasContentToReplace`** is unused as well and is removed in a separate refactoring commit.

## Relationship to Other RFCs

- **RFC 0008** made token matching case-insensitive in the replacement. This RFC completes it in
  the checks around the replacement.
- **RFC 0009** introduced protected spans. The validation now honors them.
- **RFC 0019** warns when nothing in a file matched. A case-only change no longer triggers it.
- **RFC 0026** announced this RFC and compares the release data file byte by byte for that reason.

## Test Plan

81 new tests:

| File | New | Covers |
|---|---|---|
| `PSScriptBuilderBumpFilesValidator.Tests.ps1` | 19 | duplicates in both modes, same and different case, not adjacent, several duplicates, the Regex-mode hint, empty entries, entries that are not text |
| `PSScriptBuilderBumpFilesProcessor.Tests.ps1` | 18 | token names in any case, the message with the spellings, inserted values containing placeholder text, a nested array is not flattened, values differing in characters only |
| `PSScriptBuilderBumpReplacementHelper.Tests.ps1` | 18 | `FindPlaceholderSpellings`, a case-only change in Regex mode, equal values, values differing in characters only |
| `PSScriptBuilderReleaseDataProcessor.Tests.ps1` | 15 | `GetReleaseDataChanges`: the three categories, an ordinary change, case-only and character-only changes per category, `$null` and `''` |
| `PSScriptBuilderReleaseManagementOrchestrator.Tests.ps1` | 1 | an update that changes a value in letter case only is listed |
| `PSScriptBuilderReleaseManagement.Integration.Tests.ps1` | 10 | the same through the cmdlets, including that no file changes when a duplicate is rejected |

Against the unchanged code, 51 of the 81 new tests fail on PowerShell 5.1 and 47 on PowerShell 7;
the others pin behavior that must stay as it is.

Each test file was checked by mutation against the built module: of 56 deliberately introduced
faults, 55 are detected. The remaining one is equivalent: comparing the spellings for the message
with `-cne` gives the same message.

Results against the built module, with Pester 5.9.1: full suite PS 5.1: 2398 passed, 2 skipped;
PS 7: 2397 passed, 3 skipped; none failed. The built module is identical in code to the
prototype the design was measured on (compared token by token, comments left out).

## Unresolved Questions

None.

## Appendix: How it was measured

Each case creates a project with `New-PSScriptBuilderProject -IncludeReleaseManagement` in a
temporary directory, writes the files and the bump configuration, and calls
`Test-PSScriptBuilderBumpConfiguration`, `Update-PSScriptBuilderBumpFiles` or
`Update-PSScriptBuilderReleaseData`, on Windows PowerShell 5.1 and PowerShell 7. The previous
behavior was measured against the installed release 1.3.1, the new behavior against a patched
copy of the built module, never against the repository. After the code was applied, the test
suite and the mutation check were repeated against the module built from the repository.

## Revision Log

- 2026-11-25 — Implemented on `development`. The test suite and all 56 mutants were run again
  against the built module, with the results given under Test Plan.
- 2026-11-25 — The duplicate message names the two spellings only when they differ. The
  comparison of the release data moved from the orchestrator to the release data processor in a
  step of its own before this change; its tests moved with it.
- 2026-11-24 — An independent review of the prototype found no fault in its logic. It added the
  unknown token written in another case to Motivation and Backwards Compatibility, and corrected
  the sentence on the help texts. The lines normalizing `$null` and `''`, which the ordinal
  comparison had made ineffective, are removed with the change instead of being left in place.
  The helper returns the spellings of a placeholder (`FindPlaceholderSpellings`) instead of
  positions the processor had to interpret, after three built variants were compared.
- 2026-11-24 — File created; the code is applied in a following step.
- 2026-11-21 — The comparison became ordinal after a measurement showed that `-cne` compares by
  language rules. The second duplicate check in the helper was dropped. Measuring against 1.3.1
  showed that the duplicate rule is not new, which settled the versioning question.
- 2026-11-20 — Draft agreed. Found on 2026-11-05 while implementing RFC 0026. Paths were split off
  into their own RFC, the unknown-token finding likewise. Decisions revised on the way: the message
  names the configured spelling instead of the file's; `Exception.Data` was replaced by validating
  one token at a time; the validation reuses the replacement's search after a measurement showed
  the case-insensitive check would otherwise raise a new unnecessary error; a nested-array
  regression of the prototype was found and fixed.

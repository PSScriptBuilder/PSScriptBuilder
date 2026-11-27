# RFC 0020: Source File Encoding Corruption

- **Status:** Implemented (2026-09-30) — written retroactively, after implementation and full
  verification; see Revision Log
- **Type:** Fix
- **Created:** 2026-09-30
- **Branch:** development (no dedicated branch — landed directly, same precedent as the
  multiple-Using-placeholder fix in commit `24e6e74`)

## Summary

A source file without a UTF-8 byte order mark (BOM) containing non-ASCII characters (e.g.
umlauts) was silently corrupted when collected on any system whose default codepage isn't UTF-8.
This affected every collector type — Enum, Class, Function, and Using (all four via
`PSScriptBuilderAstEngine.ParseFile`), and File (via its own, separate reader) — not just one
isolated code path. Both reading paths now read file content explicitly as UTF-8, regardless of
BOM presence or the system's codepage.

## Motivation

Found during a broader "what else should we stress-test" pass following the `Compress-
PSScriptBuilderScript` line-ending fix (also this release cycle, no RFC — scoped as a small,
direct fix). That investigation moved on to cross-platform robustness generally: path separator
handling (found sound — a single normalization point, `GetProjectRootedPath`, applied consistently
at every public entry point) and encoding handling.

The encoding check surfaced `Get-Content -Path ... -Raw` in `PSScriptBuilderFileCollector`, with
no explicit `-Encoding`. Empirical, byte-level verification confirmed the risk directly: a
BOM-less UTF-8 file containing "u-umlaut" was read back as two garbled characters under PS5.1
(system default codepage 1252) and, once re-written, ended up as four corrupted UTF-8 bytes
instead of the original two — a textbook double-encoding defect, not a display artifact.

**The investigation's first conclusion was wrong, and the correction is the reason this RFC
exists.** The initial fix proposal scoped the defect to the File collector alone, reasoning that
`PSScriptBuilderAstEngine.ParseFile` — used by the Enum, Class, Function, and Using collectors —
was safe because `[Parser]::ParseFile()` is "the PowerShell parser's own, battle-tested file
reading." That claim was never verified before being used to justify removing
`WarnEncodingIssues()`/`FindNonAsciiFilesWithoutBom()` as newly-dead code. A direct question about
that removal ("why would this become dead code?") prompted verifying the assumption instead of
restating it — and `[Parser]::ParseFile()` turned out to suffer from the exact same corruption.
For a BOM-less file with a non-ASCII character inside a class *name*, this even produced a genuine
parse error (`MissingTypeBody`) severe enough to already be caught by an existing safeguard
(`ThrowIfParseFailedSilently`). But for the same character inside a string literal or comment —
content that doesn't break PowerShell's grammar — the file parsed without error and the corrupted
text was silently collected, with no safeguard in place. This is structurally the same
"silent when free-text, guarded only when grammar breaks" pattern as the File collector's own bug,
just one level deeper in the pipeline, and confirmed the defect's true scope: the entire
AST-based collection path, not one auxiliary collector.

## Detailed Design

**`PSScriptBuilderAstEngine.ParseFile([string] $path)`** — previously called
`[Parser]::ParseFile($path, ...)` directly, letting the parser read the file itself. Now reads the
file explicitly via `[PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($path)` (already used
in 17 other places in the codebase, correctly handles both BOM-present and BOM-less UTF-8 — its
BOM detection is automatic regardless of which encoding variant is passed) and calls
`[Parser]::ParseInput($content, $path, [ref] $tokens, [ref] $parseErrors)` — the three-argument
overload, which keeps the file path associated with the resulting AST (`Extent.File`, error
messages) exactly as `ParseFile()` did, verified byte-for-byte identical for existing ASCII
fixtures. A `DecoderFallbackException` (genuinely invalid UTF-8, not just BOM-less) is caught
specifically and re-thrown with a clear message, mirroring the established pattern in
`PSScriptBuilderBumpFilesProcessor`.

**`PSScriptBuilderFileCollector.CollectFromFiles`** — the same change: `Get-Content -Raw` replaced
with `[PSScriptBuilderFileIOHelper]::ReadAllTextUTF8WithBOM($file.FullName)`, with the same
specific `DecoderFallbackException` handling added to its existing catch block.

**`WarnEncodingIssues()` / `FindNonAsciiFilesWithoutBom()`** — kept, not removed. See Rationale.
Message and docstrings reworded: the original text claimed PSScriptBuilder itself "may misread"
these files, which becomes false once the fix lands. The new wording frames it as advisory for
other tools in the user's workflow (editors, diff tools, linters) that may still assume the system
codepage for a BOM-less file, independent of what PSScriptBuilder itself now does correctly.

## Rationale and Alternatives

**Why `ParseInput(content, fileName, ...)` instead of the simpler two-argument
`ParseInput(content, ...)`.** The two-argument overload has no way to associate a file path with
the result, which would silently blank out `Extent.File` and any file path named in a parse-error
message. The three-argument overload exists specifically for this case and was verified to
produce output identical to `ParseFile()`'s in every other respect.

**Considered removing `WarnEncodingIssues()`/`FindNonAsciiFilesWithoutBom()` as newly-dead code,
then reversed that decision.** The reasoning at the time was that once both reading paths are
fixed, the specific risk this check was built to catch — PSScriptBuilder itself misreading the
file — can no longer occur for any file `GetProcessedFiles()` reports, making the check
unable to ever find a genuinely at-risk file again. This reasoning was itself checked thoroughly
(a second, wider search for any third file-reading path; reading `FindNonAsciiFilesWithoutBom`'s
full implementation rather than assuming its behavior from its name) and held up. But it answered
the wrong question. The user's pushback reframed it correctly: the information "this file lacks a
BOM" has value independent of whether *PSScriptBuilder's own* reading is still at risk — other
tools in a user's workflow may still care. The check is not dead code merely because the specific
harm its docstring originally named can no longer happen; it still runs, still finds real
BOM-less files, and the information is still actionable. Only the message and docstring needed to
change, not the mechanism.

**Considered widening `WarnEncodingIssues()`'s trigger to run regardless of the build machine's
own codepage** (since the new, broader justification — other tools might mishandle the file — has
nothing to do with what codepage *this* machine happens to have). Left unchanged and out of scope
for this fix; see Unresolved Questions.

## Scope

**In scope:** `PSScriptBuilderAstEngine.ParseFile`, `PSScriptBuilderFileCollector.CollectFromFiles`,
the `WarnEncodingIssues`/`FindNonAsciiFilesWithoutBom` message and docstring wording, new
regression tests, a `CHANGELOG.md` entry.

**Out of scope:** Changing `WarnEncodingIssues()`'s codepage-based skip condition (see Unresolved
Questions); any change to how PSScriptBuilder *writes* output files, which already goes through
`PSScriptBuilderFileIOHelper` consistently and was never at risk.

## Relationship to Other RFCs

None directly. Found via the same session's broader pre-release robustness sweep as RFC 0019, but
an unrelated root cause (file-reading encoding vs. bump-pattern matching).

## Test Plan

- **Unit, all four AST-based collector types**: BOM-less UTF-8 content with a non-ASCII character
  in a member name (Enum), a type name and a string literal (Class), a comment and a default
  parameter value (Function), and a trailing comment (Using) — each parses with zero errors and
  produces byte-exact correct output.
- **Unit, File collector**: BOM-less UTF-8 content collected byte-exact; a genuinely invalid
  (non-UTF-8) byte sequence throws with a clear, specific message.
- **Regression, both fixed methods**: existing ASCII fixtures (with and without BOM) produce
  byte-identical AST text, identical error counts and IDs, and identical token counts between the
  old (`ParseFile`/`Get-Content`) and new (`ReadAllTextUTF8WithBOM` + `ParseInput`) approaches —
  verified directly against the real, checked-in `ClassWithParseError.ps1` fixture, not just
  synthetic strings.
- **Edge cases**: empty file, BOM-only file with no content after it, `#Requires` statement
  handling — all produce zero parse errors, no crash.
- **End-to-end**: a real multi-collector build (Enum + Class + Function + File, all non-ASCII,
  BOM-less) verified byte-exact correct in the final merged output, with an explicit check that no
  double-encoding corruption marker appears anywhere in the file.
- **Full suite**: 2041 passed, 0 failed (2035 baseline + 6 new tests), including both fixed
  collector types and the reworded-warning behavior.

## Unresolved Questions

- `WarnEncodingIssues()` still skips its check entirely when the *build machine's* default
  codepage is UTF-8, even though the check's new justification (other tools in the user's
  workflow might still mishandle a BOM-less file) has nothing to do with that machine's codepage.
  Left as pre-existing behavior, out of scope for this fix — a candidate for a future, separate
  refinement if the project decides the advisory should be unconditional.
- No other file-reading path in `src/` was found to have the same defect (verified via a project-
  wide search for `Get-Content` and `ReadAllText`/`ReadAllBytes` outside
  `PSScriptBuilderFileIOHelper`); config, release-data, and template files are read through
  helpers that were never at risk. Documented here so this isn't re-investigated from scratch
  later.

## Revision Log

- 2026-09-30 — Implemented directly on `development` (commits `6d9828d`, `9c276d5`, `3d2434b`,
  `20eb1b9`, `60db683`, `c99af80`, `f6557a7`). RFC written retroactively, after implementation and
  full verification, specifically to preserve the investigative narrative — in particular the
  corrected assumption about `[Parser]::ParseFile()`'s safety and the reversed decision on
  removing `WarnEncodingIssues()` — for future maintainers, matching this project's established
  practice of documenting non-obvious fixes even when the RFC follows rather than precedes the
  code.

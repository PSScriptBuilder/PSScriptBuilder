# RFC 0019: Release Management Silent Zero-Match Bump File

- **Status:** Implemented (2026-09-29)
- **Type:** Fix
- **Created:** 2026-09-29
- **Branch:** None yet — small, isolated fix; expected to land directly on `development`, not a
  dedicated branch (no other in-flight work touches this area)

## Summary

A bump file whose configured entries match nothing in its current content is silently skipped -
`PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()` simply omits it from the returned
`Changes` list, with no warning and no error. Add a file-level warning for this specific case:
*every* configured entry for a file failed to match, not just one of several (which is the normal,
expected state in a working Mixed Bump Mode setup).

## Motivation

Found while exploratory-testing a large fictional project ("TicketFlow") ahead of the 1.3.0
release. A bump file entry for `TicketFlow.psd1` was configured with a single Placeholder-mode item
(`{{VERSION}}`) and no Regex-mode fallback. The first `Update-PSScriptBuilderBumpFiles` run bumped
it correctly (`{{VERSION}}` -> `1.1.0`). The second run produced no error, no warning, and no
change to the file - `{{VERSION}}` no longer existed in the content, so the pattern matched
nothing, and `ApplyPatternReplacements` returned the content unchanged. The only trace was a
neutral, file-count-only `Write-Verbose` summary at the orchestrator level
(`"Bump files update completed: {N} files processed, {M} files modified"`), which does not name
the file or explain why it was skipped.

**Distinct from RFC 0013.** RFC 0013 is about a pattern whose *shape* is invalid - it ambiguously
combines Placeholder and Regex syntax in one string, a static, config-time-detectable mistake now
caught by `PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode`. This RFC's pattern is
perfectly valid and unambiguous; it simply doesn't match this particular file's *current content*,
a dynamic, per-run condition that can only be observed at replacement time, not at config
validation time. Kept as a separate RFC per this project's established same-investigation
(here: same general *area*, silent-zero-match bump replacements)-different-root-cause convention,
the direct precedent being RFC 0007/0008/0009 and RFC 0012/0013.

**Why this wasn't already caught by RFC 0013 or earlier RFCs.** All of RFC 0007-0016 address
patterns that are *wrong* in some detectable way (case mismatch, ambiguous shape, unescaped
literals, collisions). This is the first case where the pattern is entirely correct and the
"failure" is really just "nothing to do this run" - which is why no existing validation layer
was positioned to catch it: validation checks the *pattern*, not whether today's *content* happens
to contain something for it to match.

**Decision to fix rather than document as a known limitation:** per this project's established
Cost-of-Quality bar (RFC 0013's own phrasing: "a reachable silent-failure defect gets fixed"), this
is genuinely reachable - any bump file entry that only ever gets a Placeholder-mode item, without a
Mixed Bump Mode Regex fallback, goes silently inert after its first successful run, indefinitely.

## Detailed Design

### Why file-level, not item-level

Mixed Bump Mode's entire mechanism depends on exactly one entry matching per run and the other(s)
*not* matching: a Placeholder item matches only on the first run (before the token is replaced), a
Regex item matches on every run after (once real content exists to match against). A per-item
"this didn't match" warning would fire on **every single run** of a correctly-configured Mixed Bump
Mode file, for whichever item isn't this run's active one - constant, false-positive noise that
would train users to ignore the warning entirely.

`PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()` already groups all configured entries
for a path together before comparing content
(`$groupedByPath = $this.BumpFilesConfig.bumpFiles | Group-Object -Property path`) and only checks
`$originalContent -ne $newContent` once, after every entry in the group has run. In a working Mixed
Bump Mode setup, at least one entry always matches on any given run, so this file-level total is
never "unchanged." The warning only fires when *every* entry for a file failed to match - the
genuine reachable-silent-failure case this RFC targets, structurally incapable of false-triggering
on a correctly-configured multi-entry file.

**Verified against a real, live example, not just a hypothetical.** This project's own
`build/Release/psscriptbuilder.bumpconfig.json` targets
`build\Templates\PSScriptBuilder.psm1.template` with exactly this two-block shape: one Simple Mode
entry (8 tokens, including `VERSION`) and one Items/Regex Mode entry (5 regex fallback patterns,
covering only 5 of those 8 tokens - `VERSION`, `BUILD_DATE`, and `BUILD_TIME` have no regex
fallback). This confirms `Group-Object -Property path` producing more than one entry per file is
real, active production usage, not a theoretical "Phase 1/Phase 2" comment.

**A limitation this surfaced, made explicit rather than hidden.** Because the check is file-level,
a file where *some* entries have a working fallback and *others* don't - exactly the real example
above - will never trigger this warning: the 5 regex-covered tokens keep matching on every run,
so `$originalContent -ne $newContent` stays true, silently masking that `VERSION`, `BUILD_DATE`,
and `BUILD_TIME` have had no regex fallback and gone stale since the first bump. Catching *that*
would require item-level tracking, which was already rejected above for the noise it would cause
on every correctly-configured file. This RFC deliberately only closes the "entire file went
silent" case; a partially-stale file with at least one still-working entry remains undetected. That
tradeoff is accepted here, not a defect to fix in scope - documented so it isn't mistaken for a
completeness guarantee this design was never meant to provide.

**A pre-existing assumption this design inherits, not introduces.** `Group-Object -Property path`
groups by exact string match; it normalizes case (`build\X.psd1` and `BUILD\X.PSD1` land in one
group, verified empirically) but not path separators (`build\X.psd1` and `build/X.psd1` do not).
A `bumpFiles` config that referred to the same physical file with inconsistent separators would
already, today, split it into two independently-processed groups that read and write the same file
without coordinating - this RFC does not create that risk. It only means such a split could now
also surface as a spurious per-group warning where today it is invisible. This project's own
`build/Release/psscriptbuilder.bumpconfig.json` uses an identical path string across both entries
for `PSScriptBuilder.psm1.template` (verified directly), so this is not currently active - noted
here as a documented precondition, not addressed by this RFC (fixing it would mean normalizing
paths before grouping, a separate, pre-existing concern unrelated to zero-match detection).

### Change

In `PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()`, add an `else` branch next to the
existing "only add to changes if modified" check:

```powershell
                # Increment total processed count
                $totalProcessed++

                # Only add to changes if content was modified
                if ($originalContent -ne $newContent) {
                    $change = [PSCustomObject] @{
                        filePath        = $filePath
                        originalContent = $originalContent
                        newContent      = $newContent
                        changedItems    = $fileChanges
                    }

                    $changes.Add($change)
                }
                else {
                    # None of this file's configured entries matched anything in its current
                    # content. In a working Mixed Bump Mode setup (multiple entries per file)
                    # this is never true - at least one entry always matches on any given run -
                    # so this only fires when every configured entry failed to match: a genuine
                    # reachable silent-failure case (e.g. a Simple/Placeholder-only entry with no
                    # Regex fallback, already consumed by a prior run).
                    #
                    # Deliberately no attempted count of "how many patterns/tokens were tried" in
                    # the message: a single $fileConfig entry can itself hold several tokens
                    # (Simple Mode) or several items (Items/Regex Mode), so a naive
                    # $fileConfigs.Count would undercount - verified against this project's own
                    # bumpconfig.json, where a 2-entry group represents 13 individual
                    # tokens/patterns, not 2. Restating that count correctly would duplicate the
                    # Simple/Items mode-detection logic that already lives in
                    # PSScriptBuilderBumpModeResolver, for a number the message doesn't need to be
                    # actionable.
                    $format  =
                        "Bump file '{0}' is configured for release data substitution, but none of " +
                        "its patterns matched the current content - nothing was updated. If this " +
                        "file was already bumped by a prior run, add a Regex-mode fallback entry " +
                        "(Mixed Bump Mode) so subsequent runs keep matching."
                    $message = $format -f $filePath
                    Write-Warning $message
                }
```

`$filePath` is already in scope at this point in the loop (resolved earlier in the same iteration).

## Rationale and Alternatives

**Considered warning at the item level instead of the file level.** Rejected - see "Why
file-level, not item-level" above; this would make Mixed Bump Mode, the project's own recommended
pattern for repeatable bumps, permanently noisy.

**Considered throwing instead of warning.** Rejected - unlike RFC 0012/0013's cases (a malformed
config that can never work), a zero-match run is not necessarily wrong: a file's *last* remaining
Mixed Bump Mode entry going quiet after a version format changes underneath it, or a file being
legitimately removed from active rotation without updating the bump config, are recoverable,
non-fatal states the caller may want to investigate rather than have their entire release process
halted by. A warning surfaces it without blocking `Update-PSScriptBuilderBumpFiles` for every other,
correctly-matching file in the same run.

**Considered making the existing orchestrator-level verbose summary louder (e.g. always displayed,
not just under `-Verbose`) instead of adding a new, file-specific warning.** Rejected - the summary
is an aggregate count (`{N} processed, {M} modified`); it cannot name *which* file went unchanged
or suggest *why*, which is the actionable information a caller actually needs to fix their config.

## Scope

**In scope:** `PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()`'s new file-level
zero-match warning; a `CHANGELOG.md` entry (this is an observable behavior change - a previously
fully silent no-op now emits a warning).

**Out of scope:** Any change to `ApplyPatternReplacements`, `DetermineBumpPatternMode`, or bump
config validation - the pattern here is valid and correctly classified; only the *absence of
feedback* when it matches nothing is being addressed.

## Relationship to Other RFCs

- **RFC 0013** (mixed pattern syntax validation) - closest precedent, same general silent-zero-match
  problem space in the same replacement pipeline, different root cause (invalid pattern *shape* vs.
  valid pattern with no matching *content*). Not blocked by or blocking this RFC.
- **RFC 0011** (`PSScriptBuilderBumpModeResolver.DetermineBumpPatternMode` / Mixed Bump Mode
  concept) - this RFC's design explicitly relies on Mixed Bump Mode's "exactly one entry matches
  per run" guarantee to justify a file-level (not item-level) warning without false positives.

## Test Plan

- Regression test: a bump file with a single Placeholder-mode entry, given content that does not
  contain the placeholder (simulating "already bumped by a prior run"), produces a `Write-Warning`
  naming the file path, with no exception thrown and no entry in the returned `Changes` list.
- Non-regression test: a bump file configured with a working Mixed Bump Mode pair (one Placeholder
  entry, one Regex entry), where exactly one matches, produces **no** warning.
- Non-regression test: a bump file where all configured entries match and change content behaves
  identically to today (present in `Changes`, no warning).
- Non-regression test, modeled directly on this project's own `PSScriptBuilder.psm1.template`
  bump config: a file with one Simple Mode entry (multiple tokens) and one Items/Regex Mode entry
  (fewer patterns than tokens in the Simple entry, i.e. a partial fallback), where the Regex entry
  still matches something - confirms this deliberately does **not** warn, documenting the accepted
  "partial staleness can be masked" limitation from Detailed Design as expected behavior, not an
  oversight to catch later.
- End-to-end test: three configured bump files in one run, one of which is stale (matches nothing)
  and two of which match and change normally - confirms `Update-PSScriptBuilderBumpFiles` still
  completes without throwing, `TotalProcessed` includes all three, `Changes` contains only the two
  that actually changed, and exactly one `Write-Warning` fires, naming only the stale file.

## Unresolved Questions

None currently - decision, scope, and the exact warning wording are settled; only implementation
remains.

## Revision Log

- 2026-09-29 — Second review pass before implementation, incorporating the first pass's findings.
  Re-verified the proposed code snippet against the current, unmodified real source
  (`PSScriptBuilderBumpFilesProcessor.ps1` lines 174-187) line-for-line - confirmed `$filePath` is
  the already-resolved absolute path at that point, matching the sibling `Write-Verbose` line.
  Confirmed `UpdateBumpFilesInMemory()` has exactly one call site
  (`PSScriptBuilderReleaseManagementOrchestrator.ps1:333`), independent of `-WhatIf`, so the new
  warning cannot double-fire across a preview/persist split. Found and documented a further
  pre-existing (not introduced by this RFC) assumption: `Group-Object -Property path` normalizes
  case but not path-separator style, so a config that referred to one physical file with mixed
  `\`/`/` separators would already split it into independently-processed groups today - verified
  empirically and checked against the real `bumpconfig.json`, which is not affected (identical path
  strings). Added an explicit end-to-end Test Plan case covering a mixed stale/non-stale multi-file
  run in a single `Update-PSScriptBuilderBumpFiles` call.
- 2026-09-29 — Reviewed before implementation. Verified all three replacement methods
  (`ApplySimpleReplacements`, `ApplyPlaceholderReplacements`, `ApplyRegexReplacements`) return
  unchanged content with empty `Changes` on zero matches, with no exception - confirming the
  Detailed Design's premise directly against the code rather than assuming it. Found the "Phase
  1/Phase 2" grouping is real, active usage (this project's own bumpconfig.json), not
  hypothetical, which strengthens the file-level design decision. Found and fixed a real defect in
  the original message wording: `$fileConfigs.Count` undercounts individual tokens/patterns when a
  single entry holds several (confirmed against the same real bumpconfig.json - 2 entries
  represent 13 individual tokens/patterns) - removed the count from the message entirely rather
  than duplicating mode-detection logic to compute it correctly. Made explicit a previously-unseen
  limitation: a file with a partially-working fallback (some but not all tokens covered by a
  Regex entry) will not trigger this warning, since the working entries keep the file-level
  content check "changed" - added as an accepted, documented tradeoff and a new Test Plan case,
  not a defect.
- 2026-09-29 — Initial draft, written after reproducing the silent no-op with a real, large,
  purpose-built test project (multiple bump targets across Simple/Placeholder/Regex modes) and
  tracing the exact code path in `PSScriptBuilderBumpFilesProcessor.UpdateBumpFilesInMemory()`.
  Confirmed via `internal/rfc/*.md` search that no prior RFC had already decided to leave this
  case silent on purpose.

# Implementation Plan: `refactor/template-engine-consolidation`

Not itself an RFC — this is the single place where the build order across RFC 0001-0004 and RFC
0006-0009 lives, so that reordering a phase touches only this file, never the RFCs themselves. Each
RFC describes its own root cause, decision, and scope in isolation; this document is the only place
that says which order they land in and why.

RFC 0005 (centralized template tokenizer) is explicitly **not** part of this plan — it is a
deferred architectural idea, not tied to this branch (see RFC 0005's own Status).

## Phases

Each phase is its own commit (lettered sub-steps get their own commit too), verified against the
full test suite before moving to the next.

1. **Consolidate placeholder/mode detection into `PSScriptBuilderTemplateModeResolver`** — RFC 0001's own
   prerequisite refactor. Pure refactor, no behavior change. **✅ Done (2026-09-03)** — see RFC
   0001's own Revision Log for detail.
2. **Fix the ordered-components-key collision** — RFC 0002. Includes its `CHANGELOG.md` entry
   (`### Fixed`) as part of this phase's own commit(s), not deferred to Wrap-up. **✅ Done
   (2026-09-03)** — see RFC 0002's own Revision Log for detail.
3. **Fix the Release-Management-token key collision** — RFC 0006. No dependency on any other
   phase; grouped next to Phase 2 as the same kind of reserved-key validation check. **✅ Done
   (2026-09-03)** — see RFC 0006's own Revision Log for detail. Includes its
   own `### Fixed` entry.
4. **Fix the Ordered/Hybrid Mode template-injection bug** — RFC 0003. Introduces the
   `Discover*` sibling methods. Includes its own `### Fixed` entry. **✅ Done (2026-09-04)** — see
   RFC 0003's own Revision Log for detail.
5. **Fix the placeholder case-sensitivity mismatch** — RFC 0004. Builds directly into the
   `Discover*` methods Phase 4 introduces (see RFC 0004, Relationship to Other RFCs) and into
   `DiscoverReplacements` (Free Mode) and `ValidateNoDuplicatePlaceholders` independently. Includes
   its own `### Fixed` entry. **✅ Done (2026-09-04)** — see RFC 0004's own Revision Log for
   detail.
6. **Escape mechanism** — RFC 0001's own masking work: mask/unmask
   applied at the three call sites that load raw template content (`Test-PSScriptBuilderTemplate.ps1`,
   `PSScriptBuilderTemplateAnalyzer`, `PSScriptBuilderBuildOrchestrator`), not inside the
   Validator/Processor themselves (see RFC 0001's corrected Detailed Design). Release Management is
   explicitly out of scope (see RFC 0001, Step 2's "Deliberately excluded" note) — no sub-step here.
   Includes its own `### Added` entry (new escape syntax, a Feature, not a Fix). **✅ Done
   (2026-09-05)** — see RFC 0001's own Revision Log for detail.
7. **Fix Release Management's sequential value collision** — RFC 0007. Converts
   `ApplySimpleReplacements` and `ApplyPlaceholderReplacements` in
   `PSScriptBuilderBumpReplacementHelper` to discover/assemble via two new shared helper methods
   (`ApplyRegexReplacements` confirmed already safe, no change needed). No dependency on Phases 1-6 —
   a structurally independent implementation in a different subsystem (see RFC 0007, Relationship to
   Other RFCs). Includes its own `### Fixed` entry. **✅ Done (2026-09-05)** — see RFC 0007's own
   Revision Log for detail.
8. **Make Release Management token matching case-insensitive** — RFC 0008. The `{{TOKEN}}` half
   builds directly into the discover/assemble methods Phase 7 introduces; the `{REGEX_TOKEN}` half
   (`ReplaceRegexPatterns`) is fixed independently, in the same phase, since Phase 7 deliberately
   leaves that method untouched (see RFC 0008, Relationship to Other RFCs). Includes its own
   `### Fixed` entry. **✅ Done (2026-09-06)** — see RFC 0008's own Revision Log for detail.
9. **Fix Release Management's cross-item sequential value collision** — RFC 0009. Extends Phase 7's
   discover/assemble methods (and `ApplyRegexReplacements`/`ApplyMatchesWithCaptureGroups`) with
   protected-span tracking, and adds a ledger to `PSScriptBuilderBumpFilesProcessor`'s orchestration
   loop — the only phase in this plan touching that file (see RFC 0009, Relationship to Other RFCs).
   Includes its own `### Fixed` entry. **✅ Done (2026-09-07)** — see RFC 0009's own Revision Log for detail.
10. **Wrap-up** — full test suite, module rebuild. No `CHANGELOG.md` work here anymore: each fix
    phase above already carries its own entry (see Revision Log for why this changed from the
    original "batch everything at Wrap-up" plan). This phase only re-verifies the accumulated
    `CHANGELOG.md` reads correctly top-to-bottom once every phase has landed. **✅ Done (2026-09-07)**
    — fresh rebuild byte-identical to the committed output, full suite 1883 passed / 0 failed,
    `CHANGELOG.md` re-read top-to-bottom with no issues found. All phases (1-10) on this branch are
    now complete.

**Phase 1 gets no `CHANGELOG.md` entry** — RFC 0001's own consolidation step is an explicit
"pure refactor, no behavior change" (see Phase 1's own description above), and `CHANGELOG.md`
documents observable behavior, not internal reorganization.

## Deferred Follow-Ups

Small, purely internal cleanups identified while implementing Phase 4, deliberately not inserted
into the phase sequence above so they don't disrupt it. Pick these up once Phases 4 and 5 are
both fully done:

- **Deduplicate the closing log line** `RenderFreeMode()` and `RenderOrderedMode()` now share
  verbatim (`Write-Verbose "  Template rendered with $($replacements.Count) replacement(s)"`
  followed by `return $result`) — move it into `AssembleFromReplacements()` itself, which both
  already call and which already has `$replacements` in scope, instead of keeping it duplicated
  in both callers.
- **Group the `Discover*` methods by mode under explicit `#region` blocks** (`#region Free Mode` /
  `#region Ordered/Hybrid Mode`), matching this class's existing `#region Properties`/
  `#region Constructors` convention. Once Phase 4's old `Replace*` methods are removed, the three
  Ordered/Hybrid `Discover*` methods already end up textually adjacent to each other as a side
  effect (each was inserted directly before the `Replace*` method it replaces) — the `#region`
  wrapping is purely about making that grouping explicit and visually scannable, not about
  physically reordering anything further.

## Why this order

- **1 before 6:** the escape mechanism's masking must apply consistently across all three
  consolidated detection call sites; consolidating them first (Phase 1) means Phase 6 only has to
  change one thing, not three.
- **4 before 5:** Phase 5's Ordered/Hybrid-Mode fix lands inside the `Discover*` methods Phase 4
  creates. Fixing case-sensitivity in today's pre-Phase-4 `Replace*` methods first would mean
  redoing the same fix a second time when Phase 4 replaces them — same matching logic touched
  twice instead of once.
- **4 and 5 before 6:** Phase 6's masking is applied before `PSScriptBuilderTemplateProcessor.Render()`
  (and the mode-detection/validation steps that precede it) ever see the template content. Landing
  the injection fix (4) and the case-sensitivity fix (5) first means masking wraps an
  already-correct implementation, rather than needing to be re-verified once 4 and 5 land on top of
  it later.
- **2 and 3 relative to 4/5:** no ordering dependency — RFC 0002's and RFC 0006's validation-time
  checks are independent of the rendering fixes. Placed early, next to each other, as the smallest,
  most isolated changes and the same kind of reserved-key check.
- **7 before 8:** Phase 8's case-insensitivity fix lands inside the discover/assemble methods
  Phase 7 creates — same reasoning as Phase 4 before Phase 5.
- **7 and 8 relative to 1-6:** no ordering dependency at all — RFC 0007/0008 touch
  `PSScriptBuilderBumpReplacementHelper.ps1` exclusively, a file none of Phases 1-6 touch. Placed
  after the Template-side work only for grouping clarity (both are Release-Management-specific),
  not because of any real constraint.
- **7 before 9:** Phase 9's protected-span tracking is built directly into the discover/assemble
  methods Phase 7 creates — same reasoning as Phase 7 before Phase 8.
- **9 after 8 (not before):** Phases 8 and 9 both extend Phase 7's methods independently of each
  other (no dependency between them), but Phase 9 is the more invasive change (also touches
  `PSScriptBuilderBumpFilesProcessor.ps1`, unlike any other phase in this plan) — sequenced last
  among the Release Management fixes so the simpler, more contained change (8) lands and is verified
  first.

## Branch-scope note

RFC 0002, 0003, and 0004 all touch `PSScriptBuilderTemplateProcessor.ps1` and/or
`PSScriptBuilderTemplateValidator.ps1`, the same files RFC 0001's Phase 5 masking work wraps. That
file-level overlap — not a functional dependency between the fixes themselves — is why those RFCs
share a single branch instead of shipping independently: whichever change landed second would need
to rebase around the other's edits to the same files regardless of branch structure.

RFC 0006 also touches `PSScriptBuilderTemplateValidator.ps1` (a new validation check), so the same
reasoning applies there too. RFC 0007, RFC 0008, and RFC 0009, by contrast, touch only Release
Management files — `PSScriptBuilderBumpReplacementHelper.ps1` (all three) and, for RFC 0009 only,
`PSScriptBuilderBumpFilesProcessor.ps1` too — no file overlap with any Template-side RFC on this
branch. RFC 0007/0008/0009 do overlap *with each other* (all three touch the same discover/assemble
methods `PSScriptBuilderBumpReplacementHelper.ps1`), which is exactly why Phases 7-9 are sequenced
adjacently. They share this branch simply because they were found during the same investigation, not
because of any git-mechanical necessity; they could equally well ship on their own branch without
any rebase concern relative to Phases 1-6.

## Revision Log

- 2026-09-07 — Marked Phase 10 (Wrap-up) as done: fresh rebuild byte-identical to the committed
  output, full suite 1883 passed / 0 failed, `CHANGELOG.md` re-read top-to-bottom with no issues
  found. All phases on this branch are complete.
- 2026-09-07 — Marked Phase 9 as done. See RFC 0009's own Revision Log for detail.
- 2026-09-06 — Marked Phase 8 as done. See RFC 0008's own Revision Log for detail; also found and
  separately documented (RFC 0010, deferred, not part of this plan) an unrelated value-collision bug
  in `ReplaceRegexPatterns` while verifying RFC 0008 against current source.
- 2026-09-05 — Marked Phase 7 as done. Also corrected its own description here, which listed all
  three replacement methods as converted to discover/assemble — only `ApplySimpleReplacements` and
  `ApplyPlaceholderReplacements` needed the change; `ApplyRegexReplacements` was already safe. See
  RFC 0007's own Revision Log for detail.
- 2026-09-05 — Marked Phase 6 as done. Also corrected two stale references to this phase's masking
  location (previously said masking wraps `PSScriptBuilderTemplateProcessor.Process()` — that method
  no longer exists, and masking is actually applied at the three call sites that load raw template
  content, not inside the Validator/Processor; see RFC 0001's own Revision Log for the full
  correction).
- 2026-09-04 — Marked Phase 5 as done. See RFC 0004's own Revision Log for detail.
- 2026-09-04 — Marked Phase 4 as fully done: the old, now-unused `Replace*` methods have been
  removed. See RFC 0003's own Revision Log.
- 2026-09-04 — Noted Phase 4's bug fix as verified and pushed (old `Replace*` methods still
  pending removal before the phase counts as fully done). Added a "Deferred Follow-Ups" section
  for two small internal cleanups found during Phase 4 implementation (deduplicating a log line,
  grouping `Discover*` methods by mode under `#region` blocks) — deliberately not inserted into
  the phase sequence itself. Also fixed a stray memory-link artifact that had leaked into this
  file's own prose.
- 2026-09-03 — Marked Phase 3 as done (2026-09-03). See RFC 0006's own Revision Log for detail.
- 2026-09-03 — Marked Phase 2 as done (2026-09-03). See RFC 0002's own Revision Log for detail.
- 2026-09-03 — Marked Phase 1 as done (2026-09-03). This file is the single place per-phase
  implementation progress is tracked — RFC 0001's own `Status` field intentionally stays
  "Decided, not yet implemented" until *both* its steps (this Phase 1 prerequisite and Phase 6's
  escape masking) are complete, matching how Rust RFCs/Kubernetes KEPs keep a document's top-level
  status coarse-grained and track granular progress in a separate artifact instead.
- 2026-09-03 — Moved `CHANGELOG.md` updates out of Wrap-up (Phase 10) and into each fix phase
  (2-9) individually, so a phase's own commit(s) are complete on their own instead of leaving an
  open "document this later" obligation until the very end. Phase 1 explicitly gets no entry (pure
  refactor, no observable behavior change) — confirmed against the project's actual `CHANGELOG.md`
  history that every existing entry documents observable behavior only, never internal
  reorganization.
- 2026-09-02 — Added RFC 0009 (Release Management cross-item sequential value collision) as new
  Phase 9, before Wrap-up (now Phase 10). Extends Phase 7's discover/assemble methods and also
  touches `PSScriptBuilderBumpFilesProcessor.ps1` — the only phase in this plan touching that file.
  Sequenced after Phase 8 (the simpler, more contained change) since Phase 9 is the more invasive of
  the two independent extensions to Phase 7's methods. Updated the Branch-scope note: RFC
  0007/0008/0009 overlap with each other (same discover/assemble methods), which is why they are
  sequenced adjacently, even though none of them overlap with the Template-side RFCs.
- 2026-09-02 — Clarified Phase 8's description: RFC 0008's fix has two independent halves
  (`{{TOKEN}}`, built into Phase 7's new methods; `{REGEX_TOKEN}`, fixed on its own in
  `ReplaceRegexPatterns`) after finding the latter is a separate, previously undocumented bug — see
  RFC 0008's own Revision Log.
- 2026-09-02 — Added RFC 0007 (Release Management sequential value collision) and RFC 0008
  (Release Management token case-insensitivity) as new Phases 7-8, before Wrap-up (now Phase 9).
  Both touch only `PSScriptBuilderBumpReplacementHelper.ps1`, with no file overlap with any other
  RFC on this branch — grouped here for topical clarity, not because of any real ordering
  constraint with Phases 1-6.
- 2026-09-02 — Inserted RFC 0006 (Release-Management-token key collision) as new Phase 3, grouped
  next to Phase 2 (same kind of reserved-key check, no dependency on anything else). Renumbered
  Phases 3-6 to 4-7 accordingly.
- 2026-09-01 — Removed Phase 5's Release Management sub-step (formerly 5b) after RFC 0001 dropped
  Release Management from its scope entirely — see RFC 0001's Revision Log for the reasoning
  (its existing decorative-brace substitution behavior is legitimate and must not be disturbed).
- 2026-08-31 — Created by extracting the phase/sequencing plan that had previously accreted inside
  RFC 0001's Detailed Design (and been duplicated/renumbered across RFC 0002, 0003, and 0004's
  Relationship sections every time a new RFC was added). Renumbered the case-sensitivity RFC from
  0005 to 0004 and the deferred unified-rendering RFC from 0004 to 0005 at the same time, so the
  four active-branch RFCs occupy consecutive numbers. No decisions changed — this is a
  documentation reorganization only.

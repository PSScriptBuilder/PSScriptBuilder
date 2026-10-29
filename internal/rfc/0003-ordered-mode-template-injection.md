# RFC 0003: Ordered/Hybrid Mode Template Injection

- **Status:** Implemented (2026-09-04)
- **Type:** Fix
- **Created:** 2026-08-29
- **Branch:** `refactor/template-engine-consolidation`

## Summary

`RenderOrderedMode` replaces `Using`, `File`, and `{{ORDERED_COMPONENTS}}` placeholders
sequentially, each step operating on the previous step's already-modified output. When one step's
inserted content happens to contain text matching another placeholder, it gets matched and
replaced again — sometimes failing loudly, sometimes silently corrupting the build output.
`RenderFreeMode` already has the correct architecture to prevent this; this RFC converts
`RenderOrderedMode` to the same pattern.

## Motivation

`PSScriptBuilderTemplateProcessor.RenderFreeMode()` (`PSScriptBuilderTemplateProcessor.ps1:238-250`)
uses an explicit two-phase design specifically to prevent this class of bug — its own doc comment
states it directly:

> "This two-phase design prevents template injection: source code written into earlier
> replacements may contain `{{Placeholder}}` tokens (e.g., in PowerShell comment-based help), but
> these are never interpreted as placeholders because the scanner only reads from the original
> `$template`."

`RenderOrderedMode()` (`PSScriptBuilderTemplateProcessor.ps1:195-208`) has no such protection. It
replaces placeholders **sequentially**, with each step operating on the *result* of the previous
one, not the original template:

```powershell
$result = $this.ReplaceUsingCollectorPlaceholders($template)      # Step 1
$result = $this.ReplaceFileCollectorPlaceholders($result)          # Step 2 — operates on Step 1's output
$result = $this.ReplaceOrderedComponentsPlaceholder($result, $orderedComponents)  # Step 3 — operates on Step 2's output
```

Because Step 3's `.Replace()` call runs against `$result` — which by that point already contains
whatever `Using` and `File` inserted in Steps 1 and 2 — any occurrence of
`{{ORDERED_COMPONENTS}}`-shaped text *inside content that Using or File inserted* gets matched and
replaced too, exactly like a real template placeholder.

Found 2026-08-29 while answering a question about what happens when collected source code (a
class or function body) happens to contain literal `{{KEY}}`-shaped text. That specific question
turned out to be already safe (see "Ruled Out," below) — but tracing through why led directly to
this real, separate, already-shipping bug.

### Repro 1 — `File` content colliding with `{{ORDERED_COMPONENTS}}` (fails loudly)

A `File` collector whose source file contains a plain comment mentioning the reserved token,
combined with a real class, in a Hybrid Mode template (`{{FILE_CONTENTS}}` / `{{ORDERED_COMPONENTS}}`):

`Header.ps1`: `# Documentation note: this project uses {{ORDERED_COMPONENTS}} in its template.`
`Widget.ps1`: a real `class Widget { [string] $Name; Widget([string] $name) { $this.Name = $name } }`

`Invoke-PSScriptBuilderBuild` **fails** — but only *after* writing a corrupted output file
(`ValidateSyntax` runs after `WriteOutput`):

```powershell
# Documentation note: this project uses class Widget {
    [string] $Name
    Widget([string] $name) {
        $this.Name = $name
    }
} in its template.

class Widget {
    [string] $Name
    Widget([string] $name) {
        $this.Name = $name
    }
}
```

The `Widget` class was inserted **twice** — once correctly, once erroneously in the middle of the
`File` collector's comment, because Step 3 re-scanned Step 2's already-modified output. The
corrupted comment breaks PowerShell's single-line comment syntax, producing
`"Unexpected token '}' in expression or statement"` — this build happened to fail loudly only
because the accidental match landed inside a `#` comment. A different collision position could
produce syntactically valid but silently wrong output — this build failing loudly is not evidence
the bug is otherwise safe.

### Repro 2 — two `File` collectors alone, no `Using`/`ORDERED_COMPONENTS` needed (fails silently)

Found in response to a question about projects with multiple `File` collectors. Happens **inside
`ReplaceFileCollectorPlaceholders` itself**, and — unlike Repro 1 — **the build succeeds and
reports no error at all.**

`File1.ps1`: `# Note: this project also has {{FILE_CONTENT2}} elsewhere.`
`File2.ps1`: `# This is the real second file's content.`

Template (Hybrid Mode): `{{USING_STATEMENTS}}` / `{{FILE_CONTENT1}}` / `{{FILE_CONTENT2}}` /
`{{ORDERED_COMPONENTS}}`. `Invoke-PSScriptBuilderBuild` **reports success**, but `FILE_CONTENT2`'s
content appears **twice** and `FILE_CONTENT1`'s comment is corrupted mid-sentence — because .NET's
`String.Replace(oldValue, newValue)` replaces **every** occurrence of `oldValue`, not just one.
`ReplaceFileCollectorPlaceholders` (`PSScriptBuilderTemplateProcessor.ps1:520-557`) processes
`FILE_CONTENT1` first, inserting its content (which happens to contain the literal text
`{{FILE_CONTENT2}}`) into `$template`. When the loop's next iteration processes `FILE_CONTENT2`,
`$template` now contains that literal text *twice* — once at its real position, once inside
`FILE_CONTENT1`'s just-inserted comment — and `.Replace()` substitutes both. This is a stronger
repro than Repro 1: no `Using`/`ORDERED_COMPONENTS` interaction needed, and it fails **silently**,
strictly more dangerous to leave unfixed.

### Repro 3 — compounding with the ordered-components-key collision (RFC 0002)

See RFC 0002 for the full scenario: a `File` collector whose own `-CollectionKey` collides with
the reserved ordered-components key produces this same silent-corruption pattern, self-
referentially — the `File` collector's own content contains the literal text of its own key,
which is also the reserved key text. Confirms the fix below resolves that scenario's
*content*-level corruption too, though the *key-collision* itself still needs RFC 0002's separate
validation-time check — the two fixes address different aspects of the same compounding failure.

### Ruled out: placeholder-shaped text inside collected source code itself

Literal `{{KEY}}`-shaped text *inside collected source code itself* (e.g., a string literal in a
class property, or a comment inside a function body) is **already safe**, in both Free and
Ordered/Hybrid Mode. Verified with a real build: a class with both a string property containing
`{{CLASS_DEFINITIONS}}` and a comment containing `{{{{ORDERED_COMPONENTS}}}}` was built in both
modes; the output was byte-for-byte identical to the source, with neither string touched. In Free
Mode, `DiscoverReplacements` scans only the original template, never collected content, and no
further pass runs after assembly. In Ordered/Hybrid Mode, collected class/function content is
inserted only in Step 3, the *last* step — nothing runs afterward that could re-scan it. The bug
here is specifically about content inserted by an *earlier* step (or an earlier `File` iteration)
being re-scanned by a *later* one — not about collected source containing placeholder-shaped text.

## Detailed Design

### Root Cause

`RenderOrderedMode` was implemented as three independent sequential replacements instead of
reusing the two-phase discover/assemble pattern `RenderFreeMode` already established in the same
class for exactly this reason. Both methods solve the same problem (turn a template plus
collected content into a final script); only one of them protects against inserted content being
re-interpreted.

### Decision

Convert `RenderOrderedMode` to the same two-phase approach `RenderFreeMode` already uses —
verified by reading `DiscoverReplacements`, `AssembleFromReplacements`, and all three existing
`Replace*` methods in full, not just their doc comments.

`RenderFreeMode`'s existing `DiscoverReplacements()` (`PSScriptBuilderTemplateProcessor.ps1:288-312`)
is **not** directly reusable for Ordered Mode as-is: it loops over every registered collector and,
for each one, finds *that collector's own* `CollectionKey`-based placeholder — "one placeholder
per collector," which is Free Mode's structure but not Ordered/Hybrid Mode's. `Using` needs
different handling even there: `ReplaceUsingCollectorPlaceholders` consolidates statements from
*all* Using collectors into one block and places it at only the *first* Using placeholder found.
`Enum`/`Class`/`Function` collectors have no individual placeholders in Ordered/Hybrid Mode at
all — their content combines into the single `{{ORDERED_COMPONENTS}}` block, computed by
`ReplaceOrderedComponentsPlaceholder`'s logic (`PSScriptBuilderTemplateProcessor.ps1:572-615`):
walk the topologically-sorted `$orderedComponents` array, pull each one's source via
`ContentProcessor.GetComponentSourceCode()`, and concatenate.

The fix needs **new sibling `Discover*` methods**, each adapted from its corresponding existing
`Replace*` method to *return* a `(Start, Length, Replacement)` entry (or entries) instead of
mutating and returning a template string:

- `DiscoverUsingReplacement($template)` — same "consolidate across all Using collectors, first
  placeholder wins" logic as `ReplaceUsingCollectorPlaceholders`, computing position via
  `IndexOf` against the **original** template, returning at most one entry.
- `DiscoverFileReplacements($template)` — same per-File-collector logic as
  `ReplaceFileCollectorPlaceholders`, adapted the same way; returns zero or more entries.
- `DiscoverOrderedComponentsReplacement($template, $orderedComponents)` — same combined-block
  computation as `ReplaceOrderedComponentsPlaceholder`, returning one entry instead of calling
  `.Replace()`.

`RenderOrderedMode` then calls all three, combines their entries into one list, and hands that
list to the *existing, unmodified* `AssembleFromReplacements()` (`PSScriptBuilderTemplateProcessor.ps1:407-430`)
— already fully generic (it only cares about `Start`/`Length`/`Replacement`), needing no changes.
This reuses the exact mechanism `RenderFreeMode` already relies on, without touching
`AssembleFromReplacements` or `DiscoverReplacements` (Free Mode's own method stays as-is).

**Verified this fix design against all three repros above**, including Repro 2 (two `File`
collectors): `DiscoverFileReplacements` finds every File collector's position via `IndexOf`
against the same untouched `$template` parameter for every iteration, never against a mutating
intermediate result — no further design change needed for that case.

Note for implementation: RFC 0004 fixes a separate, compounding bug (case-sensitivity) inside
these same three positions. Its fix belongs inside these new `Discover*` methods directly (see
RFC 0004's Detailed Design) — build both fixes into the same methods in one pass rather than
building these `Discover*` methods first and revisiting them immediately after.

## Rationale and Alternatives

No alternative fix design was seriously considered: reusing `RenderFreeMode`'s established,
already-correct architecture is the natural choice over inventing a new mechanism, and it keeps
the two rendering modes structurally consistent.

**Considered and deferred: unifying `RenderFreeMode` and `RenderOrderedMode` into a single
rendering mechanism** (raised while reviewing this RFC), so this class of bug becomes structurally
impossible for any future mode/collector-type addition, not merely fixed for today's known cases.
Genuinely a cleaner end state, but risk-disproportionate to bundle into this fix — it would require
touching the already-correct, unmodified `RenderFreeMode`, and the design isn't fully worked out
yet (a wrinkle in `Using`'s "first found wins" semantics needs its own design pass). Logged
separately as **RFC 0005**, to be picked up deliberately later rather than folded into this branch
under time pressure.

## Scope

**In scope:** rewriting `RenderOrderedMode`'s three replacement steps as `Discover*` methods
feeding the existing `AssembleFromReplacements`.

**Explicitly out of scope — a pre-existing, unrelated formatting difference:** Ordered Mode has
never had Free Mode's `CalculateConsumedLength()` blank-line-avoidance logic (confirmed via a real
build: Ordered Mode output ends up as `}\n#endregion...` vs. Free Mode's `}\r\n#endregion...`) — a
pre-existing, purely cosmetic difference, unrelated to this bug. The fix must not change it: the
new `Discover*` methods reuse each existing `Replace*` method's content-computation logic exactly
as-is, only changing *when* positions are computed, not how whitespace is handled.

## Relationship to Other RFCs

- **RFC 0001** (template placeholder escaping) shares the same underlying principle — "compute
  replacements from the original content, never re-scan what was already inserted" — but this is a
  different, pre-existing, already-shipping bug, not contingent on that work. Both fixes touch
  `PSScriptBuilderTemplateProcessor.ps1`, which is why both live on the same branch — see
  `internal/rfc/IMPLEMENTATION-PLAN.md` for build order.
- **RFC 0002** (ordered-components-key collision) — Repro 3, above, is a compounding interaction
  between both bugs; both fixes are needed for that scenario to be fully resolved.
- **RFC 0004** (template placeholder case-sensitivity mismatch) — a distinct bug (comparison mode,
  not sequencing/injection) found in the same three methods this RFC rewrites into `Discover*`
  methods. Its fix belongs inside the new `Discover*` methods this RFC introduces (see Detailed
  Design, above).
- **RFC 0005** (centralized template tokenizer) — the deeper architectural improvement this RFC's
  narrower fix was deliberately not expanded into; this RFC's `Discover*`-method vocabulary is what
  RFC 0005's tokenizer output would feed into, once picked up. See Rationale and Alternatives,
  above.

## Test Plan

- Regression test for Repro 1 — must now build successfully with the `Widget` class appearing
  exactly once.
- Regression test for Repro 2 — must build successfully with each collector's content appearing
  exactly once, uncorrupted.
- Confirm `RenderFreeMode` behavior is unchanged (existing tests already cover this).
- Confirm the fix does not change output for templates with no collision potential — existing
  Ordered/Hybrid Mode integration tests must continue to pass unmodified.

## Unresolved Questions

- Does converting `RenderOrderedMode` to two-phase change performance meaningfully? Unlikely —
  `RenderFreeMode` already does the equivalent work successfully — but worth confirming with the
  existing build-time verbose phase-duration logging (`Invoke-PSScriptBuilderBuild -Verbose`) on a
  reasonably large project before/after.

## Revision Log

- 2026-09-04 — Removed the old, now-unused `ReplaceUsingCollectorPlaceholders`,
  `ReplaceFileCollectorPlaceholders`, and `ReplaceOrderedComponentsPlaceholder` methods, and
  updated the two `Discover*` doc comments that had referenced them by name. Verified: 1836
  passed / 9 failed, unchanged — a pure cleanup, no behavior change. This RFC is now fully
  implemented.
- 2026-09-04 — Implemented and pushed: `DiscoverUsingReplacement`, `DiscoverFileReplacements`,
  and `DiscoverOrderedComponentsReplacement` added, `RenderOrderedMode` rewired to call all three
  and hand the combined entries to the existing, unmodified `AssembleFromReplacements`. Both
  repros verified fixed with the real `AssembleFromReplacements` method before insertion, each
  time compared against the real (buggy) `Render()` output for the same scenario. Full suite:
  1836 passed / 9 failed (down from 1831/14) — exactly Repro 1 and Repro 2's tests turned green,
  plus all three RFC 0004 Ordered-Mode case-insensitivity tests (built into these same new
  methods, per this RFC's own note in Detailed Design). `CHANGELOG.md` entry added. The old
  `Replace*` methods are temporarily still present (unused) — removed in a following step. Two
  minor follow-up cleanups were identified but deliberately deferred rather than inserted into
  this step sequence: deduplicating `RenderFreeMode`/`RenderOrderedMode`'s now-identical closing
  log line (move it into `AssembleFromReplacements` itself), and grouping the `Discover*`
  methods by mode under explicit `#region` blocks. See `internal/rfc/IMPLEMENTATION-PLAN.md`.
- 2026-08-31 — Rewritten as a self-contained document: removed phase-numbering language (now in
  `internal/rfc/IMPLEMENTATION-PLAN.md`) and renumbered the case-sensitivity RFC reference from
  0005 to 0004, and the deferred unified-rendering RFC reference from 0004 to 0005, per the
  branch-wide RFC renumbering. No decisions changed.
- 2026-08-30 — Found RFC 0004 (case-sensitivity mismatch, then numbered RFC 0005) in the same three
  methods this RFC rewrites; its fix belongs inside the new `Discover*` methods introduced here.
- 2026-08-30 — Found Repro 3 (compounding with RFC 0002's key collision), and separately confirmed
  PSScriptBuilder's own dogfooded self-build was never at risk (`Build-Module.ps1` registers no
  `File` collector, so the one exploitable step never runs).
- 2026-08-30 — Pre-implementation review: read all three `Replace*` methods in full (not just doc
  comments), which showed the original fix assumption ("just reuse `DiscoverReplacements`") was
  incomplete — refined to the `Discover*` sibling-methods design in Detailed Design. Found and
  documented the pre-existing, unrelated `CalculateConsumedLength` whitespace difference between
  modes, and confirmed via a real build that placeholder-shaped text inside collected source code
  is safe in both modes (see "Ruled out," above).
- 2026-08-29 — Repro 2 found (two `File` collectors, silent corruption); confirmed the proposed fix
  already covers it. Corrected an initial assumption that `Using`'s consolidated output carried the
  same risk as `File`'s — `GetConsolidatedUsingStatements()` only ever contains AST-parsed
  statement text, which cannot contain `{{...}}`-shaped text.
- 2026-08-29 — Initial finding (Repro 1), root cause identified, fix direction proposed.

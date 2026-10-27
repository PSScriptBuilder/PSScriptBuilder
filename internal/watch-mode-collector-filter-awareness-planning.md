# Planning: Collector-Aware Change Filtering in Watch Mode

## Background

`PSScriptBuilderProjectWatcher.GetWatchPaths()` derives the set of directories to monitor from
every registered collector's `IncludePaths`, and `RegisterWatchers()` creates one
`FileSystemWatcher` per path with `IncludeSubdirectories = $true` — hardcoded, unconditional.
The only filtering applied before a detected change triggers a rebuild is by file **extension**
(`$Global:_PSScriptBuilderWatchIncludeExtensions`, set from `-FileExtension` at watch start).

Verified while reviewing the Collectors Guide's "Use `-NoRecurse` for flat source layouts" Tip
(2026-08-28): confirmed by reading `PSScriptBuilderProjectWatcher.ps1`'s `RegisterWatchers()`
(line 311, `IncludeSubdirectories = $true`) and its change-event handler (lines 315-330, which
only checks the changed file's extension against the watched set — no path-based filtering at
all).

## Problem

A collector's own path-scoping settings — `-NoRecurse`, `-ExcludePath`, `-ExcludeFile` — have no
effect on what Watch Mode considers relevant:

- A collector configured with `-NoRecurse` still has its entire subdirectory tree watched
  recursively. A `.ps1` file changing in a subdirectory that collector would never actually scan
  still triggers a rebuild.
- The same applies to `-ExcludePath`/`-ExcludeFile`: a change to an explicitly excluded file or
  directory still triggers a rebuild, even though the build's own output would be unaffected by
  it.

This is not a correctness bug — the eventual build still filters correctly, so the *output* is
never wrong. The cost is purely wasted rebuild cycles: unnecessary triggers on a project that
uses these filters specifically to scope down what a collector cares about.

## Goal

Only trigger a rebuild when a changed file would actually be included by at least one
registered collector's full filter set (`-IncludePath` + `-NoRecurse` + `-ExcludePath` +
`-ExcludeFile` + `-FileExtension`), not just by extension and directory-tree membership.

## Scope Considerations

- The change-event handler in `RegisterWatchers()` would need access to each collector's full
  filter configuration (not just the merged extension set) to re-evaluate a changed file against
  it — effectively re-running the same inclusion/exclusion logic
  `PSScriptBuilderCollectorBase.GetFilesToProcess()` already implements, but for a single file
  instead of a full directory scan.
- `-IncludeFile` entries add another wrinkle: they bypass all other filters at collection time,
  so a genuinely relevant change could come from a file outside every `-IncludePath` entirely.
  `GetWatchPaths()` would need to account for `-IncludeFile` paths too, not just `IncludePaths`.
- Risk of doing this per file-change event: re-evaluating full filter logic (glob matching,
  path-prefix checks) on every raised `FileSystemWatcher` event adds CPU cost that the current
  extension-only check avoids. Needs a performance check against a large project before deciding
  this is worth it.

## Open Questions

- Is the wasted-rebuild cost actually significant in practice, or is this a real-but-minor
  inefficiency not worth the added complexity? No concrete report of this causing a problem
  yet — found during a documentation accuracy review, not a user complaint.
- Should this filtering logic be shared/extracted so both `GetFilesToProcess()` (real collection)
  and the watcher's change-event handler use the exact same inclusion/exclusion code path,
  instead of two independent implementations that could drift out of sync?

## Status

Identified during the documentation review session on 2026-08-28, while writing the Collectors
Guide's `-NoRecurse` Tip and double-checking it against the File Watching Guide's "watched
recursively" claim (which is itself accurate, just not scoped by collector filters). Not yet
scoped or implemented.

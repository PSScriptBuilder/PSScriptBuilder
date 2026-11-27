# RFC 0028: Path Resolution Against the PowerShell Location

- **Status:** Implemented (2026-11-05) — written retroactively, after implementation and full
  cross-version verification; see Revision Log
- **Type:** Fix and design decision
- **Created:** 2026-11-05
- **Branch:** development

## Summary

The cmdlets that take a directory resolved it in ways that silently ended up in the wrong place:
`New-PSScriptBuilderConfiguration` and `New-PSScriptBuilderProject` passed a relative `-Path` to
.NET, which resolves it against the process working directory that `Set-Location` does not change;
a path on another provider's drive, such as `HKCU:` or `Env:`, became a relative provider path and
ended up there as well. `Set-PSScriptBuilderProjectRoot` read `-Path` as a wildcard pattern and
accepted any provider's container, and the project root auto-discovery started from the process
working directory when the location was not on a file system drive. The fix resolves every path
at the cmdlet boundary against the PowerShell location, rejects other providers' paths, reads the
project root literally and stores every directory as Windows resolves it.

## Motivation

The first finding was found while implementing RFC 0026; the others in the reviews of its fix. All
findings were measured on PowerShell 5.1 and 7 unless marked otherwise.

1. **Relative `-Path` against the process directory.** `New-PSScriptBuilderConfiguration -Path
   '.\cfg'` and `New-PSScriptBuilderProject -Path '.\projects'` created the file or project below
   `[Environment]::CurrentDirectory` instead of the PowerShell location after `Set-Location`.
2. **Other providers' drives.** `GetUnresolvedProviderPathFromPSPath` returns a provider path that
   is not rooted for such a drive (`Env:\x` → `x`, `HKCU:\Software\x` →
   `HKEY_CURRENT_USER\Software\x`), which .NET again resolves against the process directory. The
   first fix of finding 1 therefore made `New-PSScriptBuilderProject -Path 'Env:\x'` — and a call
   without `-Path` while the location was on such a drive — silently create the project in the
   process directory. Found in review before the fix was committed.
3. **Auto-discovery outside the file system.** With the location on `HKCU:\Software`,
   `Get-PSScriptBuilderProjectRoot` searched upward from `<process directory>\HKCU:\Software` in
   PowerShell 7 and failed with "The given path's format is not supported" in 5.1.
4. **Any container accepted as project root.** `Set-PSScriptBuilderProjectRoot -Path
   'HKCU:\Software'` passed the container check and stored the registry provider path.
5. **`-Path` read as a wildcard pattern.** `Resolve-Path -Path` silently set the project root to
   `App1` for `App[1]` when `App1` existed, returned nothing for `Only[1]` (followed by a
   misleading provider error), and set the project root to an `Object[]` for `s*` matching `sa` and
   `sb`. `Test-Path -Path` returned `$false` for `Only[1]`.
6. **Trailing spaces and dots.** Windows ignores them when accessing `C:\Proj `, so the path was
   accepted, but the stored root kept the space and every path combined from it named a directory
   that does not exist (`C:\Proj \src\f.ps1`). The `New-*` cmdlets created `proj` and then failed
   writing to `proj \…` with "Could not find a part of the path", leaving an empty directory.
7. **White space only.** `Set-PSScriptBuilderProjectRoot -Path '   '` silently set the current
   location as project root.
8. **8.3 short names.** `Resolve-Path` keeps `C:\Users\TONYST~1`, while `Get-ChildItem` and
   `GetFullPath` return the long name; files below the root then no longer start with it, so
   `Format-PSScriptBuilderSourceCoverage` and the verbose list of build files show full paths
   (derived from the code, not measured end to end).
9. **Pipeline input in 5.1.** `Get-ChildItem` items convert to their name only in 5.1 (`sa`), so
   `Get-ChildItem D:\X -Directory | Set-PSScriptBuilderProjectRoot` resolved the name against the
   current location — silently wrong if a directory of that name existed there.

## Detailed Design

- **`PSScriptBuilderFileSystemHelper.ResolveFileSystemPath([PathIntrinsics] $pathIntrinsics,
  [string] $path)`** (new): resolves with the three-argument overload of
  `GetUnresolvedProviderPathFromPSPath`, which also returns the provider; throws an
  `ArgumentException` naming the path, the provider path and the provider unless it is
  `FileSystem`; returns `[Path]::GetFullPath(...)`, which removes trailing spaces and dots of the
  last segment and expands 8.3 short names of existing directories. The path does not need to
  exist.
- **`New-PSScriptBuilderConfiguration`, `New-PSScriptBuilderProject`:** `-Path`, or `'.'` when it is
  empty or white space, is resolved via the method with `$PSCmdlet.SessionState.Path`; the
  configuration still prefers a set project root over `'.'`.
- **`Get-PSScriptBuilderProjectRoot`:** the search starts at
  `ResolveFileSystemPath($ExecutionContext.SessionState.Path, '.')`; measured: inside a module
  function, it sees the caller's location.
- **`Set-PSScriptBuilderProjectRoot`:** rejects a path of white space only (`ArgumentException`);
  resolves with `Resolve-Path -LiteralPath`; throws the `ItemNotFoundException` PowerShell 7 throws
  when 5.1 returns nothing for a literal path containing `*` or `?`; rejects other providers;
  checks the container with `Test-Path -LiteralPath`; stores
  `[DirectoryInfo]::new($resolvedPath.ProviderPath).FullName`, as the auto-discovery already does.
  `-Path` gets `[Alias('PSPath')]` and `ValueFromPipelineByPropertyName`.

## Rationale and Alternatives

**Resolve at the cmdlet boundary.** The Microsoft cmdlet guideline "Support Windows PowerShell
Paths" has cmdlets convert a PowerShell path to a provider path before using it; .NET knows only
the process working directory.

**A class method with the path intrinsics passed in, not a private function.** A class method has
no access to `$ExecutionContext` or `$PSCmdlet` ("Variable is not assigned in the method", measured
on both versions), so the caller passes its `PathIntrinsics` (Method Injection, Seemann/van
Deursen). The method sits with the other path helpers, and the dependency is explicit and testable
without `InModuleScope`. A private function would hide the dependency, as `GetProjectRootedPath`
does with `Get-PSScriptBuilderProjectRoot`. This does not conflict with RFC 0025: its concern is
writing to streams through `$PSCmdlet` inside classes; `PathIntrinsics` only answers queries.

**Literal `-Path` instead of wildcards with an additional `-LiteralPath`.** The guideline allows a
`Path` with wildcards or a `LiteralPath`. Keeping `-Path` and reading it literally matches
`New-Item -Path`, needs no breaking change, and makes all three cmdlets consistent, since the
`New-*` cmdlets resolve literally through `GetUnresolvedProviderPathFromPSPath` (measured for
`App[1]` and `s*`). Full wildcard support, as in `Set-Location` (measured: "resolved to multiple
containers"), would be a new feature without a use case.

**`PSPath` alias and binding by property name** follow the guideline for literal paths and make
the pipeline independent of how an item converts to a string (finding 9). Measured on both
versions: items of `Get-ChildItem` and `Get-Item`, `PathInfo`, strings, `-Path` and `-PSPath`.

**Store directories as Windows resolves them** (`FullName`, `GetFullPath`): paths combined from the
stored directory then name the same directory (findings 6 and 8).

**Considered and kept as they are:**
- **A space before a separator** (`C:\x \cfg`, `New-*` cmdlets): PowerShell 7 creates a directory
  `x `, 5.1 fails. Windows trims only the last segment, so 7 follows the Windows definition;
  rejecting such segments would also block an intentionally named directory.
- **The `\\?\` prefix** stays in the stored root; paths are then shown in full. No one types it by
  hand.
- **A leading space** is a valid name on Windows and kept.
- **Several paths through the pipeline:** the last one wins, as with `Set-Location` (measured).
- **Invalid characters** (`a<b`) fail with different messages on 5.1 and 7, both clear.
- **A trailing separator** stays in the stored root; `Path.Combine` and `GetProjectRelativePath`
  handle it.

## Scope

**In scope:** `PSScriptBuilderFileSystemHelper`, `New-PSScriptBuilderConfiguration`,
`New-PSScriptBuilderProject`, `Set-PSScriptBuilderProjectRoot`, `Get-PSScriptBuilderProjectRoot`;
their unit tests; the CBH and `docs/cmdlets` pages of the three public cmdlets; `CHANGELOG.md`;
this RFC.

**Known limits:** Linux and macOS were not measured; .NET does not trim trailing spaces there,
which are valid names. Long paths were measured with `LongPathsEnabled = 1` only.

## Relationship to Other RFCs

RFC 0026 requires absolute paths in its transaction for the same reason (step 1 of `Commit()`);
this RFC fixes the cmdlets' own paths. The path intrinsics follow the injection RFC 0025 rejected
only for streams.

## Test Plan

- **`ResolveFileSystemPath`:**
  - a relative path resolved against the location, not the process directory
  - `.`
  - an absolute path that does not exist
  - `Env:\…`
  - `.` in an `Env:` location
  - a trailing space (Windows)
- **`New-PSScriptBuilderConfiguration`, `New-PSScriptBuilderProject`:** a relative `-Path`;
  `Env:\…` and no `-Path` in an `Env:` location, each throwing and creating nothing in the process
  directory.
- **`Get-PSScriptBuilderProjectRoot`:** throws in an `Env:` location and caches nothing.
- **`Set-PSScriptBuilderProjectRoot`:**
  - an existing directory and a file
  - `Env:\`
  - `App[1]` beside `App1`
  - `s*` (`ItemNotFoundException` on both versions)
  - white space
  - a trailing space and an 8.3 short name (Windows; the latter skipped on drives without short
    names and checked manually with `C:\Users\TONYST~1`)
  - `Get-ChildItem` through the pipeline from an `Env:` location
- **Results:** full suite PS 7: 2316 passed, 3 skipped; PS 5.1: 2317 passed, 2 skipped; smoke
  tests 22 of 22 and example tests 16 of 16 on both.

## Unresolved Questions

None.

## Revision Log

- 2026-11-05 — Implemented on `development` (commits pending). The fix of finding 1 introduced
  finding 2, which a review caught before it was committed; measuring the auto-discovery and
  `Set-PSScriptBuilderProjectRoot` for the same case added findings 3 and 4. A review of the
  provider check found the wildcard reading (5), and two further reviews of the literal variant
  added findings 6 to 9, the `ItemNotFoundException` for 5.1 and the decisions to keep the cases
  listed under Rationale.

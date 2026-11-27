# RFC 0030: Paths Read Literally

- **Status:** Draft
- **Type:** Fix and design decision
- **Created:** 2026-11-11
- **Branch:** development

## Summary

The module decides an ambiguity the wrong way round. A value such as `App[1]` can be a real path —
`[` and `]` are legal in a file name — and the module hands it to cmdlets that read it as a wildcard
pattern instead. Measured consequences: a single source file named `App[1].ps1` breaks every build
of an otherwise ordinary project, a project in a bracketed directory cannot be configured at all,
and a collector can run to the end and write a file with none of the components in it. A second
defect is unrelated to metacharacters: `-NoRecurse` together with `-ExcludeFile` collects nothing.

RFC 0028 fixed one cmdlet this way; this RFC does it for the rest, with three rules — a path is
checked through one helper that cannot interpret it, a directory is enumerated in the one form that
lists its files, and a pattern is resolved only where patterns are allowed. The solution was
measured on a patched copy of the module before being written down: twenty-one checks pass against
it and seventeen of them fail against the module as it stands today.

## Motivation

Eleven measured cases. Every one was run through the built module on Windows PowerShell 5.1, each
with its setup, its call and the message it produced, so each can be reproduced from what is
written here; Appendix A records the environment and the arrangements the cases do not state
themselves. The first three need no unusual path at all.

### 1. One file name breaks the whole build

A project with no metacharacter anywhere — not in the project root, not in any parameter. `src`
holds `App[1].ps1`, `Normal.ps1` and `Sub\Deep.ps1`:

```powershell
$collector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES' -IncludePath 'src'
Invoke-PSScriptBuilderBuild -ContentCollector $collector -TemplatePath $template -OutputPath $output
```

```text
Build failed. Error: Script building failed. Error: Failed to execute collector ClassCollector
with key 'CLASSES'. Error: Failed to collect class definitions from file:
…\Proj\src\App[1].ps1. Error: File not found: …\Proj\src\App[1].ps1
```

The enumeration finds the file and hands it to the parser, which reports it as missing. Reading it
would have worked: the parser reads with `[File]::ReadAllText`, which is literal. Only the guard in
front of it, `Test-Path -Path`, interprets the name. The build dies at a check its own operation did
not need — and no build of that project runs again until the file is renamed.

### 2. A relative pattern at `-IncludeFile` fails, an absolute one works

In a project without a single metacharacter, `src` holding two class files:

```powershell
-IncludeFile '*.ps1'           # fails
-IncludeFile 'src\*.ps1'       # fails
-IncludeFile 'C:\…\src\*.ps1'  # works, 2 components
```

```text
Build failed. Error: Script building failed. Error: Failed to execute collector ClassCollector
with key 'CLASSES'. Error: Exception calling "GetFullPath" with "1" argument(s):
"Illegal characters in path."
```

The same pattern works absolutely and fails relatively, and the message names neither the parameter
nor the value nor the reason. It comes from .NET, not from the module, so it also appears in the
language of the system it runs on.

**This case is specific to Windows PowerShell 5.1.** On PowerShell 7 the same relative pattern
resolves and collects, because .NET Core dropped the character check in `GetFullPath`. The defect
is therefore one of two behaviors for the same call, which is what rule C ends.

### 3. `-NoRecurse` with `-ExcludeFile` collects nothing

Again no metacharacter anywhere. `Classes` holds `A.ps1` and `C.Tests.ps1`, `Classes\Sub` holds
`D.ps1`:

```powershell
-IncludePath 'Classes'                                         # 3 components
-IncludePath 'Classes' -ExcludeFile '*.Tests.ps1'              # 2 components
-IncludePath 'Classes' -NoRecurse                              # 2 components
-IncludePath 'Classes' -NoRecurse -ExcludeFile '*.Tests.ps1'   # 0 components
```

```text
WARNING: ClassCollector with Key 'CLASSES': no classes found - inserting fallback comment
```

Either switch alone works; together they return nothing. The cause is the form of the call:
`Get-ChildItem -Path <directory> -File -Exclude <pattern>` without `-Recurse` yields nothing at all,
measured both inside a bracketed path and in an ordinary one. Appending `\*` to the directory makes
the same call return the expected file. The only signal is the generic "no classes found" warning
and a placeholder comment in the output.

### 4. A project in a bracketed directory cannot be configured

`New-PSScriptBuilderProject -Name 'App[1]'` creates the project correctly — directory, sources,
configuration and release files are all written. Nothing afterwards can read it:

```text
Configuration file '…\App[1]\psscriptbuilder.config.json' does not exist
```

The file is there. All six configuration and release cmdlets stop with this one message:
`Get-PSScriptBuilderConfiguration`, `Get-PSScriptBuilderReleaseData`,
`Test-PSScriptBuilderReleaseData`, `Get-PSScriptBuilderBumpConfiguration`,
`Test-PSScriptBuilderBumpConfiguration` and `Update-PSScriptBuilderBumpFiles`. None of them reaches
its own files, because the configuration is read first.

### 5. A configured path with a metacharacter

The project root is ordinary; the configuration points into `build\Rel[1]`, and the files are
measurably there:

```text
Failed to load release file '…\Plain\build\Rel[1]\psscriptbuilder.releasedata.json'
    because it does not exist
Failed to load bump configuration '…\Plain\build\Rel[1]\psscriptbuilder.bumpconfig.json'
    because it does not exist
```

With the bump configuration at an ordinary location and only the bump file under `build\Tmpl[1]`:

```text
Failed to process bump file '…\Plain\build\Tmpl[1]\Plain.ps1.template': … because it does not exist
```

Three file managers, five call sites, one failure: a path that exists is reported as missing.

### 6. A collector directory with brackets, nothing alike beside it

```powershell
New-PSScriptBuilderCollector -Type Class -CollectionKey 'CLASSES' -IncludePath '…\Proj\src[1]'
```

```text
WARNING: IncludePath does not exist: …\Proj\src[1]
Build failed. … Error: Path not found: …\Proj\src[1] (original: …\Proj\src[1])
```

The directory exists. The warning appears while the collector is created, the build stops later.

### 7. The same collector, with `src1` beside it

```text
WARNING: ClassCollector with Key 'CLASSES': no classes found - inserting fallback comment
build completed, components: 0
output file exists: True
output size: 46 characters
contains MyClass: False
contains Foreign: False
contains placeholder comment: True
```

No warning at creation this time, no error, a build that runs to the end and writes a file with
none of the project's classes in it. `Get-ChildItem -Path` matches the neighbouring directory
`src1`, and `-File` then discards it, so nothing is left — neither the project's own class nor the
neighbour's. What the file carries is `# No classes for collector: CLASSES`.

This is the costliest arrangement, because the only signals are a warning and a comment in the
output, and an unattended run reads neither. It is not silent — but it is quiet enough.

### 8. The output file in a bracketed directory

```text
Build failed. Error: Script building failed. Error: File not found: …\Proj\out[1]\o.psm1
output file exists: True
output size: 46 characters
```

The build writes the file, then fails reading it back for the result report. The file survives, the
run is reported as failed.

### 9. A file name with brackets at `-IncludeFile`

```text
WARNING: IncludeFile does not exist: src\App[1].ps1
Build failed. … Error: File not found: …\Proj\src\App[1].ps1 (original: src\App[1].ps1)
```

The file is there, and the value names it exactly. Both the warning and the error come from
`Test-Path -Path` and `Get-Item -Path`, which read `[1]` as a character class.

### 10. A wildcard at a `…Path` parameter

```powershell
-IncludePath 'src\*'                      # Failed to create collector. … Illegal characters…
-IncludePath 'src' -ExcludePath 'src\*'   # the same, at build time
```

On Windows PowerShell 5.1 both fail with the .NET exception from case 2, which names neither
parameter nor value. **On PowerShell 7 both succeed**: the value is resolved as a pattern and the
files are collected. The same call therefore crashes on one supported version and works on the
other. Measured, `-IncludePath 'src'` collects everything below `src` anyway, because recursion is
on by default, so nothing is lost by refusing the wildcard — only the diagnosis is missing today.

### 11. A file at `-IncludePath` warns and works anyway

```powershell
-IncludePath 'src\One.ps1'   # a file, not a directory
```

```text
WARNING: IncludePath does not exist: src\One.ps1
build completed, components: 1
```

The cmdlet checks for a directory and warns; the collection checks only that *something* is there
and collects the file. One of the two is wrong, and the caller is told the path does not exist
while it is being used.

### What the eleven cases have in common

The platform decides which characters a name can contain, and that settles what the module may
interpret. Measured on this system: `star*.ps1`, `quest?.ps1` and `dirstar*` cannot be created at
all, while `brack[1].ps1`, `curly{1}.ps1`, `paren(1).ps1` and `dirbrack[1]` can.
`[System.IO.Path]::GetInvalidFileNameChars()` lists `*` and `?`; it does not list `[` or `]`.

From that, three causes:

- **An ambiguity decided the wrong way.** `[` and `]` are legal in a name, so a value containing
  them can always be a real path — and it is one in every case here. `Test-Path -Path`,
  `Get-ChildItem -Path` and `Get-Item -Path` nonetheless read it as a pattern. Cases 1, 4, 5, 6, 7,
  8 and 9. Mostly it is a guard that fails while the operation behind it would have worked; in case
  1 that operation is literal already, which is why the fix is small and the damage large. In case 7
  it is the enumeration itself that matches the wrong directory.
- **A directory enumerated in a form that does not list its files.**
  `Get-ChildItem -Path <directory> -Exclude <pattern>` returns nothing unless `-Recurse` is set or
  `\*` is appended. Case 3, which has nothing to do with metacharacters.
- **A value that cannot be a path, rejected without a diagnosis.** `*` and `?` cannot occur in a
  name, so a value containing them is either a pattern or a mistake — never a path. Where the module
  joins it to the project root it passes `[Path]::GetFullPath()`, which rejects those two characters
  and raises a .NET exception that names neither parameter, value nor reason. Cases 2 and 10 — and
  the reason case 2 works when the value is absolute, since `GetFullPath` is then never called.

The first makes existing things invisible, the second drops files without saying so, the third
fails without explaining itself.

### Why thirteen classes made the same mistake

The module already centralizes file access: `PSScriptBuilderFileIOHelper` reads, writes and hashes,
and `PSScriptBuilderFileSystemHelper` creates directories and computes paths. Measured in `src`,
that layer is used 39 times and bypassed twice. Everything it offers is literal by construction,
because it works with `[File]` and `[Directory]`.

One operation is missing from it: *does this path exist*. That is the one every class had to build
for itself, and all of them built it the same way, with `Test-Path -Path`. The defect is not
thirteen independent oversights but the predictable consequence of a gap in an otherwise
consistently used layer.

## Design Decision

1. **A value is read as it stands wherever it can be a path.** `[`, `]`, `{`, `}`, `(` and `)` are
   name characters, so nothing in the module may interpret them — not in a parameter, not in
   `psscriptbuilder.config.json`, not in the bump configuration.
2. **Existence is asked of the helper layer, not of a cmdlet.** The layer that already owns file
   access gains `FileExists` and `DirectoryExists`; no class asks `Test-Path` on its own.
3. **A `…Path` value names a directory, and nothing else.** `-IncludePath` and `-ExcludePath` are
   checked against a directory at every site, so a file passed there fails instead of being
   collected with a warning that contradicts the result. A single file is what `-IncludeFile` is
   for.
4. **A directory is enumerated in the one form that lists its files**, with the caller's name
   filters still in effect.
5. **A pattern is resolved only where patterns are allowed** — at `-IncludeFile`, and nowhere else.
   A wildcard in a `…Path` value is refused **on both versions alike**, although PowerShell 7
   currently accepts it: the manifest promises `Desktop` and `Core`, the module branches on the
   version nowhere in `src`, and a behavior that crashes on one supported version is no contract.
   The helper layer does not know patterns at all: a path value carrying `*` or `?` is rejected
   there with a message naming the parameter, the value and the reason, because no file or directory
   can be named that way.
6. **A pattern that matches nothing is not an error; a named file that is missing is.** This is the
   platform's own rule, measured across four cmdlets: `Get-ChildItem`, `Get-Item`, `-Include` and
   `Remove-Item` all return nothing for a pattern without matches and all fail with "Cannot find
   path … because it does not exist" for a literal name that is absent.

## Detailed Design

### Rule A — existence moves into the helper layer

`PSScriptBuilderFileSystemHelper` gains two methods:

```powershell
static [bool] FileExists([string] $path)        # [File]::Exists($path)
static [bool] DirectoryExists([string] $path)   # [Directory]::Exists($path)
```

Both are literal by construction, exactly as `File.Exists` and `Directory.Exists` are in .NET, where
a caller who wants patterns uses `Directory.EnumerateFiles(path, searchPattern)` and the pattern is
a separate parameter that never hides inside the path. The thirteen call sites ask the helper
instead of `Test-Path`; their messages stay where they are, only the question moves.

Three of the call sites need no replacement at all. They look like this:

```powershell
if ($directory -and -not (Test-Path -Path $directory -PathType Container)) {
    [PSScriptBuilderFileSystemHelper]::EnsureDirectoryExists($directory)
}
```

`EnsureDirectoryExists` already does nothing when the directory is there, and it works through
`[Directory]::CreateDirectory`. The guard in front of it is redundant *and* is the defect; it is
deleted rather than corrected. What goes with it is the verbose line "Created directory", which the
helper takes over if it is worth keeping.

The include path is checked with `DirectoryExists`, not merely literally: that is what closes case
11, where the collection accepted a file the cmdlet had just warned about.

Fixes cases 1, 4, 5, 6, 8, 9 and 11. Case 1 is one guard: the check in
`PSScriptBuilderAstEngine.ParseFile` becomes `FileExists`, and the `[File]::ReadAllText` behind it
already does the right thing. Case 9 needs nothing else either — once the check is literal, a value
naming `App[1].ps1` finds `App[1].ps1`, and the test that classifies the entry can stay as it is,
because `[` is not a metacharacter in a name.

**Why the method and not `-LiteralPath` at each site.** Writing `-LiteralPath` thirteen times fixes
today's defect and leaves `Test-Path -Path` the shorter way to write the next one. A method that
cannot interpret removes the choice, which is why the layer exists for reading and writing already.

### Rule B — files are enumerated

Use `-Path` with the directory escaped **and `\*` appended**, `-Recurse` as the collector requires,
and the caller's filters untouched — never `-LiteralPath`.

These are two separate steps against two separate problems. Measured, with `App[1]` holding
`One.ps1` and `Two.ps1` and a neighbouring directory `App1` holding `Foreign.ps1`:

```text
-Path 'App[1]'          (as written)     0 files
-Path 'App`[1`]'        (escaped)        0 files
-Path 'App`[1`]\*'      (escaped + \*)   2 files   One.ps1, Two.ps1
```

**Escaping corrects the target.** `-Path` reads its value as a pattern, in which `App[1]` means "App
followed by one character out of {1}" — that is `App1`, the neighbour. Escaping turns the brackets
back into ordinary characters, so the value points at the directory that was meant.

**Appending `\*` corrects the level.** An escaped value is still a pattern, and a pattern returns
what matches it: the directory itself. `-File` discards directories, so the result is empty again.
Only `\*` says "everything *inside* this directory" instead of "this directory".

These numbers are Windows PowerShell 5.1. On PowerShell 7 an escaped directory without `\*` does
list its contents, so the second line there returns both files — but the form with `\*` returns the
same correct counts on both versions, which is why it is the one to use.

Why this never showed up before: for an ordinary directory all three forms return both files. A
path without metacharacters is not a pattern, and then `-Path` lists the contents — the meaning of
`-Path` only changes once a pattern is involved. That is why the defect stayed invisible until a
project carried a bracket in a name.

Measured on one fixture: `Classes` holding `A.ps1` and `C.Tests.ps1`, `Classes\Sub` holding `D.ps1`
and `E.Tests.ps1`, inside a directory named `App[1]`. Correct is 2 files without recursion and 4
with, or 1 and 2 when `-Exclude '*.Tests.ps1'` applies:

| Call | without `-Recurse` | with `-Recurse` |
|---|---|---|
| `-Path <escaped>` | 0 of 2 | 4 of 4 |
| `-Path <escaped> -Exclude` | 0 of 1 | 2 of 2 |
| `-Path <escaped>\*` | 2 of 2 | 4 of 4 |
| `-Path <escaped>\* -Exclude` | 1 of 1 | 2 of 2 |
| `-LiteralPath <dir> -Exclude` | 2 of 1 | 4 of 2 |

Only the third and fourth rows are right throughout, and they stay right in an ordinary directory,
where the same measurement gives the same four numbers. The first row is the missing `\*` explained
above; the last one is a trap of its own: on Windows PowerShell 5.1 `-LiteralPath` silently ignores
`-Include` and `-Exclude` and returns everything, so a fix that reached for it everywhere would turn
`-ExcludeFile` into a parameter without effect. On PowerShell 7 that same call honours the filter —
one more reason not to build on it, because the form would then behave differently per version.

Appending `\*` also fixes case 3, whose failure needs no metacharacter at all: `-Path <dir>
-Exclude` without `-Recurse` returns nothing in any directory, ordinary or not.

Measured, `[WildcardPattern]::Escape()` returns an ordinary path unchanged, so nothing changes for a
project without metacharacters.

Fixes cases 3 and 7, and the enumeration half of 6.

### Rule C — a pattern is resolved where patterns live, and nowhere else

At `-IncludeFile`, and only there, a value carrying `*` or `?` is a caller pattern: the project root
is escaped, the caller's value is appended unchanged, and `Get-Item -Path` resolves the two
together. That is what already happens for an absolute pattern today, so the relative form stops
being the exception. The value must not pass `[Path]::GetFullPath()`, which rejects those two
characters.

A relative pattern resolves **against the project root, not recursively**: `-IncludeFile '*.ps1'`
finds what lies in the root, `-IncludeFile 'src\*.ps1'` what lies in `src`. Everything below a
directory is what `-IncludePath` is for, where recursion is on by default.

**Everywhere else a wildcard is a mistake, and the helper says so.** This is where the first draft
of this rule was wrong: it put the pattern handling into the general path joining, so a
*configuration* value was treated as a pattern too. Measured on the prototype, `outputPath` set to
`.\build\Out*` then resolved to `…\Plain\.\build\Out*` — normalization skipped along with the
pattern check, an unusable path handed on without a word, where the module fails loudly today. The
helper therefore knows nothing about patterns: it rejects `*` and `?` in a path value with a message
naming the parameter or setting, the value, and that no file or directory can carry those
characters. `-IncludePath 'src\*'` and `-ExcludePath 'src\*'` fail that way at collector creation,
earlier than today.

Fixes cases 2 and 10.

### Rule D — a pattern that matches nothing is not an error

Today an `-IncludeFile` entry that resolves to nothing throws `FileNotFoundException`, whether it
was a name or a pattern. After this RFC the two part ways, following the platform:

| `-IncludeFile` value | matches nothing |
|---|---|
| `src\App.ps1` — a name | error, as today |
| `*.ps1`, `src\*.ps1` — a pattern | no error, nothing collected |

Measured with `-ErrorAction Stop`, `Get-ChildItem`, `Get-Item`, `-Include` and `Remove-Item` all
behave this way: a pattern without matches returns nothing quietly, a literal name that is absent
fails with "Cannot find path … because it does not exist". A module whose users know those cmdlets
should not invent a third rule.

This is not a silent result: when a collector ends up with nothing, the existing "no classes found"
warning and the placeholder comment in the output still appear. What it buys is the optional
pattern — `-IncludeFile '*.Generated.ps1'` in a fresh checkout no longer breaks the build.

### Which rule applies where

**Rule A** — `PSScriptBuilderConfigLoader` (the configuration file),
`PSScriptBuilderConfiguration.CreateDefault` (the project root),
`PSScriptBuilderReleaseDataFileManager` (two sites),
`PSScriptBuilderBumpConfigFileManager` (three sites),
`PSScriptBuilderBumpFilesProcessor` (each bump file),
`PSScriptBuilderReleaseManagementOrchestrator` (the file it checks before writing),
`PSScriptBuilderAstEngine` (the file it parses), `PSScriptBuilderBuildOrchestrator` (the output file
it reads back), `PSScriptBuilderCollectorBase` (the include path's existence check and the include
file it resolves) and `New-PSScriptBuilderCollector` (both of its validations) — these ask the
helper. `PSScriptBuilderBuildResultExporter`, `PSScriptBuilderOutputFileManager` and
`PSScriptBuilderTemplateGenerator` lose their guard entirely.

**Rule B** — `PSScriptBuilderCollectorBase` where it enumerates an include path.

**Rule C** — `PSScriptBuilderCollectorBase` and `New-PSScriptBuilderCollector` where an include file
is joined to the project root, and `PSScriptBuilderFileSystemHelper` where any other path value is,
which is where a wildcard is refused.

**Rule D** — `PSScriptBuilderCollectorBase` where an include file resolves to nothing.

**Unchanged:** `-ExcludeFile` is matched against names by `Get-ChildItem -Exclude` and needs no
change once the enumeration is shaped correctly. `-ExcludePath` is a prefix comparison on the
resolved string and was never interpreted; case 10 is its only defect. `-EntryPoint` of
`Find-PSScriptBuilderUnusedComponent` matches component names, not paths. The test that decides
whether an `-IncludeFile` entry is a specific file, `-match '[*?]'`, is correct as it stands: `*`
and `?` cannot be part of a name, `[` and `]` can.

### What a caller can express afterwards

| Value | Meaning |
|---|---|
| `-IncludePath 'src[1]'` | the directory of that name, used as it stands, recursive by default |
| `-IncludeFile 'src\App[1].ps1'` | the file of that name, used as it stands; an error if absent |
| `-IncludeFile '*.ps1'` | a pattern over the project root, not recursive; empty is allowed |
| `-IncludeFile 'src\*.ps1'` | a pattern over `src`, not recursive; empty is allowed |
| `-IncludePath 'src\*'` | rejected, naming the parameter and the value |

A caller who wants every `.ps1` below a bracketed directory writes the directory at `-IncludePath`
and the file pattern at `-ExcludeFile`; neither needs escaping.

### An independent defect in the same method

While rules B and D rewrite `GetFilesToProcess`, one more defect in it is fixed. It has nothing to
do with metacharacters, and it is carried here because this RFC opens that method anyway; it gets
its own `Fixed` entry.

Measured on both versions, with the released module:

| `-ExcludePath` | files left after the filter | `-IncludeFile` entries | result |
|---|---|---|---|
| set | **1** | **at least 1** | **the build fails** |
| set | 1 | none | works |
| set | 2 or more | any | works |
| not set | any | any | works |

```text
Build failed. … Error: Failed to execute collector ClassCollector with key 'CLASSES'.
Error: Method invocation failed because [System.IO.FileInfo] does not contain a method named
'op_Addition'.
```

The cause is one line: the exclude filter assigns the result of a pipeline back to the list, and
`Where-Object` returns the element itself when exactly one survives, not a list of one. The next
statement appends the explicitly named files to it, and PowerShell looks for an addition on
`FileInfo`. Wrapping the pipeline in `@(…)` keeps the list a list.

The case needs no unusual input: a project where one file is left after an exclusion — a small
module, a generous `-ExcludePath`, or a project early in its life — together with one
`-IncludeFile`. Without `-ExcludePath` it cannot occur, because the list keeps its type. The
message names neither parameter, nor file, nor any connection to the collector.

## Backwards Compatibility

- **A project in a path containing `[` or `]` works, and so does a source file named that way.**
  That is the point.
- **`-IncludeFile` with a relative pattern starts working.** A script that worked around the defect
  by passing an absolute pattern keeps working unchanged.
- **`-IncludeFile` naming a file with brackets starts finding it.** A caller who worked around the
  defect by renaming the file is unaffected.
- **`-NoRecurse` together with `-ExcludeFile` starts collecting.** A build that produced an empty
  component set this way now produces the files it should always have produced — and that is a
  changed output for anyone who, knowingly or not, relied on the empty result.
- **An `-IncludeFile` pattern that matches nothing stops failing the build.** A script that relied
  on that failure as a check — "the generated files must exist" — loses it and has to assert on the
  component count instead. The same value spelled as a name still fails.
- **A file passed to `-IncludePath` now fails.** It works today, but only alongside a warning saying
  the path does not exist; the remedy is `-IncludeFile`, which is what that value always was.
- **Two false warnings and the false "does not exist" errors disappear.** A script running with
  `-WarningAction Stop` that fails today will now proceed.
- **A wildcard in a path value still fails,** now with a message that names the parameter or
  setting and the value instead of a .NET exception, and for `-ExcludePath` it fails at collector
  creation rather than at build time. **On PowerShell 7 this is a change in outcome**, not only in
  wording: `-IncludePath 'src\*'` collects there today and will be refused afterwards. The remedy is
  the directory itself, which collects the same files because recursion is on by default.
- **`-ExcludeFile` and `-EntryPoint` behave as before** for every value that works today; the
  exception is the `-NoRecurse` combination named above.
- **`-ExcludePath` together with `-IncludeFile` stops breaking the build** where exactly one file
  survives the exclusion. That call fails today with a message about `op_Addition`; afterwards it
  collects, which is a changed outcome for anyone who has worked around it.
- **Error messages change in content, not in kind:** a file that is really missing is still
  reported, now for the right file and in the module's own wording.

## Rationale and Alternatives

**Why the platform settles the split, not a convention.** Which characters a name may contain is not
a matter of taste: `[System.IO.Path]::GetInvalidFileNameChars()` lists `*` and `?` and does not list
`[` or `]`, and the measurement confirms it — a file named `brack[1].ps1` can be created, one named
`star*.ps1` cannot. So a value with brackets is a path and must not be interpreted, and a value with
a wildcard is never a path.

**Why the empty pattern is not an error.** The same platform answers that too, and consistently:
measured across `Get-ChildItem`, `Get-Item`, `-Include` and `-Remove-Item`, a pattern without
matches returns nothing and a missing literal name fails. Users of this module know those cmdlets;
a module that inverted the rule would be the surprising one.

**How comparable tools separate the two.** robocopy excludes directories by name or path (`/XD`) and
files by name, path or wildcard (`/XF`), as its own help states — the split this RFC arrives at.
tsconfig keeps a literal `files` list beside glob-based `include` and `exclude`. PowerShell itself
offers `-LiteralPath` beside `-Path`. grep is sometimes cited here but does not fit: its own help
says `--exclude-dir=PATTERN`, so both of its switches take patterns and the distinction is files
against directories. MSBuild goes the other way and treats everything as a pattern.

**Why not `-LiteralPath` everywhere.** Measured, it ignores `-Include` and `-Exclude`, which would
make `-ExcludeFile` a parameter without effect. Escaping the module's own part is the one mechanism
PowerShell offers for a fixed prefix with a caller-supplied tail.

**Why not make `-IncludePath` a pattern parameter,** as MSBuild's `Include` is? That is a feature
with its own documentation, not the repair of a defect, and it would require changing `-ExcludePath`
as well or leave the pair inconsistent in the other direction. A possible future decision; not this
one.

**Why no literal counterpart parameter.** After this RFC a literal file name needs no special
parameter, because `-IncludeFile` reads brackets as what they are. The only values that cannot be
expressed are names containing `*` or `?`, which this platform cannot create.

## Scope

**In scope:** `PSScriptBuilderFileSystemHelper` (the two new methods and the wildcard refusal),
`PSScriptBuilderConfigLoader`, `PSScriptBuilderConfiguration`,
`PSScriptBuilderReleaseDataFileManager`, `PSScriptBuilderBumpConfigFileManager`,
`PSScriptBuilderBumpFilesProcessor`, `PSScriptBuilderReleaseManagementOrchestrator`,
`PSScriptBuilderAstEngine`, `PSScriptBuilderBuildResultExporter`,
`PSScriptBuilderOutputFileManager`, `PSScriptBuilderTemplateGenerator`,
`PSScriptBuilderBuildOrchestrator`, `PSScriptBuilderCollectorBase` (including the exclude filter
that loses its list type), `New-PSScriptBuilderCollector`,
`Add-PSScriptBuilderCollector`; their tests; `CHANGELOG.md`; this RFC. The documentation of the
collector parameters follows the implemented behavior.

**Out of scope:** making `-IncludePath` a pattern parameter; the lifetime of the project context and
the base against which a relative path is resolved, both RFC 0029.

## Relationship to Other RFCs

RFC 0028 made `Set-PSScriptBuilderProjectRoot -Path` literal and shipped it as a `Fixed` entry in a
minor release; `CHANGELOG.md` describes it as "`-Path` was read as a wildcard pattern, so a
directory such as `App[1]` silently set the project root to `App1` … The path is now used as it
is." This RFC is the same change for the remaining paths and is therefore a fix as well, on the 1.x
line — in 1.4.0 if it is ready in time, in the next minor release otherwise. The reason is
reachability, not severity: a user pinned to `1.*` never receives a fix that ships only in a major.

Neither RFC depends on the other, but they touch the same code and have to be sequenced. RFC 0029
deletes `GetProjectRootedPath` and moves the joining of root and value into the cmdlets; it leaves
the `Test-Path`, `Get-ChildItem` and `Get-Item` calls where they are. Rules A, B and D therefore
apply unchanged after that move — rule A even gains, because the helper class survives and keeps its
two new methods. Rule C concerns the joining itself, which RFC 0029 relocates without saying where
the normalization of a relative value then happens; that document does not mention `GetFullPath` at
all. Wherever the joining ends up, rule C applies there. If RFC 0029 lands first, which its release
planning assumes, the sites named above are to be found in their new shape.

## Test Plan

- **The eleven cases as regression tests.** Case 1 with an ordinary project and one file named
  `App[1].ps1`; case 3 with all four combinations of `-NoRecurse` and `-ExcludeFile`; cases 6, 7 and
  8 in the three arrangements that distinguish them: no matching neighbour, a neighbour with the
  same substructure, and an output path under the bracketed directory.
- **The enumeration matrix** from rule B over its own fixture: the five call forms, with and without
  recursion, in a bracketed and in an ordinary directory, with the numbers the table gives.
- **The name characters:** a file and a directory named with `[`, `]`, `{`, `}`, `(` and `)` are
  reached literally; a value containing `*` or `?` is rejected in every path value, including a
  configured one such as `outputPath`, with a message naming the value.
- **The empty pattern:** `-IncludeFile '*.Generated.ps1'` without a match collects nothing and does
  not fail; `-IncludeFile 'src\Missing.ps1'` still fails.
- **The relative pattern:** `-IncludeFile '*.ps1'` matches the project root only, `'src\*.ps1'`
  matches `src` only, in a project root with and without a metacharacter; the absolute form keeps
  working.
- **The filters keep working:** `-ExcludeFile '*.Tests.ps1'` against a project root that contains a
  metacharacter — the case a careless fix with `-LiteralPath` would break by ignoring the exclusion.
- **Recursion stays as documented:** `-IncludePath 'src'` collects from every subdirectory,
  `-NoRecurse` only from the directory itself — with and without `-ExcludeFile`.
- **A `…Path` value names a directory:** a file at `-IncludePath` fails, and the message does not
  contradict what the collector then does.
- **`-ExcludePath` is unchanged**, including its precedence over `-IncludePath`.
- **The exclude filter keeps its list type:** `-ExcludePath` leaving exactly one file, together with
  one and with two `-IncludeFile` entries, collects instead of failing — and the same four
  combinations that work today still work.
- **Proof that the new tests can find the defect:** every test is shown to fail against the current
  code before the fix is applied. Appendix B records that this already holds for the prototype.

## Unresolved Questions

None. The decision, its scope and its release line are settled; what remains is implementation.

## Appendix A: How the cases were measured

**Environment.** Windows PowerShell 5.1.26100.9711 and PowerShell 7.6.10 on Windows 11, the latter
installed from the MSI into `C:\Program Files\PowerShell\7`. The module was loaded with
`using module build\Output\PSScriptBuilder.psd1`, and the module output was the one built in commit
`1561cd0d`; no source file had changed since, verified against the commit range and the working
tree, and three of the call sites named above were found verbatim in the built `psm1`. Every case
was run on both versions. Where they differ, the case says so.

**Language of the messages.** The runs were made with `CurrentUICulture` and `CurrentCulture` set to
`en-US`, because the messages that do not come from the module are localized: the same exception
reads `Illegales Zeichen im Pfad.` on a German system, which is what the machine these measurements
were taken on reports by default. Everything the module itself writes is English in any case. The
`WARNING:` prefix in the transcripts is how the console renders a warning — the `WarningRecord`
carries only the text after it.

**Common arrangement.** Each case built its own temporary directory tree, set the project root with
`Set-PSScriptBuilderProjectRoot` — literal since RFC 0028, so the root itself is never the variable
under test — ran one cmdlet, and captured output and warnings through `3>&1` filtered by
`WarningRecord`, because `-WarningVariable` does not reliably capture warnings from inside class
methods (see `internal/test-strategy.md`, Known Constraints). The tree was removed afterwards with
`-LiteralPath`.

**Arrangements the cases do not state themselves.**

- **Case 2** — an ordinary project root, `src` holding `Normal.ps1` and `Zweite.ps1`, two classes;
  hence two components when the pattern resolves. The absolute form was the same pattern with the
  project root spelled out.
- **Case 4** — `New-PSScriptBuilderProject -Name 'App[1]' -Path <temp> -IncludeReleaseManagement`,
  nothing else; the scaffolding wrote `build`, `src`, `psscriptbuilder.config.json`,
  `Build-App[1].ps1` and `Release-App[1].ps1`, and no directory named `App1` existed beside it.
- **Case 5** — an ordinary project root named `Plain`, with `build\Release` renamed to
  `build\Rel[1]` and `build\Templates` to `build\Tmpl[1]`, the configuration rewritten through
  `ConvertTo-Json` so the escapes were certain, and the files confirmed present with
  `[File]::Exists` before each call. The bump file was measured separately, with the bump
  configuration left at its ordinary location, because otherwise the run stops before reaching it.
- **Cases 6, 7 and 8** — the same project with `src[1]\MyClass.ps1`; for cases 7 and 8 additionally
  `src1\Foreign.ps1`, the neighbour that matches the pattern. Case 7 wrote its output outside the
  bracketed directory, case 8 into `out[1]`. These three differ only in that arrangement, which is
  what makes one of them warn, one fail and one run to the end.
- **Case 3 and the rule B matrix** — `Classes\A.ps1`, `Classes\C.Tests.ps1`, `Classes\Sub\D.ps1`
  and, for the matrix, `Classes\Sub\E.Tests.ps1`, measured through the module in all four
  combinations of `-NoRecurse` and `-ExcludeFile` and against `Get-ChildItem` directly in all five
  call forms, each in a bracketed and an ordinary directory.
- **Case 10** — the project of case 1, with the wildcard passed at `-IncludePath` and at
  `-ExcludePath` in turn.
- **The name characters** — `[File]::WriteAllText` and `[Directory]::CreateDirectory` were called
  with names containing `*`, `?`, `[`, `{` and `(`, and the result compared with
  `[System.IO.Path]::GetInvalidFileNameChars()`.
- **Case 11** — the project of case 1 with `-IncludePath` pointing at `src\One.ps1`, measured
  against the unchanged module: the warning appears at creation and the build collects the file.
- **The platform's rule for an empty pattern** — `Get-ChildItem`, `Get-Item`, `-Include` and
  `Remove-Item`, each with a pattern that matches nothing and with a literal name that is absent,
  all four under `-ErrorAction Stop`.

## Appendix B: How the solution was measured

The rules were not only reasoned about. A copy of the built module in a scratch directory — never
the repository — was patched to follow them, in fifteen replacements, each verified to hit exactly
the expected number of sites, with no `Test-Path -Path` left afterwards. Twenty-one checks were then
run against the patched copy and against the unchanged module, each with its expected value fixed in
advance:

| | PowerShell 5.1 | PowerShell 7.6.10 |
|---|---|---|
| patched copy | 21 passed, 0 failed | 21 passed, 0 failed |
| unchanged module | 4 passed, 17 failed | 5 passed, 16 failed |

The one case that passes today on PowerShell 7 but not on 5.1 is the relative pattern of case 2.
The four that pass in both runs are the controls — `-IncludePath 'Classes'`, `-ExcludeFile`,
`-NoRecurse` alone and `-ExcludePath 'Classes\Sub'` — which show that the fix changes nothing that
works today. The seventeen others fail against the current code and pass against the prototype,
which is the proof the test plan asks for.

Two things the prototype does **not** establish. It patched each call site individually rather than
moving the check into the helper layer, so it measures the semantics of rules A to C, not the
structure rule A prescribes. And it still throws on an empty pattern, because rule D was decided
after the run; that rule rests on the platform measurement instead.

The prototype also corrected the design once. Its first version put the pattern handling into the
general path joining, which made a configured `outputPath` of `.\build\Out*` resolve to
`…\Plain\.\build\Out*` and be passed on silently — worse than the loud failure it replaced. That is
why rule C now lives at `-IncludeFile` alone.

## Revision Log

- 2026-11-11 — Draft, written from a description of the mechanism and a list of claims, three of
  which were refuted while writing. Superseded by the entries below.
- 2026-11-12 — Rewritten from measurement rather than from reasoning. Every case was run through the
  built module before it was written down, under the conditions in Appendix A. The earlier draft's
  case list did not survive this intact, and the three worst defects were not in it: a source file
  named `App[1].ps1` breaks every build of an ordinary project; `-IncludeFile '*.ps1'` fails
  whenever written relatively and works only as an absolute path; and `-NoRecurse` together with
  `-ExcludeFile` collects nothing, with no metacharacter involved. Two claims of the earlier draft
  were refuted outright: that `-IncludePath 'src\*'` collects what `-IncludePath 'src'` collects —
  it fails when the collector is created, and `-ExcludePath 'src\*'` fails at build time, both with
  the same .NET message — and that a bracketed project root yields five messages, when all six
  configuration and release cmdlets stop at the configuration file and never reach their own.
- 2026-11-12 — Second revision, after measuring which characters a name can contain at all. This
  replaced the document's organising idea: the split is not "which parameter carries the value" but
  "which characters the platform allows in a name". The rule requiring the pattern test to recognise
  `[` and `]` was deleted — it would have made `-IncludeFile 'App[1].ps1'` a pattern that never
  finds the file of that name. Cases 2 and 10 changed character: a value containing `*` or `?` can
  name nothing on this platform, so what fails there is the diagnosis, not the path handling.
  Corrections from the same pass: the rule B table had mixed measurements from two fixtures; case 5
  names three file managers, not four; the claim that three of the four collector parameters keep
  their promise was dropped; grep was removed as an example, because its own help says
  `--exclude-dir=PATTERN`.
- 2026-11-13 — Third revision, after building the prototype (Appendix B) and after the decision that
  the module's own documentation carries no weight in a design question. Three changes:
  - **Rule A became a structural change.** Measured, the file-access layer is used 39 times in `src`
    and bypassed twice, but it offers no existence check — which is exactly the operation all
    thirteen classes built for themselves, all of them with `Test-Path -Path`. The layer gains
    `FileExists` and `DirectoryExists`; three call sites lose their guard entirely, because it sits
    in front of an `EnsureDirectoryExists` that is already idempotent and literal.
  - **Rule C moved.** The prototype's first version handled patterns in the general path joining and
    thereby mangled a configured `outputPath` of `.\build\Out*` into a silent non-path. Pattern
    resolution now exists only at `-IncludeFile`; every other path value refuses a wildcard with a
    diagnosis.
  - **Rule D was added:** a pattern that matches nothing is not an error, a named file that is
    missing is. Measured across four cmdlets, that is the platform's own rule, and following it also
    makes an optional pattern such as `*.Generated.ps1` usable.
  Also recorded: a relative pattern resolves against the project root and is not recursive, which
  the earlier wording left open and which an expectation in the prototype run got wrong at first.

- 2026-11-14 — Fourth revision, after installing PowerShell 7.6.10 and repeating every measurement
  there. The claim that the document says nothing about PowerShell 7 is gone: all eleven cases and
  the prototype were run on both versions. Three differences in today's behavior came out, and one
  of them needed a decision:
  - **`GetFullPath` does not reject `*` and `?` on PowerShell 7.** Case 2 therefore does not exist
    there — a relative pattern at `-IncludeFile` already works — and case 10 does not fail there
    either: `-IncludePath 'src\*'` is resolved as a pattern and collects.
  - **Decided: the wildcard is refused on both versions alike.** The module's manifest promises
    `Desktop` and `Core`, `src` contains no version branch at all, and a behavior that crashes on
    one supported version is a coincidence of the implementation, not a contract. The alternative —
    making `-IncludePath` a pattern parameter on both — is a feature, and it would need building on
    5.1 where the platform refuses such values.
  - **`-LiteralPath` honours `-Include`/`-Exclude` on PowerShell 7** but ignores them on 5.1, and an
    escaped directory without `\*` lists its contents on 7 but not on 5.1. Neither changes rule B:
    the chosen form returns the same correct counts on both versions, which is now its strongest
    argument.
  The prototype passes 21 of 21 on both versions; the unchanged module passes 4 on 5.1 and 5 on 7.
# RFC 0029: The Project Context Per Command Call

- **Status:** Draft
- **Type:** Fix and design decision
- **Created:** 2026-11-06
- **Branch:** development

## Summary

Release management kept the configuration it loaded first for the rest of the session, and the
project root found by auto-discovery was kept for the session as well. After switching to another
project — explicitly with `Set-PSScriptBuilderProjectRoot`, or with `Set-Location` — the release
cmdlets silently updated the previous project and wrote its version into the new project's files,
and `New-PSScriptBuilderConfiguration -Force` overwrote the previous project's configuration. This
RFC states the invariant the code violated, has each command determine its project once and pass
the configuration read from it, gives every path exactly one base it is resolved against, exports
`Get-PSScriptBuilderProjectRoot` and `Clear-PSScriptBuilderProjectRoot`, and deprecates
`$Global:PSScriptBuilderProjectRoot`. Nothing is cached across calls, no class resolves a path of
its own any more, and the two free path helpers are gone — so the invariant is enforced by the code
rather than by a rule.

## Motivation

All nine findings were measured on Windows PowerShell 5.1.26100.9711 and on PowerShell 7.6.10, each
through the built module in one session with two projects; both versions behave identically in every
one of them. Both caches exist since v1.0.0 (2026-04-14) and therefore affect every released
version.

1. **Release management uses the first project of the session.** The orchestrator takes the
   configuration from `[PSScriptBuilderConfiguration]::GetCurrent()`, a singleton loaded once and
   never invalidated outside of tests. With projects A and B in one session:
   - Root A, `Update-PSScriptBuilderReleaseData -Patch`: A 0.1.0 → 0.1.1.
   - Root B, `-Minor`: **A 0.1.1 → 0.2.0, B stays 0.1.0**; `Get-PSScriptBuilderReleaseData` with
     root B returns A's data.
   - The shipped examples reproduce it: `11-mixed-bump-mode\Run-Example.ps1`, then
     `12-full-workflow\Run-Example.ps1` in one session (on copies) left example 11 at 1.0.2 and
     example 12 at 1.0.0, although both scripts call `Set-PSScriptBuilderProjectRoot -Path
     $PSScriptRoot` and `using module` does not reload the module.
2. **Mixed state in bump files.** The data file and bump configuration paths are resolved when the
   configuration is first loaded, the bump file paths when bumping. With the same bump
   configuration in A and B, root A `-Patch` and bump, then root B `-Minor` and bump left A's data
   at 0.2.0 with A's file at 0.1.1, and B's data at 0.1.0 with B's file at 0.2.0 — A's version, in
   B's file, through A's bump configuration. No warning, no error.
3. **Configuration changes are ignored, and the query confirms them anyway.** After changing
   `release.dataFile` during the session, `-Patch` still updated the file from the first load.
   Measured in the same session: `Get-PSScriptBuilderConfiguration` reports the **new** path while
   `Update-PSScriptBuilderReleaseData -Minor` moves the **old** file from 0.1.1 to 0.2.0 and leaves
   the new one at 0.1.0. The two reach the same setting by different routes — the query calls the
   constructor and reads the file, the release cmdlets take the singleton of the first call. A user
   who changes the setting, checks it and then runs the command is told the change applies and
   watches it not apply.
4. **The discovered root is kept for the session.** `Get-PSScriptBuilderProjectRoot` stores it in
   `$Global:PSScriptBuilderProjectRoot`, the variable `Set-PSScriptBuilderProjectRoot` sets, and
   never searches again. Discovered in A, then `Set-Location B` and `-Minor`: A 0.1.1 → 0.2.0,
   B stays 0.1.0. Every command that resolves a project path is affected (derived from the code;
   measured for release management).
5. **`New-PSScriptBuilderConfiguration` overwrites another project's configuration.** Discovered
   in A, then in the empty directory C: without `-Force` the error names
   `…\A\psscriptbuilder.config.json`; with `-Force` A's configuration was reset to the defaults
   (`backupEnabled` `true` → `false`) and C got none. The help promises the root set with
   `Set-PSScriptBuilderProjectRoot`, otherwise the current directory.
6. **The documentation prescribes a workaround that does not work.** `docs/troubleshooting.md`
   ("Wrong configuration loaded", 2026-03-25) describes this symptom and advises calling
   `Set-PSScriptBuilderProjectRoot` at the start of the script — finding 1 shows that this does
   not help. "Bump files not updated" names a different session and a wrong working directory as
   causes; neither applies.
7. **An explicit root applies for the session**, as documented. After running A's build script,
   which sets root A, a release command typed in B's directory still updates A. This is a
   deliberate model (see Rationale) and remains a risk after this RFC.
8. **Empty paths become the project root.** A configuration path is combined with the project
   root, so an empty or missing one names the root itself: without `backupPath`,
   `Build.BackupPath` is the project root, and `-BackupPath $config.Build.BackupPath
   -EnableBackup` writes backups into it; `"outputPath": ""` and `"dataFile": ""` pass the
   validator and become the root as well. The orchestrator's check for an empty data file path
   never applies, because the path is resolved before it; the release cmdlets then fail with
   "release file '…' does not exist" for a directory.
9. **Two rules for the base of a relative path.** Eleven cmdlets resolve a relative path given by
   the caller against the **project root** (`Invoke-PSScriptBuilderBuild`,
   `Watch-PSScriptBuilderProject`, `Compress-PSScriptBuilderScript`,
   `Export-PSScriptBuilderBuildResult`,
   `Export-PSScriptBuilderDependencyGraph`, `Get-PSScriptBuilderSourceCoverage`,
   `Resolve-PSScriptBuilderSourceLocation`, `New-PSScriptBuilderTemplate`,
   `Test-PSScriptBuilderTemplate`, `New-PSScriptBuilderCollector`,
   `Get-PSScriptBuilderTemplateAnalysis`), while
   `Set-PSScriptBuilderProjectRoot` and `New-PSScriptBuilderConfiguration` resolve it against the
   **PowerShell location** since RFC 0028. Both are documented. `cd src;
   Invoke-PSScriptBuilderBuild -OutputPath .\out.psm1` therefore writes to the project root, not
   into `src`, without a hint — while every other PowerShell cmdlet with a `-Path` resolves against
   the location.

**Why no test found it:** `internal/test-strategy.md` prescribes
`[PSScriptBuilderConfiguration]::Reset()` in `BeforeAll` and `AfterAll`, and the example tests run
each example in its own process. The fixture removed the very state whose lifetime the defect
consisted of, so the suite could not observe it (Meszaros, *xUnit Test Patterns*, "Interacting
Tests"). The consequence for this RFC is in the Test Plan: every new test is shown to fail against
the old behavior before it is trusted.

**Damage.** Silent wrong writes since 1.0.0, in every released version up to 1.3.1, triggered by
more than one project in one session. Two different damages: wrong version numbers (findings 1, 2
and 4), reconstructible by comparing the release data file with the bump files; and a lost
configuration (finding 5), destructive and not reconstructible without version control.

## Design Decision: The Contract

### The invariant

> **A call works on at most one project. If it needs one, it determines it once in that call, in
> one place, and every path and every setting that comes from the project derives from that one
> decision. Nothing of it outlives the call.**

"At most one" rather than "exactly one": a command whose paths are all absolute reads nothing from a
project and needs none, and a command that creates a project has none yet. "Comes from the project"
rather than "every path": an absolute path from the caller comes from the caller.

The defect findings are not separate defects. They are ways of violating this one sentence:

| Finding | Part violated |
|---|---|
| 1 | *once in that call* — the configuration comes from the first call of the session |
| 2 | *that one decision* — two roots in one call: A for the data file, B for the bump files |
| 3 | *once in that call* — as 1, visible in the configuration's content |
| 4 | *once in that call* — the root comes from an earlier call |
| 5 | *in one place* — a resolution for an existing project answers a command that creates one |

Finding 7 does not violate it: an explicitly set root is an *input* to the resolution, not something
derived from the project (see Rationale). Finding 9 does not violate it either — it is not a
lifetime defect but a second question, about which base a path has, answered by contract item 2.

### The contract

1. **The invariant above holds for every command.**
2. **Every path has exactly one base, decided by its origin.**
   - A path from a configuration file is resolved against the **project root**.
   - A path given by the caller is resolved against the **PowerShell location**, through
     `PathIntrinsics`, as every PowerShell cmdlet with a `-Path` does — **from 2.0.0 on**.
   - Until then a caller's path keeps the project root as its base: changing it moves where a
     command writes, and SemVer puts such a change in a major release (see "The transition for
     caller paths").
   - No command chooses its own base, and no path is resolved against two bases.
3. **The inputs of the resolution, in this order:** the `-ProjectRoot` of the call, otherwise the
   root set with `Set-PSScriptBuilderProjectRoot`, otherwise the current PowerShell location. The
   resolution writes into none of them.
4. **Where a new project is created is a second question.**
   - A command that works on an **existing** project resolves: those inputs, otherwise upward
     search from the location, otherwise an error.
   - A command that **creates** a project resolves: those inputs, otherwise the current location. It
     never searches, and it does not fail because no project exists; a path that is not on a file
     system drive still fails (RFC 0028).
   - Each question is answered where it is asked, so neither needs a switch to tell them apart.
5. **An explicitly set root applies for the session** (unchanged). **A discovered root applies to
   the call only** — the next call searches from its own location.
6. **The configuration is read at every call.** Nothing derived from it outlives the call.
7. **`$Global:PSScriptBuilderProjectRoot` holds an explicitly set root only.**
   - It is deprecated and will be removed in 2.0.0.
   - `Get-`, `Set-` and `Clear-PSScriptBuilderProjectRoot` are the interface — asking, setting and
     removing, so the session root can be reached without touching the variable.
   - What 2.0.0 removes is the variable, not the session root: an explicitly set root still applies
     for the session, held inside the module and reachable only through those three cmdlets.
   - Which mechanism holds it is decided with that release, not here. This RFC only makes that move
     possible, by leaving no class that reads a root — the reason the variable had to be global.
8. **`Get-PSScriptBuilderProjectRoot` returns the root the next call would use** for an existing
   project, and fails as that call would when there is none. It does not read the configuration, so
   it still answers while the configuration file is invalid.

The rule of item 2 is decided; only the base for a caller's path takes effect later than the rest,
and the item carries that date with it.

## Detailed Design

### Two steps, not one resolution

Determining the project and loading its settings are two steps, and keeping them apart is what lets
contract item 8 hold:

| Step | Produces | Reads |
|---|---|---|
| `Get-PSScriptBuilderProjectRoot` | the project root and where it came from | the inputs, and the file system while searching |
| `PSScriptBuilderConfiguration.FromProjectRoot` | the configuration, with its paths made absolute | `psscriptbuilder.config.json` |

A command that needs only a root takes the first step; a command that needs settings takes both.
Collapsing them would make `Get-PSScriptBuilderProjectRoot` fail on an invalid configuration file,
where today it answers.

### What a command determines, and what it passes on

A command is the composition root (Seemann/van Deursen, *Dependency Injection Principles,
Practices, and Patterns*, ch. 4): it determines the project and loads the configuration once, and
passes the configuration to the classes that do the work. **It passes one value, because the
configuration carries its own project:** it knows the root it was loaded from and the file it was
read from, the way `PathInfo` knows its provider. A root and a configuration cannot be mismatched
within a call, because there is only one object.

```
[PSScriptBuilderConfiguration]
    ProjectRoot    : string      # the root this configuration was loaded from
    ConfigFilePath : string      # the file it was read from
    Release        : …
    Build          : …

    ResolvePath([string] $path) : string   # roots a configuration path against ProjectRoot
```

`ResolvePath` serves the paths that come from a configuration file but are first looked at later —
the bump files, whose paths come from the bump configuration. Paths given by the caller are resolved
at the cmdlet boundary and never reach this method.

**What the root query returns.** `Get-PSScriptBuilderProjectRoot` answers a different question than
the configuration does, and it must answer it even when the configuration file is unreadable. Its
return value is therefore its own type:

```
[PSScriptBuilderProjectInfo]
    Root           : string                            # the project root
    RootSource     : PSScriptBuilderProjectRootSource  # which rule determined it
    ConfigFilePath : string                            # the configuration file for this root

    ToString() → Root
```

- **It is a class, not a `PSCustomObject`.** Every other `Get-` cmdlet of this module returns a
  class — `Get-PSScriptBuilderConfiguration` a `PSScriptBuilderConfiguration`,
  `Invoke-PSScriptBuilderBuild` a `PSScriptBuilderBuildResult` — and `PSCustomObject` is used for
  raw configuration data passed through.
- **The `…Info` suffix is the established name for this shape:** an immutable descriptor with
  several facets of one answer, as in `FileInfo`, `PathInfo`, `CultureInfo` and `PSModuleInfo`. A
  `Get-` cmdlet returning a `…Info` type is the PowerShell standard — `Get-Module` returns
  `PSModuleInfo`, `Get-Command` a `CommandInfo`, `Get-Location` a `PathInfo`.
- **`ToString()` returns `Root`,** as `FileInfo`, `PathInfo` and `Uri` return the value they
  describe. The cmdlet's name promises a root, so the object behaves like the path wherever text is
  expected: interpolation, a `[string]` parameter, a cast, pipeline binding to a `[string]`
  parameter (measured on 5.1). Without the override the name would promise something the return
  value does not deliver.
- **`ConfigFilePath` means the configuration file *for this root*,** computed without touching the
  file system, so it is always filled. The query reads nothing; for an explicitly set root the file
  may not exist yet, and naming the file a command *would* read is the useful answer.
- **`RootSource`** is a `[PSScriptBuilderProjectRootSource]` enum with `Parameter`, `Session` and
  `Discovered` — one value per input of contract item 3, all three reachable. It exists because it
  decides the remedy: a set root is removed with `Clear-PSScriptBuilderProjectRoot`, while a
  discovered one means the current directory is wrong.
  **No production code branches on it** — where the code needs the distinction, it has its own named
  resolution (contract item 4). It names the rule that won, not the path: a discovery never runs
  when a root is set, and a `$Global:` variable written directly, supported until 2.0.0, is
  indistinguishable from `Set-…` and is `Session`.
- **Its values are set in the constructor and never changed.** PowerShell classes have no
  `readonly` property, so immutability is a convention held by the type: no setters, no mutating
  methods. Measured on both versions: a property can still be written from outside, and nothing
  prevents it.
- **Three behaviors belong in the cmdlet''s help**, all measured on both versions and all shared with
  `Get-Location`: `$info -eq 'C:\proj'` is false while `'C:\proj' -eq $info` is true, because the
  left operand decides the comparison; `$info -is [string]` is false; and `ConvertTo-Json` writes
  `RootSource` as a number, since `-EnumsAsStrings` exists only from PowerShell 6 and no other
  result class of this module has an enum property.

**No context object.** An earlier draft had a type holding the root, its source, the configuration
file and the configuration. It is not in this design: the configuration already carries its root, so
a wrapper prevents no mismatch, and its two extra values are read by no class. The criterion for
introducing one later is in the Rationale.

### Who resolves a path, and against what

```
psscriptbuilder.config.json      ─► project root        ─► absolute when the configuration is loaded
bump configuration               ─► project root        ─► absolute when bumping, via the config
caller's -Path, -OutputPath, …   ─► PowerShell location  ─► absolute at the cmdlet boundary
```

The first two share their base — the project root is the directory of
`psscriptbuilder.config.json`, so "against the project root" and "against the configuration file's
directory" are the same rule — but they become absolute at different moments: the configuration's
own paths when it is read, the bump configuration's file paths when a bump runs, because that is
when they are first looked at.

Three consequences:

- **A class is given its paths, it does not go looking for a root.** Twelve classes look today. Six of them are
  on the build side — `PSScriptBuilderCollectorBase`, `PSScriptBuilderBackupManager`,
  `PSScriptBuilderOutputFileManager`, `PSScriptBuilderTemplateFileManager`,
  `PSScriptBuilderTemplateAnalyzer`, `PSScriptBuilderProjectWatcher`. Five of them receive absolute
  paths from the cmdlet that created them, which is RFC 0028's rule applied to the rest of the
  module; `PSScriptBuilderCollectorBase` is held by the caller instead and is treated in "An object
  the caller holds" below.
  Three resolve configuration paths while loading them (`PSScriptBuilderConfigLoader` and the two
  options classes) and do it against the configuration file's directory; two more
  (`PSScriptBuilderReleaseDataFileManager`, `PSScriptBuilderBumpConfigFileManager`) receive paths
  that are already absolute. The one class left that resolves at all is
  `PSScriptBuilderBumpFilesProcessor`, whose file paths come from the bump configuration, and it
  resolves them through the configuration it was given — which carries exactly one root, so finding
  2 cannot recur there.
- **`GetProjectRootedPath` is deleted.** With one base per origin there is nothing left for it to
  decide. Its signature was the defect in miniature: a root as a parameter means every caller may
  bring a different one, which is what finding 2 is.
- **`GetProjectRelativePath` becomes
  `GetDisplayPath([string] $absolutePath, [string] $projectRoot)`** and shortens a path for output
  only, returning it unchanged when the root is empty. It resolves nothing. Its callers are the
  build orchestrator's verbose file list and `Format-PSScriptBuilderSourceCoverage`.

### An object the caller holds

Five of the six build-side classes are created by the cmdlet that uses them, live inside one call
and die with it. A collector is not: `New-PSScriptBuilderCollector` creates it, the caller keeps it,
and `Invoke-PSScriptBuilderBuild` — or any of the nine further commands that take a
`ContentCollector` — uses it later. Between those two calls there is no cmdlet that could resolve
anything.

Measured, exactly one type is in this position. `PSScriptBuilderCollectorBase` carries
`IncludePaths`, `ExcludePaths` and `IncludeFiles`; `PSScriptBuilderBuildResult` carries an output
path as a result, not for resolving; `PSScriptBuilderConfiguration` is handed the root it was loaded
from (step 2); the `ContentCollector` holds collectors and no paths of its own.

**An object the caller holds keeps what the caller wrote and receives the context when it runs.**
Measured on the released module: a collector created under root A collects from B once the root is
B. It describes "collect from `src`", not a fixed location, and the same object serves every
project. Storing the resolved path instead would tie it to the project it was created in — finding 1
in a new place, state that outlives the call and points at the wrong project. It would also stop the
object from echoing its input: `$collector.IncludePaths` would read back as something the caller
never wrote.

The resolution therefore stays where it is — in time at collection, and in place in the collector.
`Collect()`, `Execute()` and `GetFilesToProcess()` keep their signatures; what changes is that the
root is fetched **once per collection** and combined through `GetRootedPath` (step 10), instead of
being fetched inside the loops by `GetProjectRootedPath` (step 11).

**Why the root is not passed in here, although every other class receives it.** Passing it would
mean a parameter on `Collect()` and `Execute()`, and the gain would be consistency with step 12 and
nothing else. The damage step 12 prevents is the one from finding 1: a root that comes from the
wrong project. A collector cannot have it, because it asks when it collects, not when it is created
— measured, the same object serves A and then B. Where there is nothing to prevent, there is no
reason to change a signature that callers can reach.

**What this costs is an exception in the architecture test**, and step 12 names it rather than
listing it: the rule is aimed at classes that work inside one call and help themselves to a context
while doing it. An object the caller holds between two commands is a different case and asks when
it runs.

### The transition for caller paths

Resolving a caller's relative path against the project root is behavior of the exported commands:
the same call with the same argument writes to a different directory once the base changes. That is
a break whether or not anyone wrote it down, so SemVer puts the change in a major release.

- **1.4.0:** a relative path from the caller keeps resolving against the project root. Nothing in
  the code announces the coming change; the announcement is the `Deprecated` entry in the changelog.
- **2.0.0:** contract item 2 applies as written for caller paths as well.

**Why no warning in the code.** This module runs in build scripts and CI, mostly unattended, and a
warning in a CI log is read as little as a changelog — it scrolls past or is filtered. The audience
a warning would reach is the developer running a command interactively while writing a build
script; the audience that needs protecting runs it unattended, and what protects them is the
version number, which they can act on *before* the change with `-MaximumVersion '1.*'` or a
`#Requires` specification. That is SemVer's instrument for exactly this, and it is what comparable
tools rely on for path and output changes: `dotnet` keeps a breaking-change list tied to its
majors, npm changed path behavior across majors with release notes, and Terraform, facing the same
question, *added* `-chdir` instead of changing a base. A warning would also have cost what it
always costs: a second resolution of the same path to compare the two bases, built in 1.4.0 and
deleted in 2.0.0, with its value proportional to how many users pass through 1.4.0 at all.

**What carries the change instead.** The `Deprecated` entry in 1.4.0 names the coming change and
the version. In 2.0.0 the `Changed` entry names it again and says what a script must do — pass an
absolute path, or run from the project root — and a short migration note in the documentation
carries the words someone searches for when an output file turns up in the wrong place.

**What follows for the contract.** After 1.4.0 the contract is not yet fully in force: item 1 and
items 3 to 8 hold, and item 2 holds for paths from a configuration file. For a caller's paths it
takes effect with 2.0.0, which is the only part of this RFC that a release other than 1.4.0
carries.

### Implementation (1.4.0)

1. **The two steps, and the second question.** `Get-PSScriptBuilderProjectRoot` holds the precedence
   rule and the search and returns a `[PSScriptBuilderProjectInfo]`;
   `[PSScriptBuilderConfiguration]::FromProjectRoot` takes it and reads the settings. The second
   question (contract item 4) is answered where it is asked, in
   `New-PSScriptBuilderConfiguration`, and yields a directory, because there is no configuration to
   read yet. The precedence rule for an existing project exists once and is tested once, as a
   function of its inputs.

   **`Get-PSScriptBuilderProjectRoot` writes a verbose line naming the root, its source and the
   configuration file it found**, and the second question writes its own line for the directory a
   new project goes into — the other decision a user can be surprised by.
   An output that always appears can never fire wrongly, unlike a warning, and pytest prints its
   `rootdir` and `configfile` in the header of every run for the same reason. The line appears
   **exactly once per command**, which follows from the design rather than from discipline: a call
   determines its project once, in one place, and the architecture test keeps classes from
   resolving. "Once per command" is not once per user action — a watcher writes the line at its
   start and again for every build a change triggers, because each of those builds determines its
   own project and the line is the evidence of that decision.
2. **`PSScriptBuilderConfiguration` is decoupled from global state.** `Current`, `IsLoaded`,
   `Load()`, `Set()`, `Reset()`, `GetCurrent()` and both constructors are removed — all of them,
   with no transitional stubs. None of them is an exported command or a value a command returns;
   they are reachable only because PowerShell cannot hide a class from `using module`, which is
   where the declaration of the public API (step 13) draws the line. The constructor takes the parsed
   configuration data, the project root and the file name, and reads nothing (Hevery, "Flaw:
   Constructor does Real Work"). `FromFile([string] $configFilePath)` reads an absolute path and
   takes the file's directory as project root; `FromProjectRoot([string] $projectRoot)` reads
   `psscriptbuilder.config.json` from the root; `CreateDefault()` stays. Named factory methods
   instead of two constructors with the same signature (Bloch, *Effective Java*, item 1; .NET
   `Image.FromFile`). Every path that is set in the configuration is absolute once it is loaded; an
   optional path left out stays empty (step 3).
3. **An empty required path fails when the configuration is loaded**, naming the option
   (`dataFile`, `bumpConfigFile`, `outputPath`, `templatePath`); a missing optional `backupPath`
   stays empty (finding 8). Measured: the validator checks presence and type and never emptiness,
   and `Path.Combine(root, '')` returns the root unchanged — which is how an empty option becomes
   the project root. Two of the three effects are confusing errors, but the third is a silent wrong
   write and the reason this rides in the same release: with no `backupPath` configured,
   `Build.BackupPath` *is* the project root, so `-BackupPath $config.Build.BackupPath
   -EnableBackup` scatters backups into the project directory without a word. This is an
   independent defect of validation, not of context lifetime; it is carried here because the
   validator and both options classes are rewritten in this release anyway, and it gets its own
   `Fixed` entry.
4. **Options.** The base constructor only checks that it is not instantiated directly; each derived
   constructor stores the project root and then calls `SetOptions()` and `ValidateOptions()`. A
   method overridden in a derived class and called from the base constructor runs before the
   derived constructor's body (measured on both versions), so the root would not be set yet
   (CA2214).
5. **Release management takes the configuration.** The orchestrator has a single constructor taking
   the configuration and passes it to the bump files processor, so the data file, the bump
   configuration and the bump files of one call cannot come from different projects (finding 2) —
   one object, one root. The unused `Exists()` and `Save()` methods of the two file managers are
   removed (Fowler, *Refactoring*: Remove Dead Code). The eight cmdlets that work on a project's
   release data — `Get-PSScriptBuilderBumpConfiguration`, `Test-PSScriptBuilderBumpConfiguration`,
   `Get-PSScriptBuilderReleaseData`, `New-PSScriptBuilderReleaseData`,
   `Test-PSScriptBuilderReleaseData`, `Update-PSScriptBuilderReleaseData`,
   `Get-PSScriptBuilderReleaseDataTokens`, `Update-PSScriptBuilderBumpFiles` — and
   `Get-PSScriptBuilderConfiguration` take two lines: get the root, load the configuration from it.
   The two `Format-` cmdlets take objects and resolve nothing.
6. **The session root's interface is complete: ask, set, remove.**
   `Get-PSScriptBuilderProjectRoot` is exported and moves to `src/Public`: it returns an explicit
   root, otherwise discovers the root without storing it anywhere, and throws as before when there
   is none. It does not read the configuration (contract item 8). It takes `-ProjectRoot` as well,
   so the query answers for the same inputs the commands use.

   **`Clear-PSScriptBuilderProjectRoot`** is new and removes the root that
   `Set-PSScriptBuilderProjectRoot` installed: no parameters beyond the common ones, no output, a
   verbose line naming the root it removed, and a silent no-op when none is set, because `Clear-`
   is idempotent in PowerShell. Afterwards the next command searches from the current location
   again. It changes no file and no directory, and not the current location either, which is why it
   declares no `ShouldProcess` — the repository excludes that analyzer rule for cmdlets that only
   touch in-memory state. Whoever offers setting must offer removing: `Clear-AzContext`,
   `kubectl config unset current-context` and `gh repo set-default --unset` are the precedents, and
   `Clear` is an approved verb. Today a user can reach the same end by writing `$null` into the
   deprecated variable; in a release that deprecates it, that cannot be the documented answer.
7. **`-ProjectRoot` on the nine commands that work on a project** — the eight release cmdlets and
   `Get-PSScriptBuilderConfiguration`. It is the first input of contract item 3, applies to that
   call only and changes no state; `RootSource` then reports `Parameter`. Every comparable tool has
   this override, including those whose context is as short-lived as this one: `git -C`,
   `cargo --manifest-path`, `npm --prefix`, `terraform -chdir`. Without it, working on several
   projects in one script means `Set-Location` per iteration, which changes state the rest of the
   script sees — the pattern this RFC removes. It carries no logic; the precedence rule stays in the
   resolution. Three constraints: a relative value is resolved against the PowerShell location
   through `PathIntrinsics` (RFC 0028); the value is read literally, not as a wildcard pattern
   (RFC 0030) — Terraform is the measured warning, where `-chdir` was reported not to apply to
   provider mirrors under `terraform.d/plugins`, which is finding 2 in another tool; and a value
   that names no existing directory fails at once and names the parameter, rather than letting a
   missing configuration file report the consequence instead of the cause. That is what
   `Set-PSScriptBuilderProjectRoot` already does for `-Path` — measured, it throws
   `ItemNotFoundException` naming the path — and what `git -C` does, which refuses with "cannot
   change to …" before it looks for a repository.
   `New-PSScriptBuilderConfiguration` keeps `-Path` and gets no alias: it answers where a project is
   *created*, not which one is worked on, and an alias would blur exactly the distinction finding 5
   is about. `Set-PSScriptBuilderProjectRoot` keeps `-Path` alone for a different reason: there the
   path is the target of the action, not an input to the precedence rule, so a second parameter
   would say the same thing twice. `git` draws the same line — `git -C <dir>` supplies the
   directory for one call, `git init <dir>` takes it as the target.
8. **`New-PSScriptBuilderConfiguration` keeps its behavior, and the read of the deprecated variable
   is encapsulated.** The cmdlet already answers the second question correctly and without
   searching, inline in its own body; finding 5 is fixed by contract item 7 alone, because the
   discovered root stops reaching `$Global:PSScriptBuilderProjectRoot`. What this step requires is
   only a goal: after it, `$Global:PSScriptBuilderProjectRoot` is read in **one** place, so
   replacing its storage in 2.0.0 touches one file (Feathers, *Working Effectively with Legacy
   Code*: Encapsulate Global References). Today two places read it — this cmdlet and the root
   resolution. Which form that takes — a private accessor for the variable, a named resolution for
   the second question, or both — is an implementation choice and is not fixed here; note that a
   named resolution alone does not reach the goal, because it would read the variable itself.
9. **Caller paths are resolved at the cmdlet boundary.** The eleven cmdlets of finding 9 resolve
   every path parameter once, in their own body, through `GetRootedPath` (step 10), and hand
   absolute paths to the classes below them. A relative path keeps the project root as its base in
   1.4.0; an absolute path needs no project, as today.
10. **Classes are given their paths, with one named exception, and the helpers go.** The six build-side
   classes listed under "Who resolves a path" take absolute paths; the bump files processor resolves
   through the configuration; `GetProjectRootedPath` is deleted; `GetProjectRelativePath` becomes
   `GetDisplayPath(absolutePath, projectRoot)` with the root passed in.

   **`GetRootedPath([string] $path, [string] $projectRoot)` takes its place** as the counterpart of
   `GetDisplayPath`, with the same parameter order: it returns a rooted path unchanged, normalizes
   the separators, combines and normalizes `.` and `..` — everything the deleted method did except
   fetching the root, which the caller now supplies. Without it the eleven cmdlets of step 9 would
   each carry those four lines, which is the defect step 10 removes elsewhere: the existence check
   was built thirteen times because the layer offered none. One more reason for a single place:
   measured, `[Path]::GetFullPath` rejects a value containing `*` or `?` on Windows PowerShell 5.1
   and accepts it on 7 (RFC 0030, cases 2 and 10), and that difference is easier to hold in one
   method than in eleven.

   The fourteen calls in those six classes — `PSScriptBuilderBackupManager` 5 (lines 46, 47, 108,
   109, 155), `PSScriptBuilderCollectorBase` 3 (lines 178, 242, 272),
   `PSScriptBuilderOutputFileManager` 2, `PSScriptBuilderTemplateFileManager` 2,
   `PSScriptBuilderTemplateAnalyzer` 1, `PSScriptBuilderProjectWatcher` 1 — are not alike, and each
   was traced before this was written.

   **Eleven are a second resolution and are deleted**, because `GetProjectRootedPath` returns a
   rooted path unchanged and the value is already absolute when it arrives. For
   `PSScriptBuilderBackupManager` that was measured rather than argued: `CreateBackup` has exactly
   one caller in `src`, the build orchestrator, which passes the output and backup paths it was
   given; traced with relative input — `-OutputPath 'out\c.psm1'`, `-BackupPath 'backups'` — both
   arrive rooted, because `Invoke-PSScriptBuilderBuild` and `Watch-PSScriptBuilderProject` resolve
   them before the orchestrator exists. Lines 108, 109 and 155 sit in `RestoreBackup` and
   `HasBackup`, **and both methods are removed with them.** The build writes a timestamped copy of
   the previous output when `-EnableBackup` is given, and nothing reads it again: an archive of
   stands cannot be replayed automatically, and no command offers it — the module's own rollback is
   the file transaction of RFC 0026, used in release management and scaffolding, not here. The two
   methods are the never-shipped half of that feature, reachable only through `using module`, and
   they wrap what PowerShell already does: a copy with a check, and a file test. Whoever wants a
   stand back copies the `.bak` file. Like the members step 2 removes they are outside the public
   API, so the changelog names them no more than it names those — what it announces is the
   declaration itself (step 13). Offering the restore as a command instead would be a feature of its
   own, with the choice of stand, `-WhatIf`, help and tests, and it is out of scope here.

   **Three are the only resolution and are replaced, not deleted.** Traced through the documented
   path, the collector receives relative values — `IncludePaths` `'src'`, `ExcludePaths` `'src\Sub'`,
   `IncludeFiles` `'src\One.ps1'` — because `New-PSScriptBuilderCollector` resolves them to validate
   them but stores what the caller wrote. These three ask for the root once per collection and
   combine it through `GetRootedPath`; the signatures stay as they are, for the reasons in "An
   object the caller holds". Line 242 loses its repetition on the way, because the resolution moves
   out of the per-file loop (step 11).

   **While that file is open, `EnsureDirectoryExists` learns to fail clearly.** Today a path that
   is a file reaches `Directory::CreateDirectory`, and the user gets .NET's localized message
   wrapped in "Exception calling CreateDirectory with 1 argument(s)" — it names an internal method
   and says "already exists" where the real cause is that a file sits where a directory is
   required (measured on 5.1). Two additions, both in the house style of the module's other 83
   catch blocks, which name the operation and append the original text: a check that rejects a
   path that is a file, with `ArgumentException` and the parameter name as the method's two
   existing checks do; and `CreateDirectory` wrapped, so a file *inside* the path, a denied access
   or an over-long path also name the operation and the path while keeping the original reason and
   the inner exception. All six callers of the helper inherit both —
   `PSScriptBuilderConfiguration.CreateDefault`, `PSScriptBuilderBackupManager` twice,
   `PSScriptBuilderBuildResultExporter`, `PSScriptBuilderOutputFileManager` and
   `PSScriptBuilderTemplateGenerator`. Like finding 8 this is an independent defect, and unlike
   finding 8 it is not even the same subject: it rides along because this release opens the file,
   and it gets its own `Fixed` entry.
11. **The per-file resolver calls disappear with step 10.** `PSScriptBuilderCollectorBase` measured
    3004 resolver calls for 1000 files with three exclude paths, and 4 without exclude paths,
    because the resolution sat inside the loops. With the paths resolved once at the boundary there
    is no loop-invariant work left to hoist.
12. **Architecture test.** A Pester test parses `src` based on the AST, so that help text and
    comments do not count, and asserts that there are none of:
    - calls of `Get-PSScriptBuilderProjectRoot` in `src/Classes`, with one named exception:
      `PSScriptBuilderCollectorBase`, which the caller holds between two commands and which
      therefore asks when it collects (see "An object the caller holds"). Cmdlets are the
      composition root; every other class receives what it needs;
    - accesses to `$Global:PSScriptBuilderProjectRoot` outside `Set-PSScriptBuilderProjectRoot` and
      the one place that encapsulates the read (step 8);
    - any reference to `GetProjectRootedPath` or `GetProjectRelativePath`.

    An assertion, not a list of allowed counts: there is no backlog left to count down, and a test
    holding numbers per file would have to be maintained for no gain (ArchUnit's architecture rules
    rather than its `FreezingArchRule`).
13. **Documentation, and the declaration of the public API.**
    - **The module declares what its public API is**, which SemVer requires (item 1: a project
      "MUST declare a public API", precisely and comprehensively) and which this project has never
      done — `RELEASING.md` names "breaking changes" without saying what they break. The
      declaration goes where consumers look, in the documentation, with `RELEASING.md` pointing at
      it:

      > The public API is the exported commands — their parameters, their behavior and what they
      > return — together with the properties of the objects they return. It does not include the
      > methods of the module's classes: those are reachable only because PowerShell cannot hide a
      > class from `using module`, and they may change in any release.

      The line is drawn by what the module exports and what a caller can read off a result, not by
      what happens to be mentioned somewhere — a sentence in a guide must not decide what is frozen.
      It matters in both directions: `PSScriptBuilderConfiguration` is returned by a cmdlet, so the
      type and its properties are public, while `FromFile`, `FromProjectRoot` and `CreateDefault`
      are not — which is what makes this release's rework of that class allowed at all.

      Being outside the API does not mean a member is changed lightly. `Collect` keeps its signature
      in this release, because changing it would prevent nothing (see "An object the caller holds");
      the six members and two constructors that step 2 removes go because the class cannot do its
      work while they exist.
      The declaration is written now and **narrows** what a user could assume since 1.0.0, so it is
      announced in the changelog (step 14) rather than slipped in.
    - `Set-PSScriptBuilderProjectRoot` page and "Project Root Discovery" in
      `docs/guides/configuration.md`: how long each root applies, in running text, every way out of
      a session root (`Clear-PSScriptBuilderProjectRoot`, a new session, `Import-Module -Force`),
      and `Get-PSScriptBuilderProjectRoot` to check it.
    - One place states the two bases of contract item 2 — `docs/guides/configuration.md` — and the
      pages that describe a path parameter point to it instead of repeating a rule of their own.
      `docs/guides/build-pipeline.md`, `docs/guides/collectors.md` and the comment-based help of
      `New-PSScriptBuilderTemplate` and `Test-PSScriptBuilderTemplate` name the 1.4.0 behavior and
      the change coming in 2.0.0.
    - The existing `-WhatIf` tip in `docs/guides/release-management.md` also names the project root.
    - `docs/troubleshooting.md`: "Wrong configuration loaded" rewritten for finding 7; "Bump files
      not updated" rewritten with measured causes only. No notes on earlier versions: the
      documentation describes the current state, the changelog reaches users of earlier versions.
    - Every mention of `$Global:PSScriptBuilderProjectRoot` as the interface is replaced by the
      cmdlets.
14. **Changelog.** `Added`, `Changed`, `Deprecated` and `Fixed` entries, and the affected users
    named with both damages: whoever ran release commands for more than one project in one session
    should compare, in every project, the version in the release data file with the versions in the
    bump files — a difference means another project's version was written; whoever ran
    `New-PSScriptBuilderConfiguration -Force` after a directory change should also check whether
    another project's configuration stands at the defaults.

    `Fixed` carries the empty configuration option and the unclear directory failure as two
    separate entries, each naming what a user noticed: backups landing in the project directory and
    release commands reporting a missing file, against a message that named an internal method
    instead of the cause.

    `Deprecated` carries the two announcements, both naming 2.0.0:
    `$Global:PSScriptBuilderProjectRoot`, and the base against which a caller's relative path is
    resolved — the latter with the sentence a reader needs in order to act, that an absolute path or
    a call from the project root means the same thing before and after. `Changed`
    carries the declaration of the public API, as a rule and without naming any class member —
    which is also why there is no `Removed` entry from this release: everything removed from the
    classes was outside the declared API, and `AGENTS.md` keeps internal members out of the
    changelog.

### Order of the work

The steps are an order, not phases: each one leaves the suite green, and the commits follow the
repository's rule of one per file or per logical change. Steps 1 to 4 create the root resolution
and the configuration, so everything after them has something to be passed; step 5 is the subsystem
the defect was measured in; steps 6 to 8 are the commands' own surface; steps 9 to 11 are the
largest in file count and the smallest in decisions, because by then the shape is fixed and each
file does the same thing. Steps 12 to 14 close it: the test that keeps it, the documentation, the
changelog.

Nothing is deferred to a later release except what SemVer puts there: the base of a caller's
relative path (contract item 2) and the removal of `$Global:PSScriptBuilderProjectRoot`, both
announced here and done in 2.0.0.

## Backwards Compatibility

- **Leaving the project after auto-discovery fails** with "No 'psscriptbuilder.config.json' found
  …" instead of silently using the previous project. Intended; the message names the remedy.
- **`$Global:PSScriptBuilderProjectRoot` stays empty after auto-discovery** and is deprecated.
  Scripts that read it get `$null` unless the root was set explicitly; scripts that set it directly
  keep working until 2.0.0.
- **A relative path given to a cmdlet keeps its base in 1.4.0, unchanged and unannounced in the
  code.** The change comes in 2.0.0; the `Deprecated` entry is the only notice in this release. A
  script is unaffected by that change if it passes absolute paths, or if the project root and the
  PowerShell location are the same directory — which is not the same as "runs from the project
  root": a script that calls `Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot` and is started
  from elsewhere has two different bases. All seventeen shipped examples were measured for this, and
  one is affected: every path parameter takes its value from a variable built on `$PSScriptRoot` or
  `$config.Build.*`, except three lines in `examples/14-scaffolding/Run-Example.ps1` (86 to 88),
  which pass `-IncludePath '.\src\Enums'`, `'.\src\Classes'` and `'.\src\Public'`. Those three
  resolve against the calling directory once the base moves, so they break when the script is
  started from outside its own folder and work when it is not. They are also the measure of the
  change: of every realistic call this project has written for itself, it affects three lines in one
  file, and the other sixteen examples already use the form 2.0.0 expects. That file is adjusted
  with 2.0.0, not here, because the base does not move in 1.4.0.
- **`Load()`, `Set()`, `Reset()`, `GetCurrent()`, both constructors of
  `PSScriptBuilderConfiguration` and the orchestrator's constructor are gone.** `FromProjectRoot`
  and `FromFile` replace them; `CreateDefault` stays. A call fails with PowerShell's own message —
  "does not contain a method named …" or "Cannot find an overload" — which names no replacement,
  and nothing in the changelog names them either: under the declared public API (step 13) they were
  never promised. The one capability without a direct successor is loading a configuration from a
  file of another name, which no command could use anyway; reading another project's configuration
  is `Get-PSScriptBuilderConfiguration -ProjectRoot <root>`. `Reset()` in a user's own tests needs
  no successor: nothing is cached across calls any more.
- **A relative path in a configuration file outside the project root resolves differently.**
  `new($path)` resolved the configuration's relative paths against the global project root;
  `FromFile($path)` takes the file's directory as the root and resolves them against it. For a
  configuration file inside its project root — every documented layout — nothing changes.
- **An empty required path in `psscriptbuilder.config.json` fails when the configuration is
  loaded**, instead of naming the project root; without `backupPath`,
  `Get-PSScriptBuilderConfiguration` shows `Build.BackupPath` empty instead of the project root.
- **`Get-PSScriptBuilderProjectRoot` and `Clear-PSScriptBuilderProjectRoot` are new public cmdlets,
  and `-ProjectRoot` a new parameter on nine existing commands.** Ten cmdlets carry the parameter
  afterwards, because the new root query takes it as well (step 6). All additive; listed for
  completeness. A script that already passes a parameter of that name to one of them cannot exist,
  since none has one today.
- **A directory that cannot be created fails with a different exception.** A path that is a file
  now raises `ArgumentException` naming the path and the cause instead of the `IOException` that
  `Directory::CreateDirectory` produced; every other failure still raises `IOException`, now with
  the operation and the path in the message and the original exception kept inside. A script that
  catches `[System.IO.IOException]` specifically for the file case would no longer match.
- **Unchanged:** an explicit root applies for the session; a command given only absolute paths
  needs no project; `Import-Module -Force` clears an explicit root (module template).

## Rationale and Alternatives

**How other tools decide.**

| Tool | Project from | Applies to | Query | Override per call |
|---|---|---|---|---|
| git | `.git` searched upward | one call | `git rev-parse --show-toplevel` | `-C`, `GIT_DIR` |
| cargo | `Cargo.toml` searched upward | one call | `cargo locate-project` | `--manifest-path` |
| npm | `package.json` searched upward | one call | `npm prefix` | `--prefix` |
| Invoke-Build | build script directory | one build, read-only after loading | `$BuildRoot` | set in the build script |
| Az PowerShell | `Set-AzContext` | session (optionally saved) | `Get-AzContext` | `-DefaultProfile` |
| kubectl | `current-context` | saved in kubeconfig | `kubectl config current-context` | `--context` |

Build tools determine the project per call or per run; none keeps a *discovered* project for the
session. A context for the session (Az, kubectl) is a deliberate model; such tools let the user
query it and override it per call. Every tool that determines its project offers a query, and Get is
the approved counterpart of Set (Microsoft, "Approved Verbs for PowerShell Commands").

**The settings object is the currency, not a context object.** Pester 5 replaced the scattered
`Invoke-Pester` parameters with a configuration object created by `New-PesterConfiguration` and
removed the old parameter set in v6 — and it put *which paths to run* inside that object rather than
beside it, which is the same choice made here. Sampler passes `-BuildRoot` explicitly to each helper
instead of reading global state; Invoke-Build fixes `$BuildRoot` per run and makes it read-only
afterwards. Neither has a context object.

**When a context object would be justified.** The tools that have one carry more than settings in
it: MSBuild's `ProjectCollection` holds global properties *and* loggers and toolsets; Roslyn's
`AnalysisContext` compilation, options, a cancellation token and a registration API; cargo's
`Config` configuration values, the working directory, the output channel and an HTTP client;
ASP.NET's `HttpContext` request, response and user. Go, which named the pattern, forbids using it as
a bag of dependencies and limits it to cancellation and request-scoped metadata. The criterion that
follows: **a context earns its place when more than one *kind* of thing has to travel — settings
plus a service or a sink.** Two settings values are two fields of the same kind and belong in the
settings object.

Here exactly one thing travels, the configuration, so there is no context type. The one candidate
that would change that is already known: warnings raised inside class methods do not reach
`-WarningVariable` (`docs/limitations.md`), so returning them to the cmdlet needs a sink. That is a
service, not a setting — and a separate topic from this RFC.

**Why one base per origin is the rule, not a preference.** A `-Path` on this platform is resolved
against the current location, through the provider model (Microsoft, "Support Paths and the Provider
Model"; "Standard Cmdlet Parameter Names and Types") — that is what users bring from `Get-Content`
and `Copy-Item`. Paths inside a configuration file are resolved against that file in
`tsconfig.json`, MSBuild project files and `Cargo.toml`, so a configuration means the same wherever
it is read from.
Every comparable tool splits exactly this way: command-line paths against the working directory,
configured paths against the configuration. RFC 0028 already applied the first half of the rule at
two boundaries of this module; finding 9 is the other ten.

**Why a command without a project still works.** A tool requires a project exactly when it must
read something from it: `cargo build` needs `Cargo.toml` and `cargo new` does not, `git log` needs a
repository and `git diff --no-index` does not, `tsc datei.ts` needs no configuration and `tsc -b`
does. The build side of this module reads no configuration at all — `-TemplatePath` and
`-OutputPath` are mandatory — so requiring one would add a dependency on ambient state that nothing
uses, which is the critique this RFC is built on (Seemann/van Deursen, ch. 5), only reversed.

**Why the singleton is a design error, not a bug.** It is a cache derived from the project root
with no tie to the root and no invalidation — an Ambient Context (Seemann/van Deursen, ch. 5). The
build side never used it, so the same file applied for different lengths of time depending on the
cmdlet.

**Why an explicit root may outlive the call and a discovered one may not.** An explicitly set root
is an *input* to the resolution: declared by the user, read afresh at every call. Auto-discovery is
its *output*. Both were stored in `$Global:PSScriptBuilderProjectRoot`, so the resolution wrote its
result into its own input, and the second call replayed the first instead of resolving. Finding 4 is
that replay; finding 5 is the replay reaching a command that asked a different question. This is why
the asymmetry of contract item 5 is not a courtesy to whoever typed `Set-…`: an input may apply for
the session, an output may not outlive its call.

**Partial freshness is worse than staleness.** Finding 2 mixed values resolved at two different
times: A's version, through A's bump configuration, into B's file. Had everything been stale, the
wrong project would have been updated consistently and the result would have been recognizable. This
is the argument against a cache with invalidation rules: such a rule would have to guarantee the
completeness of *all* derived values, and that proof would have to be redone with every change.
Reading the configuration per call needs no such proof. Finding 3 is the same defect seen from the
other side: there the query is fresh and the command is stale, so the check agrees with the user
instead of with the result.

**No cache instead of a cache tied to the location.** Searching costs about 0.3 ms (1000 calls:
+350 ms in PS 7, +310 ms in 5.1, four levels deep). A cache tied to the location would need rules
for when to discard it and would miss a configuration created below the current location. The
per-file resolver calls disappear with step 10 rather than being hidden behind a cache.

What reading the configuration at every call costs is measured: 4.2 ms per load on 5.1 and 4.9 ms on
7.6.10, against 0.10 and 0.06 ms for a cache hit. The cost falls on the eight release cmdlets alone,
because `Get-PSScriptBuilderConfiguration` already pays it today — it calls the constructor instead
of the cache, measured at 4.25 ms with a warm singleton. In the full workflow of example 12, two of
thirteen cmdlet calls are affected, so that run grows by some 8 to 10 ms. The watcher does not pay
per event either: its script block builds an orchestrator from paths the cmdlet resolved once. What
remains for after the implementation is the comparison end to end — see the Test Plan.

**One release, not two.** An earlier draft split the work: the fix and the release side first, the
build side later. The argument for splitting was release pressure — a silent wrong write has shipped
since 1.0.0, and every extra changed file adds regression risk to the fix. There is no such
pressure, and without it the split only costs: `GetProjectRootedPath` would live on as a second way
to root a path, so the invariant would be held by the contract and a counting test instead of by the
code; files would be rewritten twice, first to take a root and later to take the configuration; and
the deprecated global's removal would depend on a backlog being emptied.

**Change the base in a major release, not in a minor one.** Correcting it in a minor release would
move an output file without a word — the failure class this RFC exists to remove. SemVer puts a
behavior change that users depend on in a major release, and where a command writes is as plainly
part of its behavior as what it returns. The alternative, refusing the ambiguous case outright in
1.4.0 (MSBuild does this for an ambiguous project file, MSB1011), would
break working scripts in a minor release just the same.

**And announce it in the changelog, not in the code.** A warning in 1.4.0 was decided first and
then dropped, on a correction of the argument that carried it: the claim had been that a warning is
the only channel reaching a CI script, which reads no changelog — but a warning in a CI log is read
no better; it scrolls past or is filtered. This module runs unattended in build scripts, so the
audience that needs protecting is reached by the version number, which it can pin *before* the
change, and not by output it never sees. The tools facing the same question agree: `dotnet` keeps a
breaking-change list tied to its majors, npm changed path behavior across majors with release notes,
Terraform *added* `-chdir` rather than changing a base. Git's `push.default` is the counter-example
and shows where a warning does pay — an interactive tool, where the person who sees it is the person
who types the next command. The heavier mechanism, an opt-in switch as .NET does with `AppContext`
and Python with `from __future__ import`, needs a channel this module does not have: the only
candidate, `psscriptbuilder.config.json`, is ruled out because the base cannot come from the file
that is found by using that base — pytest states the same rule for `--rootdir`.

**Deprecate the global variable instead of removing it.** The documentation described it as the
project root, so it is part of the public API; SemVer has deprecations announced in a minor release
and removed in the next major one. Mirroring it into a module variable would create two sources for
the same value.

**Finding 7 is mitigated, not removed.** `Get-PSScriptBuilderProjectRoot` shows the root, the
resolution's verbose line names where it came from, and `-WhatIf` and `-Confirm` of the writing
release cmdlets name the full paths. A tip, not a warning: the consequence is possible, not certain
(Microsoft Learn alerts: Caution vs. Warning), and the reader can check beforehand.

**Considered and rejected:**
- **Reset the singleton in `Set-PSScriptBuilderProjectRoot`:** misses auto-discovery and
  configuration changes (findings 3 and 4).
- **Only correct the contract, keeping the global state:** fixes the effects, but leaves the cause
  and needs the invalidation rule whose completeness cannot be proven.
- **A configuration for every command, including the ones that read none:** would make a missing or
  invalid `psscriptbuilder.config.json` break a build that is given every path explicitly, and
  would require ambient state that nothing reads.
- **A context type holding the root, its source, the configuration file and the configuration:**
  the configuration already carries its root, so the wrapper prevents no mismatch, and its two
  extra values are read by no class — see "When a context object would be justified".
- **Keeping `GetProjectRootedPath` with a project root parameter:** the invariant would stand as a
  parameter, so every caller could bring a different root. That possibility is what finding 2 is.
- **A `PSCustomObject` instead of `PSScriptBuilderProjectInfo`:** would be the only `Get-` cmdlet of
  this module without a type name to filter or format on.
- **A plain string from `Get-PSScriptBuilderProjectRoot`:** the provenance would exist only in the
  verbose line of a run, and a return type cannot be widened later without a break. PowerShell
  returns strings from the calculating path cmdlets (`Join-Path`, `Split-Path`, `Convert-Path`) and
  objects where the answer has facets (`Get-Location`, `Resolve-Path`); this answer has facets.
- **`Get-PSScriptBuilderProjectRoot -Explicit` for the second question:** a switch covering a
  missing name; two named resolutions say what they answer.
- **Abolish the session root:** breaks every existing script.
- **Warn when the location is outside an explicit root (finding 7):** fires for
  `& C:\proj\build.ps1` started elsewhere.
- **Migrating the build side in a later release** (Strangler Fig, Fowler; Feathers, *Working
  Effectively with Legacy Code*: Parameterize Constructor, Encapsulate Global References): the right
  approach against a deadline, and the wrong one here — see "One release, not two".
- **An opt-in switch for the new base in 1.4.0:** needs a channel the module does not have, and the
  obvious one is ruled out — see "And announce it in the changelog, not in the code".
- **A warning in 1.4.0 about the coming base change:** reaches the interactive developer and not the
  unattended CI run that needs protecting, and costs a second resolution of every relative path to
  compare the two bases, built in one release and deleted in the next — same reference.
- **A verbose line wherever the project is used, instead of where it is determined:** the decision
  is made once per call, so repeating it says nothing new, while a line that appears forty times in
  one build displaces the verbose output that does carry new information — and is then read by
  nobody, which loses the benefit rather than leaving it unchanged. pytest prints its `rootdir` in
  the header of a run, not per test. The one line at the resolution plus
  `Get-PSScriptBuilderProjectRoot` for asking beforehand covers what this would have covered.

## Scope

**In scope:** `PSScriptBuilderProjectInfo`, `PSScriptBuilderProjectRootSource`,
the encapsulated read of `$Global:PSScriptBuilderProjectRoot`;
`PSScriptBuilderConfiguration`, `PSScriptBuilderConfigLoader`, `PSScriptBuilderOptionsBase` and the
two options classes; the release management orchestrator, its two file managers and the bump files
processor; `PSScriptBuilderFileSystemHelper` — `GetProjectRootedPath` removed and `GetRootedPath` added,
`EnsureDirectoryExists` given its two clear failures, `GetProjectRelativePath` replaced by
`GetDisplayPath`; the six build-side classes that receive
absolute paths instead of resolving them
(`PSScriptBuilderCollectorBase`, `PSScriptBuilderBackupManager`,
`PSScriptBuilderOutputFileManager`, `PSScriptBuilderTemplateFileManager`,
`PSScriptBuilderTemplateAnalyzer`, `PSScriptBuilderProjectWatcher`) and
`PSScriptBuilderBuildOrchestrator` for its verbose list; the eight release cmdlets,
`Get-PSScriptBuilderConfiguration`, `Get-PSScriptBuilderProjectRoot`,
`Clear-PSScriptBuilderProjectRoot`,
`New-PSScriptBuilderConfiguration`, `Format-PSScriptBuilderSourceCoverage`, and the eleven cmdlets of
finding 9; the `-ProjectRoot` parameter on the nine commands that work on a project, with its help
and its pages; their tests and the architecture test; the CBH and `docs/cmdlets` pages concerned,
including a new page for `Get-PSScriptBuilderProjectRoot` and the cmdlet index;
`docs/guides/configuration.md`, `docs/guides/build-pipeline.md`, `docs/guides/collectors.md`,
`docs/guides/release-management.md`, `docs/troubleshooting.md`, the documentation page that declares
the public API and `RELEASING.md` pointing at it; `internal/test-strategy.md`,
`internal/release-management-config-bypass-planning.md`; `CHANGELOG.md`; this RFC.

**Out of scope:** the base change itself, which 2.0.0 makes; the watcher's global event variables
(set at every start and stop); provider cmdlets that read a path as a wildcard pattern (RFC 0030).

## Relationship to Other RFCs

RFC 0028 resolves a path at the cmdlet boundary against the PowerShell location and passes
`PathIntrinsics` by Method Injection; this RFC applies the same rule to the project root, the
configuration and the remaining eleven cmdlets, and finding 9 is the inconsistency RFC 0028 left
behind. RFC 0026's transaction is unaffected; it now writes to the project of the call.
`internal/release-management-config-bypass-planning.md` names `Set()` as the only override and asks
for a second orchestrator constructor; with the configuration passed in, the override is that
constructor's parameter.

RFC 0030 reads every path literally and resolves a caller's pattern without destroying it; its
cases are listed there. Unlike the findings of this RFC, none of them is silent: most fail with an
error, and the quietest still warns and marks the gap in the output, which is why that defect
carries its own weight and is not the same failure class. `-ProjectRoot` is read literally for that
reason already (step 7).

**It belongs on the 1.x line, not in 2.0.0.** RFC 0028 made the same change for one cmdlet and this
release ships it as a `Fixed` entry: "`-Path` was read as a wildcard pattern, so a directory such as
`App[1]` silently set the project root to `App1` … The path is now used as it is." The remaining
paths are the same defect, so they are a fix and not a break, and the argument that split 1.4.0 from
2.0.0 applies to them too: a user pinned to `1.*` would otherwise never receive it. It therefore
goes into 1.4.0 if it is specified by then, and into the next minor release otherwise.

That also settles the order between the two documents, which this RFC used to leave open: RFC 0030
comes first or alongside, on files this release has already reworked, and 2.0.0 carries only what
breaks — the base for a caller's paths and the removal of `$Global:PSScriptBuilderProjectRoot` with
the move of its storage.

## Test Plan

**The precedence rule, once, as a function of its inputs.** For an existing project: `-ProjectRoot`
beats the session root beats the location, including when two of them name the same path, where
`RootSource` still reports the rule that won; a relative `-ProjectRoot` resolved against the
PowerShell location, not the process directory; a `-ProjectRoot` with wildcard metacharacters
(`App[1]`) read literally; a `-ProjectRoot` that names no existing directory fails naming the
parameter, not the configuration file; a `-ProjectRoot` on another provider's drive fails, as does a
location there; no configuration found → an error naming the remedy; a nested project → the nearest
configuration; `RootSource` correct in all three cases; the resolution writes to none of its
inputs; an invalid configuration file still yields a root (contract item 8). For the
place a new project goes: the `-Path` of the call, otherwise the session root, otherwise the current
PowerShell location; never searches; in an empty directory, that directory; a directory that does
not exist yet is returned unchanged; a path with wildcard metacharacters arrives literally; a path
on another provider's drive fails with the message of RFC 0028, and no absent project ever fails.

**What the root query returns.** `Get-PSScriptBuilderProjectRoot` yields a
`PSScriptBuilderProjectInfo` whose `Root` is the path, whose `RootSource` names the rule that won in
both reachable cases, and whose `ConfigFilePath` is filled for a set root whose file does not exist;
`ToString()` gives the path, so interpolation, a `[string]` parameter, a cast and pipeline binding
to a `[string]` parameter all yield the path; the default output has three columns. The three
documented surprises are asserted as behavior, not fixed: the comparison is false with the object on
the left and true with the string on the left, `-is [string]` is false, and `ConvertTo-Json` writes
`RootSource` as a number.

**Directories and clear failures.** An empty required option fails when the configuration is
loaded, naming the option, instead of becoming the project root; a missing `backupPath` stays
empty, so `Build.BackupPath` is empty and not the root. `EnsureDirectoryExists` rejects a path that
is a file, naming the path and the cause; a file inside the path, a denied access and an over-long
path each fail with the operation, the path and the original reason, and keep the inner exception;
an existing directory and a directory to be created still succeed.

**The configuration.** `FromFile` with an absolute path, a relative path (error) and
a missing file; `FromProjectRoot`; every configuration path absolute after loading, resolved against
the configuration file's directory; `ResolvePath` roots a bump configuration path against the root;
an empty required path fails when loading, naming the option; a missing `backupPath` stays empty;
each options class has its values set and its paths resolved after the constructor.

**The verbose line.** It appears once per command and names the root, its source and the
configuration file; a command that needs no project writes none; the location resolution writes
its own; and no second line appears for the same decision when the configuration is loaded or passed
on.

**Setting and removing the session root.** After `Clear-PSScriptBuilderProjectRoot` the next command
searches from the current location and the query reports `Discovered`, or fails where no
configuration is found above it; with no root set, clearing writes a verbose line and no error, and
nothing else changes — not the current location, not a file. A root set again afterwards applies as
before.

**The two bases.** A caller's relative path resolves against the project root in 1.4.0, unchanged
and with no warning — including where the project root and the PowerShell location differ, which is
the case 2.0.0 will change. A path from a configuration file resolves against the project root.
`GetDisplayPath` shortens
a path below the root, returns a path outside it unchanged, and returns its input when the root is
empty.

**No project needed where none is read.** Each of the eleven cmdlets of finding 9 runs with absolute
paths only, outside any project and with no `psscriptbuilder.config.json` anywhere above, and with
an invalid configuration file present.

**The invariant, end to end and without resetting anything.** Two projects in one session, switched
with `Set-PSScriptBuilderProjectRoot` and with `Set-Location`; a configuration changed during the
session takes effect at the next call; `Push-Location` into a sub-project between two calls;
`New-PSScriptBuilderConfiguration` after auto-discovery and a location change creates the file in
the current directory and leaves the other project's configuration unchanged; leaving the project
after auto-discovery fails and `$Global:PSScriptBuilderProjectRoot` stays empty; examples 11 and 12
one after another in one process. And the test for finding 2: **all** paths of one call follow the
same configuration, shown on the bump files, not only on the data file.

**The build side keeps its behavior.** Every migrated cmdlet and class resolves the same paths as
before for the same inputs — a build, a compressed script, an exported graph, a source map lookup, a
template test, a collector with include and exclude paths, and the watcher over a change — with
relative and with absolute parameters. Results and output are unchanged; nothing new is written to
any stream.

**Proof that the new tests can find the defect.** Before the merge the old behavior is restored
temporarily — the configuration singleton, the storing of the discovered root, and a second root
source for the bump file paths, each on its own — and every new test is shown to fail. A regression
test that has not been shown to catch its regression is an assertion, and for a defect whose
detection failed on the test fixture for six releases, this step is not optional.

**The architecture test** fails when a file reintroduces `Get-PSScriptBuilderProjectRoot` in a
class other than `PSScriptBuilderCollectorBase`, an access to the global variable, or a reference to
one of the removed helpers — and it fails just as well when the collector's own call disappears
into a loop again, because that is what step 11 removes.

**Load cost, the second half.** The before side is measured (see "No cache instead of a cache tied
to the location"); what the full workflow of example 12 costs afterwards is compared against it on
5.1 and 7, together with `Watch-PSScriptBuilderProject`, where
"per command" could tip: the watcher itself resolves its watch paths once in `Start()`, but its
script block runs a cmdlet on every change, so the cost lands per event there. If it does, the
answer is a root determined once per run and passed on, as Invoke-Build does with `$BuildRoot` —
not an exception to the invariant.

## Unresolved Questions

None. Decision, scope and target versions are settled; what remains is the implementation itself.
Everything this document asked for beforehand has been done: the verification on PowerShell 7 that
`AGENTS.md` requires — all nine findings and the class behaviors the design decisions rest on,
measured on 5.1 and on 7.6.10 with identical results; the per-call-site proof for step 10, which
changed that step; the load cost of reading the configuration per call; and the examples affected by
the 2.0.0 base change. What cannot be measured before the work is the comparison of the full
workflow before and after, which the Test Plan carries.

## Revision Log

- 2026-11-06 — Draft. Found on 2026-11-05 while measuring RFC 0027, whose probes ran against the
  previous project's configuration.
- 2026-11-06 — Detail review of release management: the configuration is bound to its file
  (`FromFile`, `FromProjectRoot`, no I/O in the constructor), the options no longer call virtual
  methods from the base constructor, unused manager methods are removed, empty paths fail
  (finding 8), and literal paths are moved to RFC 0030.
- 2026-11-08 — Rewritten around the invariant and the project context: the invariant with the table
  of which part each finding violates, the context as a class with a diagnostic `RootSource`, the
  second question as its own resolution and contract item, input against output as the reason for
  the asymmetry, the completeness argument against a cache with invalidation, the proof that each
  new test fails against the old behavior, and the load-cost measurement. The two phases of the
  earlier draft are dropped; the change is one release.
- 2026-11-08 — Second full review, against the code and against the document itself. Corrected: it
  is eight release cmdlets, not nine; `Get-PSScriptBuilderProjectRoot` must not read the
  configuration, so the root resolution, the configuration and the context are three layers;
  `GetProjectRelativePath` resolves nothing and becomes `GetDisplayPath`; the architecture test's
  rule covers `src/Classes`, since the resolution itself calls the root cmdlet; `RootSource` has two
  reachable values while `-ProjectRoot` is open; the removal of the two static members carries a
  pointer to its open question. Added as finding 9: the module resolves a caller's relative path
  against the project root in ten cmdlets and against the PowerShell location in the two RFC 0028
  touched. Contract item 2 now gives every path one base by its origin — configured paths against
  the project root, the caller's paths against the location — and the documented base change is
  announced with a warning in 1.4.0 and made in 2.0.0. Because the build side reads no configuration
  at all, it resolves its paths at the cmdlet boundary and needs no context; a command given only
  absolute paths keeps working without a project.
- 2026-11-08 — The split over two releases is confirmed and the warning is decided. 1.4.0 carries
  the fix alone, so it reaches the users who pinned themselves to `1.*` — the ones who behaved
  correctly and would otherwise never receive a fix for a silent wrong write that has shipped since
  1.0.0; 2.0.0 carries the base change and the removal of the global variable, where a consumer can
  protect themselves with `-MaximumVersion` or a `#Requires` specification. The warning in 1.4.0
  fires only where the two bases differ, names the parameter, both paths, the version and the step
  that both silences it and is the migration, and warns once per affected parameter per call without
  remembering anything (git's `push.default` and `init.defaultBranch` are the precedent). An opt-in
  switch and a de-duplicating warning are rejected with reasons. The verbose line is decided with
  it: it names the root, its source and the configuration file, the location resolution gets its
  own, and both appear once per command — logging wherever the context is used is rejected, because
  the decision is made once and a line repeated forty times in a build displaces the output that
  carries new information.
- 2026-11-09 — The second resolution is renamed `Resolve-PSScriptBuilderProjectLocation`. What it
  determines is a place, not a target something is sent to, so the earlier
  `…ProjectDestination` carried a connotation of moving that does not apply. The objection against
  "Location" — that it reads as a synonym for the root of an existing project, next to
  `Get-PSScriptBuilderProjectRoot` — does not hold where the name is read: the function is private
  and has one call site, inside `New-PSScriptBuilderConfiguration`, where the surrounding code
  already says that a project is being created. The naming rules for cmdlets (approved verb,
  specific singular noun, Pascal case, module prefix) are met; they govern exported commands, and
  for a private helper the measure is readability at its call site.
- 2026-11-08 — Six contradictions in the text corrected, none of which needed a decision: the
  invariant now says "at most one project" and "every path that comes from the project", because a
  command with only absolute paths needs no project at all; the diagram gives the bump configuration
  its own line, since its paths become absolute when a bump runs and not when the configuration is
  read; "every path in the configuration is absolute" is limited to the paths that are set, as an
  optional one stays empty; the build side's behavior test says that the results are unchanged while
  the output gains the warning; the condition for not warning is that the two bases agree or the
  path is absolute, not that the call comes from the project root — verified on
  `examples/12-full-workflow`, with the other examples still to measure; and step 10 and the
  rationale no longer point at each other. Two further contradictions are left standing and marked:
  they exist only because the base change rides in this document, and the decision about that is now
  an open question of its own.
- 2026-11-09 — The last two contradictions are closed by wording rather than by a decision. The rule
  for path bases now carries its own date: a caller's path is resolved against the PowerShell
  location from 2.0.0 on, and keeps the project root until then, with the warning where the two
  differ. "No path is resolved twice" became "no path is resolved against two bases", with the
  transition warning named as the single exception that is removed in 2.0.0. Splitting the base
  change into its own RFC is therefore no longer a prerequisite for a consistent document, and the
  question is gone; what is left of it is the one practical item of when the fifteen redundant
  resolutions in six classes are deleted.
- 2026-11-09 — Every new element was audited with one question: what does it buy, what is lost
  without it. **The context type is dropped.** The configuration already carries the root it was
  loaded from, so a wrapper around root and configuration prevents no mismatch, and its two extra
  values are read by no class; a command passes the configuration, and `ProjectRoot` and
  `ConfigFilePath` on it are self-description, the way `PathInfo` knows its provider.
  `Resolve-PSScriptBuilderProjectContext` goes with it, having nothing left to assemble — a command
  that needs settings takes two steps instead of three. The criterion for ever introducing a context
  is written down in the Rationale: more than one *kind* of thing has to travel, settings plus a
  service or a sink, with the sink for warnings raised inside classes as the one known candidate.
  **`Get-PSScriptBuilderProjectRoot` returns a `PSScriptBuilderProjectInfo`** holding `Root`,
  `RootSource` and `ConfigFilePath`, with `ToString()` giving the path: the `…Info` suffix is the
  established name for a descriptor with several facets, and `Get-` returning a `…Info` type is the
  PowerShell standard. A plain string was rejected — the provenance decides the remedy, a set root
  is cleared while a discovered one means the wrong directory, and a return type cannot be widened
  later without a break. The second query cmdlet is dropped: Az has one `Get-AzContext`, not two.
  Measured on 5.1 and recorded for the help: the comparison is asymmetric, `-is [string]` is false,
  and `ConvertTo-Json` writes the enum as a number. Verification on PowerShell 7 is deferred and
  still required before implementation.
- 2026-11-09 — Implementation choices are no longer stated as decisions. Step 7 now names only the
  goal — `$Global:PSScriptBuilderProjectRoot` is read in one place, so replacing its storage in
  2.0.0 touches one file (Feathers: Encapsulate Global References) — and leaves the form open: a
  private accessor, a named resolution for the second question, or both. Measured for the record:
  after the fix two places read the variable, this cmdlet and the root resolution, so a named
  resolution alone would not reach the goal, which an earlier wording claimed. The architecture
  test's rule names that one place instead of two cmdlet definitions, and the scope lists the
  encapsulated read instead of a function name.
- 2026-11-09 — Decided: 1.4.0 removes `GetProjectRootedPath` together with the fifteen second
  resolutions in six classes. It was not a free choice — the architecture test of the same release
  forbids the implicit resolution, so the function and its callers go together, and keeping them
  would restore the two-pattern state the one-release decision removed. The open question is gone;
  what it contained — the per-call-site proof that each path is already absolute, with the five
  calls in `PSScriptBuilderBackupManager` and `PSScriptBuilderCollectorBase` line 272 named as the
  untraced ones — now stands in step 10, where the work is described.
- 2026-11-09 — Decided: `-ProjectRoot` ships in 1.4.0, on the eight release cmdlets,
  `Get-PSScriptBuilderConfiguration` and the root query. It is the first input of the precedence
  rule, which contract item 3 now names in order, and `RootSource` has three reachable values
  instead of two. Two facts carried the decision: the release is already a mixed one — its
  unreleased changelog holds two added entries, three changed and thirteen fixed, and RFC 0026
  records that the
  version is a minor *because* of added features — so "a fix release carries only the fix" no longer
  applies; and those nine commands and their nine pages are rewritten in this release anyway, so
  adding the parameter later would open the same files twice. `New-PSScriptBuilderConfiguration`
  keeps `-Path` with no alias: it answers where a project is created, not which one is worked on,
  and an alias would blur the distinction finding 5 is about.
- 2026-11-09 — Decided: `Clear-PSScriptBuilderProjectRoot` ships in 1.4.0, and contract item 7 now
  names asking, setting and removing as the interface. Its justification does not depend on where
  the root is stored — only on `Set-PSScriptBuilderProjectRoot` existing and on there being a way
  back without ending the session, both of which the contract settles; whoever offers setting offers
  removing (`Clear-AzContext`, `kubectl config unset current-context`,
  `gh repo set-default --unset`). Today a user can write `$null` into the deprecated variable
  instead, which cannot be the documented answer in the release that deprecates it. Also recorded
  here: the storage that replaces the global variable in 2.0.0 is **not** decided by this RFC — a
  module-scoped variable is the obvious candidate, and the reason the variable had to be global
  disappears with this fix, since no class reads a root any more (`PSScriptAnalyzerSettings.psd1`
  records that class methods in 5.1 cannot read `$script:` variables). What two loaded module
  versions in one session would then see is unmeasured and belongs to that decision.
- 2026-11-10 — Decided: every removed member of `PSScriptBuilderConfiguration` goes without a
  transitional stub, and the changelog names none of them. What settled it was a gap found while
  checking: SemVer requires a project to declare its public API (item 1, "MUST"), and this one never
  has — `RELEASING.md` names breaking changes without saying what they break, which is why the
  question had no project-sanctioned answer and kept being re-argued. The declaration is therefore
  part of this release (step 13): the exported commands with their parameters, outputs and
  documented behavior, plus the documented members of the types they return; the rest of the class
  surface is visible only because PowerShell cannot hide it. That one rule answers three questions
  at once — no stubs, no changelog entries for class members, and the rework of the configuration
  class is permitted, because its factory methods are not documented members. Because the
  declaration narrows what users could assume since 1.0.0, it is announced in the changelog as a
  rule, without naming members. Rejected on the way: throwing stubs for `new($path)` and `Reset()`
  — a throw in a minor release is itself a break, which is what SemVer reserves for a major, so the
  shape contradicted the premise that the members were never public; and a `-Path` parameter on
  `Get-PSScriptBuilderConfiguration`, which no command could consume and whose realistic purpose
  `-ProjectRoot` already serves.
- 2026-11-10 — The last two open points are decided, and `Unresolved Questions` is empty. Both are
  validation defects found while specifying this change, and one rule settled them: a defect stays
  here when it is fixed in a file this release rewrites anyway and needs no measurement or release
  of its own. The empty configuration option stays on substance as well — measured, the validator
  checks presence and type and never emptiness, and `Path.Combine(root, '')` returns the root, so
  with no `backupPath` configured `-BackupPath $config.Build.BackupPath -EnableBackup` scatters
  backups into the project directory: a silent wrong write, the failure class of this whole RFC.
  The unclear directory failure rides along on the open file alone, which is stated as such.
  `EnsureDirectoryExists` gets both a check that rejects a path that is a file and a wrapped
  `CreateDirectory`; the second was first argued *against*, on the grounds that wrapping would
  hide the cause, until the code showed the opposite — the module's 83 catch blocks name the
  operation and append the original text, so wrapping is the house pattern and covers the cases a
  pre-check cannot reach. Both defects get their own `Fixed` entry.
- 2026-11-10 — The warning in 1.4.0 is dropped, and the release plan is recorded. The argument that
  had carried the warning turned out to be wrong: a warning is not "the only channel that reaches a
  CI script", because a warning in a CI log is read no better than a changelog. This module runs
  unattended, so what protects that user is the version number they can pin before the change —
  SemVer's own instrument, and what `dotnet`, npm and Terraform rely on for path and output
  changes. Git's `push.default` remains the counter-example and marks where a warning pays: an
  interactive tool. 1.4.0 therefore changes nothing about the base and says nothing in the code;
  the `Deprecated` entry is the notice, and 2.0.0's `Changed` entry plus a migration note carry the
  change. Contract item 2 loses the warning and the exception for a path resolved against two
  bases, and the transition section now states what had been implicit: after 1.4.0 the contract
  holds except for item 2's caller-path half.

  With the warning gone, nothing couples the two releases, and the plan is: 1.4.0 the compatible
  fixes, 2.0.0 only what breaks. RFC 0030 moves to the 1.x line, because RFC 0028 made the same
  change for one cmdlet and this release ships it as a `Fixed` entry — the same defect cannot be a
  fix in one release and a breaking change in the next, and a user pinned to `1.*` would otherwise
  never receive a fix for a build that succeeds with empty output. That also settles the order
  between the two documents.
- 2026-11-11 — RFC 0030 is written, and measuring its findings corrected a claim this document
  carried: a build in a directory such as `App[1]` does not simply succeed with empty output. The
  arrangement decides — without a matching neighbour it fails with "Path not found"; with one and a
  bracketed output path it writes the file and fails reading it back; only with a matching
  neighbour and an unbracketed output path does it run to the end, and then it warns and marks the
  gap in the output. The relationship section is corrected accordingly: that defect is not of the
  same failure class as this RFC's findings, which are silent. The placement of RFC 0030 on the 1.x
  line is unaffected, because it rests on reachability and on SemVer, not on severity.
- 2026-11-10 — Contract item 7 now says what 2.0.0 removes: the variable, not the session root,
  which goes on applying for the session, held inside the module and reachable only through the
  three cmdlets. Without that sentence a reader could conclude the session root disappears with the
  variable, and `Clear-PSScriptBuilderProjectRoot` would rest on an unstated assumption; the
  mechanism that holds it stays a decision of that release. Items 2, 4 and 7, each of which carried
  several statements in one paragraph, are now written as bullets, the way the implementation steps
  already are.

- 2026-11-14 — Every finding re-measured, this time on both versions, after PowerShell 7.6.10 was
  installed from the MSI. Twenty-one checks with expected values fixed in advance — four for
  finding 1, six for finding 2, one for 3, two for 4, three for 5, one for 7, two for 8 and two for
  9 — confirmed all nine findings, and 5.1 and 7 behaved identically in every one. Finding 5 is the
  one worth naming again: in an empty directory, `New-PSScriptBuilderConfiguration -Force` resets
  the *other* project''s configuration to the defaults and creates none where it was called.
  Two corrections came out of the pass:
  - **Finding 9 named ten cmdlets; it is eleven.** `Get-PSScriptBuilderTemplateAnalysis` resolves a
    relative path against the project root as well, and says so in its own help. The other ten were
    checked one by one, and there are no further ones.
  - **The measurement basis was wrong.** The document claimed all findings were measured on 5.1 and
    7 while listing the PowerShell 7 verification as outstanding in two other places; PowerShell 7
    was not installed at the time. That verification is now done, including the five class behaviors
    the design decisions rest on: an overridden method called from a base constructor runs before
    the derived body, a property stays writable from outside, the comparison with a string is
    asymmetric, `-is [string]` is false, and `ConvertTo-Json` writes the enum as a number — all of
    it identical on both versions. What remains unmeasured is the load cost, which the test plan
    now states as a task rather than as a result.

- 2026-11-15 — The per-call-site proof that step 10 asked for was carried out, and it changed the
  step. Each of the calls in the six build-side classes was traced, and they are not alike:
  - **Eleven are a second resolution and go.** For `PSScriptBuilderBackupManager` this was measured
    rather than argued: `CreateBackup` has one caller in `src`, and with relative input both values
    arrive rooted, because the cmdlet resolves before the orchestrator exists. Lines 108, 109 and
    155 sit in `RestoreBackup` and `HasBackup`, which have no caller in `src` at all — what to do
    with those two is still open.
  - **Three are the only resolution.** The collector receives relative values even on the
    documented path, because `New-PSScriptBuilderCollector` resolves them to validate them and
    stores what the caller wrote. Deleting those three would break every relative `-IncludePath`,
    `-ExcludePath` and `-IncludeFile`.
  - **The count was wrong:** fourteen calls, not fifteen.
  The collector turned out to be a case the plan did not have: an object the caller holds between
  two commands, not a class that lives inside one call. It has its own section now. Measured, the
  same collector object serves project A and then B, because it resolves when it collects — storing
  absolute paths instead would tie it to the project it was created in, which is finding 1 in a new
  place. Its signatures therefore stay as they are; what changes is that the root is fetched once
  per collection instead of inside the loops, and step 12 names the collector as its one exception
  instead of pretending the rule has none.

  Two further corrections:
  - **`GetRootedPath([string] $path, [string] $projectRoot)` is named.** Step 10 deleted
    `GetProjectRootedPath` without saying what the eleven cmdlets of step 9 should resolve with;
    without a named method each of them would carry the same four lines, which is the defect step 10
    removes elsewhere.
  - **Nothing is justified by being documented any more.** Four justifications rested on it — why
    the base stays until 2.0.0, why the base change needs a major, why the members of a class may go
    without stubs, and the declaration of the public API itself. They now rest on behavior and on
    what the module exports: a sentence in a guide must not decide what is frozen. The declaration
    draws its line at the exported commands and the properties of what they return; class methods
    are outside it, which is what permits the rework in step 2. Earlier revision-log entries are
    left as they were, because they record what was decided at the time.

  The `op_Addition` defect found while tracing — `-ExcludePath` leaving exactly one file together
  with an `-IncludeFile` breaks the build on both versions — went into RFC 0030, which rewrites that
  method anyway.

  Measured on the same day, and entered where they belong:
  - **The load cost.** A configuration load takes 4.2 ms on 5.1 and 4.9 ms on 7.6.10, a cache hit
    0.10 and 0.06 ms. It falls on the eight release cmdlets only, because
    `Get-PSScriptBuilderConfiguration` calls the constructor and therefore pays it already today;
    example 12 grows by some 8 to 10 ms. The watcher does not pay per event.
  - **Finding 3 has a second half.** While the release cmdlets write the file from the first load,
    `Get-PSScriptBuilderConfiguration` reports the new path — the query confirms a change that does
    not apply. That turns the finding from ineffective into misleading.
  - **The examples.** All seventeen measured: one file, three lines, and only when started from
    outside its own folder. The remaining sixteen already pass absolute paths.
  - Four counts and headings were corrected on the way: the members step 2 removes are six plus two
    constructors rather than five, one sentence still said ten cmdlets instead of eleven, the test
    plan did not know the collector exception, and two headings claimed that no class resolves a
    path at all.

# Setting Up Release Management

This tutorial walks you through setting up PSScriptBuilder's release management system. You
will create a release data file, configure which files receive automatic version updates,
and create a dedicated release script alongside your existing build script.

Along the way, you'll start with the simplest method for updating a file automatically and
discover it doesn't hold up on its own. The obvious next step — switching to a different method entirely — turns out to have its
own gap, one that only shows up on a first release. The fix is using both together. Seeing each
limitation firsthand makes the reasoning stick far better than reading about it upfront.

By the end, running a single command will bump the version, update all registered files, and
produce a correctly versioned build output — on every release, not just the first.

**Prerequisites:**

- A working PSScriptBuilder project — see [Building Your First Project](building-your-first-project.md)

---

## The Two Release Files

Release management is built around two files, which you'll create over the next two steps:

| File | Purpose |
|---|---|
| `psscriptbuilder.releasedata.json` | Stores the current version and release metadata |
| `psscriptbuilder.bumpconfig.json` | Defines which project files get updated, and how |

---

## 1. Create the Release Data File

The release data file `psscriptbuilder.releasedata.json` is the central store for your
project's current version and release metadata. All other release management steps read from
and write to this file.

Create it by running `New-PSScriptBuilderReleaseData`. Like every PSScriptBuilder cmdlet, it
only works once the module has been imported. Open a PowerShell session in your project
directory and import it:

```powershell
using module PSScriptBuilder
```

Then run the cmdlet:

```powershell
New-PSScriptBuilderReleaseData
```

Running the cmdlet writes the file to the path configured in `psscriptbuilder.config.json`'s
`release.dataFile` field.

Unless you've changed it, that's `build\Release\psscriptbuilder.releasedata.json`. If that
directory doesn't exist yet, PSScriptBuilder creates it automatically.

Everything in the file starts at its initial value, always the same fixed default regardless
of your project's actual state.

The version deserves a second look before you continue: unlike the build number and
timestamps, which simply catch up on the next release, the version follows semantic
versioning — once a release is tagged or published, others rely on major/minor/patch changes
to mean something specific. Starting it at the wrong number — `0.1.0` for a project that
already has real releases out — is not something that quietly corrects itself later.

If your project already has an established version, edit `psscriptbuilder.releasedata.json`
and set the `"major"`, `"minor"`, `"patch"`, and `"full"` fields under `"version"` to match
your current version before continuing.

---

## 2. Create the Bump Configuration

The bump configuration file `psscriptbuilder.bumpconfig.json` defines which project files
get updated, and how.

Unlike the release data file, there is no cmdlet to create the bump configuration file —
create it yourself at the path set in `psscriptbuilder.config.json`'s `release.bumpConfigFile`
field.

By default, that's `build\Release\psscriptbuilder.bumpconfig.json`:

```json title="psscriptbuilder.bumpconfig.json"
{
    "bumpFiles": []
}
```

For each file that should receive version updates, add an entry to `bumpFiles`.

In this tutorial, that file is `HRTools.ps1.template` — the same template you wrote in
Building Your First Project. Since every build regenerates the output from this template,
embedding the version and build timestamp directly in it means every future build carries the
current release information automatically, without touching anything else:

```json title="psscriptbuilder.bumpconfig.json"
{
    "bumpFiles": [
        {
            "description": "Output template — inject version and build metadata",
            "path": "build\\Templates\\HRTools.ps1.template",
            "tokens": ["VERSION", "BUILD_TIMESTAMP"]
        }
    ]
}
```

Here's what each field does:

- **`description`** — sets the text that identifies this entry in the bump result (optional,
  but recommended)
- **`path`** — sets the file this entry modifies: `build\Templates\HRTools.ps1.template`
- **`tokens`** — defines which values get written into that file: `VERSION` and
  `BUILD_TIMESTAMP`

An entry like this — with just a `tokens` array — is PSScriptBuilder's **Simple Token Mode**.

For PSScriptBuilder to know *where* in the file each value belongs, the file itself must
contain a matching placeholder for every name listed in `tokens` — written as `{{TOKEN_NAME}}`.
This entry lists `VERSION` and `BUILD_TIMESTAMP`, so add a line for each at the top of the
template:

```powershell title="build\Templates\HRTools.ps1.template"
# Version: {{VERSION}}
# Built: {{BUILD_TIMESTAMP}}

{{ENUM_DEFINITIONS}}

{{CLASS_DEFINITIONS}}

{{FUNCTION_DEFINITIONS}}
```

With the release data file and bump configuration in place, nothing updates automatically yet
— something needs to trigger the bump and the build together. That's what you'll create next.

!!! note "Available tokens"
    PSScriptBuilder provides tokens for version components, build metadata, and Git details.
    To see all available tokens, run `Get-PSScriptBuilderReleaseDataTokens`.
    For the full token list with descriptions, see the [Release Management Guide](../guides/release-management.md).

---

## 3. Create a Release Script

A release bumps the version, updates every registered file, and produces the build — all in
one command, rather than three separate ones.

Rather than adding this logic to `Build-HRTools.ps1` itself, create a separate script for it.
Build and release are different actions with different consequences: a build is safe to run at
any time, but a release changes the version and rewrites files on disk. Keeping them as
separate scripts means running a release is always a deliberate, explicit choice — you run
`Release-HRTools.ps1` instead of `Build-HRTools.ps1` — rather than a flag you could pass by
accident, and `Build-HRTools.ps1` never needs to know release management exists at all.

Bumping the version also means deciding which part to bump — major, minor, or patch, per the
semantic versioning already covered in
[Create the Release Data File](#1-create-the-release-data-file) — so `-Major`, `-Minor`, and
`-Patch` are three switches for that choice.

Create `Release-HRTools.ps1`:

```powershell title="Release-HRTools.ps1"
using module PSScriptBuilder

[CmdletBinding(DefaultParameterSetName = 'None')]
param(
    [Parameter(ParameterSetName = 'Major')]
    [switch] $Major,

    [Parameter(ParameterSetName = 'Minor')]
    [switch] $Minor,

    [Parameter(ParameterSetName = 'Patch')]
    [switch] $Patch
)

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$releaseParams = @{
    UpdateBuildDetails = $true
}

switch ($PSCmdlet.ParameterSetName) {
    'Major' { $releaseParams.Major = $true }
    'Minor' { $releaseParams.Minor = $true }
    'Patch' { $releaseParams.Patch = $true }
}

$releaseDataResult = Update-PSScriptBuilderReleaseData @releaseParams
$releaseDataResult | Format-PSScriptBuilderReleaseDataResult

$bumpResult = Update-PSScriptBuilderBumpFiles
$bumpResult | Format-PSScriptBuilderBumpResult

. "$PSScriptRoot\Build-HRTools.ps1"
```

What each release step does:

- `Update-PSScriptBuilderReleaseData` — bumps the version in `psscriptbuilder.releasedata.json`
  and records the current build timestamp (`-UpdateBuildDetails`)
- `Update-PSScriptBuilderBumpFiles` — reads the updated release data and applies all
  registered replacements across every file in `psscriptbuilder.bumpconfig.json`
- `. "$PSScriptRoot\Build-HRTools.ps1"` — runs the existing build script, producing the output
  with the version and files now up to date

The order matters:

1. Release data is updated first
2. Bump files are processed next
3. `Build-HRTools.ps1` runs last

**Why it matters:** Swap 2 and 3, and release management tokens such as `{{VERSION}}` would
still be present when the build runs. The build validates that all `{{...}}` patterns are
expected — and since it only recognizes the placeholders it manages itself, any remaining
release management placeholder would cause a validation error.

---

## 4. Run a Release Build

With the release script in place, running a release is now a single command. Try it with a
patch release — the smallest kind of version bump:

```powershell
.\Release-HRTools.ps1 -Patch
```

You will see three blocks of output:

**1. Release data result** — the new version and the metadata that was recorded:

```text title="Release data result"
Category : Version

  Property  : patch
  Old Value : 0
  New Value : 1

  Property  : full
  Old Value : 0.1.0
  New Value : 0.1.1

...
```

**2. Bump files result** — every changed file, with each replacement listed:

```text title="Bump files result"
File : build\Templates\HRTools.ps1.template

  Token     : VERSION
  Old Value : {{VERSION}}
  New Value : 0.1.1

  Token     : BUILD_TIMESTAMP
  Old Value : {{BUILD_TIMESTAMP}}
  New Value : 2026-08-27T10:52:53Z
```

**3. Build result** — the output path, file size, build time, and component counts:

```text title="Build result"
WARNING: 5 cross-collector dependency(s) detected. Verify template placeholder order. Run with -Verbose for details.

Build Summary
  Output : build\Output\HRTools.ps1
  Size   : 1.95 KB
  Time   : 770.56 ms

Components
  Enums     : 2
  Classes   : 3
  Functions : 1
  Total     : 6
```

To see the effect in the actual file, open the template — the placeholders shown above are
now real values:

```powershell title="build\Templates\HRTools.ps1.template"
# Version: 0.1.1
# Built: 2026-08-27T10:52:53Z
```

---

## 5. Run a Second Release Build

Run another release on the same template — another patch release, exactly like the first:

```powershell
.\Release-HRTools.ps1 -Patch
```

The version and build metadata update correctly again, but the bump files result now reads:

```text title="Expected output"
WARNING: Bump file '...\build\Templates\HRTools.ps1.template' is configured for release data substitution, but none of its patterns matched the current content - nothing was updated. If this file was already bumped by a prior run, add a Regex-mode fallback entry (Mixed Bump Mode) so subsequent runs keep matching.

No changes were made.
```

And the template is exactly what it was after the first release:

```powershell title="build\Templates\HRTools.ps1.template"
# Version: 0.1.1
# Built: 2026-08-27T10:52:53Z
```

Identical to before the release — that's the point. This is a real limitation of Simple
Token Mode: `{{VERSION}}` and `{{BUILD_TIMESTAMP}}` only ever existed in the file until the first
release replaced them with real values. From the second release onward, there is nothing left
to find — the placeholders are gone — so `Update-PSScriptBuilderBumpFiles` has nothing to do
for this file, which is exactly what "No changes were made" reports.

This is also exactly the situation the warning above is for: every entry configured for this
file failed to match. The next section fixes this permanently.

`psscriptbuilder.releasedata.json` itself is unaffected by any of this: it doesn't rely on
placeholders, so it keeps updating correctly on every release regardless.

---

## 6. Keep the Template Up to Date on Every Release

To fix this permanently, add a second entry for the same file to
`psscriptbuilder.bumpconfig.json` — this time using a different approach that looks for a
pattern instead of a literal placeholder marker, so it keeps working after that marker is gone:

```json title="psscriptbuilder.bumpconfig.json"
{
    "bumpFiles": [
        {
            "description": "Output template — inject version and build metadata (first release)",
            "path": "build\\Templates\\HRTools.ps1.template",
            "tokens": ["VERSION", "BUILD_TIMESTAMP"]
        },
        {
            "description": "Output template — update version and build metadata (every later release)",
            "path": "build\\Templates\\HRTools.ps1.template",
            "items": [
                {
                    "pattern": "# Version: ({REGEX_VERSION})",
                    "tokens": ["VERSION"]
                },
                {
                    "pattern": "# Built: ({REGEX_BUILD_TIMESTAMP})",
                    "tokens": ["BUILD_TIMESTAMP"]
                }
            ]
        }
    ]
}
```

Here's what each field does:

- **`description`** — same as the first entry: identifies this entry in the bump result
- **`path`** — the same file the `tokens` entry updates
- **`items`** — one entry per value to replace: a `pattern` (regex, with the replaced part in
  parentheses) and `tokens` (which value fills it in)

An entry like this — with an `items` array instead of `tokens` — is PSScriptBuilder's
**Regex Pattern Mode**.

The difference is *what* each mode looks for. Simple Token Mode looks for a literal marker —
`{{VERSION}}` — which is why it stops working once that marker is gone. Regex Pattern Mode
instead looks for a *pattern*: a description of where the value always sits in the line,
regardless of what that value currently is.

You do not need to write that pattern yourself: every release token has a matching
`REGEX_*` counterpart that PSScriptBuilder expands into a ready-made regular expression.
`{REGEX_VERSION}` and `{REGEX_BUILD_TIMESTAMP}` are the ones used here — one recognizes a
version number like `0.1.3`, the other a timestamp like `2026-08-27T10:53:25Z`.

Your job is only to say *where* in the line that value sits, by wrapping the placeholder in
parentheses: everything inside the parentheses is the part that gets replaced; everything
outside is only there to help PSScriptBuilder find the right spot in the line — it has to
match, but it is never changed itself.

Both entries point at the same file and both stay. Using both together like this is
PSScriptBuilder's **Mixed Mode**.

The `tokens` entry from [Create the Bump Configuration](#2-create-the-bump-configuration)
already did its one job — replacing the literal placeholders during
[Run a Release Build](#4-run-a-release-build)'s first release — and has nothing left to do for
this project from here on.

The `items` entry is what actually keeps the template updated on every release after that, as
you just saw.

The template is still stuck at 0.1.1 from the first release — the second didn't touch it.
Meanwhile, the release data file moved on regardless: the second release already bumped it to
0.1.2. Any build
produced in between would have embedded that stale 0.1.1, silently out of sync with the
official 0.1.2 release.

The lesson carries beyond this one file: for any file you register going forward, use
Mixed Mode from the start, rather than beginning with Simple Token Mode alone and hitting
this same gap again.

Run the release again to see the fix in action:

```powershell
.\Release-HRTools.ps1 -Patch
```

```text title="Expected output"
File : build\Templates\HRTools.ps1.template

  Pattern   : # Version: ({REGEX_VERSION})
  Token     : VERSION
  Old Value : # Version: 0.1.1
  New Value : # Version: 0.1.3

  Pattern   : # Built: ({REGEX_BUILD_TIMESTAMP})
  Token     : BUILD_TIMESTAMP
  Old Value : # Built: 2026-08-27T10:52:53Z
  New Value : # Built: 2026-08-27T10:53:25Z
```

The version advanced to 0.1.3, and the template caught up from 0.1.1 straight to the current
value — skipping 0.1.2 entirely. That gap only exists because this tutorial deliberately
introduced Mixed Mode two releases late; with both entries in place from the start, Simple
Token Mode handles the first release and Regex Pattern Mode every one after, so no file ever
falls behind like this.

Open the template to see the actual file:

```powershell title="build\Templates\HRTools.ps1.template — after"
# Version: 0.1.3
# Built: 2026-08-27T10:53:25Z
```

From here on, every future release updates the template the same way, automatically — no
further configuration needed.

---

## Summary

You now have a complete release management setup: `psscriptbuilder.releasedata.json` tracks
the version and build metadata, `psscriptbuilder.bumpconfig.json` keeps `HRTools.ps1.template`
in sync with that data, and `Release-HRTools.ps1` ties both to a build — calling
`Build-HRTools.ps1` once both files are up to date.

A single command now bumps the version, updates every registered file, and produces a
correctly versioned build output.

Along the way, you also saw why Simple Token Mode alone isn't enough — it only ever fires on a
file's first release — and fixed that permanently with Mixed Mode, pairing it with Regex
Pattern Mode for every release after.

In short: version bumping and file updates only stay correct together when both keep working
on every release, not just the first — that's what Mixed Mode guarantees, and why it belongs on
every file you register from here on.

---

## See Also

- [Release Management Guide](../guides/release-management.md) — full token reference and advanced configuration
- [Configuration Guide](../guides/configuration.md#release-options-reference) — `release.dataFile` and `release.bumpConfigFile` settings

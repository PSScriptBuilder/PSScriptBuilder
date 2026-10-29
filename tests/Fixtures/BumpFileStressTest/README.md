# BumpFileStressTest fixture

This is a **stress-test fixture**, not a numbered `examples/` entry — see
`internal/test-strategy.md`'s "Integration Tests" section for the distinction. It exists purely to
maximize interaction surface across every bump-mode combination at once, run over multiple
consecutive releases, for permanent regression coverage; it is not meant to teach one concept at a
time and is not listed in `examples/README.md`.

## What it covers

Five bump targets covering every combination RFC 0019 cares about:

| Target | Mode | Fallback? | Behavior from run 2 onward |
|---|---|---|---|
| `build\Output\Manifest.psd1` | Simple (`{{VERSION}}`) | none | goes stale -> **warns** |
| `CHANGELOG.md` | Placeholder (`{{VERSION}}`, `{{BUILD_DATE}}`) | none | goes stale -> **warns** |
| `config\app.json` | Regex (`"apiVersion": "(...)"`), self-sustaining | n/a | always matches current content -> never warns |
| `build\Output\Manifest2.psd1` | Mixed Bump Mode (Placeholder + Regex pair, two separate `bumpFiles` entries for the same path) | present | never warns |
| `build\Templates\Template.ps1.template` | Simple, 3 tokens; Regex fallback for `BUILD_NUMBER` only | partial | `VERSION`/`BUILD_DATE` go stale but the fallback for `BUILD_NUMBER` keeps the file-level check "changed" -> **never warns**, demonstrating RFC 0019's documented "partial staleness can be masked" limitation as expected behavior, not a bug |

`Run-StressTest.ps1` calls `Update-PSScriptBuilderReleaseData -Patch -UpdateBuildDetails` +
`Update-PSScriptBuilderBumpFiles` three times in a row (not once), capturing warnings via
`-WarningVariable` each time, to show the actual multi-run behavior instead of a single snapshot.

## Why this exists

Emergent, multi-run interaction bugs (like RFC 0019's silent zero-match bump file, and the
multiple-Using-collector issue the sibling `TemplateStressTest` fixture covers) tend to surface
only through large, dense scratch projects, not the narrower Unit/Integration suite. This fixture
formalizes that density permanently instead of rebuilding it before every release.

## How to run manually

```powershell
.\Run-StressTest.ps1
```

To run it again from a clean state:

```powershell
.\Reset-StressTest.ps1
.\Run-StressTest.ps1
```

## Automated coverage

`tests/Integration/ReleaseManagement/PSScriptBuilderBumpFileStressTest.Integration.Tests.ps1`
exercises this fixture (copied into `$TestDrive` per `Context`, per the established Integration
test convention) as part of the regular Pester suite.

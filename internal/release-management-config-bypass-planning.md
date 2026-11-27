# Planning: Config-Free Release Management

## Background

`Invoke-PSScriptBuilderBuild` accepts every build path (`-TemplatePath`, `-OutputPath`,
`-BackupPath`, etc.) as a direct cmdlet parameter — a build can run without
`psscriptbuilder.config.json` existing at all (see `examples.md` Example 02).

Release management has no equivalent. `New-PSScriptBuilderReleaseData`,
`Update-PSScriptBuilderReleaseData`, and `Update-PSScriptBuilderBumpFiles` all construct a
`PSScriptBuilderReleaseManagementOrchestrator`, which has a single, parameterless constructor
that unconditionally reads `[PSScriptBuilderConfiguration]::GetCurrent()`. There is no
constructor overload and no cmdlet parameter that accepts an explicit data-file or
bump-config-file path. The only override mechanism found is
`[PSScriptBuilderConfiguration]::Set($customConfig)` — a static method on the configuration
class itself, documented for "testing or when you need to use an alternate configuration," but
not exposed as a first-class, discoverable cmdlet parameter.

Verified while writing the Configuration Guide's introduction (2026-08-27): confirmed by reading
`Update-PSScriptBuilderReleaseData.ps1` (`.NOTES: Requires configuration to be loaded`),
`Update-PSScriptBuilderBumpFiles.ps1` (`param()` — zero parameters), and
`PSScriptBuilderReleaseManagementOrchestrator.ps1` line 112 (single no-args constructor).

## Problem

This asymmetry creates real friction, not just an API inconsistency:

- **Onboarding / demos.** Build has a genuine zero-config path, useful for a first try or a
  minimal example. Release management has no equivalent — trying it out at all requires first
  creating a full `psscriptbuilder.config.json`, even if only the two `release.*` fields matter.
- **Multi-environment / multi-branch setups.** Pointing release management at a different data
  file per branch or environment currently means maintaining and swapping multiple complete
  config files, or reaching for `[PSScriptBuilderConfiguration]::Set()`.
- **Testability.** A test that wants to exercise a release cmdlet against a throwaway data file
  cannot pass `-DataFile "test.json"` — it must go through the config file or the `Set()`
  workaround, neither of which is a normal, discoverable cmdlet-parameter pattern.

## Goal

Give the release management cmdlets a way to bypass the configuration file, analogous to how
`Invoke-PSScriptBuilderBuild` already works — without requiring `[PSScriptBuilderConfiguration]::Set()`.

## Scope Considerations

- Cmdlets likely affected: `New-PSScriptBuilderReleaseData`, `Get-PSScriptBuilderReleaseData`,
  `Update-PSScriptBuilderReleaseData`, `Update-PSScriptBuilderBumpFiles`,
  `Get-PSScriptBuilderReleaseDataTokens`.
- `PSScriptBuilderReleaseManagementOrchestrator` would need a second constructor overload
  accepting explicit paths, instead of always pulling from
  `[PSScriptBuilderConfiguration]::GetCurrent()`.
- `[PSScriptBuilderConfiguration]::Set()` already establishes that overriding the loaded
  configuration is a supported idea in principle — this would formalize the same capability as
  a documented, per-cmdlet parameter rather than a class-level override.

## Open Questions

- Parameter naming: `-DataFile` / `-BumpConfigFile`, or something consistent with
  `Get-PSScriptBuilderConfiguration -Flat`'s `ReleaseDataFile` / `ReleaseBumpConfigFile` names.
- Whether bump-file schema/validation behaves any differently when running without a loaded
  configuration object.
- Whether to change all affected cmdlets together or phase the work.

## Status

Identified during the documentation review session on 2026-08-27. Not yet scoped or implemented.

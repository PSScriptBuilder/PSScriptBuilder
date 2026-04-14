# TODO

## Planned Features

- **Automatic ReleaseNotes extraction** — extend the Release build (`Build-Module.ps1 -Release`) to automatically extract the current version's section from `CHANGELOG.md` and write it to `ReleaseNotes` in `PSScriptBuilder.psd1`. Single source of truth: CHANGELOG feeds both the `.psd1` and `release_notes.md` (GitHub Release). Natural candidate for a PSScriptBuilder feature itself (CHANGELOG token support in build pipeline).
- **Website download page** — hybrid static link (releases/latest fallback button) + dynamic GitHub API table (all releases with version, date, download link) via `https://api.github.com/repos/PSScriptBuilder/PSScriptBuilder/releases`


## Bugs
- [ ] None reported yet

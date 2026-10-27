# Git Workflow

## Branches

| Branch | Purpose |
|---|---|
| `main` | Last published version. Always stable. |
| `development` | Active development. Carries the next planned version. |
| `chore/*` | Non-code changes (website, docs, config) directly on `main`. |
| `hotfix/docs-*` | Documentation/website hotfixes directly on `main`. |

## Feature Development on `development`

1. Create and commit new files
2. Update `FunctionsToExport` in the `.psd1`
3. Bump the version to the next minor version (e.g. `1.1.0` → `1.2.0`)
4. Run and validate the build (`.\Build-Module.ps1`)
5. Commit and push

`development` always carries the **next planned** version — no last-minute bump just before the release.

## Release

1. Create a Merge Request from `development` to `main` via GitLab
2. GitHub is updated automatically as a mirror
3. `development` is kept alive (do not delete the branch)

## Documentation/Website Hotfix (without a Feature Release)

When a documentation or website change needs to go live without triggering a feature release:

1. Branch `hotfix/docs-<description>` off `main`
2. Commit and push the changes
3. Merge Request `hotfix/docs-*` → `main` (change goes live)
4. Merge the same branch into `development` (do not lose the changes)
5. Delete the hotfix branch

## Chore (Non-Code Changes)

For changes that are not code (website, docs, config) and should go live immediately:

1. `git checkout main && git pull origin main`
2. `git checkout -b chore/<description>`
3. Commit and push the changes
4. Merge Request `chore/*` → `main` via GitLab (enable "Delete source branch")
5. After merge, sync `development`:
   ```powershell
   git checkout main
   git pull origin main
   git checkout development
   git merge main
   git push origin development
   ```

## Versioning Strategy

- `main` = last **published** version
- `development` = next **planned** version
- Semantic Versioning: `MAJOR.MINOR.PATCH`
  - `PATCH`: Bug fixes
  - `MINOR`: New features (backwards compatible)
  - `MAJOR`: Breaking changes

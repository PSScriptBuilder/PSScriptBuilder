# CI/CD Publishing Strategy

## Übersicht

Dieses Dokument beschreibt die Strategie, PSScriptBuilder automatisiert auf **GitHub** und in der **PowerShell Gallery** zu veröffentlichen.

### Ziele

| Ziel | Umsetzung |
|------|-----------|
| GitLab bleibt die einzige Entwicklungsquelle | Kein Workflow-Wechsel |
| GitHub erhält den aktuellen Stand | Automatischer Orphan-Push bei jedem Merge nach main |
| Commit-History bleibt verborgen | GitHub zeigt dauerhaft genau 1 Commit ("Latest") |
| PowerShell Gallery erhält jede Version | Automatisches `Publish-Module` bei Git-Tag |
| Kein manueller Aufwand | Merge nach main bzw. Tag-Push löst alles aus |

---

## Konzept: Orphan-Push zu GitHub

Ein **Orphan Branch** hat keine Eltern-Commits – er ist wie ein frisch erstelltes Repository. Durch Force-Push zu GitHub wird die bisherige History dort vollständig ersetzt.

**Ablauf bei jedem Merge nach main:**

```
GitLab:   C1 → C2 → C3 → ... → C200   (vollständige History, bleibt erhalten)
                                   │
                                   ▼ Orphan-Push (bei jedem Merge nach main)
GitHub:   "Latest"                     (ein einziger Commit, wird überschrieben)
```

GitHub zeigt **dauerhaft genau einen Commit** — niemals die interne Entwicklungshistorie.

Bei Einführung von Tags (zukünftig) akkumulieren sich Release-Commits:

```
GitHub:   "Release v1.0.0" → "Release v1.1.0" → "Release v1.2.0"
```

---

## Einmalige Einrichtung

### 1. GitHub Repository erstellen

1. Auf **github.com** anmelden
2. Neues Repository erstellen: `PSScriptBuilder`
3. **Leer lassen** – kein README, keine .gitignore, keine Lizenz
4. Sichtbarkeit: Public (für GitHub Pages und PSGallery-Links)

### 2. GitHub Personal Access Token erstellen

1. GitHub → **Settings → Developer Settings → Personal Access Tokens → Tokens (classic)**
2. **Generate new token (classic)** klicken
3. Einstellungen:
   - Note: `PSScriptBuilder GitLab CI`
   - Expiration: nach Bedarf (z.B. 1 Jahr)
   - Scopes: `repo` (Full control of private repositories) aktivieren
4. Token generieren und **sofort kopieren** (wird nur einmal angezeigt!)

### 3. GitHub Token in GitLab hinterlegen

1. GitLab → Projekt → **Settings → CI/CD → Variables**
2. **Add variable** klicken:
   - Key: `GITHUB_TOKEN`
   - Value: der kopierte GitHub-Token
   - Type: **Variable**
   - Flags: **Mask variable** ✅, **Protect variable** ✅
3. Speichern

### 4. PowerShell Gallery API Key erstellen

1. Auf **powershellgallery.com** anmelden (Microsoft-Konto)
2. **Account → API Keys → Create**
3. Einstellungen:
   - Key Name: `PSScriptBuilder CI`
   - Expiration: nach Bedarf
   - Glob Pattern: `PSScriptBuilder`
4. Key generieren und **sofort kopieren**

### 5. Gallery API Key in GitLab hinterlegen

1. GitLab → Projekt → **Settings → CI/CD → Variables**
2. **Add variable** klicken:
   - Key: `PSGALLERY_API_KEY`
   - Value: der kopierte Gallery-Key
   - Type: **Variable**
   - Flags: **Mask variable** ✅, **Protect variable** ✅
3. Speichern

### 6. GitHub als Remote lokal hinzufügen (einmalig)

```powershell
git remote add github https://github.com/PSScriptBuilder/PSScriptBuilder.git
```

---

## Die `.gitlab-ci.yml`

Datei im Root des Projekts.

```yaml
# .gitlab-ci.yml

stages:
  - test
  - secret-detection
  - mirror
  - deploy

variables:
  SECRET_DETECTION_ENABLED: 'true'

include:
  - template: Security/Secret-Detection.gitlab-ci.yml

# Run Pester tests on every push to main and on version tags (e.g. v1.0.0).
# Tests must pass before the mirror stage runs.
pester-tests:
  stage: test
  image: mcr.microsoft.com/powershell:lts
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  script:
    - pwsh -Command "Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck"
    - pwsh -File tests/Invoke-Tests.ps1 -Suite All

secret_detection:
  stage: secret-detection

# Push the current state to the GitHub mirror on every merge to main,
# and push a tagged release commit on version tags (e.g. v1.0.0).
# Creates an orphan branch (no commit history) and force-pushes it.
# GitHub will always show exactly one commit per merge, or a release commit per tag.
mirror-to-github:
  stage: mirror
  image: bitnami/git:latest
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  script:
    - git config user.email "ci@psscriptbuilder.com"
    - git config user.name "PSScriptBuilder CI"
    - git remote add github https://x-access-token:${GITHUB_TOKEN}@github.com/PSScriptBuilder/PSScriptBuilder.git
    - git checkout --orphan mirror-snapshot
    - git add -A
    - |
      if [ -n "$CI_COMMIT_TAG" ]; then
        git commit -m "Release $CI_COMMIT_TAG"
        git push github mirror-snapshot:main --force
        git tag -f $CI_COMMIT_TAG
        git push github $CI_COMMIT_TAG
      else
        git commit -m "Latest"
        git push github mirror-snapshot:main --force
      fi

# Trigger GitHub Pages deployment when website/** has changed.
# Runs after mirror-to-github to ensure GitHub has the latest code before deploying.
trigger-github-pages:
  stage: deploy
  image: bitnami/git:latest
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      changes:
        - website/**
  script:
    - |
      curl --fail -X POST \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/PSScriptBuilder/PSScriptBuilder/actions/workflows/deploy-pages.yml/dispatches \
        -d '{"ref":"main"}'
```

---

## Mirror auslösen

Der Mirror wird automatisch bei jedem Merge nach `main` ausgelöst — kein manueller Eingriff nötig.

**Was passiert bei einem Merge nach main:**

```
git merge development → main  (auf GitLab)
        │
        ▼
GitLab Pipeline startet
        │
        └─► pester-tests → mirror-to-github
              1. Orphan-Branch erstellen
              2. Aktuellen Stand committen ("Latest")
              3. Force-Push zu GitHub main
              └─► GitHub zeigt: 1 Commit "Latest"
                  GitHub Actions deploy-pages.yml wird ausgelöst
                  └─► GitHub Pages Website wird aktualisiert
```

---

## Release veröffentlichen

Ein Release wird durch einen annotierten Tag ausgelöst:

```powershell
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

**Was passiert:**

```
git push origin v1.0.0  (auf GitLab)
        │
        ▼
GitLab Pipeline startet
        │
        └─► pester-tests → mirror-to-github
              1. Orphan-Branch erstellen ("Release v1.0.0")
              2. Force-Push zu GitHub main
              3. Tag v1.0.0 zu GitHub pushen
              └─► GitHub Actions cd.yml wird ausgelöst
                    analyze → test → publish-to-psgallery
                                          │
                                          └─► Publish-Module → PSGallery
                                     → create-release
                                          └─► GitHub Release mit Release Notes
```

---

## Release Notes in der PowerShell Gallery

Die Gallery zeigt Release Notes direkt aus der `PSScriptBuilder.psd1` an.
Das Feld `ReleaseNotes` im `PSData`-Block wird für jede Version gespeichert:

```powershell
PrivateData = @{
    PSData = @{
        ReleaseNotes = "
            v1.1.0 (14.03.2026)
            - Added: Get-PSScriptBuilderCollector
            - Added: Remove-PSScriptBuilderCollector
            - Added: Get-PSScriptBuilderCollectorContent
        "
        ProjectUri   = "https://psscriptbuilder.com"
        LicenseUri   = "https://github.com/PSScriptBuilder/PSScriptBuilder/blob/main/LICENSE"
        Tags         = @("PowerShell", "Build", "ScriptBuilder", "OOP", "Automation", "ReleaseManagement")
    }
}
```

---

## Versionshistorie in der PowerShell Gallery

Die Gallery-Versionshistorie entsteht **unabhängig von Git-Commits** – allein durch mehrfaches Publizieren mit unterschiedlichen Versionsnummern:

```
PowerShell Gallery:
  PSScriptBuilder 1.0.0  (01.03.2026)  ← Install-Module PSScriptBuilder -RequiredVersion 1.0.0
  PSScriptBuilder 1.1.0  (14.03.2026)  ← Install-Module PSScriptBuilder -RequiredVersion 1.1.0
  PSScriptBuilder 1.2.0  (01.04.2026)  ← Install-Module PSScriptBuilder (neueste Version)
```

Jede Version bleibt dauerhaft in der Gallery verfügbar und installierbar.

---

## Übersicht: Was landet wo?

| Inhalt | GitLab | GitHub | PS Gallery |
|--------|--------|--------|------------|
| Vollständige Commit-History | ✅ | ❌ | — |
| Branches (dev, feature/...) | ✅ | ❌ | — |
| Aktueller Quellcode | ✅ | ✅ | — |
| Release-Tags | ✅ | ✅ | — |
| Kompiliertes Modul (.psm1) | ✅ | ✅ | ✅ |
| Versionshistorie | ✅ (Git) | ✅ (1 Commit/Release) | ✅ (pro Publish) |
| Release Notes | ✅ | ✅ | ✅ (aus .psd1) |

## Offene Punkte

Keine offenen Punkte — der vollständige Publish-Prozess ist implementiert.

---

## Sicherheitshinweise

- Beide Tokens (`GITHUB_TOKEN`, `PSGALLERY_API_KEY`) sind in GitLab als **Masked Variables** gespeichert – sie erscheinen niemals in Pipeline-Logs
- **Protected Variables** stellen sicher, dass die Jobs nur auf geschützten Branches/Tags laufen
- Der GitHub-Token sollte regelmäßig erneuert werden (Empfehlung: jährlich)
- Der Gallery-Key ist auf das Paket `PSScriptBuilder` beschränkt (Glob Pattern)

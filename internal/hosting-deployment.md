# Hosting & Deployment

## Übersicht

| URL | Inhalt | Quelle | Hosting |
|---|---|---|---|
| `psscriptbuilder.com` | Landing Page | `website/` im Hauptrepo | GitHub Pages (`PSScriptBuilder/PSScriptBuilder`) |
| `docs.psscriptbuilder.com` | MkDocs-Dokumentation | Separates Repo `PSScriptBuilder/PSScriptBuilder-Docs` | GitHub Pages (`PSScriptBuilder/PSScriptBuilder-Docs`) |

Der Deploy der Landing Page wird von **GitLab CI** gesteuert und über die GitHub Actions API ausgelöst. Die Dokumentation wird direkt aus dem Hauptrepo gebaut und in das separate Docs-Repo deployed — **ein zweites Repo ist notwendig**, weil das Hauptrepo bereits GitHub Pages für die Landing Page verwendet (ein Repo, eine Pages-Site).

### Warum ein separates Docs-Repo?

GitHub Pages erlaubt pro Repo nur eine Site. Das Hauptrepo (`PSScriptBuilder/PSScriptBuilder`) hostet bereits `psscriptbuilder.com` über GitHub Actions. Ein zweiter Pages-Endpunkt im selben Repo ist nicht möglich. Daher wird das gebaute HTML in das separate Repo `PSScriptBuilder-Docs` gepusht, das ausschließlich als Hosting-Ziel dient.

### Wie funktioniert das Docs-Deployment?

Die Markdown-Quelldateien liegen im Hauptrepo unter `docs/`. GitHub Actions baut daraus mit MkDocs statisches HTML und pusht `site/` auf den `gh-pages`-Branch des Docs-Repos.

```
PSScriptBuilder (Hauptrepo)            PSScriptBuilder-Docs (Docs-Repo)
main-Branch                            gh-pages-Branch
├── src/                               ├── index.html
├── docs/          → mkdocs build →    ├── guides/
├── mkdocs.yml      → push site/ →     ├── cmdlets/
└── ...                                └── assets/
```

Das Docs-Repo wird nie manuell bearbeitet — sein `gh-pages`-Branch wird bei jedem Deploy vollständig neu geschrieben.

---

## DNS-Einrichtung beim Domain-Provider

Die folgenden Einträge müssen **einmalig** beim Domain-Provider angelegt werden.

### Apex-Domain `psscriptbuilder.com`

GitHub verlangt für Apex-Domains A-Records (CNAME ist dort nicht möglich):

| Typ | Name | Wert |
|---|---|---|
| `A` | `@` | `185.199.108.153` |
| `A` | `@` | `185.199.109.153` |
| `A` | `@` | `185.199.110.153` |
| `A` | `@` | `185.199.111.153` |

> `@` steht für die Root-Domain. Manche Provider verlangen stattdessen den leeren Namen oder `psscriptbuilder.com`.

### Subdomain `www.psscriptbuilder.com`

| Typ | Name | Wert |
|---|---|---|
| `CNAME` | `www` | `psscriptbuilder.github.io` |

### Subdomain `docs.psscriptbuilder.com`

| Typ | Name | Wert |
|---|---|---|
| `CNAME` | `docs` | `psscriptbuilder.github.io` |

> **Cloudflare-Hinweis:** Den Proxy-Status (orangene Wolke) für alle GitHub-Einträge auf **DNS only** (graue Wolke) stellen — sonst funktioniert das SSL-Zertifikat von GitHub nicht.

---

## GitHub Pages einrichten

### Landing Page (`psscriptbuilder.com`)

1. Repository `PSScriptBuilder/PSScriptBuilder` auf GitHub öffnen
2. **Settings → Pages → Source:** "GitHub Actions" auswählen
3. **Settings → Pages → Custom domain:** `psscriptbuilder.com` eintragen
4. "Enforce HTTPS" aktivieren (erscheint automatisch nach DNS-Verifizierung)

### Dokumentation (`docs.psscriptbuilder.com`)

1. Repository `PSScriptBuilder/PSScriptBuilder-Docs` auf GitHub anlegen (leer, public)
2. **Settings → Pages → Source:** "Deploy from a branch" auswählen
3. **Branch:** `gh-pages` / `/ (root)` auswählen (erscheint nach erstem Deploy)
4. **Settings → Pages → Custom domain:** `docs.psscriptbuilder.com` eintragen
5. "Enforce HTTPS" aktivieren

### Personal Access Token (PAT) für Cross-Repo-Deploy

Der Workflow im Hauptrepo muss in das Docs-Repo schreiben können. Dazu benötigt er ein PAT:

1. GitHub → eigenes Profil → **Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Token erstellen mit Zugriff auf `PSScriptBuilder/PSScriptBuilder-Docs`, Berechtigung: **Contents: Read and write**
3. Den Token als Secret im **Hauptrepo** eintragen: **Settings → Secrets and variables → Actions → New repository secret**
   - Name: `DOCS_DEPLOY_TOKEN`
   - Value: der generierte Token

> SSL-Zertifikate werden von GitHub automatisch über Let's Encrypt ausgestellt. Die Ausstellung dauert einige Minuten nach der DNS-Verifizierung.

---

## GitHub Actions Workflows

### Warum kein `push`-Trigger für die Landing Page?

Der GitHub-Mirror arbeitet mit **Orphan-Commits** (keine Git-History). GitHub kann bei einem Orphan-Commit keinen Diff berechnen — alle Dateien gelten als geändert. Ein `paths`-Filter in GitHub Actions greift daher nicht: der Deploy würde bei **jedem Merge auf `main`** ausgelöst, unabhängig davon ob `website/` tatsächlich geändert wurde.

Die Lösung: Die Entscheidung, ob ein Deploy nötig ist, trifft **GitLab CI** — denn GitLab kennt den tatsächlichen Diff. GitLab ruft den Deploy nur auf, wenn `website/**` geändert wurde, und triggert ihn über die GitHub Actions API (`workflow_dispatch`).

### Landing Page Deployment (`.github/workflows/deploy-pages.yml`)

Wird ausschließlich über `workflow_dispatch` ausgelöst — niemals durch einen direkten Push.

```yaml
name: Deploy Website to GitHub Pages

on:
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  deploy:
    name: Deploy to GitHub Pages
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: website/
      - uses: actions/deploy-pages@v4
        id: deployment
```

### GitLab CI: Trigger für den Landing Page Deploy

Neuer Job `trigger-github-pages` im Stage `deploy` (nach `mirror`). Läuft nur bei Merge auf `main` **und** Änderungen in `website/**`.

```yaml
stages:
  - test
  - secret-detection
  - publish
  - mirror
  - deploy          # Neuer Stage nach mirror

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

> `--fail` stellt sicher, dass der GitLab-Job rot markiert wird, wenn der API-Call fehlschlägt — kein lautloser Fehlschlag.

### Dokumentation Deployment (`.github/workflows/deploy-docs.yml`)

Wird bei jedem Push auf `main` ausgelöst, wenn Dateien unter `docs/**` oder `mkdocs.yml` geändert wurden.

```yaml
name: Deploy Documentation to GitHub Pages

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - 'mkdocs.yml'

permissions:
  contents: write

jobs:
  deploy:
    name: Deploy Docs
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
      - run: pip install mkdocs-material
      - run: mkdocs gh-deploy --force
```

> `mkdocs gh-deploy --force` baut die Doku und pusht das fertige HTML direkt auf den `gh-pages`-Branch. Die `CNAME`-Datei in `docs/CNAME` stellt sicher, dass die Custom Domain dabei nicht überschrieben wird.

---

## Deployment-Workflow

```
feature/... Branch
        ↓
  development Branch  (kein Deployment — Änderungen nicht öffentlich)
        ↓
    main Branch
        ↓
  GitLab CI läuft
        ↓
  mirror-to-github          → GitHub main wird aktualisiert (immer)
        ↓
  trigger-github-pages      → nur wenn website/** geändert
        ↓ (workflow_dispatch API-Call)
  GitHub Actions: deploy-pages.yml
        ↓
  psscriptbuilder.com       → Landing Page aktualisiert

  GitHub Actions: deploy-docs.yml  → nur wenn docs/** oder mkdocs.yml geändert
        ↓ (pusht site/ via PAT in PSScriptBuilder-Docs)
  docs.psscriptbuilder.com  → Dokumentation aktualisiert
```

Der Trigger für den Website-Deploy ist ausschließlich ein Merge auf `main` **mit Änderungen in `website/**`**. Der Docs-Deploy wird direkt von GitHub Actions ausgelöst, wenn `docs/**` oder `mkdocs.yml` geändert wurde. Solange in `development` gearbeitet wird, sind keine Änderungen öffentlich sichtbar.

---

## MkDocs einrichten

### Voraussetzungen

Python muss installiert sein:
- Download: https://www.python.org/downloads/
- Oder über den Microsoft Store: "Python 3.12"

### Installation

```bash
pip install mkdocs-material
```

### Projektstruktur

Die Dokumentationsquelle liegt im Hauptrepo. Das Docs-Repo dient ausschließlich als Hosting-Ziel:

```
PSScriptBuilder/ (Hauptrepo)
├── docs/
│   ├── CNAME                    ← docs.psscriptbuilder.com (landet in site/CNAME)
│   ├── index.md
│   ├── getting-started/
│   │   ├── installation.md
│   │   └── quick-start.md
│   ├── cmdlets/
│   │   ├── index.md
│   │   └── *.md                 ← generiert durch Build-Module.ps1
│   ├── guides/
│   │   ├── collectors.md
│   │   ├── templates.md
│   │   ├── dependency-analysis.md
│   │   └── release-management.md
│   └── stylesheets/
│       └── extra.css
└── mkdocs.yml

PSScriptBuilder-Docs/ (Docs-Repo auf GitHub — nur gh-pages-Branch relevant)
└── gh-pages-Branch/             ← vollständig von deploy-docs.yml befüllt
    ├── index.html
    ├── CNAME
    └── ...
```

### `mkdocs.yml` Konfiguration

```yaml
site_name: PSScriptBuilder
site_url: https://docs.psscriptbuilder.com
repo_url: https://github.com/PSScriptBuilder/PSScriptBuilder
repo_name: PSScriptBuilder/PSScriptBuilder

theme:
  name: material
  palette:
    - scheme: default
      primary: custom
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      primary: custom
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.tabs
    - navigation.sections
    - search.suggest
    - content.code.copy

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Cmdlets:
    - Overview: cmdlets/index.md
    - Invoke-PSScriptBuilderBuild: cmdlets/Invoke-PSScriptBuilderBuild.md
  - Guides:
    - Template System: guides/template-system.md
    - Release Management: guides/release-management.md
```

### Lokale Vorschau

```bash
mkdocs serve
# → http://127.0.0.1:8000
```

---

## Trigger-Übersicht

Die folgende Tabelle zeigt, welche Aktion welches Deployment auslöst:

| Aktion | Landing Page `psscriptbuilder.com` | Doku `docs.psscriptbuilder.com` | PSGallery Publish | GitHub Mirror |
|---|---|---|---|---|
| Push auf `feature/...` | ❌ | ❌ | ❌ | ❌ |
| Push auf `development` | ❌ | ❌ | ❌ | ❌ |
| Merge → `main` — nur `website/**` geändert | ✅ | ❌ | ❌ | ✅ |
| Merge → `main` — nur `docs/**` geändert | ❌ | ✅ | ❌ | ✅ |
| Merge → `main` — `website/**` + `docs/**` geändert | ✅ | ✅ | ❌ | ✅ |
| Merge → `main` — nur `src/**` geändert | ❌ | ❌ | ❌ | ✅ |
| Git-Tag `v1.0.0` erstellen + pushen | ❌ | ❌ | ✅ | ✅ |

> Der **GitHub Mirror** läuft bei **jedem Merge auf `main`** — unabhängig davon, was geändert wurde. Der Website- und Docs-Deploy laufen nur bei tatsächlichen Änderungen in den jeweiligen Ordnern.

### Zusammenfassung der Trigger

| Workflow | Trigger | Ausgelöst von |
|---|---|---|
| Landing Page | Merge auf `main` + Änderung in `website/**` | GitLab CI via `workflow_dispatch` |
| Dokumentation | Merge auf `main` + Änderung in `docs/**` | GitLab CI via Mirror in `PSScriptBuilder-Docs` |
| PSGallery Publish | Git-Tag `v*` | GitLab CI |
| GitHub Mirror (Hauptrepo) | Jeder Merge auf `main` + Git-Tag `v*` | GitLab CI |

### Wichtige Hinweise

- Ein Merge nach `main` löst **immer** den GitHub Mirror aus — Website- und Docs-Deploy nur bei tatsächlichen Änderungen in `website/**` bzw. `docs/**`
- PSGallery wird **ausschließlich** durch einen Git-Tag ausgelöst — nie durch einen einfachen Push
- Der GitHub Mirror läuft bei **jedem Merge auf `main`** sowie bei jedem Git-Tag
- Im `development`-Branch kann geändert, getestet und gepusht werden ohne dass irgendetwas öffentlich wird
- Die Landing Page kann lokal direkt im Browser geöffnet werden (`index.html`)
- Die Dokumentation kann lokal mit `mkdocs serve` geprüft werden (`http://127.0.0.1:8000`)

### PSGallery — Wichtiger Hinweis zum Rückgängigmachen

Ein versehentlich gepushtes Modul kann nur innerhalb von **72 Stunden** vollständig gelöscht werden (PSGallery-Website → Manage → Delete). Danach ist nur noch "Unlisting" möglich — die Version bleibt installierbar, ist aber nicht mehr auffindbar. Der Git-Tag als einziger Trigger ist daher eine wichtige Sicherheitsmaßnahme.

---

## Offene Schritte

### Landing Page

- [x] `.github/workflows/deploy-pages.yml` — auf `workflow_dispatch`-only umstellen
- [x] `.gitlab-ci.yml` — Stage `deploy` + Job `trigger-github-pages` ergänzen
- [x] DNS-Einträge beim Domain-Provider anlegen (`A`-Records für Apex, CNAME für `www`)
- [x] GitHub Repository-Settings: Custom Domain `psscriptbuilder.com` eintragen

### Dokumentation

- [x] Python installieren
- [x] GitHub Repo `PSScriptBuilder-Docs` anlegen
- [x] DNS-Eintrag `docs.psscriptbuilder.com` CNAME anlegen
- [x] GitHub Repository-Settings: Custom Domain `docs.psscriptbuilder.com` eintragen + Enforce HTTPS
- [x] `mkdocs.yml` anlegen
- [x] `docs/` im Hauptrepo mit ersten Markdown-Seiten befüllen
- [x] `docs/CNAME` anlegen
- [x] `.github/workflows/deploy-docs.yml` anlegen (pusht via PAT in PSScriptBuilder-Docs)
- [x] Secret `DOCS_DEPLOY_TOKEN` im Hauptrepo eintragen
- [x] Comment-Based Help für alle Public Cmdlets — generiert via PlatyPS
- [ ] GitLab CI: Mirror-Job für `docs/` → `PSScriptBuilder-Docs` einrichten (nicht mehr nötig — deploy-docs.yml übernimmt das)

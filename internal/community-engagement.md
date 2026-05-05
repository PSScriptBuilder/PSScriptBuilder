# Community Engagement

## Timing Recommendations

### Best days to publish releases / announcements
- **Tuesday to Thursday** — Monday: people are still catching up; Friday: attention shifts to the weekend

### Best times (UTC) for maximum reach
- **07:00–11:00 UTC** — European community is active, US East Coast comes online (06:00–09:00 EST)

| UTC   | CET/CEST (UTC+1/+2) |
|-------|---------------------|
| 07:00 | 08:00 / 09:00       |
| 08:00 | 09:00 / 10:00       |
| 10:00 | 11:00 / 12:00       |
| 11:00 | 12:00 / 13:00       |

---

## Platforms

### r/PowerShell (Reddit)

**Audience:** PowerShell practitioners — sysadmins, DevOps engineers, developers. Pragmatic community that values working solutions over theory.

**Post types:**
- Release announcements (`[Release]` flair)
- Answering questions where PSScriptBuilder is a relevant solution
- Tutorials / use-case write-ups (link to docs or dev.to article)

**Markdown:** Fully supported — code blocks, bold, links all render correctly.

**Best practices:**
- Always disclose authorship: "a module I built" — hiding it is considered spam
- Help first, promote second — if answering a question, solve the problem before mentioning PSScriptBuilder
- No greeting ("Hey guys") — get straight to the point
- Reply to comments within the first 24h — the algorithm rewards engagement and the community expects it
- No crossposting from other subreddits without adapting the text

**Recommended tags/flair:** `[Release]`, `[Module]`, `[Discussion]`

---

### dev.to

**Audience:** Broader developer community, including many PowerShell users. Skews toward web/DevOps but actively reads PowerShell content.

**Post types:**
- Long-form tutorials ("How I build single-file PowerShell scripts from multi-file projects")
- Release announcements with context and examples
- Article series (performs better than single posts)

**Markdown:** Fully supported, including fenced code blocks with syntax highlighting.

**Best practices:**
- Start with a concrete problem, not a feature list — "Have you ever had a 2000-line `.psm1`?" performs better than "PSScriptBuilder v1.1.0 released"
- Always include working code examples — pure announcement posts get little traction
- A series outperforms a single article (e.g. "Part 1: The Problem", "Part 2: The Solution", "Part 3: Advanced Usage")
- Set a **canonical URL** if the same content appears elsewhere (e.g. your own blog) to avoid SEO penalties
- Recommended tags: `#powershell`, `#devops`, `#opensource`, `#automation`

---

### PowerShell Gallery

**Role:** Publication target, not a communication channel. Users discover and install the module here.

**Best practices:**
- `ReleaseNotes`: plain text only — Markdown is not rendered; keep under ~20 lines
  - Format: version line, `Added:` / `Changed:` / `Fixed:` categories, bullet list, link to full CHANGELOG
- `Tags`: choose carefully (max. 10); used for search — include `PowerShell`, `Build`, `ScriptBuilder`, `Automation`, `DependencyAnalysis`
- Always populate `LicenseUri`, `ProjectUri`, `IconUri` — projects without these look unmaintained
- Link to `CHANGELOG.md` on GitHub for the full history

---
name: commit-messages
description: Draft copy/paste-ready commit messages for the current git changes in this repo (PSScriptBuilder), one message per changed file, following this repo's Conventional Commits style and AGENTS.md conventions. Use when the user asks to prepare, draft, or write commit messages for staged/modified/untracked files. Never runs git add/commit/push itself.
---

# Commit Messages (PSScriptBuilder)

Drafts one commit message per changed file for the user to commit manually. This repo commits at file-level granularity (see `git log`), not one big commit per session.

## Steps

1. Run `git status --porcelain` to list modified/untracked files, and `git diff` (staged + unstaged) to understand each change.
2. Run `git log --oneline -20` to confirm the current Conventional Commits type prefixes in use (`fix:`, `refactor:`, `test:`, `docs:`, `build:`, `feat:`, `chore:`, ...) and match the established style.
3. Read `AGENTS.md`'s `## Git` section if present — it is the source of truth for this repo's commit conventions and overrides anything below if they conflict.
4. For each changed file, draft exactly one message:
   - Subject line: `type: concise imperative summary` (lowercase type, no period at the end).
   - Blank line, then a short body explaining **why** the change was made (the reader can see *what* changed from the diff itself — don't restate it line by line).
   - Keep the body precise and concise — a few sentences at most, not a wall of text.
   - **Never** append a `Co-Authored-By` line or any other AI-attribution trailer.
5. If several files were changed for the exact same reason with effectively identical content (e.g. the same fix applied identically across multiple cmdlets), say so explicitly and give one shared message, rather than inventing artificial differences between near-duplicate messages.
6. If a generated build artifact changed (e.g. `build/Output/*.psm1`), give it its own trailing `build: rebuild module output via Build-Module.ps1` -style message, briefly noting what it now includes.
7. Present each message as plain prose in the chat response: state just the file path wrapped in backticks (e.g. `` `path/to/file` ``) as its own line, then a blank line, then the message itself (subject line, blank line, body), flush at the left margin throughout — no fenced code block around the message, no standalone bold-only line, no bullets nearby, and no introductory phrase like "Commit message for" before the file path. The backticks apply only to the file path label, never to the message text itself. Any leftover left-margin indent the user sees when copying the message text from chat is a terminal/host rendering artifact, not something in the message text itself (verified: the same text written to a plain file had zero indent) — do not try to "fix" it with further markdown workarounds on the message text.
8. Suggest a sensible commit order (source/tests first, docs like `CHANGELOG.md` next, build artifact last) as a one-line note, but leave the final grouping and order to the user.

## Non-negotiables

- Never run `git add`, `git commit`, or `git push` — only draft and present the messages. The user commits manually.
- Never add a `Co-Authored-By` or similar attribution trailer.
- Never pad body text with implementation-mechanics the user hasn't asked to see (e.g. specific .NET APIs) unless that detail is itself part of the public contract of the change.

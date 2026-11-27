# Agent Instructions

## General

- **NEVER** autonomously change code — this includes when responding to a user question or
  suggestion, where the planned change must be shown in chat only, not applied
- **ALWAYS** treat an explicit, direct instruction to apply a previously shown change as
  authorization to proceed
- **NEVER** install, update, or remove software (e.g. PowerShell modules) on the local machine
  autonomously — always show the exact command and let it be run manually

## Quality

- **ALWAYS** verify a statement before writing it — a count by counting, a call site by
  searching, a behavior by running it, a source by reading and quoting it — never from memory or
  from another document
- **ALWAYS** measure the very case a statement, example or rating is about: one spelling, mode or
  PowerShell version does not stand for a neighboring one, and a statement about a released
  version is measured against that release, not the development build
- **ALWAYS** mark a statement as unverified only when it cannot be verified here, and name what
  is missing
- **NEVER** present anything as existing, decided or documented that is not — what does not exist
  yet is marked as a proposal in the sentence that introduces it; what exists is named with its
  ground (file and line, RFC section, or measurement), and where there is none, say so
- **NEVER** recommend a mechanism that has not been run; a measured counter-example outranks a
  plausible argument
- **NEVER** let the project's own documentation decide a design question — not as a reason, a
  hint or a secondary argument. Develop as though it did not exist: what matters is the problem,
  what the code does, and what a measurement shows
- **ALWAYS** correct documentation that contradicts the behavior a change decides, as part of
  that change
- **ALWAYS** check a design decision, implementation or recommendation — also on timing, scope
  and the choice between variants — against established practice before proposing it, and for a
  draft before it is first shown; name the practice, with its source when it is not common
  knowledge, and say where the draft deviates and why
- **ALWAYS** cover in that check at least: names that cannot be confused with existing ones, no
  boolean parameter that selects behavior, validations that report every error instead of the
  first, exceptions that keep the original as inner exception, comparisons that do not depend on
  the system culture, members that sit in the class whose data or task they belong to, and
  comments and help in neighboring code that the change makes untrue
- **ALWAYS** treat edge cases as first-class: for every change, identify boundary, empty, null,
  malformed and unexpected-type inputs, verify their behavior on PowerShell 5.1 and 7, and cover
  them with tests
- **NEVER** classify an edge case as harmless or out of scope on your own — every wrong,
  misleading or silent result is a finding, reported with a realistic assessment (can it occur,
  and with what consequence?) and a proportionate proposal, and decided by the user
- **ALWAYS** judge a finding by whether the public interface can reach it — the cmdlets, their
  parameters and the objects they return, with the members the Type Reference describes — and
  measure that on PowerShell 5.1 and 7
- **ALWAYS** report a finding that only a call outside the public interface can trigger together
  with that measurement — it needs a fix only when the call silently produces a wrong or partial
  result, and then a simple check that fails clearly is enough
- **ALWAYS** cover the check at the boundary that keeps such input away from the classes with a
  test
- **ALWAYS** prefer failing clearly over silently producing a wrong or partial result

## Findings

- **ALWAYS** record a finding that lies outside the change being worked on as one entry in the
  project's list of findings (currently `internal/findings.md`) — what happens, who is affected
  and how severe it is — and continue with the change
- **ALWAYS** interrupt the current work for a finding only when the change being worked on causes
  or worsens it, or when it loses a user's data or silently writes wrong data into a user's files
- **NEVER** add a finding to the current release, start work on it, or propose more work for a
  release whose scope the user has fixed, apart from these two cases — the user decides what is
  fixed and when
- **PREFER** restructuring code as a step of its own, before the change that touches the same
  code; open points are collected under "Structure" in the list of findings
- **ALWAYS** order open findings by severity, never by the effort to fix them
- **NEVER** widen a requested review beyond the artifact under review — what is noticed outside
  it becomes a finding

## Language

- **ALWAYS** use "German" in chat
- **ALWAYS** use "English" in source code

## PowerShell

- **ALWAYS** be compatible with PowerShell 5.1 and PowerShell 7
- **NEVER** define or implement interfaces — PowerShell cannot define an interface in script
  code, and implementing an existing .NET interface is not needed so far
- **NEVER** use ternary operators — ternary operators are not available in PowerShell 5.1
- **ALWAYS** use `[Environment]::NewLine` instead of `` "`r`n" `` for platform-independent line endings
- **ALWAYS** use `[System.IO.Path]` methods (or the current platform's directory separator) instead of
  a hardcoded backslash, for Linux/macOS compatibility
- **PREFER** returning warning messages to the calling cmdlet, which writes them, when a class method
  is called directly by the cmdlet and needs no extra plumbing to do so — warnings written inside
  class methods are not collected by `-WarningVariable` (see Known Limitations in
  `docs/limitations.md`)

## Development

### Region Blocks

- **ALWAYS** follow the region pattern of comparable files — a class file has
  `#region Class <Name>` and section regions such as `Properties`, `Constructors` and `Methods` —
  and keep that pattern when adding, moving or removing code

### Functions

- **ALWAYS** declare functions and cmdlets using the `Function` keyword
- **NEVER** start functions or cmdlets with `[CmdletBinding()]` — it must be declared inside the function body

### Classes

- **PREFER** one responsibility per class, and composing objects over inheriting
- **PREFER** an established design pattern where its problem is really present, named in the
  class help — and none where it is not

### Comment-Based Help

- **ALWAYS** give every class, property, constructor, method and enum value comment-based help with
  `.SYNOPSIS` and `.DESCRIPTION`, every parameter a `.PARAMETER` and every non-void method an
  `.OUTPUTS` — also in drafts shown for review

### Return Values

- **ALWAYS** use guard clauses (early returns) for invalid input, "nothing to do" or clearly named
  special cases instead of nesting the main path in `if`/`else` blocks
- **ALWAYS** build the main path's return value in easy-to-follow steps, assigned to named
  variables, and end it with `return $variable` — never return a compound expression directly
  (e.g. `` return $a.Length - $a.Replace("`n", '').Length ``)

### Exceptions

- **ALWAYS** throw the most specific exception possible
- **ALWAYS** throw an exception object, never a bare text; `throw` on its own is only for
  passing on a caught exception unchanged
- **ALWAYS** build a longer exception message in a variable (e.g. `$message`) and pass that to
  the exception — with a format string and placeholders when it contains variable values,
  assigned directly (split with `+` if long) when it does not

### Tests

- **ALWAYS** pass the actual value to `Should`, never the result of a comparison — e.g.
  `$message | Should -MatchExactly $pattern` instead of
  `$message.StartsWith($prefix) | Should -BeTrue` — so that a failing test shows the value
- **ALWAYS** compare text with the case-sensitive operators (`-BeExactly`, `-MatchExactly`,
  `-BeLikeExactly`) unless ignoring letter case is what the test is about
- **ALWAYS** assert the complete wording of a message in one test per message and only the
  relevant fragment in the others, so that a change of wording breaks few tests
- **ALWAYS** run a new test against the unchanged code and report which new tests fail there —
  a test that passes without the change does not test it, and one that is meant to pass already
  needs its reason stated
- **ALWAYS** apply these rules to new and changed tests; an existing test is left as it is

### Changelog

- **ALWAYS** describe observable behavior in a CHANGELOG entry, never internal implementation
  details (private methods, internal mechanisms) — a changelog is written for humans, not
  machines (Keep a Changelog)
- **ALWAYS** order the sections of a release as Keep a Changelog defines: Added, Changed,
  Deprecated, Removed, Fixed, Security
- **ALWAYS** start an entry with the affected cmdlets and its topic
  (`` - `Cmdlet`, `Cmdlet` — topic `` followed by two trailing spaces), then describe it in an
  indented paragraph
- **ALWAYS** describe a fix as what went wrong, what the user noticed, and how it behaves now
- **ALWAYS** make an entry as detailed as a user needs to tell whether they were affected — name
  every input or situation that behaves differently, but leave out causes and explanations
- **PREFER** two to five lines per entry; a longer entry is justified only by several distinct
  observable effects
- **ALWAYS** quote an error message only when a user should recognize it, and give an example only
  when the change cannot be understood without it
- **ALWAYS** insert a new entry next to related entries and by its impact on the user, not at the
  end of its section

### RFCs

- **ALWAYS** write a retroactive RFC in `internal/rfc/` for a severe or silent-failure bug fix, or
  a non-obvious design decision — even when the RFC follows rather than precedes the code

## Documentation

- **ALWAYS** describe how a command or step behaves in running text, not in an admonition —
  admonitions are for side information a reader could skip (Google developer documentation style
  guide, "Notices"; Microsoft Writing Style Guide, "Notes")
- **ALWAYS** reserve `!!! warning` for a consequence the reader must act on, such as possible data
  loss or a failing run
- **NEVER** place two admonitions directly after each other within running text — merge them,
  turn one into running text, or move one to the page's Tips section, whose entries are a
  collection of independent admonitions

## Metadata

- **ALWAYS** use the actual current date and time where a date or time is written or updated —
  a date that records when something happened stays as it is
- **NEVER** autonomously change a version

## Build

- **NEVER** run the module's build (`Build-Module.ps1`, `build.ps1`) — not even after asking for
  permission; suggest running it manually

## Git

- **ALWAYS** keep a commit message's explanatory body precise and concise
- **NEVER** append a "Co-Authored-By" (or similar AI-attribution) trailer to a commit message
- **ALWAYS** create one commit per changed file by default, never one combined commit per session
- **ALWAYS** propose grouping several files into one commit per logical change when committing them
  one by one would leave intermediate states that do not work together (e.g. code and the tests
  that cover it), and let the user decide case by case
- **NEVER** split one file across several commits unless the user asks for it
- **ALWAYS** use a Conventional Commits prefix (`fix:`, `docs:`, `test:`, `build:`, `feat:`,
  `chore:`, `refactor:`) matching the existing history

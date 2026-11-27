# TemplateStressTest fixture

This is a **stress-test fixture**, not a numbered `examples/` entry — see
`internal/test-strategy.md`'s "Integration Tests" section for the distinction. It exists purely to
maximize interaction surface across many collectors and modes at once, for permanent regression
coverage; it is not meant to teach one concept at a time and is not listed in `examples/README.md`.

## What it covers

A single project spanning 6 domains (Core, Workflow, Notifications, Reporting, CLI, Integrations)
with, deliberately, **multiple collectors of the same type** rather than one combined collector per
type:

- 7 Enum collectors' worth of enums, 19 Class collectors' worth of classes, 11 Function
  collectors' worth of functions - 17 non-`Using` collectors total
- **4 separate `Using` collectors** (`CoreUsings`, `WorkflowUsings`, `NotificationUsings`,
  `IntegrationUsings`), each scanning a different subfolder that contains real `using
  namespace` statements
- Real, multi-path cross-dependencies forcing Ordered Mode: `WorkflowEngine` (Workflow) depends on
  `Ticket`/`TicketList` (Core); `SlackNotifier` -> `AsyncNotifierBase` -> `NotifierBase` is a
  3-level inheritance chain; `Send-TicketNotification` (Notifications) depends on `Ticket` (Core);
  `JiraSync`/`GitHubSync` (Integrations) both depend on `Ticket` (Core); `CommandParser` (CLI)
  depends on `Ticket` (Core)

Two template variants:

- `build/Templates/StressTest.ps1.template` - **valid**: one consolidated `{{CoreUsings}}`
  placeholder for all 4 registered `Using` collectors, plus `{{ORDERED_COMPONENTS}}`
- `build/Templates/StressTest.Broken.ps1.template` - **invalid**: a second, independent
  `{{NotificationUsings}}` placeholder alongside `{{CoreUsings}}` - in Ordered/Hybrid Mode, all
  registered Using collectors are consolidated into a single block assigned to whichever one
  placeholder is present; a second one is rejected rather than silently left unreplaced in the
  build output

## Why this exists

Emergent, multi-component interaction bugs (like the shape validated above, and the multi-run
bump-file staleness the sibling `BumpFileStressTest` fixture covers - see RFC 0019) tend to surface
only through large, dense scratch projects, not the narrower Unit/Integration suite. This fixture
formalizes that density permanently instead of rebuilding it before every release.

## How to run manually

```powershell
.\Run-StressTest.ps1
```

Nothing here is mutated between runs - no reset script needed.

## Automated coverage

`tests/Integration/Template/PSScriptBuilderTemplateStressTest.Integration.Tests.ps1` exercises this
fixture read-only (no `$TestDrive` copy needed) as part of the regular Pester suite.

# Test Strategy

This document defines the conventions and guidelines for writing tests in PSScriptBuilder.
It is derived from the existing test suite and serves as the reference for all new tests.

---

## Test Runner

Run the full test suite from the repository root:

```powershell
.\tests\Invoke-Tests.ps1
```

Run only unit or integration tests:

```powershell
.\tests\Invoke-Tests.ps1 -Suite Unit
.\tests\Invoke-Tests.ps1 -Suite Integration
```

---

## Folder Structure

Unit tests mirror the `src/` folder structure exactly:

```
tests/
├── CustomMatcher/          # Custom Should-* operators + self-tests in Test/
├── Integration/            # End-to-end integration tests
│   ├── Build/
│   ├── DependencyAnalysis/
│   ├── ReleaseManagement/
│   └── Template/
└── Unit/
    ├── Common/
    ├── Configuration/
    │   └── Options/
    ├── Public/
    ├── ReleaseManagement/
    │   ├── Helper/
    │   ├── Managers/
    │   ├── Orchestrators/
    │   ├── Requests/
    │   ├── Results/
    │   └── Validators/
    ├── Scaffolding/
    │   ├── Requests/
    │   └── Results/
    └── ScriptBuilder/
        ├── Collectors/
        ├── Core/
        ├── Data/
        ├── Dependencies/
        ├── Helper/
        ├── Managers/
        ├── Orchestrators/
        ├── Results/
        └── Template/
```

---

## Naming Conventions

| Artifact | Convention | Example |
|---|---|---|
| Unit test file | `ComponentName.Tests.ps1` | `PSScriptBuilderClassCollector.Tests.ps1` |
| Integration test file | `Feature.Integration.Tests.ps1` | `PSScriptBuilderBuild.Integration.Tests.ps1` |
| `Describe` block | Exact component name | `Describe 'PSScriptBuilderClassCollector'` |
| `Context` block | `'Aspect'` or `'MethodName - scenario'` | `'Constructor - property mapping'`, `'HasCycle - simple cycles'` |
| `It` block | Always starts with `'Should'` | `'Should collect a single class from a file'` |
| Helper functions | `New-` prefix, no PSScriptBuilder prefix | `New-TestFile`, `New-Collector`, `New-ValidConfigObj` |

---

## File Structure

```powershell
using namespace System          # Only when needed
using namespace System.IO

Describe 'ComponentName' {

    BeforeAll {
        # Helper functions
        Function New-TestFile { ... }
        Function New-Collector { ... }

        # Shared state
        $script:SharedValue = ...
    }

    AfterAll {
        $Global:PSScriptBuilderProjectRoot = $null
    }

    Context 'MethodName - scenario' {

        It 'Should ...' {
            # Arrange
            # Act
            # Assert
        }
    }
}
```

---

## Imports

- `using namespace` at the top of the file, only when needed (`System`, `System.IO`, `System.Collections.Generic`, etc.)
- No `using module` in test files — the module is loaded by `Invoke-Tests.ps1` before test execution

---

## Helper Functions

- Defined in `BeforeAll` at the `Describe` level so they are available in all `Context` blocks
- Use `New-` prefix (e.g. `New-TestFile`, `New-Collector`, `New-ValidConfigObj`, `New-BumpFile`)
- No PSScriptBuilder namespace prefix
- Return the created object or path so callers can chain operations

---

## State Management

- `$script:` scope for state shared between `BeforeAll` and `It` blocks within the same `Describe`
- `$Global:PSScriptBuilderProjectRoot = $TestDrive` in `BeforeAll` for tests that invoke cmdlets that call `Get-PSScriptBuilderProjectRoot`; reset to `$null` in `AfterAll`
- `[PSScriptBuilderConfiguration]::Reset()` in both `BeforeAll` and `AfterAll` for tests that depend on configuration state
- `BeforeEach` for resetting mutable objects (e.g. fresh `DependencyGraph` instances) when each test needs a clean slate

---

## Assertions

- `.GetType().Name -eq 'TypeName'` instead of `-is [TypeName]` — PowerShell class types from modules are not resolvable as type literals in test files
- `Should -Throw -ExceptionType ([ExceptionType])` for specific exception types
- `Should -Throw "*pattern*"` for message content matching
- One assertion per `It` block; closely related properties (e.g. two sides of the same fact) may be combined

---

## Integration Tests

- Always tagged: `Describe '...' -Tag 'Integration'`
- Use `examples/` as fixture data — do not create synthetic fixture files for integration tests
- Reset all global and static state in `BeforeAll` and `AfterAll`:
  ```powershell
  BeforeAll {
      [PSScriptBuilderConfiguration]::Reset()
      $Global:PSScriptBuilderProjectRoot = $script:Root
  }
  AfterAll {
      [PSScriptBuilderConfiguration]::Reset()
      $Global:PSScriptBuilderProjectRoot = $null
  }
  ```
- Write output to `$TestDrive` — never to the actual `examples/**/build/Output/` folder

---

## Custom Matchers

Located in `tests/CustomMatcher/`. Each matcher:

- Is a single `.ps1` file calling `Add-ShouldOperator`
- Has a corresponding self-test in `tests/CustomMatcher/Test/`
- Is dot-sourced by `Invoke-Tests.ps1` before any test runs

Available matchers:

| Matcher | Purpose |
|---|---|
| `Should -HaveProperty` | Checks for instance or static property existence |
| `Should -HavePropertyOfType` | Checks property existence and type |
| `Should -HavePropertyWithValue` | Checks property existence and value |
| `Should -HaveMethod` | Checks for instance or static method existence |

---

## Known Constraints

- **`-is [PSScriptBuilderType]`** does not work in test files — use `.GetType().Name -eq 'TypeName'` instead. PowerShell class types defined in a module are resolved at parse time, but test files are parsed without the module context.
- **`#region` blocks** — used inconsistently across the test suite (present in `Common/` and some `Core/` tests, absent elsewhere). New tests do not need to add them.

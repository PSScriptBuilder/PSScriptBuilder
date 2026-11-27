---
hide:
  - toc
---

# Guides

These guides explain each PSScriptBuilder feature in depth. They assume you already have a
working PSScriptBuilder project — if you are new, start with the [Quick Start](../getting-started/quick-start.md).
The guides are grouped into four areas that follow the natural workflow: the core concepts every
build relies on, assembling and running a build, analyzing its structure, and publishing a
release.

## Core Concepts

Every build depends on three things, covered here in the order you'll set them up.

- **Configuration** centralizes settings in a single file — creating and reading it, the full
  field reference, and how paths resolve relative to the project root.
- **Collectors** scan source files and extract components — the five collector types, combining
  and filtering them, and the properties each one exposes.
- **Templates** define how those collected components are assembled into the output script — the
  three placeholder modes (Free, Ordered, Hybrid) and how validation catches mistakes before a
  build.

Every other guide in this section — and the Analysis guides that inspect a project without
building it — builds directly on these three.

<div class="grid cards" markdown>

-   **Configuration**

    ---

    Centralizes build and release settings in a single JSON file.

    [:octicons-arrow-right-24: Configuration](configuration.md)

-   **Collectors**

    ---

    Scan source files and extract classes, functions, enums, using statements, and raw file content.

    [:octicons-arrow-right-24: Collectors](collectors.md)

-   **Templates**

    ---

    Define the output script structure with placeholder tokens and validation modes.

    [:octicons-arrow-right-24: Templates](templates.md)

</div>

## Building

Once configuration, collectors, and templates are in place, these guides cover turning them into
a build.

- **Build Pipeline** runs the build, interprets the result, exports a report, and covers
  logging, backups, and post-processing.
- **Tool Integrations** combines a build with Invoke-Build, PSScriptAnalyzer, Pester, and
  ModuleBuilder for a complete development workflow.
- **File Watching** automates the build itself, rebuilding — or running a custom script — every
  time a source file changes.

<div class="grid cards" markdown>

-   **Build Pipeline**

    ---

    Run the full pipeline, interpret the result, configure backups, and post-process the output.

    [:octicons-arrow-right-24: Build Pipeline](build-pipeline.md)

-   **Tool Integrations**

    ---

    Combine PSScriptBuilder with Invoke-Build, PSScriptAnalyzer, Pester, and ModuleBuilder.

    [:octicons-arrow-right-24: Tool Integrations](tool-integrations.md)

-   **File Watching**

    ---

    Automatically rebuild, or run a custom script block, whenever source files change.

    [:octicons-arrow-right-24: File Watching](file-watching.md)

</div>

## Analysis

These guides inspect a project's structure and behavior without necessarily running a build.

- **Dependency Analysis** builds and queries the dependency graph that determines component load
  order, including circular and cross-collector dependencies.
- **Code Analysis** inspects collector content, dependency data, and template validation mode —
  all without running a build.
- **Source Maps** is the exception: it traces a completed build's output, and Pester coverage
  measured against it, back to the original source.

<div class="grid cards" markdown>

-   **Dependency Analysis**

    ---

    Build a dependency graph, detect cycles, and determine the correct component load order.

    [:octicons-arrow-right-24: Dependency Analysis](dependency-analysis.md)

-   **Code Analysis**

    ---

    Inspect your project's structure and collector content without running a build.

    [:octicons-arrow-right-24: Code Analysis](code-analysis.md)

-   **Source Maps**

    ---

    Trace runtime errors back to source and translate Pester code coverage back to per-source-file results.

    [:octicons-arrow-right-24: Source Maps](source-maps.md)

</div>

## Publishing

These guides cover tracking a project's version across releases and wiring the whole workflow
into an automated pipeline.

- **Release Management** tracks and propagates version numbers, build metadata, and Git context
  across a project's files, using bump files configured in Simple Token Mode or Regex Pattern
  Mode.
- **CI/CD Integration** takes the whole workflow — build, analyze, release — and runs it in an
  automated pipeline, illustrated with a GitHub Actions example.

<div class="grid cards" markdown>

-   **Release Management**

    ---

    Track and propagate version numbers, build metadata, and Git context across all registered project files.

    [:octicons-arrow-right-24: Release Management](release-management.md)

-   **CI/CD Integration**

    ---

    Integrate PSScriptBuilder into any CI/CD system with a GitHub Actions example.

    [:octicons-arrow-right-24: CI/CD Integration](cicd-integration.md)

</div>

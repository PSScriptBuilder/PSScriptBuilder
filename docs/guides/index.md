---
hide:
  - toc
---

# Guides

These guides explain each PSScriptBuilder feature in depth. They assume you already have a
working build — if you are new, start with the [Quick Start](../getting-started/quick-start.md).
The guides are grouped into three areas that follow the natural workflow: building a script,
analyzing its structure, and publishing a release.

## Building

Configure, collect, and assemble — these guides cover each step of the build pipeline in order.

<div class="grid cards" markdown>

-   **Configuration**

    ---

    Centralizes build and release settings in a single JSON file. Covers path resolution and project root discovery.

    [:octicons-arrow-right-24: Configuration](configuration.md)

-   **Collectors**

    ---

    Scan source files and extract classes, functions, enums, using statements, and raw file content.

    [:octicons-arrow-right-24: Collectors](collectors.md)

</div>

<div class="grid cards" markdown>

-   **Templates**

    ---

    Define the output script structure with placeholders — Free, Hybrid, and Ordered mode.

    [:octicons-arrow-right-24: Templates](templates.md)

-   **Build**

    ---

    Run the full pipeline, interpret the result, configure backups, and post-process the output.

    [:octicons-arrow-right-24: Build](build.md)

</div>

## Analysis

Inspect what PSScriptBuilder collects and resolves — without producing any output.

<div class="grid cards" markdown>

-   **Dependency Analysis**

    ---

    Build a dependency graph, detect cycles, and determine the correct component load order.

    [:octicons-arrow-right-24: Dependency Analysis](dependency-analysis.md)

-   **Code Analysis**

    ---

    Inspect your project's structure and collector content without running a build.

    [:octicons-arrow-right-24: Code Analysis](code-analysis.md)

</div>

## Publishing

Manage versions, propagate metadata, and automate the full workflow in CI/CD.

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

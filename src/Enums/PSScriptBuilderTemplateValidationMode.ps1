#region Enum PSScriptBuilderTemplateValidationMode
<#
.SYNOPSIS
    Defines the template validation modes for PSScriptBuilder.
.DESCRIPTION
    The PSScriptBuilderTemplateValidationMode enum represents the different validation modes used when validating
    template files. The mode determines which placeholders are allowed and how the template structure is validated.

    - Free: No cross-dependencies between component types and no {{ORDERED_COMPONENTS}} placeholder in the
      template. Individual collector placeholders ({{USING}}, {{ENUM}}, {{CLASS}}, {{FUNCTION}}, {{FILE}}) are
      allowed and required.

    - Hybrid: No cross-dependencies between component types (HasCrossDependencies = false), but the template
      explicitly contains {{ORDERED_COMPONENTS}}. Validation and rendering behave identically to Ordered mode.
      Useful for mode-agnostic templates that remain valid regardless of whether cross-dependencies are
      introduced later.

    - Ordered: Cross-dependencies detected between Class and Function components (HasCrossDependencies = true).
      The {{ORDERED_COMPONENTS}} placeholder is required. The {{USING}} and {{FILE}} placeholders are allowed
      (if their collectors are registered). The {{ENUM}}, {{CLASS}}, and {{FUNCTION}} placeholders are forbidden
      as these components must be merged in dependency order within {{ORDERED_COMPONENTS}}.
#>
enum PSScriptBuilderTemplateValidationMode {
    <#
    .SYNOPSIS
        Free mode - individual collector placeholders allowed.
    .DESCRIPTION
        Free mode is used when no cross-dependencies exist between component types and the template does not
        contain the {{ORDERED_COMPONENTS}} placeholder. In this mode, individual collector placeholders are
        required and the {{ORDERED_COMPONENTS}} placeholder is absent.
    #>
    Free = 0

    <#
    .SYNOPSIS
        Hybrid mode - Free mode codebase with explicit {{ORDERED_COMPONENTS}} in the template.
    .DESCRIPTION
        Hybrid mode is used when no cross-dependencies exist (HasCrossDependencies = false), but the template
        explicitly contains the {{ORDERED_COMPONENTS}} placeholder. Validation and rendering behave identically
        to Ordered mode. This allows a template to remain valid regardless of whether cross-dependencies are
        introduced later, without requiring any template changes.
    #>
    Hybrid = 1

    <#
    .SYNOPSIS
        Ordered mode - ORDERED_COMPONENTS required, USING and FILE allowed.
    .DESCRIPTION
        Ordered mode is used when Class <-> Function dependencies exist (HasCrossDependencies = true).
        In this mode, the {{ORDERED_COMPONENTS}} placeholder is required, and {{USING}} and {{FILE}} placeholders
        are allowed (if their collectors are registered).
        Individual {{ENUM}}, {{CLASS}}, and {{FUNCTION}} placeholders are forbidden as these components must be
        merged in dependency order within {{ORDERED_COMPONENTS}}.
    #>
    Ordered = 2
}
#endregion Enum PSScriptBuilderTemplateValidationMode

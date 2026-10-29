# Compress-PSScriptBuilderScript

Post-processes a built PowerShell script by removing comments, blank lines, or output statements.

## Description

Applies one or more independent, freely-combinable transformations to an already-built script
file — typically to produce a leaner deployment artifact from a build output that's otherwise
kept readable (comments, blank lines, and diagnostic logging intact) during development.

Whatever operations are selected, they always run in this fixed order regardless of the order
the switches were passed in: `-RemoveComments`, then `-RemoveOutputStatements`, then
`-RemoveBlankLines` — so removing comments or output statements never leaves behind blank lines
that `-RemoveBlankLines` would otherwise have to clean up separately.

The original file is never modified unless `-DestinationPath` explicitly points back at it —
typically it points at a separate deploy location instead.

## Parameters

| Name | Type | Description |
|---|---|---|
| `-Path` | string | **Required.** Path to the script file to process. Aliased as `OutputPath`, so a [`PSScriptBuilderBuildResult`](../reference/types.md#psscriptbuilderbuildresult) can be piped in directly from [`Invoke-PSScriptBuilderBuild`](Invoke-PSScriptBuilderBuild.md). |
| `-RemoveComments` | switch | Remove every comment — single-line, block, and `#region`/`#endregion` markers. `#Requires` statements are always preserved. |
| `-RemoveBlankLines` | switch | Remove every line containing only whitespace. |
| `-RemoveOutputStatements` | string[] | Remove isolated calls to the given cmdlets: `Write-Verbose`, `Write-Debug`, `Write-Host`, `Write-Warning`, `Write-Information`. A call counts as isolated only when it stands alone as its own statement — not piped, and not nested inside `if`/`foreach`/other control flow. Non-isolated calls are skipped silently; use `-Verbose` to see which ones and why. |
| `-DestinationPath` | string | Path to write the processed script to. Omit to get the processed content back as a string instead. |
| `-Force` | switch | Overwrite `-DestinationPath` if it already exists. Without it, an existing file causes an `IOException`. |

## Examples

### Remove comments and blank lines before deploying

```powershell
Compress-PSScriptBuilderScript -Path '.\build\Output\MyScript.ps1' `
    -RemoveComments -RemoveBlankLines `
    -DestinationPath '.\deploy\MyScript.ps1' -Force
```

### Chain directly onto a build

```powershell
Invoke-PSScriptBuilderBuild -ContentCollector $contentCollector -TemplatePath '.\template.ps1' -OutputPath '.\output\MyScript.ps1' |
    Compress-PSScriptBuilderScript -RemoveComments -RemoveBlankLines -DestinationPath '.\deploy\MyScript.ps1' -Force
```

### Strip diagnostic logging calls only

```powershell
Compress-PSScriptBuilderScript -Path '.\output\MyScript.ps1' `
    -RemoveOutputStatements 'Write-Verbose', 'Write-Debug' `
    -DestinationPath '.\deploy\MyScript.ps1' -Force
```

### Get the result without writing a file

```powershell
$compressed = Compress-PSScriptBuilderScript -Path '.\output\MyScript.ps1' -RemoveComments
```

## Output

Returns the processed script as a `string` when `-DestinationPath` is omitted; otherwise writes
the file and returns nothing.

## See Also

- [Build Pipeline Guide: Post-Processing](../guides/build-pipeline.md#post-processing)
- [Cmdlet Reference: Invoke-PSScriptBuilderBuild](Invoke-PSScriptBuilderBuild.md)

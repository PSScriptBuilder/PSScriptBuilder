---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Watch-PSScriptBuilderProject

## SYNOPSIS
Watches project source files and triggers a build or custom script block on every change.

## SYNTAX

### Build (Default)
```
Watch-PSScriptBuilderProject -ContentCollector <PSScriptBuilderContentCollector> -TemplatePath <String>
 [-Debounce <Int32>] [-IncludeExtension <String[]>] -OutputPath <String> [-BackupPath <String>]
 [-OrderedComponentsKey <String>] [-EnableBackup] [-SkipSyntaxValidation] [-OnSuccess <ScriptBlock>]
 [-OnError <ScriptBlock>] [<CommonParameters>]
```

### Script
```
Watch-PSScriptBuilderProject -ContentCollector <PSScriptBuilderContentCollector> [-TemplatePath <String>]
 [-Debounce <Int32>] [-IncludeExtension <String[]>] -ScriptBlock <ScriptBlock>
 [<CommonParameters>]
```

## DESCRIPTION
The Watch-PSScriptBuilderProject cmdlet monitors the source directories of all registered
collectors and optionally the template file for changes.
When a change is detected, it
either runs a full build (Build mode) or invokes a user-provided script block (Script mode).

Multiple changes within the debounce window are collapsed into a single execution.
Changes
that arrive during a running build or script are collected and trigger exactly one additional
execution after the current one completes - without waiting for the debounce period again.

The watcher runs until stopped with Ctrl+C.
Build failures and script errors do not stop the watcher.

## EXAMPLES

### EXAMPLE 1
```
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'
Watch-PSScriptBuilderProject -ContentCollector $cc `
                             -TemplatePath     'build\MyModule.psm1.template' `
                             -OutputPath       'build\Output\MyModule.psm1'
```

Watches source directories and rebuilds on every change.
Press Ctrl+C to stop.

### EXAMPLE 2
```
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'
Watch-PSScriptBuilderProject -ContentCollector $cc `
                             -TemplatePath     'build\MyModule.psm1.template' `
                             -OutputPath       'build\Output\MyModule.psm1' `
                             -OnSuccess        { Invoke-Pester -Path 'tests' -Output Minimal }
```

Rebuilds on change and runs Pester tests after each successful build.

### EXAMPLE 3
```
$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath 'src\Classes' |
    Add-PSScriptBuilderCollector -Type Function -IncludePath 'src\Public'
Watch-PSScriptBuilderProject -ContentCollector $cc `
                             -ScriptBlock      {
                                 param([string[]] $changedFiles)
                                 Write-Host "Changed: $($changedFiles -join ', ')"
                                 & '.\my-build.ps1'
                             }
```

Watches source directories and runs a custom script block on every change.

## PARAMETERS

### -ContentCollector
The ContentCollector instance containing all registered collectors.
Used in both Build and Script mode to derive the directories to watch.

```yaml
Type: PSScriptBuilderContentCollector
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TemplatePath
The path to the template file.
When provided, the directory containing this file is added
to the watched paths.
Changes to the template file always trigger a rebuild or script
execution, regardless of the -IncludeExtension filter.
Mandatory in Build mode.
Optional in Script mode.
Can be relative (to project root) or absolute.

```yaml
Type: String
Parameter Sets: Build
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: String
Parameter Sets: Script
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Debounce
The number of milliseconds to wait after a change before triggering the build or script block.
Multiple changes within this window are collapsed into a single execution.
Default: 500.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 500
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeExtension
The file extensions that are allowed to trigger a build or script execution (e.g.
'.ps1').
The template file is always exempt from this filter.
Pass an empty array to allow all
extensions.
Applies to both Build and Script mode.
Default: @('.ps1').

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @('.ps1')
Accept pipeline input: False
Accept wildcard characters: False
```

### -ScriptBlock
A script block executed instead of a build when running in Script mode.
Receives the changed
file paths as a string array via the first argument.
Script mode only.

```yaml
Type: ScriptBlock
Parameter Sets: Script
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputPath
The path to the output file.
Automatically excluded from the watch to prevent rebuild loops.
Build mode only.
Can be relative (to project root) or absolute.

```yaml
Type: String
Parameter Sets: Build
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackupPath
The directory where backup files are stored before overwriting the existing output file.
Build mode only.
Can be relative (to project root) or absolute.

```yaml
Type: String
Parameter Sets: Build
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OrderedComponentsKey
The placeholder key in the template that will be replaced with the dependency-ordered
components.
Build mode only.
Defaults to "ORDERED_COMPONENTS".

```yaml
Type: String
Parameter Sets: Build
Aliases:

Required: False
Position: Named
Default value: ORDERED_COMPONENTS
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnableBackup
Enables backup creation of the existing output file before overwriting it.
Build mode only.

```yaml
Type: SwitchParameter
Parameter Sets: Build
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipSyntaxValidation
Skips the syntax validation step after writing the output file.
Build mode only.

```yaml
Type: SwitchParameter
Parameter Sets: Build
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -OnSuccess
An optional script block to execute after each successful build.
Receives the
PSScriptBuilderBuildResult as the first argument.
Build mode only.

```yaml
Type: ScriptBlock
Parameter Sets: Build
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OnError
An optional script block to execute after each failed build.
Receives a
PSScriptBuilderWatchBuildErrorResult as the first argument.
Build mode only.

```yaml
Type: ScriptBlock
Parameter Sets: Build
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### None
## NOTES
The watcher blocks the current thread until stopped with Ctrl+C.
The ContentCollector
cannot be modified while the watcher is running.

## RELATED LINKS

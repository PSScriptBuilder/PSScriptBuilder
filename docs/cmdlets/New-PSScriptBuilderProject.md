---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# New-PSScriptBuilderProject

## SYNOPSIS
Scaffolds a new PSScriptBuilder project structure.

## SYNTAX

```
New-PSScriptBuilderProject [-Name] <String> [[-Path] <String>] [-IncludeReleaseManagement] [-NoSampleFiles]
 [-Force] [<CommonParameters>]
```

## DESCRIPTION
The New-PSScriptBuilderProject cmdlet creates a complete project directory structure for a
new PSScriptBuilder project, including the configuration file, a template, a build script,
and all required source directories.

If -IncludeReleaseManagement is specified, the cmdlet also creates release management files:
psscriptbuilder.releasedata.json, psscriptbuilder.bumpconfig.json, and a Release script
with -Major, -Minor, and -Patch switches.

If the target directory already exists and is not empty, the cmdlet fails with an error.
Use -Force to overwrite existing files.

To add release management to an existing project, run the cmdlet again with
-IncludeReleaseManagement and -Force.
Note that -Force overwrites all existing project
files, including the configuration file, the build script, and the template.

## EXAMPLES

### EXAMPLE 1
```
New-PSScriptBuilderProject -Name "MyProject"
```

Creates a new project named "MyProject" in the current working directory,
including the configuration file, a template, a build script, and sample source files.

### EXAMPLE 2
```
New-PSScriptBuilderProject -Name "MyModule" -Path "C:\Projects" -IncludeReleaseManagement
```

Creates a new project in C:\Projects\MyModule with full release management support,
including psscriptbuilder.releasedata.json, psscriptbuilder.bumpconfig.json,
and a Release script with -Major, -Minor, and -Patch switches.

### EXAMPLE 3
```
New-PSScriptBuilderProject -Name "MyProject" -Force
```

Recreates the project structure in the current working directory,
overwriting existing files.
Useful for resetting a project to its default scaffolding.

### EXAMPLE 4
```
New-PSScriptBuilderProject -Name "MyProject" -NoSampleFiles
```

Creates a new project without sample source files.
Useful when starting from scratch
or in automated environments where example code would need to be removed anyway.

## PARAMETERS

### -Name
The name of the project to scaffold.
Used to derive file and directory names.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
The directory in which to create the project folder.
Defaults to the current working
directory if not specified.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeReleaseManagement
If specified, creates release management files in addition to the base project structure.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoSampleFiles
Suppresses creation of sample source files.
By default, sample files demonstrating
enum, class, and function definitions with dependency relationships are created.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Overwrites existing files in the target directory without error.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSScriptBuilderScaffoldingResult
## NOTES

## RELATED LINKS

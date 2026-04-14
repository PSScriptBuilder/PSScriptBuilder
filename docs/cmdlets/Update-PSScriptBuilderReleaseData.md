---
external help file: PSScriptBuilder-help.xml
Module Name: PSScriptBuilder
online version:
schema: 2.0.0
---

# Update-PSScriptBuilderReleaseData

## SYNOPSIS
Updates release data including version and metadata.

## SYNTAX

### Bump (Default)
```
Update-PSScriptBuilderReleaseData [-Major] [-Minor] [-Patch] [-Version <String>] [-Prerelease <String>]
 [-ClearPrerelease] [-BuildMetadata <String>] [-ClearBuildMetadata] [-UpdateBuildDetails] [-UpdateGitDetails]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Details
```
Update-PSScriptBuilderReleaseData [-Prerelease <String>] [-ClearPrerelease] [-BuildMetadata <String>]
 [-ClearBuildMetadata] [-UpdateBuildDetails] [-UpdateGitDetails] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The Update-PSScriptBuilderReleaseData cmdlet performs atomic release data management operations with 
transactional semantics and automatic rollback capability. 

It supports:

- Semantic version bumping (Major/Minor/Patch)
- Explicit version setting via -Version (e.g., "1.0.0", "2.1.0-beta")
- Build metadata updates (automatic or manual)
- Git metadata updates (automatic from repository)
- Prerelease and build metadata management

Operations are transactional with automatic rollback on failure.

## EXAMPLES

### EXAMPLE 1
```
# Bump major version and update build details (date, time, number)
Update-PSScriptBuilderReleaseData -Major -UpdateBuildDetails
```

### EXAMPLE 2
```
# Bump minor version with prerelease and preview changes
Update-PSScriptBuilderReleaseData -Minor -Prerelease "beta.1" -WhatIf
```

### EXAMPLE 3
```
# Set version directly to 1.0.0 and update build details
Update-PSScriptBuilderReleaseData -Version "1.0.0" -UpdateBuildDetails
```

### EXAMPLE 4
```
# Update only git details from repository
Update-PSScriptBuilderReleaseData -UpdateGitDetails
```

## PARAMETERS

### -Major
Increment the major version (X.0.0).
Resets minor and patch to 0.
Cannot be combined with -Minor or -Patch switches.

```yaml
Type: SwitchParameter
Parameter Sets: Bump
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Minor
Increment the minor version (0.X.0).
Resets patch to 0.
Cannot be combined with -Major or -Patch switches.

```yaml
Type: SwitchParameter
Parameter Sets: Bump
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Patch
Increment the patch version (0.0.X).
Cannot be combined with -Major or -Minor switches.

```yaml
Type: SwitchParameter
Parameter Sets: Bump
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version
Set an explicit version string (e.g., "1.0.0", "2.1.0-beta", "v1.0.0").
Supports SemVer formats including prerelease and build metadata.
Cannot be combined with -Major, -Minor, or -Patch.

```yaml
Type: String
Parameter Sets: Bump
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Prerelease
Set prerelease identifier (e.g., "alpha.1", "beta", "rc.1").
Must match pattern: ^\[0-9a-zA-Z\-\.\]+$
Can be combined with any version type or -BuildMetadata (per SemVer: 1.2.3-alpha+build.123).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClearPrerelease
Clear/remove the prerelease identifier (set to $null).
Cannot be combined with -Prerelease.

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

### -BuildMetadata
Set build metadata string (NOT auto-update).
Can be combined with -Prerelease (per SemVer: 1.2.3-alpha+build.123).
Must match pattern: ^\[0-9a-zA-Z\-\.\]+$
Different from -UpdateBuildDetails switch.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClearBuildMetadata
Clear/remove the build metadata (set to $null).
Cannot be combined with -BuildMetadata.

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

### -UpdateBuildDetails
Auto-update build details including:

- Date, time, timestamp, year, month, day, hour, minute, second
- Incrementing build number by 1
Can be combined with version bumps or used standalone.

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

### -UpdateGitDetails
Auto-update git details (commit hash, short commit, branch, latest tag) from repository.
Requires git command availability.
Can be combined with -Version or version bumps or used standalone.

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

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

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

### PSScriptBuilderReleaseDataResult
## NOTES

- Requires configuration to be loaded (PSScriptBuilderConfiguration.GetCurrent())
- Requires release data file to exist
- Supports PowerShell's ShouldProcess pattern (-Confirm, -WhatIf)
- Automatic rollback on failure restores all modified files

## RELATED LINKS

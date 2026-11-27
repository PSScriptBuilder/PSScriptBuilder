<#
.SYNOPSIS
    Build script for PSScriptBuilder module with automatic dependency resolution.

.DESCRIPTION
    This script builds the PSScriptBuilder module by:
    1. Analyzing dependencies of all PowerShell files
    2. Resolving the correct load order using topological sort
    3. Dot-sourcing files in dependency order to make all classes available
    4. Loading configuration from PSScriptBuilderConfiguration
    5. Creating the compiled module

.PARAMETER ProjectRoot
    (Required) The root path of the PSScriptBuilder project.

.PARAMETER Verbose
    Show detailed build information.

.EXAMPLE
    .\build.ps1 -ProjectRoot 'C:\PSScriptBuilder'
    .\build.ps1 -ProjectRoot 'C:\PSScriptBuilder' -Verbose
#>

using namespace System.Collections.Generic
using namespace System.Management.Automation.Language

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $ProjectRoot
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Resolve ProjectRoot to absolute path
$ProjectRoot = ($ProjectRoot | Resolve-Path).ProviderPath

# Store in global variable for reference
$Global:PSScriptBuilderProjectRoot = $ProjectRoot

#region Build Configuration
$SrcPath     = Join-Path $ProjectRoot 'src'
$EnumPath    = Join-Path $SrcPath 'Enums'
$ClassesPath = Join-Path $SrcPath 'Classes'
$PrivatePath = Join-Path $SrcPath 'Private'
$PublicPath  = Join-Path $SrcPath 'Public'

Write-Information "=== PSScriptBuilder Build ==="
Write-Information "ProjectRoot: $ProjectRoot"
Write-Verbose "SrcPath: $SrcPath"
#endregion Build Configuration

#region Dependency Analysis
class FileDependency {
    [string] $FilePath
    [string] $FileName
    [string[]] $DependsOn = @()
    [string[]] $UsingStatements = @()
    [string] $Type
}

function Analyze-FileDependencies {
    param(
        [string] $FilePath,
        [string] $Type
    )

    $fileName = Split-Path -Path $FilePath -Leaf
    $dependencies = @()
    $usingStatements = @()

    try {
        $ast = [Parser]::ParseFile($FilePath, [ref] $null, [ref] $null)
        $content = Get-Content -Path $FilePath -Raw

        $usingAsts = $ast.FindAll({ param($node) $node -is [UsingStatementAst] }, $true)
        foreach ($using in $usingAsts) {
            $usingName = $using.Name.Value
            $usingKind = $using.UsingStatementKind

            $usingStatement = "using $($usingKind.ToString().ToLower()) $usingName"
            if ($usingStatement -notin $usingStatements) {
                $usingStatements += $usingStatement
            }
        }

        # Find dependencies via AST
        $typeDefinitions = $ast.FindAll({ param($node) $node -is [TypeDefinitionAst] }, $true)
        foreach ($typeDef in $typeDefinitions) {
            # Base classes
            if ($typeDef.BaseTypes.Count -gt 0) {
                foreach ($baseType in $typeDef.BaseTypes) {
                    $baseTypeName = $null
                    if ($baseType.TypeName) {
                        $baseTypeName = $baseType.TypeName.Name
                    }
                    elseif ($baseType -is [TypeExpressionAst]) {
                        $baseTypeName = $baseType.Type.Name
                    }
                    
                    if ($baseTypeName -and $baseTypeName -match '^PSScriptBuilder' -and $baseTypeName -notin $dependencies) {
                        $dependencies += $baseTypeName
                    }
                }
            }

            # Member types (properties and method return types)
            foreach ($member in $typeDef.Members) {
                if ($member -is [PropertyMemberAst]) {
                    # Property types - including generics like Dictionary[string, Type]
                    if ($member.PropertyType -and $member.PropertyType.TypeName) {
                        # Get the full type string (may include generic parameters)
                        $typeStr = $member.PropertyType.TypeName.Name
                        
                        # Extract all PSScriptBuilder types from the string
                        $typeMatches = [regex]::Matches($typeStr, '\bPSScriptBuilder\w+')
                        foreach ($match in $typeMatches) {
                            $typeName = $match.Value
                            if ($typeName -notin $dependencies) {
                                $dependencies += $typeName
                            }
                        }
                    }
                }
                elseif ($member -is [FunctionMemberAst]) {
                    # Return types
                    if ($member.ReturnType -and $member.ReturnType.TypeName) {
                        $typeStr = $member.ReturnType.TypeName.Name
                        $typeMatches = [regex]::Matches($typeStr, '\bPSScriptBuilder\w+')
                        foreach ($match in $typeMatches) {
                            $typeName = $match.Value
                            if ($typeName -notin $dependencies) {
                                $dependencies += $typeName
                            }
                        }
                    }
                    
                    # Parameter types
                    if ($member.Parameters) {
                        foreach ($param in $member.Parameters) {
                            foreach ($attribute in $param.Attributes) {
                                if ($attribute -is [TypeConstraintAst] -and $attribute.TypeName) {
                                    $typeStr = $attribute.TypeName.Name
                                    $typeMatches = [regex]::Matches($typeStr, '\bPSScriptBuilder\w+')
                                    foreach ($match in $typeMatches) {
                                        $typeName = $match.Value
                                        if ($typeName -notin $dependencies) {
                                            $dependencies += $typeName
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        # Find static method calls like [PSScriptBuilderFileSystemHelper]::Method()
        # Use regex to find [ClassName]:: patterns in the source code
        $staticCallMatches = [regex]::Matches($content, '\[PSScriptBuilder\w+\]::', 'IgnoreCase')
        foreach ($match in $staticCallMatches) {
            # Extract the class name from [ClassName]::
            $fullMatch = $match.Value
            $typeName = $fullMatch.Substring(1, $fullMatch.Length - 4)  # Remove [ and ]::
            if ($typeName -notin $dependencies) {
                $dependencies += $typeName
            }
        }
    }
    catch {
        Write-Warning "Error parsing $fileName : $($_.Exception.Message)"
    }

    # Get the class/enum names defined in this file
    $content = Get-Content -Path $FilePath -Raw
    $definedNames = @()
    $classMatches = [regex]::Matches($content, 'class\s+(\w+)', 'IgnoreCase')
    foreach ($match in $classMatches) {
        $definedNames += $match.Groups[1].Value
    }
    $enumMatches = [regex]::Matches($content, 'enum\s+(\w+)', 'IgnoreCase')
    foreach ($match in $enumMatches) {
        $definedNames += $match.Groups[1].Value
    }
    
    # Filter out self-references
    $uniqueDependencies = @($dependencies | Where-Object { $_ -notin $definedNames })

    return [PSCustomObject] @{
        FilePath = $FilePath
        FileName = $fileName
        DependsOn = @($uniqueDependencies | Select-Object -Unique)
        UsingStatements = @($usingStatements | Select-Object -Unique)
        Type = $Type
    }
}

function Build-ClassNameMap {
    param(
        [FileDependency[]] $FileDependencies
    )

    $map = @{}

    foreach ($dep in $FileDependencies) {
        try {
            $ast = [Parser]::ParseFile($dep.FilePath, [ref] $null, [ref] $null)

            # Find actual class definitions using AST
            $classDefinitions = $ast.FindAll({ param($node) $node -is [TypeDefinitionAst] }, $true)
            foreach ($classdef in $classDefinitions) {
                $className = $classdef.Name
                $map[$className] = $dep.FilePath
            }
        }
        catch {
            Write-Warning "Error parsing $($dep.FileName): $($_.Exception.Message)"
        }
    }

    Write-Verbose "  Classes found: $($map.Count)"
    return $map
}

function Resolve-FileDependencies {
    param(
        [object[]] $FileDependencies,
        [hashtable] $ClassNameMap
    )

    foreach ($fileDep in $FileDependencies) {
        $resolvedDeps = @()

        foreach ($dep in $fileDep.DependsOn) {
            if ($ClassNameMap.ContainsKey($dep)) {
                $depFilePath = $ClassNameMap[$dep]
                if ($depFilePath -ne $fileDep.FilePath -and $depFilePath -notin $resolvedDeps) {
                    $resolvedDeps += $depFilePath
                }
            }
        }

        $fileDep.DependsOn = $resolvedDeps
    }
}

function Resolve-LoadOrder {
    param(
        [FileDependency[]] $FileDependencies
    )

    # Create lookup map for quick file access by path
    $fileMap = @{}
    foreach ($file in $FileDependencies) {
        $fileMap[$file.FilePath] = $file
    }

    # Build graph of dependencies: file -> list of files that depend on it
    $graph = @{}
    $inDegree = @{}

    # Initialize all nodes
    foreach ($file in $FileDependencies) {
        if (-not $graph.ContainsKey($file.FilePath)) {
            $graph[$file.FilePath] = @()
        }
        if (-not $inDegree.ContainsKey($file.FilePath)) {
            $inDegree[$file.FilePath] = 0
        }
    }

    # Build edges and calculate in-degrees
    # If file A depends on file B, then B -> A (B must be loaded before A)
    foreach ($file in $FileDependencies) {
        foreach ($depFile in $file.DependsOn) {
            # depFile must be loaded before file
            # So: graph[depFile] += file (depFile points to file)
            # And: inDegree[file]++
            
            if (-not $graph.ContainsKey($depFile)) {
                # Dependency resolved to a file that doesn't exist in our list
                # This shouldn't happen if Resolve-FileDependencies is working correctly
                Write-Verbose "WARNING: Dependency file '$depFile' not found in file list"
                continue
            }
            
            if ($file.FilePath -notin $graph[$depFile]) {
                $graph[$depFile] += $file.FilePath
                $inDegree[$file.FilePath]++
            }
        }
    }

    if ($Verbose) {
        Write-Verbose "Kahn's Algorithm - In-Degrees:"
        foreach ($file in $inDegree.GetEnumerator() | Sort-Object Value -Descending) {
            $fileName = Split-Path -Leaf $file.Key
            Write-Verbose "  $fileName : $($file.Value)"
        }
    }

    # Kahn's algorithm
    [System.Collections.Queue] $queue = [System.Collections.Queue]::new()
    
    # Start with files that have no dependencies
    $noDepFiles = @($inDegree.Keys | Where-Object { $inDegree[$_] -eq 0 })
    Write-Verbose "Starting with $($noDepFiles.Count) files with no dependencies"
    
    foreach ($filePath in $noDepFiles) {
        $queue.Enqueue($filePath)
    }

    $sorted = @()

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $sorted += $current

        # For each file that depends on current
        foreach ($dependent in $graph[$current]) {
            # Decrement in-degree
            $inDegree[$dependent]--
            
            # If all dependencies are satisfied, add to queue
            if ($inDegree[$dependent] -eq 0) {
                $queue.Enqueue($dependent)
            }
        }
    }

    # Check for cycles
    if ($sorted.Count -lt $FileDependencies.Count) {
        $unprocessed = @()
        foreach ($file in $FileDependencies) {
            if ($file.FilePath -notin $sorted) {
                $unprocessed += $file.FileName
            }
        }
        throw "Circular dependency detected: $($unprocessed -join ', ')"
    }

    return $sorted
}
#endregion Dependency Analysis

#region Build Process
Write-Information ""

$allFiles = @()

if (Test-Path $EnumPath) {
    Get-ChildItem -Path $EnumPath -Filter '*.ps1' | ForEach-Object {
        $dep = Analyze-FileDependencies -FilePath $_.FullName -Type 'Enum'
        $allFiles += $dep
        Write-Verbose "  Found enum: $($_.Name)"
    }
}

if (Test-Path $ClassesPath) {
    Get-ChildItem -Path $ClassesPath -Recurse -Filter '*.ps1' | ForEach-Object {
        $dep = Analyze-FileDependencies -FilePath $_.FullName -Type 'Class'
        $allFiles += $dep
        Write-Verbose "  Found class: $($_.Name)"
    }
}

if (Test-Path $PrivatePath) {
    Get-ChildItem -Path $PrivatePath -Filter '*.ps1' | ForEach-Object {
        $dep = Analyze-FileDependencies -FilePath $_.FullName -Type 'Private'
        $allFiles += $dep
        Write-Verbose "  Found private: $($_.Name)"
    }
}

if (Test-Path $PublicPath) {
    Get-ChildItem -Path $PublicPath -Filter '*.ps1' | ForEach-Object {
        $dep = Analyze-FileDependencies -FilePath $_.FullName -Type 'Public'
        $allFiles += $dep
        Write-Verbose "  Found cmdlet: $($_.Name)"
    }
}

Write-Verbose "  Total files found: $($allFiles.Count)"
Write-Information "  [OK] Dependency analysis      ($($allFiles.Count) files)"

$classNameMap = Build-ClassNameMap -FileDependencies $allFiles
Write-Information "  [OK] Class name map           ($($classNameMap.Count) classes)"

Resolve-FileDependencies -FileDependencies $allFiles -ClassNameMap $classNameMap

foreach ($file in $allFiles) {
    if ($file.DependsOn.Count -gt 0) {
        $deps = ($file.DependsOn | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', '
        Write-Verbose "  $($file.FileName) depends on: $deps"
    }
}

$loadOrder = Resolve-LoadOrder -FileDependencies $allFiles

# Filter out invalid paths (should only contain file paths)
$loadOrder = $loadOrder | Where-Object { Test-Path $_ -PathType Leaf }

Write-Verbose "  Load order:"
$loadOrder | ForEach-Object {
    $fileName = Split-Path -Path $_ -Leaf
    Write-Verbose "    $([Array]::IndexOf($loadOrder, $_) + 1). $fileName"
}
Write-Information "  [OK] Load order resolved      ($($loadOrder.Count) files)"

foreach ($filePath in $loadOrder) {
    try {
        $fileName = Split-Path -Path $filePath -Leaf
        . $filePath
        Write-Verbose "  Loaded: $fileName"
    }
    catch {
        Write-Information "  [FAIL] Classes loaded         -> Failed to load: $filePath"
        throw
    }
}
Write-Information "  [OK] Files loaded             ($($loadOrder.Count) files)"

$configuration = [PSScriptBuilderConfiguration]::new()

# Resolve output path - if it's relative, resolve it from ProjectRoot; if absolute, use as-is
if ([System.IO.Path]::IsPathRooted($configuration.Build.OutputPath)) {
    $OutputPath = $configuration.Build.OutputPath
} else {
    $OutputPath = Join-Path $ProjectRoot $configuration.Build.OutputPath
}

$ModuleFile = Join-Path $OutputPath 'PSScriptBuilder.psm1'
Write-Verbose "Output path: $OutputPath"
Write-Verbose ($configuration | Format-List | Out-String)
Write-Information "  [OK] Configuration loaded"

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Verbose "  Created output directory: $OutputPath"
}

$moduleContent = @()
$allUsingStatements = @()

foreach ($filePath in $loadOrder) {
    $content = Get-Content -Path $filePath -Raw
    $fileName = Split-Path -Path $filePath -Leaf

    $fileDep = $allFiles | Where-Object { $_.FilePath -eq $filePath }
    if ($fileDep) {
        foreach ($using in $fileDep.UsingStatements) {
            if ($using -notin $allUsingStatements) {
                $allUsingStatements += $using
            }
        }
    }

    $cleanContent = $content -replace '(?m)^using\s+(?:namespace|assembly|module)\s+[^\r\n]+[\r\n]*', ''

    $regionStart = "#region $fileName`n"
    $regionEnd = "`n#endregion $fileName`n`n"
    $moduleContent += $regionStart + $cleanContent + $regionEnd
}

$finalContent = @()

if ($allUsingStatements.Count -gt 0) {
    Write-Verbose "  Adding $($allUsingStatements.Count) using statement(s)..."
    foreach ($using in $allUsingStatements | Sort-Object) {
        $finalContent += $using
    }
    $finalContent += ""
}

$finalContent += $moduleContent

$finalContent -join "`n" | Out-File $ModuleFile -Encoding UTF8 -Force

$moduleSizeKB = [Math]::Round((Get-Item $ModuleFile).Length / 1KB, 1)
Write-Verbose "  Module compiled: $ModuleFile"
Write-Verbose "  Module size: ${moduleSizeKB} KB"
Write-Information "  [OK] Module compiled          ($(Split-Path $ModuleFile -Leaf), ${moduleSizeKB} KB)"

$syntaxTokens = $null
$syntaxErrors = $null
[Parser]::ParseFile($ModuleFile, [ref] $syntaxTokens, [ref] $syntaxErrors) | Out-Null

if ($syntaxErrors.Count -gt 0) {
    Write-Information "  [FAIL] Syntax validation      -> $($syntaxErrors[0].Message)"
    throw [System.InvalidOperationException]::new("Module syntax validation failed: $($syntaxErrors[0].Message)")
}

Write-Information "  [OK] Syntax validation"
#endregion Build Process

Write-Information ""
Write-Information "=== Build completed successfully ==="
Write-Verbose "Module location: $ModuleFile"
Write-Information ""

#Requires -Version 5.1
<#
.SYNOPSIS
    Project analysis script for PSScriptBuilder — reports codebase metrics.
.DESCRIPTION
    Analyzes the PSScriptBuilder project itself and reports metrics across four
    categories: overview (component counts), inheritance chains, dependency graph
    statistics, and quality indicators (cycles, unused components, file density).
.EXAMPLE
    .\tests\Invoke-ProjectAnalysis.ps1
    Runs the full analysis and displays a formatted report.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#region Setup
$ProjectRoot      = Resolve-Path "$PSScriptRoot\.."
$ModulePath       = Join-Path $ProjectRoot 'build\Output\PSScriptBuilder.psd1'
$SourceDir        = Join-Path $ProjectRoot 'src'
$SourceEnumsDir   = Join-Path $ProjectRoot 'src\Enums'
$SourceClassesDir = Join-Path $ProjectRoot 'src\Classes'
$SourcePrivateDir = Join-Path $ProjectRoot 'src\Private'
$SourcePublicDir  = Join-Path $ProjectRoot 'src\Public'

Write-Host ''
Write-Host "  PSScriptBuilder $([char] 0x2014) Project Analysis" -ForegroundColor White
Write-Host "  $([string]::new([char] 0x2550, 34))"               -ForegroundColor DarkGray
Write-Host "  Project : $ProjectRoot"                            -ForegroundColor DarkGray
Write-Host "  Module  : $ModulePath"                             -ForegroundColor DarkGray
#endregion Setup

#region Initialize
Import-Module $ModulePath -Force
Set-PSScriptBuilderProjectRoot -Path $ProjectRoot

$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Using    -IncludePath $SourceDir |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath $SourceEnumsDir |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $SourceClassesDir |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $SourcePrivateDir, $SourcePublicDir

$analysis = $cc | Get-PSScriptBuilderDependencyAnalysis

# Retrieve collected data — collectors were executed by Get-PSScriptBuilderDependencyAnalysis
$classData = @($cc | Get-PSScriptBuilderCollector -Type ClassCollector    | Get-PSScriptBuilderCollectorContent)
$enumData  = @($cc | Get-PSScriptBuilderCollector -Type EnumCollector     | Get-PSScriptBuilderCollectorContent)
$funcData  = @($cc | Get-PSScriptBuilderCollector -Type FunctionCollector | Get-PSScriptBuilderCollectorContent)

$unusedComponents = @($cc | Find-PSScriptBuilderUnusedComponent -EntryPoint '*-PSScriptBuilder*')
#endregion Initialize

#region Helpers
function Write-SectionHeader {
    param([string]$Title)
    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "  $([string]::new([char] 0x2500, $Title.Length))" -ForegroundColor DarkGray
}

function Write-Metric {
    param(
        [string] $Label,
        [object] $Value,
        [string] $Color = 'White',
        [string] $Note  = ''
    )
    $paddedLabel = $Label.PadRight(24)
    Write-Host "  $paddedLabel : " -NoNewline
    Write-Host $Value -ForegroundColor $Color -NoNewline

    if ($Note) {
        Write-Host "  ($Note)" -ForegroundColor DarkGray -NoNewline
    }

    Write-Host ''
}

function Write-CountMetric {
    param(
        [string]   $Label,
        [int]      $Count,
        [string[]] $Names = @(),
        [int]      $Width = 0
    )
    $paddedLabel  = $Label.PadRight(24)
    $displayCount = if ($Width -gt 0) { $Count.ToString().PadLeft($Width) } else { $Count.ToString() }

    Write-Host "  $paddedLabel : " -NoNewline

    if ($Count -eq 0) {
        Write-Host $displayCount -ForegroundColor Green -NoNewline
        Write-Host "  $([char]0x2714) None" -ForegroundColor DarkGray -NoNewline
    }
    else {
        Write-Host $displayCount -ForegroundColor Yellow -NoNewline

        if ($Names.Count -gt 0) {
            if ($Names.Count -le 3) {
                $displayNames = $Names -join ', '
            }
            else {
                $displayNames = "$($Names[0..2] -join ', ') and $($Names.Count - 3) more"
            }

            Write-Host "  ($displayNames)" -ForegroundColor DarkGray -NoNewline
        }
    }

    Write-Host ''
}
#endregion Helpers

#region OVERVIEW
Write-SectionHeader 'OVERVIEW'

$counts = $analysis.ComponentCounts
$overviewValues = @(
    $counts.ClassDefinitions,
    $counts.EnumDefinitions,
    $counts.FunctionDefinitions,
    $counts.FileContents,
    $counts.UsingStatements,
    $analysis.TotalComponents
)

$overviewWidth = ($overviewValues | ForEach-Object { $_.ToString().Length } | Measure-Object -Maximum).Maximum

Write-Metric 'Classes'   $counts.ClassDefinitions.ToString().PadLeft($overviewWidth)
Write-Metric 'Enums'     $counts.EnumDefinitions.ToString().PadLeft($overviewWidth)
Write-Metric 'Functions' $counts.FunctionDefinitions.ToString().PadLeft($overviewWidth)
Write-Metric 'Files'     $counts.FileContents.ToString().PadLeft($overviewWidth)
Write-Metric 'Usings'    $counts.UsingStatements.ToString().PadLeft($overviewWidth)
Write-Host "  $([string]::new([char]0x2500, 32))" -ForegroundColor DarkGray
Write-Metric 'Total'     $analysis.TotalComponents.ToString().PadLeft($overviewWidth)
#endregion OVERVIEW

#region INHERITANCE
Write-SectionHeader 'INHERITANCE'

# Build class name → base class lookup (own classes only)
$classMap = @{}

foreach ($cd in $classData) {
    $classMap[$cd.Name] = $cd.BaseClass
}

# Compute the deepest inheritance chain within own classes
$maxDepth     = 0
$deepestChain = @()

foreach ($cd in $classData) {
    $chain = [System.Collections.Generic.List[string]]::new()
    $chain.Add($cd.Name)

    $current = $cd.BaseClass
    $visited = @{}

    while (-not [string]::IsNullOrEmpty($current) -and $classMap.ContainsKey($current) -and -not $visited.ContainsKey($current)) {
        $visited[$current] = $true
        $chain.Add($current)
        $current = $classMap[$current]
    }

    if ($chain.Count -gt $maxDepth) {
        $maxDepth     = $chain.Count
        $deepestChain = @($chain)
    }
}

$inheritanceDepth = $maxDepth - 1
$classesWithBase  = @($classData | Where-Object { -not [string]::IsNullOrEmpty($_.BaseClass) -and $classMap.ContainsKey($_.BaseClass) })

Write-Metric 'Classes with base class' "$($classesWithBase.Count) / $($counts.ClassDefinitions)"
Write-Metric 'Deepest chain (depth)'   $inheritanceDepth

if ($deepestChain.Count -gt 0 -and $inheritanceDepth -gt 0) {
    Write-Host "    $([char] 0x21B3) $($deepestChain -join ' -> ')" -ForegroundColor DarkGray
}
#endregion INHERITANCE

#region DEPENDENCIES
Write-SectionHeader 'DEPENDENCIES'

$graph = $analysis.DependencyGraph

if ($null -ne $graph) {
    # Build Fan-Out (outgoing) and Fan-In (incoming) per node
    $fanOut = @{}
    $fanIn  = @{}

    foreach ($node in $graph.Dependencies.Keys) {
        if (-not $fanOut.ContainsKey($node)) { $fanOut[$node] = 0 }
        if (-not $fanIn.ContainsKey($node))  { $fanIn[$node]  = 0 }

        $uniqueTargets = @($graph.Dependencies[$node] | Select-Object -ExpandProperty Target -Unique)
        $fanOut[$node] = $uniqueTargets.Count

        foreach ($target in $uniqueTargets) {
            if (-not $fanIn.ContainsKey($target)) { $fanIn[$target] = 0 }
            $fanIn[$target]++
        }
    }

    # Average dependencies per node
    if ($analysis.TotalNodes -gt 0) {
        $avgDeps = [math]::Round($analysis.TotalEdges / $analysis.TotalNodes, 1)
    }
    else {
        $avgDeps = 0
    }

    # Highest Fan-Out and Fan-In
    $topFanOut = $fanOut.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
    $topFanIn  = $fanIn.GetEnumerator()  | Sort-Object Value -Descending | Select-Object -First 1

    if ($topFanOut) {
        $topFanOutValue = $topFanOut.Value.ToString()
        $topFanOutName  = $topFanOut.Name
    }
    else {
        $topFanOutValue = '0'
        $topFanOutName  = ''
    }

    if ($topFanIn) {
        $topFanInValue = $topFanIn.Value.ToString()
        $topFanInName  = $topFanIn.Name
    }
    else {
        $topFanInValue = '0'
        $topFanInName  = ''
    }

    # Longest transitive chain — longest path in DAG via DP on topological order
    $longestChain = 0

    if (-not $analysis.HasCycles -and $analysis.OrderedComponents.Count -gt 0) {
        $dist = @{}

        foreach ($node in $analysis.OrderedComponents) { $dist[$node] = 0 }

        foreach ($node in $analysis.OrderedComponents) {
            if ($graph.Dependencies.ContainsKey($node)) {
                foreach ($edge in $graph.Dependencies[$node]) {
                    $target = $edge.Target

                    if ($dist.ContainsKey($target)) {
                        $newDist = $dist[$target] + 1

                        if ($newDist -gt $dist[$node]) { $dist[$node] = $newDist }
                    }
                }
            }
        }

        $maxDistResult = $dist.Values | Measure-Object -Maximum

        if ($null -ne $maxDistResult.Maximum) {
            $longestChain = [int]$maxDistResult.Maximum
        }
    }

    # Isolated components — Fan-In = 0 AND Fan-Out = 0
    $isolatedNames = @($graph.Dependencies.Keys | Where-Object { $fanIn[$_] -eq 0 -and $fanOut[$_] -eq 0 })

    # Compute display width from all dependency values
    $depsWidth = (@(
        $analysis.TotalNodes.ToString()
        $analysis.TotalEdges.ToString()
        $avgDeps.ToString()
        $topFanOutValue
        $topFanInValue
        $longestChain.ToString()
        $isolatedNames.Count.ToString()
    ) | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

    Write-Metric 'Nodes'           $analysis.TotalNodes.ToString().PadLeft($depsWidth)
    Write-Metric 'Edges'           $analysis.TotalEdges.ToString().PadLeft($depsWidth)
    Write-Metric 'Avg per node'    $avgDeps.ToString().PadLeft($depsWidth)
    Write-Metric 'Highest fan-out' $topFanOutValue.PadLeft($depsWidth) -Note $topFanOutName
    Write-Metric 'Highest fan-in'  $topFanInValue.PadLeft($depsWidth)  -Note $topFanInName
    Write-Metric 'Longest chain'   $longestChain.ToString().PadLeft($depsWidth)
    Write-CountMetric 'Isolated' $isolatedNames.Count $isolatedNames -Width $depsWidth
}
else {
    Write-Host '  (Graph unavailable — cycles detected)' -ForegroundColor Yellow
}
#endregion DEPENDENCIES

#region QUALITY
Write-SectionHeader 'QUALITY'

# Cycles
$paddedCycleLabel = 'Cycles'.PadRight(24)

Write-Host "  $paddedCycleLabel : " -NoNewline

if ($analysis.HasCycles) {
    $cyclePath = $analysis.CyclePath -join ' -> '
    Write-Host 'DETECTED' -ForegroundColor Red -NoNewline
    Write-Host "  ($cyclePath)" -ForegroundColor DarkGray -NoNewline
}
else {
    Write-Host '0' -ForegroundColor Green -NoNewline
    Write-Host "  $([char]0x2714) None" -ForegroundColor DarkGray -NoNewline
}

Write-Host ''

# Unused components
$unusedNames = @($unusedComponents | Select-Object -ExpandProperty Name)
Write-CountMetric 'Unused components'  $unusedNames.Count $unusedNames

# Multiple components per file
$fileMap = @{}
foreach ($cd in $classData) {
    if (-not $fileMap.ContainsKey($cd.SourceFile)) { $fileMap[$cd.SourceFile] = [System.Collections.Generic.List[string]]::new() }
    $fileMap[$cd.SourceFile].Add($cd.Name)
}

foreach ($ed in $enumData) {
    if (-not $fileMap.ContainsKey($ed.SourceFile)) { $fileMap[$ed.SourceFile] = [System.Collections.Generic.List[string]]::new() }
    $fileMap[$ed.SourceFile].Add($ed.Name)
}

foreach ($fd in $funcData) {
    if (-not $fileMap.ContainsKey($fd.SourceFile)) { $fileMap[$fd.SourceFile] = [System.Collections.Generic.List[string]]::new() }
    $fileMap[$fd.SourceFile].Add($fd.Name)
}

$multiFiles     = @($fileMap.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 })
$multiFileNames = @($multiFiles | ForEach-Object { [System.IO.Path]::GetFileName($_.Key) })

Write-CountMetric 'Multiple per file'  $multiFiles.Count $multiFileNames
#endregion QUALITY

Write-Host ''

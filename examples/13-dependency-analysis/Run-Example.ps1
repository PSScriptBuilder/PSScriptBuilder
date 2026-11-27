using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

# ============================================================
# Setup: register collectors for PSScriptBuilder source itself
# ============================================================

$enumsPath   = Join-Path $PSScriptRoot '..\..\src\Enums'
$classesPath = Join-Path $PSScriptRoot '..\..\src\Classes'
$privatePath = Join-Path $PSScriptRoot '..\..\src\Private'
$publicPath  = Join-Path $PSScriptRoot '..\..\src\Public'

$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -IncludePath $enumsPath |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $privatePath, $publicPath

Write-Host ''
Write-Host '=== Scenario 1: Dependency analysis overview ===' -ForegroundColor Cyan

$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc

Write-Host "Enums            : $($analysis.ComponentCounts.EnumDefinitions)"
Write-Host "Classes          : $($analysis.ComponentCounts.ClassDefinitions)"
Write-Host "Functions        : $($analysis.ComponentCounts.FunctionDefinitions)"
Write-Host "Total components : $($analysis.TotalComponents)"
Write-Host "Total nodes      : $($analysis.TotalNodes)"
Write-Host "Total edges      : $($analysis.TotalEdges)"
Write-Host "Has cycles       : $($analysis.HasCycles)"
Write-Host "Has cross-deps   : $($analysis.HasCrossDependencies)"

Write-Host ''
Write-Host '=== Scenario 2: Cycle check ===' -ForegroundColor Cyan

if ($analysis.HasCycles) {
    Write-Warning "Cycle detected: $($analysis.CyclePath -join ' -> ')"
}
else {
    Write-Host 'No cycles detected - project is clean.'
}

Write-Host ''
Write-Host '=== Scenario 3: Ordered components (topological sort) ===' -ForegroundColor Cyan

Write-Host "Ordered components ($($analysis.OrderedComponents.Count)):"
$analysis.OrderedComponents | ForEach-Object { Write-Host "  $_" }

Write-Host ''
Write-Host '=== Scenario 4: Export Mermaid diagram to .md file (Dependencies subsystem only) ===' -ForegroundColor Cyan

# The full project has 60+ components - far too large for a readable Mermaid diagram.
# Scoping to the Dependencies subsystem (8 classes) produces a meaningful diagram.
$depsPath = Join-Path $PSScriptRoot '..\..\src\Classes\ScriptBuilder\Dependencies'

$ccDeps = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -IncludePath $depsPath

$analysisDeps = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $ccDeps

$outputDir   = Join-Path $PSScriptRoot 'output'
$mermaidPath = Join-Path $outputDir 'dependency-graph.md'

if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }

$analysisDeps | Export-PSScriptBuilderDependencyGraph -OutputPath $mermaidPath -Force
Write-Host "Mermaid diagram written to: $mermaidPath"
Write-Host "(Open in VS Code Markdown preview or GitHub to render the graph)"

Write-Host ''
Write-Host '=== Scenario 5: Export Graphviz DOT diagram (with edge types) ===' -ForegroundColor Cyan

# Scoped to Collectors + Core + Dependencies (~17 classes) to show cross-subsystem relationships.
# The -IncludeEdgeTypes switch annotates each edge with its dependency type (Inheritance, TypeReference, ...).
$collectorsPath = Join-Path $PSScriptRoot '..\..\src\Classes\ScriptBuilder\Collectors'
$corePath       = Join-Path $PSScriptRoot '..\..\src\Classes\ScriptBuilder\Core'

$ccDot = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'COLLECTORS' -IncludePath $collectorsPath |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'CORE'       -IncludePath $corePath |
    Add-PSScriptBuilderCollector -Type Class -CollectionKey 'DEPS'       -IncludePath $depsPath

$analysisDot = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $ccDot

$dotPath = Join-Path $outputDir 'dependency-graph.dot'
$analysisDot | Export-PSScriptBuilderDependencyGraph -Format Dot -IncludeEdgeTypes -OutputPath $dotPath -Force
Write-Host "Graphviz DOT diagram written to: $dotPath"
Write-Host "(Visualize at https://viz-js.com)"

Write-Host ''
Write-Host '=== Scenario 6: Drill-down - what does PSScriptBuilderBuildOrchestrator depend on? ===' -ForegroundColor Cyan

$analysis | Get-PSScriptBuilderComponentDependency -Name 'PSScriptBuilderBuildOrchestrator' -Direction Dependencies |
    ConvertTo-PSScriptBuilderComponentDependencyTree

Write-Host ''
Write-Host '=== Scenario 7: Drill-down - who inherits from PSScriptBuilderCollectorBase? ===' -ForegroundColor Cyan

$analysis | Get-PSScriptBuilderComponentDependency -Name 'PSScriptBuilderCollectorBase' -Direction Dependents -EdgeType  Inheritance |
    ConvertTo-PSScriptBuilderComponentDependencyTree

Write-Host ''
Write-Host '=== Scenario 8: Drill-down - who depends on PSScriptBuilderDependencyGraph? ===' -ForegroundColor Cyan

$analysis | Get-PSScriptBuilderComponentDependency -Name 'PSScriptBuilderDependencyGraph' -Direction Dependents |
    ConvertTo-PSScriptBuilderComponentDependencyTree

Write-Host ''
Write-Host '=== Scenario 9: Top 5 components with most transitive dependencies ===' -ForegroundColor Cyan

$analysis.DependencyGraph.Dependencies.Keys | ForEach-Object {
    $depEntries = $analysis | Get-PSScriptBuilderComponentDependency -Name $_ -Direction Dependencies
    [PSCustomObject] @{ Name = $_; TransitiveDeps = $depEntries.Count }
} | Sort-Object TransitiveDeps -Descending | Select-Object -First 5 | Format-Table -AutoSize

Write-Host ''
Write-Host '=== Scenario 10: All classes that use inheritance ===' -ForegroundColor Cyan

$analysis.DependencyGraph.Dependencies.GetEnumerator() | ForEach-Object {
    $name  = $_.Key
    $edges = $_.Value | Where-Object { $_.EdgeType -eq [PSScriptBuilderDependencyEdgeType]::Inheritance }
    if ($edges) {
        $edges | ForEach-Object {
            [PSCustomObject] @{ Class = $name; BaseClass = $_.Target }
        }
    }
} | Sort-Object Class | Format-Table -AutoSize

# Render each inheritance root as a tree.
# A root is a class that has subclasses (Inheritance-Dependents) but does not itself
# inherit from any other class in the project (no outgoing Inheritance edge).
Write-Host 'Inheritance hierarchy trees:'

$allBaseClasses = $analysis.DependencyGraph.Dependencies.Values |
    ForEach-Object { $_ } |
    Where-Object { $_.EdgeType -eq [PSScriptBuilderDependencyEdgeType]::Inheritance } |
    Select-Object -ExpandProperty Target -Unique

$rootBaseClasses = $allBaseClasses | Where-Object {
    $outgoingInheritance = $analysis.DependencyGraph.Dependencies[$_] |
        Where-Object { $_.EdgeType -eq [PSScriptBuilderDependencyEdgeType]::Inheritance }
    -not $outgoingInheritance
}

foreach ($root in ($rootBaseClasses | Sort-Object)) {
    Write-Host ''
    $analysis | Get-PSScriptBuilderComponentDependency -Name $root -Direction Dependents -EdgeType Inheritance |
        ConvertTo-PSScriptBuilderComponentDependencyTree
}

Write-Host ''
Write-Host 'Done.'

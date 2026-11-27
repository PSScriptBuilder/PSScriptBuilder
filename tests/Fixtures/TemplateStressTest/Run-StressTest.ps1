using module '..\..\..\build\Output\PSScriptBuilder.psd1'

<#
.SYNOPSIS
    Manual runner for the TemplateStressTest fixture.
.DESCRIPTION
    Not a numbered example (see tests/Fixtures/TemplateStressTest/README.md for why) - this is a
    deliberately dense, multi-domain project exercising many same-type collectors (7 Enum, 19
    Class, 11 Function components across 6 domains) and, in particular, 4 separately registered
    Using collectors in Ordered Mode, which real projects turned out to combine in ways the
    narrower Unit/Integration suite never exercised. Run this directly to
    inspect behavior interactively; tests/Integration/Template/PSScriptBuilderTemplateStressTest.Integration.Tests.ps1
    is the automated, permanent regression coverage for the same fixture.
#>

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-PSScriptBuilderProjectRoot -Path $root

function Write-Section {
    param([string] $Title)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

$cc = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'CoreEnums'          -IncludePath (Join-Path $root 'src\Core\Enums') |
    Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'CoreClasses'        -IncludePath (Join-Path $root 'src\Core\Classes') |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey 'CoreFunctions'      -IncludePath (Join-Path $root 'src\Core\Functions') |
    Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'WorkflowEnums'      -IncludePath (Join-Path $root 'src\Workflow\Enums') |
    Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'WorkflowClasses'    -IncludePath (Join-Path $root 'src\Workflow\Classes') |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey 'WorkflowFunctions'  -IncludePath (Join-Path $root 'src\Workflow\Functions') |
    Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'NotificationEnums'     -IncludePath (Join-Path $root 'src\Notifications\Enums') |
    Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'NotificationClasses'   -IncludePath (Join-Path $root 'src\Notifications\Classes') |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey 'NotificationFunctions' -IncludePath (Join-Path $root 'src\Notifications\Functions') |
    Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'ReportingEnums'     -IncludePath (Join-Path $root 'src\Reporting\Enums') |
    Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'ReportingClasses'   -IncludePath (Join-Path $root 'src\Reporting\Classes') |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey 'ReportingFunctions' -IncludePath (Join-Path $root 'src\Reporting\Functions') |
    Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'CliClasses'         -IncludePath (Join-Path $root 'src\CLI\Classes') |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey 'CliFunctions'       -IncludePath (Join-Path $root 'src\CLI\Functions') |
    Add-PSScriptBuilderCollector -Type Enum     -CollectionKey 'IntegrationEnums'     -IncludePath (Join-Path $root 'src\Integrations\Enums') |
    Add-PSScriptBuilderCollector -Type Class    -CollectionKey 'IntegrationClasses'   -IncludePath (Join-Path $root 'src\Integrations\Classes') |
    Add-PSScriptBuilderCollector -Type Function -CollectionKey 'IntegrationFunctions' -IncludePath (Join-Path $root 'src\Integrations\Functions') |
    Add-PSScriptBuilderCollector -Type Using -CollectionKey 'CoreUsings'         -IncludePath (Join-Path $root 'src\Core') |
    Add-PSScriptBuilderCollector -Type Using -CollectionKey 'WorkflowUsings'     -IncludePath (Join-Path $root 'src\Workflow') |
    Add-PSScriptBuilderCollector -Type Using -CollectionKey 'NotificationUsings' -IncludePath (Join-Path $root 'src\Notifications') |
    Add-PSScriptBuilderCollector -Type Using -CollectionKey 'IntegrationUsings'  -IncludePath (Join-Path $root 'src\Integrations')

#region 1. Valid template: one consolidated Using placeholder
Write-Section "1. Valid template - single consolidated Using placeholder"

$outPath = Join-Path $root 'build\Output\StressTest.ps1'
try {
    Invoke-PSScriptBuilderBuild -ContentCollector $cc `
        -TemplatePath (Join-Path $root 'build\Templates\StressTest.ps1.template') `
        -OutputPath   $outPath `
        -WriteSourceMap `
        -Verbose 4>&1 |
        Where-Object { $_ -is [System.Management.Automation.VerboseRecord] -and $_.Message -match 'cross-dependenc|Mode:' } |
        ForEach-Object { Write-Host "  VERBOSE: $($_.Message)" }

    Write-Host "BUILD SUCCEEDED: $outPath" -ForegroundColor Green
}
catch {
    Write-Host "UNEXPECTED BUILD FAILURE: $($_.Exception.Message)" -ForegroundColor Red
}
#endregion

#region 2. Broken template: a second, independent Using placeholder is rejected
Write-Section "2. Broken template - second Using placeholder (should FAIL)"

try {
    Invoke-PSScriptBuilderBuild -ContentCollector $cc `
        -TemplatePath (Join-Path $root 'build\Templates\StressTest.Broken.ps1.template') `
        -OutputPath   (Join-Path $root 'build\Output\StressTest.Broken.ps1') | Out-Null

    Write-Host "UNEXPECTED: Build succeeded, the second Using placeholder was not rejected!" -ForegroundColor Red
}
catch {
    Write-Host "Build correctly failed:" -ForegroundColor Green
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
}
#endregion

#region 3. Dependency analysis + graph export
Write-Section "3. Dependency analysis"

$analysis = Get-PSScriptBuilderDependencyAnalysis -ContentCollector $cc
Write-Host "  HasCycles: $($analysis.HasCycles)  HasCrossDependencies: $($analysis.HasCrossDependencies)"
Write-Host "  Nodes: $($analysis.TotalNodes)  Edges: $($analysis.TotalEdges)"

$graphPath = Join-Path $root 'build\Output\StressTest.dependencies.mmd'
Export-PSScriptBuilderDependencyGraph -DependencyGraph $analysis.DependencyGraph -OutputPath $graphPath -Format Mermaid -Force
Write-Host "  Graph written: $graphPath" -ForegroundColor Green
#endregion

#region 4. Unused component detection
Write-Section "4. Unused component detection"

$unused = Find-PSScriptBuilderUnusedComponent -ContentCollector $cc
if ($unused) {
    $unused | ForEach-Object { Write-Host "  Unused: $($_.Name) ($($_.ComponentType))" -ForegroundColor Yellow }
}
else {
    Write-Host "  No unused components reported." -ForegroundColor Yellow
}
#endregion

#region 5. Compression
Write-Section "5. Compress-PSScriptBuilderScript"

if (Test-Path $outPath) {
    $compressedPath = Join-Path $root 'build\Output\StressTest.compressed.ps1'
    Compress-PSScriptBuilderScript -Path $outPath -RemoveComments -RemoveBlankLines -DestinationPath $compressedPath -Force -Verbose 4>&1 |
        Where-Object { $_ -is [System.Management.Automation.VerboseRecord] -and $_.Message -match 'Size' } |
        ForEach-Object { Write-Host "  $($_.Message)" }
}
#endregion

Write-Section "Done"

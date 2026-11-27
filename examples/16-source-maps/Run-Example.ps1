using module ..\..\build\Output\PSScriptBuilder.psd1

[CmdletBinding()]
param()

$Global:VerbosePreference = $VerbosePreference
$Global:WarningPreference = $WarningPreference

Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot

$templatePath  = Join-Path $PSScriptRoot 'build\Templates\HRTools.ps1.template'
$outputPath    = Join-Path $PSScriptRoot 'build\Output\HRTools.ps1'
$classesPath   = Join-Path $PSScriptRoot 'src\Classes'
$functionsPath = Join-Path $PSScriptRoot 'src\Functions'

# ============================================================
# Build with -WriteSourceMap
# ============================================================

$contentCollector = New-PSScriptBuilderContentCollector |
    Add-PSScriptBuilderCollector -Type Class    -IncludePath $classesPath   |
    Add-PSScriptBuilderCollector -Type Function -IncludePath $functionsPath

$result = Invoke-PSScriptBuilderBuild `
    -ContentCollector $contentCollector `
    -TemplatePath     $templatePath `
    -OutputPath       $outputPath `
    -WriteSourceMap

Format-PSScriptBuilderBuildResult -BuildResult $result

Write-Host "Source map : $outputPath.sourcemap.json"
Write-Host ''

# ============================================================
# Scenario 1: Inspect the full source map
# ============================================================

Write-Host '=== Scenario 1: Inspect the full source map ===' -ForegroundColor Cyan
Write-Host ''

$map = $result | Resolve-PSScriptBuilderSourceLocation
$map | Format-Table -AutoSize

# ============================================================
# Scenario 2: Resolve a specific output line number
# ============================================================

Write-Host '=== Scenario 2: Resolve a specific line number ===' -ForegroundColor Cyan
Write-Host ''

$funcEntry  = $map | Where-Object { $_.ComponentName -eq 'Get-EmployeeById' } | Select-Object -First 1
$targetLine = $funcEntry.OutputLineNumber + 10

Write-Host "Resolving output line $targetLine (inside Get-EmployeeById)..."
Write-Host ''
Resolve-PSScriptBuilderSourceLocation -OutputPath $outputPath -LineNumber $targetLine | Format-List

# ============================================================
# Scenario 3: Resolve an ErrorRecord
# ============================================================

Write-Host '=== Scenario 3: Resolve an ErrorRecord ===' -ForegroundColor Cyan
Write-Host ''

. $outputPath

$employees = @(
    (New-Employee -Id 1 -FirstName 'Anna'  -LastName 'Schmidt' -Department 'Engineering'),
    (New-Employee -Id 2 -FirstName 'James' -LastName 'Okafor'  -Department 'Finance')
)

Write-Host 'Calling Get-EmployeeById with Id=999 (not found) - this throws...'
Write-Host ''

try {
    Get-EmployeeById -Employees $employees -Id 999
}
catch {
    Write-Host "Error at output line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    Write-Host ''
    Write-Host 'Resolving to source location:'
    Write-Host ''
    $result | Resolve-PSScriptBuilderSourceLocation -ErrorRecord $_ | Format-List
}

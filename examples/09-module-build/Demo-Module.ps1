using module .\build\Output\AppConfig.psd1

[CmdletBinding()]
param()

# Create a configuration
$config = New-AppConfig -Name "AppSettings"

$config.Add((New-ConfigEntry -Key "Environment" -Value "Production"  -Description "Deployment environment"))
$config.Add((New-ConfigEntry -Key "LogLevel"    -Value "Warning"     -Description "Minimum log level"))
$config.Add((New-ConfigEntry -Key "MaxRetries"  -Value "3"           -Description "Maximum retry attempts"))
$config.Add((New-ConfigEntry -Key "Timeout"     -Value "30"))

# Display all entries
Write-Host "Config   : $($config.Name)"
Write-Host "Entries  : $($config.Count())"
Write-Host ""

foreach ($entry in $config.Entries) {
    $desc = if ($entry.Description) { "  # $($entry.Description)" } else { '' }
    Write-Host ("  {0,-15} = {1}{2}" -f $entry.Key, $entry.Value, $desc)
}

Write-Host ""

# Retrieve values
$env     = Get-ConfigValue -Config $config -Key "Environment"
$missing = Get-ConfigValue -Config $config -Key "ApiKey" -Default "(not set)"

Write-Host "Environment : $env"
Write-Host "ApiKey      : $missing"

# Type check — only possible because of 'using module'
$entry = $config.Get("LogLevel")
Write-Host ""
Write-Host "Type of entry     : $($entry.GetType().Name)"
Write-Host "Type of config    : $($config.GetType().Name)"

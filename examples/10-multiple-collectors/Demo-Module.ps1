using module .\build\Output\AppLogFramework.psd1

[CmdletBinding()]
param()

# Create a console logger
$logger = New-ConsoleLogger

# Log entries across the severity range
Write-Log -Logger $logger -Level ([LogLevel]::Info)     -Message "Application started"     -Source "App"
Write-Log -Logger $logger -Level ([LogLevel]::Debug)    -Message "Loading configuration"   -Source "Config"
Write-Log -Logger $logger -Level ([LogLevel]::Warning)  -Message "Retry limit approaching" -Source "Network"
Write-Log -Logger $logger -Level ([LogLevel]::Error)    -Message "Connection timed out"    -Source "Network"

Write-Host ""

# Type checks - only possible because of 'using module'
$entry = New-LogEntry -Level ([LogLevel]::Info) -Message "Type check" -Source "Demo"
Write-Host "Type of entry  : $($entry.GetType().Name)"
Write-Host "Type of logger : $($logger.GetType().Name)"

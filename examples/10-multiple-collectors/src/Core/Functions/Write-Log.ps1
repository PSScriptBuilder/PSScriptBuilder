Function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [LoggerBase] $Logger,

        [Parameter(Mandatory)]
        [LogLevel] $Level,

        [Parameter(Mandatory)]
        [string] $Message,

        [string] $Source = ''
    )

    # Use [LogEntry]::new() directly to avoid a function cross-dependency on New-LogEntry
    $entry = [LogEntry]::new($Level, $Message, $Source)
    $Logger.Write($entry)
}

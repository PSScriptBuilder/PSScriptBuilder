Function New-LogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [LogLevel] $Level,

        [Parameter(Mandatory)]
        [string] $Message,

        [string] $Source = ''
    )

    return [LogEntry]::new($Level, $Message, $Source)
}

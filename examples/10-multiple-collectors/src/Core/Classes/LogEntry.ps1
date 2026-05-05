class LogEntry {
    [datetime] $Timestamp
    [LogLevel] $Level
    [string]   $Message
    [string]   $Source

    LogEntry([LogLevel] $level, [string] $message, [string] $source) {
        $this.Timestamp = [datetime]::Now
        $this.Level     = $level
        $this.Message   = $message
        $this.Source    = $source
    }
}

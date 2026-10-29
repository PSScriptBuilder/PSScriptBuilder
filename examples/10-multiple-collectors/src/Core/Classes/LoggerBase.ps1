class LoggerBase {
    hidden [LogFormatter] $Formatter

    [void] Write([LogEntry] $entry) {
        throw [System.NotImplementedException]::new("Write() must be implemented by subclass")
    }
}

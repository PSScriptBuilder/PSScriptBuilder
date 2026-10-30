class LogFormatter {
    [string] Format([LogEntry] $entry) {
        return "[{0:HH:mm:ss}] [{1,-8}] [{2}] {3}" -f $entry.Timestamp, $entry.Level, $entry.Source, $entry.Message
    }
}

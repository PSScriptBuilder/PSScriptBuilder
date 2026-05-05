class FileLogger : LoggerBase {
    [string] $FilePath

    FileLogger([string] $filePath) {
        $this.Formatter = [LogFormatter]::new()
        $this.FilePath  = $filePath
    }

    [void] Write([LogEntry] $entry) {
        $line = $this.Formatter.Format($entry)
        Add-Content -Path $this.FilePath -Value $line
    }
}

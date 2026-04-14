class ConsoleLogger : LoggerBase {
    ConsoleLogger() {
        $this.Formatter = [LogFormatter]::new()
    }

    [void] Write([LogEntry] $entry) {
        $line  = $this.Formatter.Format($entry)
        $color = switch ($entry.Level.ToString()) {
            'Trace'    { 'Gray'    }
            'Debug'    { 'Cyan'    }
            'Info'     { 'White'   }
            'Warning'  { 'Yellow'  }
            'Error'    { 'Red'     }
            'Critical' { 'Magenta' }
            default    { 'White'   }
        }
        Write-Host $line -ForegroundColor $color
    }
}

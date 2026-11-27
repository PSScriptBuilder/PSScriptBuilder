class AppConfig {
    [string]        $Name
    [ConfigEntry[]] $Entries

    AppConfig([string] $name) {
        $this.Name    = $name
        $this.Entries = @()
    }

    [void] Add([ConfigEntry] $entry) {
        $this.Entries += $entry
    }

    [ConfigEntry] Get([string] $key) {
        return ($this.Entries | Where-Object { $_.Key -eq $key } | Select-Object -First 1)
    }

    [bool] Contains([string] $key) {
        return ($this.Entries | Where-Object { $_.Key -eq $key }).Count -gt 0
    }

    [int] Count() {
        return $this.Entries.Count
    }
}

class ConfigEntry {
    [string] $Key
    [string] $Value
    [string] $Description

    ConfigEntry([string] $key, [string] $value, [string] $description) {
        $this.Key         = $key
        $this.Value       = $value
        $this.Description = $description
    }

    ConfigEntry([string] $key, [string] $value) {
        $this.Key         = $key
        $this.Value       = $value
        $this.Description = ''
    }

    [string] ToString() {
        return "{0} = {1}" -f $this.Key, $this.Value
    }
}

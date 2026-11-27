class ArgumentValidator {
    [bool] Validate([string[]] $args) {
        return $null -ne $args -and $args.Count -gt 0
    }
}

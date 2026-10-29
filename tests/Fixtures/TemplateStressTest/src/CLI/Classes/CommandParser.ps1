class CommandParser {
    hidden [ArgumentValidator] $Validator

    CommandParser() {
        $this.Validator = [ArgumentValidator]::new()
    }

    [Ticket] Parse([string[]] $args) {
        if (-not $this.Validator.Validate($args)) {
            throw [System.ArgumentException]::new("No arguments supplied")
        }

        return [Ticket]::new(0, ($args -join ' '), [TicketPriority]::Medium, [TicketCategory]::Bug)
    }

    [PSCustomObject] Summarize([TicketList] $list) {
        return Get-TicketSummary -List $list
    }
}

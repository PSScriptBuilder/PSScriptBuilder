class GitHubSync {
    [Ticket] Import([string] $issueUrl) {
        return [Ticket]::new(0, "Imported from $issueUrl", [TicketPriority]::Medium, [TicketCategory]::Bug)
    }
}

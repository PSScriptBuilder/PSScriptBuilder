using namespace System.Text.RegularExpressions

class JiraSync {
    [Ticket] Import([string] $jiraId) {
        if (-not [Regex]::IsMatch($jiraId, '^[A-Z]+-\d+$')) {
            throw [System.ArgumentException]::new("Invalid Jira issue id: $jiraId")
        }

        return [Ticket]::new(0, "Imported from $jiraId", [TicketPriority]::Medium, [TicketCategory]::Bug)
    }
}

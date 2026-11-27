function New-Ticket {
    [CmdletBinding()]
    [OutputType([Ticket])]
    param(
        [Parameter(Mandatory)]
        [int] $Id,

        [Parameter(Mandatory)]
        [string] $Title,

        [TicketPriority] $Priority = [TicketPriority]::Medium,

        [TicketCategory] $Category = [TicketCategory]::Bug
    )

    return [Ticket]::new($Id, $Title, $Priority, $Category)
}

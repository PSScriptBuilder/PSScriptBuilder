function Add-TicketComment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Ticket] $Ticket,

        [Parameter(Mandatory)]
        [Comment] $Comment
    )

    $Ticket.AddComment($Comment)
}

function Invoke-TicketCommand {
    [CmdletBinding()]
    [OutputType([Ticket])]
    param(
        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    $parser = [CommandParser]::new()
    return $parser.Parse($Arguments)
}

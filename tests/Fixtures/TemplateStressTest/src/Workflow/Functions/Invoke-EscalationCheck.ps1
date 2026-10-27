function Invoke-EscalationCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [WorkflowEngine] $Engine
    )

    if ($Engine.Ticket.Priority -eq [TicketPriority]::Critical -and $Engine.State -eq [WorkflowState]::Pending) {
        $Engine.TransitionTo([WorkflowState]::Active)
    }
}

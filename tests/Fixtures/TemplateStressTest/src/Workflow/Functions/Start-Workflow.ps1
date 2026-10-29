function Start-Workflow {
    [CmdletBinding()]
    [OutputType([WorkflowEngine])]
    param(
        [Parameter(Mandatory)]
        [Ticket] $Ticket
    )

    $engine = [WorkflowEngine]::new($Ticket)
    $engine.TransitionTo([WorkflowState]::Active)
    return $engine
}

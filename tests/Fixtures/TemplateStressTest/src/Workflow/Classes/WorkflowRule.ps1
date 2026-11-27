using namespace System.Linq

class WorkflowRule {
    [string] $Name
    [scriptblock] $Condition

    WorkflowRule([string] $name, [scriptblock] $condition) {
        $this.Name      = $name
        $this.Condition = $condition
    }

    [bool] Evaluate([Ticket] $ticket) {
        return [bool] (& $this.Condition $ticket)
    }
}

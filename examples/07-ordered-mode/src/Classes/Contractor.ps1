class Contractor : Person {
    [string]   $Company
    [DateTime] $ContractStart
    [DateTime] $ContractEnd

    Contractor([string] $firstName, [string] $lastName, [string] $company, [DateTime] $contractStart, [DateTime] $contractEnd) : base($firstName, $lastName) {
        $this.Company        = $company
        $this.ContractStart  = $contractStart
        $this.ContractEnd    = $contractEnd
    }
}

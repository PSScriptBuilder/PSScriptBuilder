class Employee : Person {
    [string]   $Department
    [DateTime] $StartDate

    Employee([string] $firstName, [string] $lastName, [string] $department, [DateTime] $startDate) : base($firstName, $lastName) {
        $this.Department = $department
        $this.StartDate  = $startDate
    }
}

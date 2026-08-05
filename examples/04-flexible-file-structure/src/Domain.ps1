enum EmploymentStatus {
    Active
    OnLeave
    Terminated
    Retired
}

enum Department {
    Engineering
    HumanResources
    Finance
    Marketing
    Management
}

class Person {
    [string] $FirstName
    [string] $LastName

    Person([string] $firstName, [string] $lastName) {
        $this.FirstName = $firstName
        $this.LastName  = $lastName
    }
}

class Employee : Person {
    [int]    $Id
    [string] $Department

    Employee(
        [int]    $id,
        [string] $firstName,
        [string] $lastName,
        [string] $department
    ) : base($firstName, $lastName) {
        $this.Id         = $id
        $this.Department = $department
    }
}

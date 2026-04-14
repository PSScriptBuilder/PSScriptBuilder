class Person {
    [string] $FirstName
    [string] $LastName

    Person([string] $firstName, [string] $lastName) {
        $this.FirstName = $firstName
        $this.LastName  = $lastName
    }
}

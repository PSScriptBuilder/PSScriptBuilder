class Address {
    [string] $Street
    [string] $City
    [string] $PostalCode
    [string] $Country

    Address([string] $street, [string] $city, [string] $postalCode, [string] $country) {
        $this.Street     = $street
        $this.City       = $city
        $this.PostalCode = $postalCode
        $this.Country    = $country
    }
}

class Employee : Person {
    [Address]          $Address
    [Department]       $Department
    [EmploymentStatus] $Status
    [DateTime]         $HireDate
    [decimal]          $Salary

    Employee(
        [string]           $firstName,
        [string]           $lastName,
        [Address]          $address,
        [Department]       $department,
        [DateTime]         $hireDate,
        [decimal]          $salary
    ) : base($firstName, $lastName) {
        $this.Address    = $address
        $this.Department = $department
        $this.Status     = [EmploymentStatus]::Active
        $this.HireDate   = $hireDate
        $this.Salary     = $salary
    }
}

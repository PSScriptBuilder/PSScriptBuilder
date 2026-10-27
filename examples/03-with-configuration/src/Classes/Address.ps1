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

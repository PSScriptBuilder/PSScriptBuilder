class User {
    [string] $Name
    [string] $Email

    User([string] $name, [string] $email) {
        $this.Name  = $name
        $this.Email = $email
    }
}

<#
This test suite is deliberately incomplete - it exists to produce a realistic, mixed
coverage report for Example 17, not to fully test HRTools.ps1. Two gaps are intentional:

1. Get-EmployeeById's "not found" branch (the throw) is never exercised.
2. Get-EmployeesByDepartment is never called at all.

Both gaps show up in the coverage report Run-Example.ps1 prints after this test run.
#>

BeforeAll {
    # CodeCoverage.Path (set in Run-Example.ps1) must point at this same built output -
    # Pester only has execution history for the file it actually dot-sourced.
    . "$PSScriptRoot\..\build\Output\HRTools.ps1"
}

Describe 'New-Employee' {

    It 'Creates an Employee with the given properties' {
        $employee = New-Employee -Id 1 -FirstName 'Anna' -LastName 'Schmidt' -Department 'Engineering'

        $employee.Id         | Should -Be 1
        $employee.FirstName  | Should -Be 'Anna'
        $employee.LastName   | Should -Be 'Schmidt'
        $employee.Department | Should -Be 'Engineering'
    }
}

Describe 'Get-EmployeeById' {

    BeforeAll {
        $script:Employees = @(
            (New-Employee -Id 1 -FirstName 'Anna'  -LastName 'Schmidt' -Department 'Engineering'),
            (New-Employee -Id 2 -FirstName 'James' -LastName 'Okafor'  -Department 'Finance')
        )
    }

    It 'Returns the employee with the matching Id' {
        $found = Get-EmployeeById -Employees $script:Employees -Id 2

        $found.FirstName | Should -Be 'James'
    }
}

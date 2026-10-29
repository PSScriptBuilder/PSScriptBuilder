<#
.SYNOPSIS
    Pester Custom Matcher to check for specific methods on an object or class.
.DESCRIPTION
    The custom matcher Should-HaveMethod checks whether an object or class has a specific method.
    It can check both instance and static methods and also considers hidden methods.
    It can be used both positively and negatively (with -Not).
.PARAMETER ActualValue
    Object, class, or type as Object.
.PARAMETER ExpectedValue
    Name of the method as String.
.PARAMETER Static
    Switch indicating whether to search for a static method.
.PARAMETER Negate
    Switch indicating whether the test should be negated.
.EXAMPLE
    $myObject | Should -HaveMethod "DoSomething"   
    Tests whether $myObject has an instance method named "DoSomething".
.EXAMPLE
    [MyClass] | Should -HaveMethod "CreateInstance" -Static
    Tests whether MyClass has a static method named "CreateInstance".
.EXAMPLE
    $myObject | Should -Not -HaveMethod "PrivateMethod"
    Tests whether $myObject does NOT have a method named "PrivateMethod".
.EXAMPLE
    $myObject | Should -HaveMethod "HiddenMethod"
    Also tests hidden methods (automatically included).
.NOTES
    The matcher considers both public and hidden methods.
    With -Static, searches for static methods; otherwise searches for instance methods.
.DATECREATED
    2025-11-16
.AUTHOR
    Tim Hartling
.DATEMODIFIED
    2026-03-11 13:43
.EDITOR
    Tim Hartling
.VERSION
    1.1.0
#>
function Should-HaveMethod ([object] $ActualValue, [string] $ExpectedValue, [switch] $Static, [switch] $Negate) {
    $methodExists = $false
    $typeName = ""
    $searchType = if ($Static) { "static" } else { "instance" }

    if ($null -eq $ActualValue) {
        $methodExists = $false
        $typeName = "null"
    }
    else {
        # Determine type - support different input types
        $targetType = $null
        $targetObject = $null

        if ($ActualValue -is [type]) {
            # Directly a Type object
            $targetType = $ActualValue
            $typeName = $targetType.Name
        }
        elseif ($ActualValue -is [System.Reflection.TypeInfo]) {
            # TypeInfo object
            $targetType = $ActualValue.AsType()
            $typeName = $targetType.Name
        }
        elseif ($ActualValue.GetType().Name -eq "RuntimeType") {
            # RuntimeType (e.g., from [MyClass])
            $targetType = $ActualValue
            $typeName = $targetType.Name
        }
        else {
            # Instance of an object
            $targetObject = $ActualValue
            $targetType = $ActualValue.GetType()
            $typeName = $targetType.Name
        }

        if ($null -ne $targetType) {
            try {
                # Determine methods via .NET Reflection
                $bindingFlags = $null

                if ($Static) {
                    # BindingFlags for static methods, including hidden
                    $bindingFlags = 
                        [System.Reflection.BindingFlags]::Static    -bor 
                        [System.Reflection.BindingFlags]::Public    -bor 
                        [System.Reflection.BindingFlags]::NonPublic
                }
                else {
                    # BindingFlags for instance methods, including hidden
                    $bindingFlags = 
                        [System.Reflection.BindingFlags]::Instance  -bor 
                        [System.Reflection.BindingFlags]::Public    -bor 
                        [System.Reflection.BindingFlags]::NonPublic
                }

                # Retrieve methods based on BindingFlags
                $methods = $targetType.GetMethods($bindingFlags)

                # Get the searched method from methods
                $matchingMethod = $methods | Where-Object { $_.Name -eq $ExpectedValue }

                # Searched method exists if $matchingMethod is not null
                $methodExists = $null -ne $matchingMethod
            }
            catch {
                # Fallback
                # Query methods via PowerShell Get-Member
                try {
                    if ($Static) {
                        # For static methods, use the type

                        # Retrieve methods via Get-Member
                        $method = $targetType | Get-Member -Static -Name $ExpectedValue -MemberType Method -ErrorAction SilentlyContinue
                    }
                    else {
                        if ($null -ne $targetObject) {
                            # For instance methods, use the object

                            # Retrieve methods via Get-Member
                            $method = $targetObject | Get-Member -Name $ExpectedValue -MemberType Method -ErrorAction SilentlyContinue
                        }
                        else {
                            # Fallback for Type objects with instance methods

                            # BindingFlags for instance methods, including public
                            $bindingFlags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::Public

                            # Retrieve methods based on BindingFlags
                            $methods = $targetType.GetMethods($bindingFlags)

                            # Get the searched method from methods
                            $method = $methods | Where-Object { $_.Name -eq $ExpectedValue }
                        }
                    }

                    # Searched method exists if $method is not null
                    $methodExists = $null -ne $method
                }
                catch {
                    $methodExists = $false
                }
            }
        }
    }

    if ($Negate) { $methodExists = -not $methodExists }

    $succeeded = $methodExists

    $failureMessage = 
        if ($Negate) {
            $format = "Expected {0} '{1}' to not have {2} method '{3}', but it does."
            $objectType = if ($Static -or ($null -eq $targetObject)) { "type" } else { "object" }
            $result = $format -f $objectType, $typeName, $searchType, $ExpectedValue
            $result
        } 
        else {
            if ($null -eq $ActualValue) {
                $format = "Expected object to have {0} method '{1}', but the input is null."
                $result = $format -f $searchType, $ExpectedValue
                $result
            } 
            else {
                # Determine available methods
                $availableMethods = @()

                if ($null -ne $targetType) {
                    # Retrieve methods via .NET Reflection
                    try {
                        $bindingFlags = $null

                        if ($Static) {
                            $bindingFlags = 
                                [System.Reflection.BindingFlags]::Static    -bor 
                                [System.Reflection.BindingFlags]::Public    -bor 
                                [System.Reflection.BindingFlags]::NonPublic
                        }
                        else {
                            $bindingFlags = 
                                [System.Reflection.BindingFlags]::Instance  -bor 
                                [System.Reflection.BindingFlags]::Public    -bor 
                                [System.Reflection.BindingFlags]::NonPublic
                        }

                        $methods = $targetType.GetMethods($bindingFlags)
                        $availableMethods = $methods | Where-Object { -not $_.IsSpecialName } | Select-Object -ExpandProperty Name | Sort-Object -Unique
                    }
                    catch {
                        # Fallback
                        # Retrieve methods via Get-Member
                        try {
                            if ($Static) {
                                $methods = $targetType | Get-Member -Static -MemberType Method -ErrorAction SilentlyContinue
                            }
                            else {
                                if ($null -ne $targetObject) {
                                    $methods = $targetObject | Get-Member -MemberType Method -ErrorAction SilentlyContinue
                                }
                                else {
                                    $methods = $targetType | Get-Member -MemberType Method -ErrorAction SilentlyContinue
                                }
                            }

                            $availableMethods = $methods | Select-Object -ExpandProperty Name | Sort-Object -Unique
                        }
                        catch {
                            $availableMethods = @("Unable to retrieve methods")
                        }
                    }
                }

                $availableList = if ($availableMethods.Count -gt 0) { $availableMethods -join ", " } else { "none" }
                $objectType = if ($Static -or ($null -eq $targetObject)) { "type" } else { "object" }

                $format = "Expected {0} '{1}' to have {2} method '{3}', but it does not. Available {2} methods: [{4}]"
                $result = $format -f $objectType, $typeName, $searchType, $ExpectedValue, $availableList
                $result
            }
        }

    return [PSCustomObject] @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

# Register custom matcher
Add-ShouldOperator -Name HaveMethod -InternalName Should-HaveMethod -Test ${function:Should-HaveMethod}

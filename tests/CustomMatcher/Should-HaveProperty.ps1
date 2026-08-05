<#
.SYNOPSIS
    Pester Custom Matcher to check for specific properties on an object or class.
.DESCRIPTION
    The custom matcher Should-HaveProperty checks whether an object or class has a specific property.
    It can check both instance and static properties and considers hidden properties.
    It can be used both positively and negatively (with -Not).
.PARAMETER ActualValue
    Object, class, or type as Object.
.PARAMETER ExpectedValue
    Name of the property as String.
.PARAMETER Static
    Switch indicating whether to search for a static property.
.PARAMETER Negate
    Switch indicating whether the test should be negated.
.EXAMPLE
    $myObject | Should -HaveProperty "PropertyName"   
    Tests whether $myObject has an instance property named "PropertyName".
.EXAMPLE
    [MyClass] | Should -HaveProperty "StaticProperty" -Static
    Tests whether MyClass has a static property named "StaticProperty".
.EXAMPLE
    $myObject | Should -Not -HaveProperty "NonExistentProperty"
    Tests whether $myObject does NOT have a property named "NonExistentProperty".
.EXAMPLE
    $myObject | Should -HaveProperty "HiddenProperty"
    Also tests hidden properties (automatically included).
.NOTES
    The matcher only considers properties, not methods.
    With -Static, searches for static properties; otherwise searches for instance properties.
    Hidden properties (NonPublic) are automatically included in the search.
.DATECREATED
    2025-11-14
.AUTHOR
    Tim Hartling
.DATEMODIFIED
    2026-03-11 13:44
.EDITOR
    Tim Hartling
.VERSION
    1.2.0
#>
function Should-HaveProperty ([object] $ActualValue, [string] $ExpectedValue, [switch] $Static, [switch] $Negate) {
    $propertyExists = $false
    $typeName = ""
    $searchType = if ($Static) { "static" } else { "instance" }

    if ($null -eq $ActualValue) {
        $propertyExists = $false
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
            # Try to determine the property via .NET Reflection
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

                $properties = $targetType.GetProperties($bindingFlags)
                $matchingProperty = $properties | Where-Object { $_.Name -eq $ExpectedValue }
                $propertyExists = $null -ne $matchingProperty
            }
            # Fallback
            # Try to determine the property via PowerShell Get-Member
            catch {
                try {
                    if ($Static) {
                        $property = $targetType | Get-Member -Static -Name $ExpectedValue -MemberType Properties -ErrorAction SilentlyContinue
                    }
                    else {
                        if ($null -ne $targetObject) {
                            $property = $targetObject | Get-Member -Name $ExpectedValue -MemberType Properties -ErrorAction SilentlyContinue
                        }
                        else {
                            $property = $targetType | Get-Member -Name $ExpectedValue -MemberType Properties -ErrorAction SilentlyContinue
                        }
                    }

                    $propertyExists = $null -ne $property
                }
                catch {
                    $propertyExists = $false
                }
            }
        }
    }

    if ($Negate) { $propertyExists = -not $propertyExists }

    $succeeded = $propertyExists

    $failureMessage = 
        if ($Negate) {
            $objectType = if ($Static -or ($null -eq $targetObject)) { "type" } else { "object" }

            $format = "Expected {0} '{1}' to not have {2} property '{3}', but it does."
            $result = $format -f $objectType, $typeName, $searchType, $ExpectedValue
            $result
        } 
        else {
            if ($null -eq $ActualValue) {
                $format = "Expected object to have {0} property '{1}', but the input is null."
                $result = $format -f $searchType, $ExpectedValue
                $result
            } 
            else {
                # List available properties
                $availableProperties = @()

                if ($null -ne $targetType) {
                    # Try to determine available properties via .NET Reflection (including hidden)
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

                        $properties = $targetType.GetProperties($bindingFlags)
                        $availableProperties = $properties | Select-Object -ExpandProperty Name | Sort-Object -Unique
                    }
                    # Fallback
                    # Try to determine available properties via PowerShell Get-Member
                    catch {
                        try {
                            if ($Static) {
                                $properties = $targetType | Get-Member -Static -MemberType Properties -ErrorAction SilentlyContinue
                            }
                            else {
                                if ($null -ne $targetObject) {
                                    $properties = $targetObject | Get-Member -MemberType Properties -ErrorAction SilentlyContinue
                                }
                                else {
                                    $properties = $targetType | Get-Member -MemberType Properties -ErrorAction SilentlyContinue
                                }
                            }

                            $availableProperties = $properties | Select-Object -ExpandProperty Name | Sort-Object -Unique
                        }
                        catch {
                            $availableProperties = @("Unable to retrieve properties")
                        }
                    }
                }

                $availableList = if ($availableProperties.Count -gt 0) { $availableProperties -join ", " } else { "none" }
                $objectType = if ($Static -or ($null -eq $targetObject)) { "type" } else { "object" }

                $format = "Expected {0} '{1}' to have {2} property '{3}', but it does not. Available {2} properties: [{4}]"
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
Add-ShouldOperator -Name HaveProperty -InternalName Should-HaveProperty -Test ${function:Should-HaveProperty}

<#
.SYNOPSIS
    Pester Custom Matcher to check for a specific property with a specific value on an object or class.
.DESCRIPTION
    The custom matcher Should-HavePropertyWithValue checks whether an object or class has a 
    specific property with a specific value.
    It can check both instance and static properties and considers hidden properties.
    It can be used both positively and negatively (with -Not).
.PARAMETER ActualValue
    Object, class, or type as Object.
.PARAMETER ExpectedValue
    Hashtable with PropertyName and ExpectedValue.
.PARAMETER Static
    Switch indicating whether to search for static properties.
.PARAMETER Negate
    Switch indicating whether the test should be negated.
.EXAMPLE
    $myObject | Should -HavePropertyWithValue @{ PropertyName = "Name"; ExpectedValue = "Test" }
    Tests whether $myObject has an instance property "Name" with the value "Test".
.EXAMPLE
    [MyClass] | Should -HavePropertyWithValue @{ PropertyName = "Version"; ExpectedValue = "1.0" } -Static
    Tests whether MyClass has a static property "Version" with the value "1.0".
.EXAMPLE
    $myObject | Should -HavePropertyWithValue @{ PropertyName = "HiddenFlag"; ExpectedValue = $true }
    Also tests hidden properties (automatically included).
.NOTES
    The matcher considers both public and hidden properties.
    With -Static, searches for static properties; otherwise searches for instance properties.
.DATECREATED
    2025-11-14
.AUTHOR
    Tim Hartling
.DATEMODIFIED
    2026-03-11 13:47
.EDITOR
    Tim Hartling
.VERSION
    1.2.0
#>
function Should-HavePropertyWithValue( [object] $ActualValue, [hashtable] $ExpectedValue, [switch] $Static, [switch] $Negate) {
    $propertyName          = $ExpectedValue.PropertyName
    $expectedPropertyValue = $ExpectedValue.ExpectedValue
    $testPassed            = $false
    $actualPropertyValue   = $null
    $typeName              = ""
    $searchType            = if ($Static) { "static" } else { "instance" }

    if ($null -eq $ActualValue) {
        $testPassed = $false
        $actualPropertyValue = $null
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
                # Use .NET Reflection
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
                $matchingProperty = $properties | Where-Object { $_.Name -eq $propertyName }

                if ($null -eq $matchingProperty) {
                    $testPassed = $false
                    $actualPropertyValue = $null
                }
                else {
                    # Retrieve the value of the property
                    if ($Static) {
                        $actualPropertyValue = $matchingProperty.GetValue($null, $null)
                    }
                    else {
                        if ($null -ne $targetObject) {
                            $actualPropertyValue = $matchingProperty.GetValue($targetObject, $null)
                        }
                        else {
                            # For Type objects with instance properties, we cannot retrieve a value
                            $testPassed = $false
                            $actualPropertyValue = "<Cannot get instance property value from type object>"
                        }
                    }

                    if ($actualPropertyValue -ne "<Cannot get instance property value from type object>") {
                        $testPassed = $actualPropertyValue -eq $expectedPropertyValue
                    }
                }
            }
            catch {
                # Fallback: Use PowerShell Get-Member
                try {
                    if ($Static) {
                        $property = $targetType | Get-Member -Static -Name $propertyName -MemberType Properties -ErrorAction SilentlyContinue

                        if ($null -ne $property) {
                            $actualPropertyValue = $targetType::$propertyName
                            $testPassed = $actualPropertyValue -eq $expectedPropertyValue
                        }
                        else {
                            $testPassed = $false
                            $actualPropertyValue = $null
                        }
                    }
                    else {
                        if ($null -ne $targetObject) {
                            $property = $targetObject | Get-Member -Name $propertyName -MemberType Properties -ErrorAction SilentlyContinue

                            if ($null -ne $property) {
                                $actualPropertyValue = $targetObject.$propertyName
                                $testPassed = $actualPropertyValue -eq $expectedPropertyValue
                            }
                            else {
                                $testPassed = $false
                                $actualPropertyValue = $null
                            }
                        }
                        else {
                            # For Type objects with instance properties
                            $testPassed = $false
                            $actualPropertyValue = "<Cannot get instance property value from type object>"
                        }
                    }
                }
                catch {
                    $testPassed = $false
                    $actualPropertyValue = $null
                }
            }
        }
    }

    if ($Negate) { $testPassed = -not $testPassed }

    $succeeded = $testPassed

    $failureMessage = 
        if ($Negate) {
            $objectType = if ($Static -or ($null -eq $targetObject)) { "type" } else { "object" }

            $format = "Expected {0} '{1}' to not have {2} property '{3}' with value '{4}', but it does."
            $result = $format -f $objectType, $typeName, $searchType, $propertyName, $expectedPropertyValue
            $result
        } 
        else {
            if ($null -eq $ActualValue) {
                $format = "Expected object to have {0} property '{1}' with value '{2}', but the input is null."
                $result = $format -f $searchType, $propertyName, $expectedPropertyValue
                $result
            }
            else {
                # Check if property exists
                $propertyExists = $false

                if ($null -ne $targetType) {
                    try {
                        # Use .NET Reflection
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
                        $matchingProperty = $properties | Where-Object { $_.Name -eq $propertyName }
                        $propertyExists = $null -ne $matchingProperty
                    }
                    catch {
                        # Fallback: Use PowerShell Get-Member
                        if ($Static) {
                            $property = $targetType | Get-Member -Static -Name $propertyName -MemberType Properties -ErrorAction SilentlyContinue
                        }
                        else {
                            if ($null -ne $targetObject) {
                                $property = $targetObject | Get-Member -Name $propertyName -MemberType Properties -ErrorAction SilentlyContinue
                            }
                            else {
                                $property = $targetType | Get-Member -Name $propertyName -MemberType Properties -ErrorAction SilentlyContinue
                            }
                        }

                        $propertyExists = $null -ne $property
                    }
                }

                $objectType = if ($Static -or ($null -eq $targetObject)) { "type" } else { "object" }

                if (-not $propertyExists) {
                    $format = "Expected {0} '{1}' to have {2} property '{3}' with value '{4}', but the property does not exist."
                    $result = $format -f $objectType, $typeName, $searchType, $propertyName, $expectedPropertyValue
                }
                elseif ($actualPropertyValue -eq "<Cannot get instance property value from type object>") {
                    $format = "Expected type '{0}' to have instance property '{1}' with value '{2}', but cannot get instance property values from type objects."
                    $result = $format -f $typeName, $propertyName, $expectedPropertyValue
                }
                else {
                    $format = "Expected {0} '{1}' to have {2} property '{3}' with value '{4}', but actual value is '{5}'."
                    $result = $format -f $objectType, $typeName, $searchType, $propertyName, $expectedPropertyValue, $actualPropertyValue
                }
                $result
            }
    }

    return [PSCustomObject] @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

# Register custom matcher
Add-ShouldOperator -Name HavePropertyWithValue -InternalName Should-HavePropertyWithValue -Test ${function:Should-HavePropertyWithValue}

<#
.SYNOPSIS
    Pester Custom Matcher to check for a specific property with a specific type on an object or class.
.DESCRIPTION
    The custom matcher Should-HavePropertyOfType checks whether an object or class has a specific 
    property of a specific type.
    It can check both instance and static properties and considers hidden properties.
    It can be used both positively and negatively (with -Not).
.PARAMETER ActualValue
    Object, class, or type as Object.
.PARAMETER ExpectedValue
    Hashtable with PropertyName and ExpectedType.
.PARAMETER Static
    Switch indicating whether to search for static properties.
.PARAMETER Negate
    Switch indicating whether the test should be negated.
.EXAMPLE
    $myObject | Should -HavePropertyOfType @{ PropertyName = "Count"; ExpectedType = [int] }
    Tests whether $myObject has an instance property "Count" of type [int].
.EXAMPLE
    [MyClass] | Should -HavePropertyOfType @{ PropertyName = "DefaultValue"; ExpectedType = [string] } -Static
    Tests whether MyClass has a static property "DefaultValue" of type [string].
.EXAMPLE
    $myObject | Should -HavePropertyOfType @{ PropertyName = "HiddenProperty"; ExpectedType = [bool] }
    Also tests hidden properties (automatically included).
.NOTES
    The matcher considers both public and hidden properties.
    With -Static, searches for static properties; otherwise searches for instance properties.
.DATECREATED
    2025-11-14
.AUTHOR
    Tim Hartling
.DATEMODIFIED
    2026-03-11 13:46
.EDITOR
    Tim Hartling
.VERSION
    1.2.0
#>
function Should-HavePropertyOfType( [object] $ActualValue, [hashtable] $ExpectedValue, [switch] $Static, [switch] $Negate) {
    $propertyName = $ExpectedValue.PropertyName
    $expectedType = $ExpectedValue.ExpectedType
    $testPassed   = $false
    $actualType   = $null
    $typeName     = ""
    $searchType   = if ($Static) { "static" } else { "instance" }

    if ($null -eq $ActualValue) {
        $testPassed = $false
        $actualType = $null
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
            # Query properties via .NET Reflection (including hidden)
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
                $matchingProperty = $properties | Where-Object { $_.Name -eq $propertyName }

                if ($null -eq $matchingProperty) {
                    $testPassed = $false
                    $actualType = $null
                }
                else {
                    # Determine the type of the property
                    $actualType = $matchingProperty.PropertyType

                    # Type comparison
                    $testPassed = $actualType -eq $expectedType -or $actualType.IsSubclassOf($expectedType)
                }
            }
            # Fallback: PowerShell Get-Member (doesn't work for hidden/static, but better than nothing)
            catch {
                try {
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

                    if ($null -eq $property) {
                        $testPassed = $false
                        $actualType = $null
                    }
                    else {
                        # With Get-Member, we need to retrieve the value to determine the type
                        if ($Static) {
                            $propertyValue = $targetType::$propertyName
                        }
                        else {
                            $propertyValue = $targetObject.$propertyName
                        }

                        if ($null -eq $propertyValue) {
                            $actualType = $null
                            $testPassed = $expectedType -eq [System.DBNull] -or $expectedType -eq $null.GetType()
                        }
                        else {
                            $actualType = $propertyValue.GetType()
                            $testPassed = $actualType -eq $expectedType -or $actualType.IsSubclassOf($expectedType)
                        }
                    }
                }
                catch {
                    $testPassed = $false
                    $actualType = $null
                }
            }
        }
    }

    if ($Negate) { $testPassed = -not $testPassed }

    $succeeded = $testPassed

    $failureMessage = 
        if ($Negate) {
            $objectType = if ($Static -or ($null -eq $targetObject)) { "type" } else { "object" }

            $format = "Expected {0} '{1}' to not have {2} property '{3}' of type [{4}], but it does."
            $result = $format -f $objectType, $typeName, $searchType, $propertyName, $expectedType.Name
            $result
        } 
        else {
            if ($null -eq $ActualValue) {
                $format = "Expected object to have {0} property '{1}' of type [{2}], but the input is null."
                $result = $format -f $searchType, $propertyName, $expectedType.Name
                $result
            }
            else {
                # Check if property exists
                $propertyExists = $false

                if ($null -ne $targetType) {
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
                        $matchingProperty = $properties | Where-Object { $_.Name -eq $propertyName }
                        $propertyExists = $null -ne $matchingProperty
                    }
                    catch {
                        # Fallback
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
                    $format = "Expected {0} '{1}' to have {2} property '{3}' of type [{4}], but the property does not exist."
                    $result = $format -f $objectType, $typeName, $searchType, $propertyName, $expectedType.Name
                }
                else {
                    $actualTypeName = if ($null -eq $actualType) { "null" } else { $actualType.Name }

                    $format = "Expected {0} '{1}' to have {2} property '{3}' of type [{4}], but actual type is [{5}]."
                    $result = $format -f $objectType, $typeName, $searchType, $propertyName, $expectedType.Name, $actualTypeName
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
Add-ShouldOperator -Name HavePropertyOfType -InternalName Should-HavePropertyOfType -Test ${function:Should-HavePropertyOfType}

BeforeAll {
    class TestClass {
                      [string]    $StringProperty       = "TestString"
                      [int]       $IntProperty          = 42
                      [bool]      $BoolProperty         = $true
                      [string]    $EmptyProperty        = ""
               hidden [string]    $HiddenProperty       = "HiddenValue"
        
        static        [string]    $StaticStringProperty = "StaticString"
        static        [int]       $StaticIntProperty    = 100
        static        [bool]      $StaticBoolProperty   = $false
        static hidden [string]    $StaticHiddenProperty = "StaticHiddenValue"
        
                      [array]     $ArrayProperty        = @(1, 2, 3)
                      [hashtable] $HashtableProperty    = @{ Key = "Value" }
                      [object]    $NullProperty         = $null
    }
}

Describe "Should-HavePropertyWithValue Custom Matcher" {
    BeforeEach {
        $testObject = [TestClass]::new()
    }

    Context "Instance Properties - Correct Values" {
        It "Should detect String property with correct value" {
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "TestString" }
        }

        It "Should detect Integer property with correct value" {
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "IntProperty"; ExpectedValue = 42 }
        }

        #It "Should detect Boolean property with correct value" {
        #    $testObject | Should -HavePropertyWithValue @{ PropertyName = "BoolProperty"; ExpectedValue = $true }
        #}

        It "Should detect empty String property" {
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "EmptyProperty"; ExpectedValue = "" }
        }

        It "Should detect hidden property with correct value" {
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "HiddenProperty"; ExpectedValue = "HiddenValue" }
        }

        It "Should detect null property value" {
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "NullProperty"; ExpectedValue = $null }
        }
    }

    Context "Static Properties - Correct Values" {
        It "Should detect static String property with correct value" {
            [TestClass] | Should -HavePropertyWithValue @{ PropertyName = "StaticStringProperty"; ExpectedValue = "StaticString" } -Static
        }

        It "Should detect static Integer property with correct value" {
            [TestClass] | Should -HavePropertyWithValue @{ PropertyName = "StaticIntProperty"; ExpectedValue = 100 } -Static
        }

        It "Should detect static Boolean property with correct value" {
            [TestClass] | Should -HavePropertyWithValue @{ PropertyName = "StaticBoolProperty"; ExpectedValue = $false } -Static
        }

        It "Should detect static hidden property with correct value" {
            [TestClass] | Should -HavePropertyWithValue @{ PropertyName = "StaticHiddenProperty"; ExpectedValue = "StaticHiddenValue" } -Static
        }

        It "Should work with Type objects" {
            $type = [TestClass]
            $type | Should -HavePropertyWithValue @{ PropertyName = "StaticStringProperty"; ExpectedValue = "StaticString" } -Static
        }
    }

    Context "Incorrect Values" {
        It "Should fail when property has incorrect value" {
            { $testObject | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "WrongValue" } } | Should -Throw
        }

        It "Should fail when static property has incorrect value" {
            { [TestClass] | Should -HavePropertyWithValue @{ PropertyName = "StaticStringProperty"; ExpectedValue = "WrongValue" } -Static } | Should -Throw
        }

        It "Should work with negation for incorrect values" {
            $testObject | Should -Not -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "WrongValue" }
        }

        It "Should work with negation for static incorrect values" {
            [TestClass] | Should -Not -HavePropertyWithValue @{ PropertyName = "StaticStringProperty"; ExpectedValue = "WrongValue" } -Static
        }

        #It "Should properly handle type mismatches" {
        #    $testObject | Should -Not -HavePropertyWithValue @{ PropertyName = "IntProperty"; ExpectedValue = "42" }  # String vs Int
        #}
    }

    Context "Non-Existent Properties" {
        It "Should fail when property does not exist" {
            { $testObject | Should -HavePropertyWithValue @{ PropertyName = "NonExistentProperty"; ExpectedValue = "AnyValue" } } | Should -Throw
        }

        It "Should fail when static property does not exist" {
            { [TestClass] | Should -HavePropertyWithValue @{ PropertyName = "NonExistentStaticProperty"; ExpectedValue = "AnyValue" } -Static } | Should -Throw
        }

        It "Should work with negation for non-existent properties" {
            $testObject | Should -Not -HavePropertyWithValue @{ PropertyName = "NonExistentProperty"; ExpectedValue = "AnyValue" }
        }
    }

    Context "Complex Data Types" {
        #It "Should work with arrays" {
        #    # Array reference comparison
        #    $expectedArray = $testObject.ArrayProperty
        #    $testObject | Should -HavePropertyWithValue @{ PropertyName = "ArrayProperty"; ExpectedValue = $expectedArray }
        #}

        It "Should work with hashtables" {
            # Hashtable reference comparison
            $expectedHashtable = $testObject.HashtableProperty
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "HashtableProperty"; ExpectedValue = $expectedHashtable }
        }

        It "Should recognize different array instances as different" {
            $differentArray = @(1, 2, 3)  # Same content, different reference
            $testObject | Should -Not -HavePropertyWithValue @{ PropertyName = "ArrayProperty"; ExpectedValue = $differentArray }
        }
    }

    Context "Type Objects with Instance Properties" {
        It "Should properly handle Type objects with instance properties" {
            # This should give a special error since we cannot retrieve instance values from Type objects
            { [TestClass] | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "TestString" } } | Should -Throw
        }

        It "Should provide meaningful error message for Type objects with instance properties" {
            try {
                [TestClass] | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "TestString" }
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "cannot get instance property values from type objects"
            }
        }
    }

    Context "Edge Cases" {
        It "Should properly handle null objects" {
            { $null | Should -HavePropertyWithValue @{ PropertyName = "AnyProperty"; ExpectedValue = "AnyValue" } } | Should -Throw
        }

        It "Should work with .NET types and their static properties" {
            [System.Environment] | Should -HavePropertyWithValue @{ PropertyName = "NewLine"; ExpectedValue = [System.Environment]::NewLine } -Static
        }

        It "Should work with PowerShell built-in objects" {
            "test" | Should -HavePropertyWithValue @{ PropertyName = "Length"; ExpectedValue = 4 }
            #@(1, 2, 3) | Should -HavePropertyWithValue @{ PropertyName = "Count"; ExpectedValue = 3 }
        }

        It "Should handle null and negative numbers" {
            # Temporary property for test
            $testObject.IntProperty = 0
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "IntProperty"; ExpectedValue = 0 }
            
            $testObject.IntProperty = -1
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "IntProperty"; ExpectedValue = -1 }
        }

        It "Should handle special string values" {
            $testObject.StringProperty = "  "  # Whitespace
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "  " }
            
            $testObject.StringProperty = "`n"  # Newline
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "`n" }
        }
    }

    Context "Error Messages" {
        It "Should provide meaningful error messages for incorrect values" {
            try {
                $testObject | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "WrongValue" }
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to have.*property.*StringProperty.*with value.*WrongValue"
                $_.Exception.Message | Should -Match "actual value is.*TestString"
            }
        }

        It "Should provide meaningful error messages for missing properties" {
            try {
                $testObject | Should -HavePropertyWithValue @{ PropertyName = "MissingProperty"; ExpectedValue = "AnyValue" }
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to have.*property.*MissingProperty"
                $_.Exception.Message | Should -Match "property does not exist"
            }
        }

        It "Should provide meaningful error messages for negated correct values" {
            try {
                $testObject | Should -Not -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "TestString" }
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to not have.*property.*StringProperty.*with value.*TestString"
            }
        }

        It "Should distinguish between static and instance in error messages" {
            try {
                [TestClass] | Should -HavePropertyWithValue @{ PropertyName = "MissingProperty"; ExpectedValue = "AnyValue" } -Static
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "static.*property"
            }
            
            try {
                $testObject | Should -HavePropertyWithValue @{ PropertyName = "MissingProperty"; ExpectedValue = "AnyValue" }
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "instance.*property"
            }
        }
    }

    Context "Performance and Consistency" {
        It "Should be consistent across multiple calls" {
            # Multiple calls should yield the same result
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "TestString" }
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "TestString" }
            $testObject | Should -HavePropertyWithValue @{ PropertyName = "StringProperty"; ExpectedValue = "TestString" }
        }

        It "Should handle consecutive rapid calls" {
            1..10 | ForEach-Object {
                $testObject | Should -HavePropertyWithValue @{ PropertyName = "IntProperty"; ExpectedValue = 42 }
            }
        }
    }
}

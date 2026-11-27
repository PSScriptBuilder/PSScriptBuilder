BeforeAll {
    class TestClass {
                      [string]    $StringProperty           = "TestString"
                      [int]       $IntProperty              = 42
                      [bool]      $BoolProperty             = $true
                      [datetime]  $DateProperty             = (Get-Date)
               hidden [string]    $HiddenStringProperty     = "HiddenString"
        
        static        [string]    $StaticStringProperty     = "StaticString"
        static        [int]       $StaticIntProperty        = 100
        static hidden [bool]      $StaticHiddenBoolProperty = $false
        
                      [array]     $ArrayProperty            = @(1, 2, 3)
                      [hashtable] $HashtableProperty        = @{ Key = "Value" }
    }
    
    class DerivedClass : TestClass {
        [double] $DoubleProperty = 3.14
    }
}

Describe "Should-HavePropertyOfType Custom Matcher" {
    BeforeEach {
        $testObject = [TestClass]::new()
        $derivedObject = [DerivedClass]::new()
    }

    Context "Instance Properties - Correct Types" {
        It "Should detect String property with correct type" {
            $testObject | Should -HavePropertyOfType @{ PropertyName = "StringProperty"; ExpectedType = [string] }
        }

        It "Should detect Int property with correct type" {
            $testObject | Should -HavePropertyOfType @{ PropertyName = "IntProperty"; ExpectedType = [int] }
        }

        It "Should detect Bool property with correct type" {
            $testObject | Should -HavePropertyOfType @{ PropertyName = "BoolProperty"; ExpectedType = [bool] }
        }

        It "Should detect DateTime property with correct type" {
            $testObject | Should -HavePropertyOfType @{ PropertyName = "DateProperty"; ExpectedType = [datetime] }
        }

        It "Should detect hidden property with correct type" {
            $testObject | Should -HavePropertyOfType @{ PropertyName = "HiddenStringProperty"; ExpectedType = [string] }
        }

        It "Should detect Array property with correct type" {
            $testObject | Should -HavePropertyOfType @{ PropertyName = "ArrayProperty"; ExpectedType = [array] }
        }

        It "Should detect Hashtable property with correct type" {
            $testObject | Should -HavePropertyOfType @{ PropertyName = "HashtableProperty"; ExpectedType = [hashtable] }
        }
    }

    Context "Static Properties - Correct Types" {
        It "Should detect static String property with correct type" {
            [TestClass] | Should -HavePropertyOfType @{ PropertyName = "StaticStringProperty"; ExpectedType = [string] } -Static
        }

        It "Should detect static Int property with correct type" {
            [TestClass] | Should -HavePropertyOfType @{ PropertyName = "StaticIntProperty"; ExpectedType = [int] } -Static
        }

        It "Should detect static hidden property with correct type" {
            [TestClass] | Should -HavePropertyOfType @{ PropertyName = "StaticHiddenBoolProperty"; ExpectedType = [bool] } -Static
        }

        It "Should work with Type objects" {
            $type = [TestClass]
            $type | Should -HavePropertyOfType @{ PropertyName = "StaticStringProperty"; ExpectedType = [string] } -Static
        }
    }

    Context "Incorrect Types" {
        It "Should fail when property has incorrect type" {
            { $testObject | Should -HavePropertyOfType @{ PropertyName = "StringProperty"; ExpectedType = [int] } } | Should -Throw
        }

        It "Should fail when static property has incorrect type" {
            { [TestClass] | Should -HavePropertyOfType @{ PropertyName = "StaticStringProperty"; ExpectedType = [int] } -Static } | Should -Throw
        }

        It "Should work with negation for incorrect types" {
            $testObject | Should -Not -HavePropertyOfType @{ PropertyName = "StringProperty"; ExpectedType = [int] }
        }

        It "Should work with negation for static incorrect types" {
            [TestClass] | Should -Not -HavePropertyOfType @{ PropertyName = "StaticStringProperty"; ExpectedType = [int] } -Static
        }
    }

    Context "Non-Existent Properties" {
        It "Should fail when property does not exist" {
            { $testObject | Should -HavePropertyOfType @{ PropertyName = "NonExistentProperty"; ExpectedType = [string] } } | Should -Throw
        }

        It "Should fail when static property does not exist" {
            { [TestClass] | Should -HavePropertyOfType @{ PropertyName = "NonExistentStaticProperty"; ExpectedType = [string] } -Static } | Should -Throw
        }

        It "Should work with negation for non-existent properties" {
            $testObject | Should -Not -HavePropertyOfType @{ PropertyName = "NonExistentProperty"; ExpectedType = [string] }
        }
    }

    Context "Inheritance" {
        It "Should detect inherited properties with correct types" {
            $derivedObject | Should -HavePropertyOfType @{ PropertyName = "StringProperty"; ExpectedType = [string] }
            $derivedObject | Should -HavePropertyOfType @{ PropertyName = "DoubleProperty"; ExpectedType = [double] }
        }

        It "Should properly handle type inheritance" {
            # Object is base class for all types
            $testObject | Should -HavePropertyOfType @{ PropertyName = "StringProperty"; ExpectedType = [object] }
        }
    }

    Context "Instance Properties on Type Objects" {
        It "Should detect instance properties on Type objects" {
            [TestClass] | Should -HavePropertyOfType @{ PropertyName = "StringProperty"; ExpectedType = [string] }
        }

        It "Should detect hidden instance properties on Type objects" {
            [TestClass] | Should -HavePropertyOfType @{ PropertyName = "HiddenStringProperty"; ExpectedType = [string] }
        }
    }

    Context "Edge Cases" {
        It "Should properly handle null objects" {
            { $null | Should -HavePropertyOfType @{ PropertyName = "AnyProperty"; ExpectedType = [string] } } | Should -Throw
        }

        It "Should work with .NET types" {
            [System.DateTime] | Should -HavePropertyOfType @{ PropertyName = "Now"; ExpectedType = [datetime] } -Static
            [System.DateTime] | Should -HavePropertyOfType @{ PropertyName = "Today"; ExpectedType = [datetime] } -Static
        }

        It "Should work with PowerShell built-in objects" {
            "test" | Should -HavePropertyOfType @{ PropertyName = "Length"; ExpectedType = [int] }
            #@(1, 2, 3) | Should -HavePropertyOfType @{ PropertyName = "Count"; ExpectedType = [int] }
        }

        It "Should handle complex .NET types" {
            $process = [System.Diagnostics.Process]::GetCurrentProcess()
            $process | Should -HavePropertyOfType @{ PropertyName = "ProcessName"; ExpectedType = [string] }
            $process | Should -HavePropertyOfType @{ PropertyName = "Id"; ExpectedType = [int] }
        }
    }

    Context "Error Messages" {
        It "Should provide meaningful error messages for incorrect types" {
            try {
                $testObject | Should -HavePropertyOfType @{ PropertyName = "StringProperty"; ExpectedType = [int] }
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to have.*property.*StringProperty.*of type.*Int32"
                $_.Exception.Message | Should -Match "actual type is.*String"
            }
        }

        It "Should provide meaningful error messages for missing properties" {
            try {
                $testObject | Should -HavePropertyOfType @{ PropertyName = "MissingProperty"; ExpectedType = [string] }
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to have.*property.*MissingProperty"
                $_.Exception.Message | Should -Match "property does not exist"
            }
        }

        It "Should provide meaningful error messages for negated correct types" {
            try {
                $testObject | Should -Not -HavePropertyOfType @{ PropertyName = "StringProperty"; ExpectedType = [string] }
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to not have.*property.*StringProperty.*of type.*String"
            }
        }

        It "Should distinguish between static and instance in error messages" {
            try {
                [TestClass] | Should -HavePropertyOfType @{ PropertyName = "MissingProperty"; ExpectedType = [string] } -Static
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "static.*property"
            }
            
            try {
                $testObject | Should -HavePropertyOfType @{ PropertyName = "MissingProperty"; ExpectedType = [string] }
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "instance.*property"
            }
        }
    }
}

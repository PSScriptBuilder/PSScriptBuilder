BeforeAll {
    class TestClass {
        [string] $PublicProperty = "PublicValue"
        
                      [string] PublicMethod()       { return "PublicMethod" }
               hidden [string] HiddenMethod()       { return "HiddenMethod" }
        static        [string] StaticMethod()       { return "StaticMethod" }
        static hidden [string] StaticHiddenMethod() { return "StaticHiddenMethod" }
        
        # Constructor
        TestClass() {}
        
        # Overloaded method
        [string] PublicMethod([string] $param) { return "PublicMethod: $param" }
    }
}

Describe "Should-HaveMethod Custom Matcher" {
    BeforeEach {
        $testObject = [TestClass]::new()
    }

    Context "Instance Methods" {
        It "Should detect existing public instance method" {
            $testObject | Should -HaveMethod "PublicMethod"
        }

        It "Should detect existing hidden instance method" {
            $testObject | Should -HaveMethod "HiddenMethod"
        }

        It "Should not detect non-existent instance method" {
            $testObject | Should -Not -HaveMethod "NonExistentMethod"
        }

        It "Should detect overloaded methods" {
            $testObject | Should -HaveMethod "PublicMethod"
        }

        #It "Should detect constructor" {
        #    $testObject | Should -HaveMethod ".ctor"
        #}

        It "Should fail when expected method does not exist" {
            { $testObject | Should -HaveMethod "NonExistentMethod" } | Should -Throw
        }

        It "Should fail when using Not with existing method" {
            { $testObject | Should -Not -HaveMethod "PublicMethod" } | Should -Throw
        }
    }

    Context "Static Methods" {
        It "Should detect existing public static method" {
            [TestClass] | Should -HaveMethod "StaticMethod" -Static
        }

        It "Should detect existing hidden static method" {
            [TestClass] | Should -HaveMethod "StaticHiddenMethod" -Static
        }

        It "Should not detect non-existent static method" {
            [TestClass] | Should -Not -HaveMethod "NonExistentStaticMethod" -Static
        }

        It "Should work with Type objects" {
            $type = [TestClass]
            $type | Should -HaveMethod "StaticMethod" -Static
        }

        It "Should fail when expected static method does not exist" {
            { [TestClass] | Should -HaveMethod "NonExistentStaticMethod" -Static } | Should -Throw
        }

        It "Should fail when using Not with existing static method" {
            { [TestClass] | Should -Not -HaveMethod "StaticMethod" -Static } | Should -Throw
        }
    }

    Context "Instance Methods on Type Objects" {
        It "Should detect instance methods on Type objects" {
            [TestClass] | Should -HaveMethod "PublicMethod"
        }

        It "Should detect hidden instance methods on Type objects" {
            [TestClass] | Should -HaveMethod "HiddenMethod"
        }
    }

    Context "Edge Cases" {
        It "Should properly handle null objects" {
            { $null | Should -HaveMethod "AnyMethod" } | Should -Throw
        }

        It "Should not confuse methods with properties" {
            $testObject | Should -Not -HaveMethod "PublicProperty"
        }

        It "Should work with .NET types" {
            [System.DateTime] | Should -HaveMethod "Parse" -Static
            [System.DateTime] | Should -HaveMethod "TryParse" -Static
        }

        It "Should work with PowerShell built-in types" {
            "test" | Should -HaveMethod "Substring"
            "test" | Should -HaveMethod "ToUpper"
            @(1,2,3) | Should -HaveMethod "Equals"
        }

        It "Should work with object instances of .NET types" {
            $dateTime = Get-Date
            $dateTime | Should -HaveMethod "AddDays"
            $dateTime | Should -HaveMethod "ToString"
        }
    }

    Context "Inheritance and Base Methods" {
        It "Should detect inherited methods from Object" {
            $testObject | Should -HaveMethod "ToString"
            $testObject | Should -HaveMethod "GetHashCode"
            $testObject | Should -HaveMethod "Equals"
            $testObject | Should -HaveMethod "GetType"
        }
    }

    Context "Error Messages" {
        It "Should provide meaningful error messages for missing methods" {
            try {
                $testObject | Should -HaveMethod "MissingMethod"
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to have.*method.*MissingMethod"
                $_.Exception.Message | Should -Match "Available.*methods"
            }
        }

        It "Should provide meaningful error messages for negated existing methods" {
            try {
                $testObject | Should -Not -HaveMethod "PublicMethod"
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to not have.*method.*PublicMethod"
            }
        }

        It "Should provide meaningful error messages for missing static methods" {
            try {
                [TestClass] | Should -HaveMethod "MissingStaticMethod" -Static
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to have.*static.*method.*MissingStaticMethod"
            }
        }

        It "Should distinguish between static and instance in error messages" {
            try {
                [TestClass] | Should -HaveMethod "MissingMethod" -Static
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "static.*method"
            }

            try {
                $testObject | Should -HaveMethod "MissingMethod"
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "instance.*method"
            }
        }
    }
}

BeforeAll {
    class TestClass {
                      [string] $PublicProperty       = "PublicValue"
               hidden [string] $HiddenProperty       = "HiddenValue"
        static        [string] $StaticProperty       = "StaticValue"
        static hidden [string] $StaticHiddenProperty = "StaticHiddenValue"
        
        [string] GetPublicMethod() { return "PublicMethod" }
    }
}

Describe "Should-HaveProperty Custom Matcher" {
    BeforeEach {
        $testObject = [TestClass]::new()
    }

    Context "Instance Properties" {
        It "Should detect existing public instance property" {
            $testObject | Should -HaveProperty "PublicProperty"
        }

        It "Should detect existing hidden instance property" {
            $testObject | Should -HaveProperty "HiddenProperty"
        }

        It "Should not detect non-existent instance property" {
            $testObject | Should -Not -HaveProperty "NonExistentProperty"
        }

        It "Should work with negation for non-existent property" {
            { $testObject | Should -Not -HaveProperty "NonExistentProperty" } | Should -Not -Throw
        }

        It "Should fail when expected property does not exist" {
            { $testObject | Should -HaveProperty "NonExistentProperty" } | Should -Throw
        }

        It "Should fail when Not is used with existing property" {
            { $testObject | Should -Not -HaveProperty "PublicProperty" } | Should -Throw
        }
    }

    Context "Static Properties" {
        It "Should detect existing public static property" {
            [TestClass] | Should -HaveProperty "StaticProperty" -Static
        }

        It "Should detect existing hidden static property" {
            [TestClass] | Should -HaveProperty "StaticHiddenProperty" -Static
        }

        It "Should not detect non-existent static property" {
            [TestClass] | Should -Not -HaveProperty "NonExistentStaticProperty" -Static
        }

        It "Should work with Type objects" {
            $type = [TestClass]
            $type | Should -HaveProperty "StaticProperty" -Static
        }

        It "Should fail when expected static property does not exist" {
            { [TestClass] | Should -HaveProperty "NonExistentStaticProperty" -Static } | Should -Throw
        }

        It "Should fail when Not is used with existing static property" {
            { [TestClass] | Should -Not -HaveProperty "StaticProperty" -Static } | Should -Throw
        }
    }

    Context "Instance Properties on Type Objects" {
        It "Should detect instance properties on Type objects" {
            [TestClass] | Should -HaveProperty "PublicProperty"
        }

        It "Should detect hidden instance properties on Type objects" {
            [TestClass] | Should -HaveProperty "HiddenProperty"
        }
    }

    Context "Edge Cases" {
        It "Should properly handle null objects" {
            { $null | Should -HaveProperty "AnyProperty" } | Should -Throw
        }

        It "Should not confuse properties with methods" {
            $testObject | Should -Not -HaveProperty "GetPublicMethod"
        }

        It "Should work with .NET types" {
            [System.DateTime] | Should -HaveProperty "Now" -Static
            [System.DateTime] | Should -HaveProperty "Today" -Static
        }

        It "Should work with PowerShell built-in types" {
            "test" | Should -HaveProperty "Length"
            #@(1, 2, 3) | Should -HaveProperty "Count"
        }
    }

    Context "Error Messages" {
        It "Should provide meaningful error messages for missing properties" {
            try {
                $testObject | Should -HaveProperty "MissingProperty"
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to have.*property.*MissingProperty"
                $_.Exception.Message | Should -Match "Available.*properties"
            }
        }

        It "Should provide meaningful error messages for negated existing properties" {
            try {
                $testObject | Should -Not -HaveProperty "PublicProperty"
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to not have.*property.*PublicProperty"
            }
        }

        It "Should provide meaningful error messages for missing static properties" {
            try {
                [TestClass] | Should -HaveProperty "MissingStaticProperty" -Static
                $false | Should -Be $true  # Should not be reached
            }
            catch {
                $_.Exception.Message | Should -Match "Expected.*to have.*static.*property.*MissingStaticProperty"
            }
        }
    }
}

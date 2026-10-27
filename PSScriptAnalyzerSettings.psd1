@{
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0', '7.4')
        }
    }

    ExcludeRules = @(
        # Format-Cmdlets (Format-PSScriptBuilderBuildResult etc.) use Write-Host by design
        # to produce console output for end users. This is intentional.
        'PSAvoidUsingWriteHost',

        # PowerShell 5.1 class methods cannot access $script: scoped variables.
        # $Global: is required as a workaround and is accessed only via dedicated cmdlets.
        'PSAvoidGlobalVars',

        # These cmdlet names use intentional plural nouns that accurately describe
        # what they operate on (e.g. BumpFiles, ReleaseDataTokens).
        'PSUseSingularNouns',

        # These cmdlets (New-*, Set-*, Remove-*) operate exclusively on in-memory
        # objects. No persistent system state is modified, so ShouldProcess adds
        # no value and would mislead users about the risk of these operations.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}

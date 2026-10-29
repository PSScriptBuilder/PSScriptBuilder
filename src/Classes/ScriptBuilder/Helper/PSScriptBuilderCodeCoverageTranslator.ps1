using namespace System
using namespace System.Collections.Generic
using namespace System.IO

#region Class PSScriptBuilderCodeCoverageTranslator
<#
.SYNOPSIS
    Translates Pester code coverage data from the built output back to source files.
.DESCRIPTION
    The PSScriptBuilderCodeCoverageTranslator class combines Pester's HitCommands and
    MissedCommands entries (reported against the built output script) with a
    PSScriptBuilderSourceLocationResolver to produce per-source-file coverage aggregates.
    Used by Get-PSScriptBuilderSourceCoverage.
#>
class PSScriptBuilderCodeCoverageTranslator {
    #region Properties
    <#
    .SYNOPSIS
        The resolver used to map output script lines back to source locations.
    .DESCRIPTION
        The Resolver property holds the PSScriptBuilderSourceLocationResolver constructed
        from the build's source map. Used by Translate() to resolve each coverage entry's
        line number.
    #>
    hidden [PSScriptBuilderSourceLocationResolver] $Resolver
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of PSScriptBuilderCodeCoverageTranslator.
    .DESCRIPTION
        Creates a new translator bound to the specified resolver. The resolver must already
        be constructed from the source map of the build under test.
    .PARAMETER resolver
        The PSScriptBuilderSourceLocationResolver to use for line resolution. Cannot be null.
    #>
    PSScriptBuilderCodeCoverageTranslator([PSScriptBuilderSourceLocationResolver] $resolver) {
        if ($null -eq $resolver) {
            $message = "Parameter 'resolver' cannot be null."
            throw [ArgumentNullException]::new("resolver", $message)
        }

        $this.Resolver = $resolver
    }
    #endregion Constructors

    #region Methods
    <#
    .SYNOPSIS
        Translates Pester coverage entries into per-source-file coverage results.
    .DESCRIPTION
        The Translate method combines the hit and missed command entries reported by Pester,
        validates that each entry originates from the expected build output file, resolves
        each entry's line number to a source location via the Resolver, and aggregates the
        results by source file.

        Entries whose File does not match outputPath are skipped - this guards against a
        misconfigured CodeCoverage.Path (pointed at something other than the build output)
        silently producing misleading results. Entries whose line cannot be resolved (falling
        outside any tracked component, e.g. template boilerplate) are also skipped.

        Both skip categories are counted and reported as a single consolidated Write-Warning
        each, rather than one warning per entry, consistent with this project's established
        pattern of consolidated warnings over per-item spam.
    .PARAMETER outputPath
        The absolute path to the build output script that CodeCoverage.Path should have been
        pointed at. Used to validate each coverage entry's File property.
    .PARAMETER hitCommands
        The CommandsExecuted entries from a Pester CodeCoverage result. Each entry must
        expose File, Line, and HitCount properties. May be null or empty.
    .PARAMETER missedCommands
        The CommandsMissed entries from a Pester CodeCoverage result. Each entry must expose
        File and Line properties. May be null or empty.
    .OUTPUTS
        Returns an array of PSScriptBuilderSourceCoverageResult, one per distinct source file
        referenced by the resolved coverage entries. Returns an empty array if there are no
        entries to translate.
    #>
    [PSScriptBuilderSourceCoverageResult[]] Translate([string] $outputPath, [object[]] $hitCommands, [object[]] $missedCommands) {
        if ([string]::IsNullOrWhiteSpace($outputPath)) {
            $message = "Parameter 'outputPath' cannot be null or empty."
            throw [ArgumentException]::new($message, "outputPath")
        }

        # GetProjectRootedPath() only guarantees the path is rooted, not normalized - a path
        # like "C:\...\tests\..\build\Output\X.psm1" is already rooted and passes through
        # unchanged, while Pester always reports fully-resolved paths (no "..") in $command.File.
        # Normalizing both sides here makes the comparison correct regardless of how the caller
        # constructed outputPath.
        $normalizedOutputPath = [Path]::GetFullPath($outputPath)

        Write-Verbose "Translating code coverage against output: $normalizedOutputPath"

        $taggedEntries = [List[PSCustomObject]]::new()

        foreach ($command in @($hitCommands)) {
            $taggedEntries.Add([PSCustomObject] @{ Command = $command; Hit = $true })
        }

        foreach ($command in @($missedCommands)) {
            $taggedEntries.Add([PSCustomObject] @{ Command = $command; Hit = $false })
        }

        Write-Verbose "  $($taggedEntries.Count) coverage entr(y/ies) to process"

        $entriesBySourceFile = [Dictionary[string, List[PSCustomObject]]]::new([StringComparer]::OrdinalIgnoreCase)
        $unexpectedFileCount = 0
        $unresolvedLineCount = 0

        foreach ($entry in $taggedEntries) {
            $command = $entry.Command

            if ([string]::IsNullOrWhiteSpace($command.File)) {
                $unexpectedFileCount++
                Write-Verbose "  Skipped (missing file): line $($command.Line)"
                continue
            }

            $normalizedCommandFile = [Path]::GetFullPath($command.File)

            if ($normalizedCommandFile -ne $normalizedOutputPath) {
                $unexpectedFileCount++
                Write-Verbose "  Skipped (unexpected file): $normalizedCommandFile`:$($command.Line)"
                continue
            }

            # TryResolve(), not Resolve() - this loop reports unresolved lines itself as one
            # consolidated warning below, so it needs the silent lookup that never emits its
            # own per-call warning.
            $location = $null
            $resolved = $this.Resolver.TryResolve($command.Line, [ref] $location)

            if (-not $resolved) {
                $unresolvedLineCount++
                Write-Verbose "  Skipped (unresolved line): $($command.Line)"
                continue
            }

            if (-not $entriesBySourceFile.ContainsKey($location.SourceFile)) {
                $entriesBySourceFile[$location.SourceFile] = [List[PSCustomObject]]::new()
            }

            $entriesBySourceFile[$location.SourceFile].Add([PSCustomObject] @{
                Location = $location
                Hit      = $entry.Hit
            })
        }

        if ($unexpectedFileCount -gt 0) {
            $format  = "{0} coverage entr(y/ies) referenced a file other than the build output. " +
                       "Was CodeCoverage.Path set correctly? Run with -Verbose for details."
            $message = $format -f $unexpectedFileCount
            Write-Warning $message
        }

        if ($unresolvedLineCount -gt 0) {
            $format  = "{0} coverage entr(y/ies) could not be resolved to a source location. Run with -Verbose for details."
            $message = $format -f $unresolvedLineCount
            Write-Warning $message
        }

        $results = [List[PSScriptBuilderSourceCoverageResult]]::new()

        foreach ($fileEntry in $entriesBySourceFile.GetEnumerator()) {
            $sourceFile = $fileEntry.Key
            $items      = $fileEntry.Value

            $hitItems    = @($items | Where-Object {      $_.Hit })
            $missedItems = @($items | Where-Object { -not $_.Hit })

            $missedLocations = @($missedItems | ForEach-Object { $_.Location })

            if ($items.Count -eq 0) {
                $percent = 0
            }
            else {
                $percent = [math]::Round(($hitItems.Count / $items.Count) * 100, 1)
            }

            $results.Add([PSScriptBuilderSourceCoverageResult]::new(
                $sourceFile,
                $items.Count,
                $hitItems.Count,
                $missedItems.Count,
                $percent,
                $missedLocations
            ))
        }

        $format  = "Translation complete: {0} source file(s); {1} entr(y/ies) skipped (unexpected file), {2} entr(y/ies) skipped (unresolved line)"
        $message = $format -f $results.Count, $unexpectedFileCount, $unresolvedLineCount
        Write-Verbose $message

        return $results.ToArray()
    }
    #endregion Methods
}
#endregion Class PSScriptBuilderCodeCoverageTranslator

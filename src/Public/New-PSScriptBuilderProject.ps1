#region Cmdlet New-PSScriptBuilderProject
function New-PSScriptBuilderProject {
    <#
    .SYNOPSIS
        Scaffolds a new PSScriptBuilder project structure.
    .DESCRIPTION
        The New-PSScriptBuilderProject cmdlet creates a complete project directory structure for a
        new PSScriptBuilder project, including the configuration file, a template, a build script,
        and all required source directories.

        If -IncludeReleaseManagement is specified, the cmdlet also creates release management files:
        psscriptbuilder.releasedata.json, psscriptbuilder.bumpconfig.json, and a Release script
        with -Major, -Minor, and -Patch switches.

        If the target directory already exists and is not empty, the cmdlet fails with an error.
        Use -Force to overwrite existing files.

        To add release management to an existing project, run the cmdlet again with
        -IncludeReleaseManagement and -Force. Note that -Force overwrites all existing project
        files, including the configuration file, the build script, and the template.
    .PARAMETER Name
        The name of the project to scaffold. Used to derive file and directory names.
    .PARAMETER Path
        The directory in which to create the project folder. Defaults to the current working
        directory if not specified.
    .PARAMETER IncludeReleaseManagement
        If specified, creates release management files in addition to the base project structure.
    .PARAMETER NoSampleFiles
        Suppresses creation of sample source files. By default, sample files demonstrating
        enum, class, and function definitions with dependency relationships are created.
    .PARAMETER Force
        Overwrites existing files in the target directory without error.
    .OUTPUTS
        PSScriptBuilderScaffoldingResult
    .EXAMPLE
        New-PSScriptBuilderProject -Name "MyProject"

        Creates a new project named "MyProject" in the current working directory,
        including the configuration file, a template, a build script, and sample source files.

    .EXAMPLE
        New-PSScriptBuilderProject -Name "MyModule" -Path "C:\Projects" -IncludeReleaseManagement

        Creates a new project in C:\Projects\MyModule with full release management support,
        including psscriptbuilder.releasedata.json, psscriptbuilder.bumpconfig.json,
        and a Release script with -Major, -Minor, and -Patch switches.

    .EXAMPLE
        New-PSScriptBuilderProject -Name "MyProject" -Force

        Recreates the project structure in the current working directory,
        overwriting existing files. Useful for resetting a project to its default scaffolding.

    .EXAMPLE
        New-PSScriptBuilderProject -Name "MyProject" -NoSampleFiles

        Creates a new project without sample source files. Useful when starting from scratch
        or in automated environments where example code would need to be removed anyway.
    #>
    [CmdletBinding()]
    [OutputType([PSScriptBuilderScaffoldingResult])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Path,

        [Parameter(Mandatory = $false)]
        [switch] $IncludeReleaseManagement,

        [Parameter(Mandatory = $false)]
        [switch] $NoSampleFiles,

        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    process {
        try {
            if ([string]::IsNullOrWhiteSpace($Path)) {
                $resolvedPath = (Get-Location).Path
            }
            else {
                $resolvedPath = $Path
            }

            Write-Verbose "Scaffolding project '$Name' in: $resolvedPath"

            $request = [PSScriptBuilderScaffoldingRequest]::new(
                $Name,
                $resolvedPath,
                $IncludeReleaseManagement.IsPresent,
                (-not $NoSampleFiles.IsPresent),
                $Force.IsPresent
            )

            $scaffolder = [PSScriptBuilderScaffolder]::new($request)
            $result     = $scaffolder.Scaffold()

            Write-Verbose "Scaffolding complete: $($result.ProjectPath)"

            return $result
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
#endregion Cmdlet New-PSScriptBuilderProject

using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

#region Class PSScriptBuilderScaffolder
<#
.SYNOPSIS
    Scaffolds a new PSScriptBuilder project structure.
.DESCRIPTION
    The PSScriptBuilderScaffolder class creates the complete directory and file structure
    for a new PSScriptBuilder project, based on a PSScriptBuilderScaffoldingRequest. It supports
    optional release management scaffolding and performs a full rollback on error.
#>
class PSScriptBuilderScaffolder {
    #region Properties
    <#
    .SYNOPSIS
        The scaffold request containing all input parameters.
    #>
    hidden [PSScriptBuilderScaffoldingRequest] $Request

    <#
    .SYNOPSIS
        Tracks directories created during scaffolding for rollback purposes.
    #>
    hidden [List[string]] $CreatedDirectories

    <#
    .SYNOPSIS
        Tracks files created during scaffolding for rollback purposes.
    #>
    hidden [List[string]] $CreatedFiles
    #endregion Properties

    #region Constructors
    <#
    .SYNOPSIS
        Initializes a new instance of the PSScriptBuilderScaffolder class.
    .PARAMETER request
        The scaffold request containing all input parameters.
    #>
    PSScriptBuilderScaffolder([PSScriptBuilderScaffoldingRequest] $request) {
        $this.Request            = $request
        $this.CreatedDirectories = [List[string]]::new()
        $this.CreatedFiles       = [List[string]]::new()
    }
    #endregion Constructors

    #region Public Methods
    <#
    .SYNOPSIS
        Executes the scaffold operation.
    .DESCRIPTION
        Orchestrates the creation of all directories and files for the new project. If any step
        fails, a full rollback is performed and the exception is re-thrown.
    .OUTPUTS
        Returns a PSScriptBuilderScaffoldingResult describing what was created.
    #>
    [PSScriptBuilderScaffoldingResult] Scaffold() {
        $projectPath = [Path]::Combine($this.Request.Path, $this.Request.Name)

        try {
            $this.ValidateTarget($projectPath)
            $this.CreateDirectories($projectPath)
            $this.CreateConfigFile($projectPath)
            $buildScriptPath = $this.CreateBuildScript($projectPath)
            $this.CreateTemplate($projectPath)

            if ($this.Request.IncludeSampleFiles) {
                $this.CreateSampleFiles($projectPath)
            }

            if ($this.Request.IncludeReleaseManagement) {
                $this.CreateReleaseFiles($projectPath)
            }

            return [PSScriptBuilderScaffoldingResult]::new(
                $this.Request.Name,
                $projectPath,
                $buildScriptPath,
                $this.CreatedFiles.ToArray(),
                $this.CreatedDirectories.ToArray()
            )
        }
        catch {
            $this.Rollback()
            throw
        }
    }
    #endregion Public Methods

    #region Private Methods
    <#
    .SYNOPSIS
        Validates that the target directory is suitable for scaffolding.
    .DESCRIPTION
        Checks whether the target project directory is empty or non-existent. If it exists and
        is non-empty, throws an InvalidOperationException unless Force is set.
    .PARAMETER projectPath
        The absolute path to the target project directory.
    #>
    hidden [void] ValidateTarget([string] $projectPath) {
        if (-not [Directory]::Exists($projectPath)) {
            return
        }

        $isEmpty = ([Directory]::GetFileSystemEntries($projectPath).Count -eq 0)

        if (-not $isEmpty -and -not $this.Request.Force) {
            $format  = "The target directory '{0}' already exists and is not empty. Use -Force to overwrite existing files."
            $message = $format -f $projectPath
            throw [InvalidOperationException]::new($message)
        }
    }

    <#
    .SYNOPSIS
        Creates all required project directories.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    #>
    hidden [void] CreateDirectories([string] $projectPath) {
        $directories = @(
            $projectPath,
            [Path]::Combine($projectPath, 'src', 'Enums'),
            [Path]::Combine($projectPath, 'src', 'Classes'),
            [Path]::Combine($projectPath, 'src', 'Public'),
            [Path]::Combine($projectPath, 'build', 'Templates'),
            [Path]::Combine($projectPath, 'build', 'Output')
        )

        if ($this.Request.IncludeReleaseManagement) {
            $directories += [Path]::Combine($projectPath, 'build', 'Release')
        }

        foreach ($directory in $directories) {
            if (-not [Directory]::Exists($directory)) {
                [Directory]::CreateDirectory($directory) | Out-Null
                $this.CreatedDirectories.Add($directory)
                Write-Verbose "  Created directory: $directory"
            }
        }
    }

    <#
    .SYNOPSIS
        Creates the psscriptbuilder.config.json file.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    #>
    hidden [void] CreateConfigFile([string] $projectPath) {
        $configPath = [PSScriptBuilderConfiguration]::CreateDefault($projectPath, $this.Request.Force)
        Write-Verbose "  Created configuration file: $configPath"
        $this.CreatedFiles.Add($configPath)
    }

    <#
    .SYNOPSIS
        Creates the build script.
    .DESCRIPTION
        Generates a Build-<Name>.ps1 script with collectors for Enum, Class, and Function types.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    .OUTPUTS
        Returns the absolute path to the created build script.
    #>
    hidden [string] CreateBuildScript([string] $projectPath) {
        $scriptName   = "Build-$($this.Request.Name).ps1"
        $scriptPath   = [Path]::Combine($projectPath, $scriptName)
        $outputName   = "$($this.Request.Name).ps1"
        $templateName = "$($this.Request.Name).ps1.template"
        $stringBuilder = [StringBuilder]::new()

        [void] $stringBuilder.AppendLine('using module PSScriptBuilder')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine('Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine('$contentCollector = New-PSScriptBuilderContentCollector |')
        [void] $stringBuilder.AppendLine("    Add-PSScriptBuilderCollector -Type Enum     -IncludePath '.\src\Enums'   |")
        [void] $stringBuilder.AppendLine("    Add-PSScriptBuilderCollector -Type Class    -IncludePath '.\src\Classes' |")
        [void] $stringBuilder.AppendLine("    Add-PSScriptBuilderCollector -Type Function -IncludePath '.\src\Public'")
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine('$buildParams = @{')
        [void] $stringBuilder.AppendLine('    ContentCollector = $contentCollector')
        [void] $stringBuilder.AppendLine("    TemplatePath     = '.\build\Templates\$templateName'")
        [void] $stringBuilder.AppendLine("    OutputPath       = '.\build\Output\$outputName'")
        [void] $stringBuilder.AppendLine('}')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine('Invoke-PSScriptBuilderBuild @buildParams | Format-PSScriptBuilderBuildResult')

        $this.SaveFile($scriptPath, $stringBuilder.ToString())
        Write-Verbose "  Created build script: $scriptPath"
        return $scriptPath
    }

    <#
    .SYNOPSIS
        Creates the template file.
    .DESCRIPTION
        Generates a <Name>.ps1.template file with standard component placeholders. If release
        management is included, a version header is prepended.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    #>
    hidden [void] CreateTemplate([string] $projectPath) {
        $templateName = "$($this.Request.Name).ps1.template"
        $templatePath = [Path]::Combine($projectPath, 'build', 'Templates', $templateName)

        $stringBuilder = [StringBuilder]::new()

        [void] $stringBuilder.AppendLine("# Auto-generated by PSScriptBuilder - do not edit the output file directly.")
        [void] $stringBuilder.AppendLine("")

        if ($this.Request.IncludeReleaseManagement) {
            [void] $stringBuilder.AppendLine("# Version:   0.1.0")
            [void] $stringBuilder.AppendLine("# Timestamp: 1970-01-01T00:00:00Z")
            [void] $stringBuilder.AppendLine("")
        }

        [void] $stringBuilder.AppendLine("{{ENUM_DEFINITIONS}}")
        [void] $stringBuilder.AppendLine("")
        [void] $stringBuilder.AppendLine("{{CLASS_DEFINITIONS}}")
        [void] $stringBuilder.AppendLine("")
        [void] $stringBuilder.AppendLine("{{FUNCTION_DEFINITIONS}}")

        if ($this.Request.IncludeSampleFiles) {
            [void] $stringBuilder.AppendLine("")
            [void] $stringBuilder.AppendLine("# Sample invocation - remove or replace with your own code.")
            [void] $stringBuilder.AppendLine('$employee = [Employee]::new("Alice", [WorkStatus]::Active)')
            [void] $stringBuilder.AppendLine('Get-EmployeeInfo -Employee $employee')
        }

        $this.SaveFile($templatePath, $stringBuilder.ToString())
        Write-Verbose "  Created template: $templatePath"
    }

    <#
    .SYNOPSIS
        Creates sample source files demonstrating enum, class, and function definitions.
    .DESCRIPTION
        Orchestrates the creation of WorkStatus.ps1, Employee.ps1, and Get-EmployeeInfo.ps1,
        which together illustrate how PSScriptBuilder resolves dependency order: Employee
        references WorkStatus, and Get-EmployeeInfo references Employee.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    #>
    hidden [void] CreateSampleFiles([string] $projectPath) {
        $this.CreateWorkStatusFile($projectPath)
        $this.CreateEmployeeFile($projectPath)
        $this.CreateGetEmployeeInfoFile($projectPath)
    }

    <#
    .SYNOPSIS
        Creates the WorkStatus.ps1 sample enum file.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    #>
    hidden [void] CreateWorkStatusFile([string] $projectPath) {
        $path          = [Path]::Combine($projectPath, 'src', 'Enums', 'WorkStatus.ps1')
        $stringBuilder = [StringBuilder]::new()

        [void] $stringBuilder.AppendLine('enum WorkStatus {')
        [void] $stringBuilder.AppendLine('    Active')
        [void] $stringBuilder.AppendLine('    OnLeave')
        [void] $stringBuilder.AppendLine('    Terminated')
        [void] $stringBuilder.AppendLine('}')

        $this.SaveFile($path, $stringBuilder.ToString())
        Write-Verbose "  Created sample file: $path"
    }

    <#
    .SYNOPSIS
        Creates the Employee.ps1 sample class file.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    #>
    hidden [void] CreateEmployeeFile([string] $projectPath) {
        $path          = [Path]::Combine($projectPath, 'src', 'Classes', 'Employee.ps1')
        $stringBuilder = [StringBuilder]::new()

        [void] $stringBuilder.AppendLine('class Employee {')
        [void] $stringBuilder.AppendLine('    [string]     $Name')
        [void] $stringBuilder.AppendLine('    [WorkStatus] $Status')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine('    Employee([string] $name, [WorkStatus] $status) {')
        [void] $stringBuilder.AppendLine('        $this.Name   = $name')
        [void] $stringBuilder.AppendLine('        $this.Status = $status')
        [void] $stringBuilder.AppendLine('    }')
        [void] $stringBuilder.AppendLine('}')

        $this.SaveFile($path, $stringBuilder.ToString())
        Write-Verbose "  Created sample file: $path"
    }

    <#
    .SYNOPSIS
        Creates the Get-EmployeeInfo.ps1 sample function file.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    #>
    hidden [void] CreateGetEmployeeInfoFile([string] $projectPath) {
        $path          = [Path]::Combine($projectPath, 'src', 'Public', 'Get-EmployeeInfo.ps1')
        $stringBuilder = [StringBuilder]::new()

        [void] $stringBuilder.AppendLine('Function Get-EmployeeInfo {')
        [void] $stringBuilder.AppendLine('    [CmdletBinding()]')
        [void] $stringBuilder.AppendLine('    [OutputType([string])]')
        [void] $stringBuilder.AppendLine('    param(')
        [void] $stringBuilder.AppendLine('        [Parameter(Mandatory = $true)]')
        [void] $stringBuilder.AppendLine('        [Employee] $Employee')
        [void] $stringBuilder.AppendLine('    )')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine('    return "$($Employee.Name) [$($Employee.Status)]"')
        [void] $stringBuilder.AppendLine('}')

        $this.SaveFile($path, $stringBuilder.ToString())
        Write-Verbose "  Created sample file: $path"
    }

    <#
    .SYNOPSIS
        Creates release management files.
    .DESCRIPTION
        Orchestrates the creation of psscriptbuilder.releasedata.json,
        psscriptbuilder.bumpconfig.json, and a Release-<Name>.ps1 script.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    #>
    hidden [void] CreateReleaseFiles([string] $projectPath) {
        $releasePath      = [Path]::Combine($projectPath, 'build', 'Release')
        $bumpTemplatePath = ".\build\Templates\$($this.Request.Name).ps1.template"

        $this.CreateReleaseDataFile($releasePath)
        $this.CreateBumpConfigFile($releasePath, $bumpTemplatePath)
        $this.CreateReleaseScript($projectPath)
    }

    <#
    .SYNOPSIS
        Creates the release data file with default values.
    .PARAMETER releasePath
        The absolute path to the build\Release directory.
    #>
    hidden [void] CreateReleaseDataFile([string] $releasePath) {
        $releaseDataPath      = [Path]::Combine($releasePath, [PSScriptBuilderWellKnownFileNames]::ReleaseData)
        $releaseDataProcessor = [PSScriptBuilderReleaseDataProcessor]::new()
        $json                 = $releaseDataProcessor.ReleaseData | ConvertTo-Json -Depth 10

        $this.SaveFile($releaseDataPath, $json)
        Write-Verbose "  Created release data file: $releaseDataPath"
    }

    <#
    .SYNOPSIS
        Creates the bump configuration file.
    .PARAMETER releasePath
        The absolute path to the build\Release directory.
    .PARAMETER bumpTemplatePath
        The relative path to the template file, used as the bump target.
    #>
    hidden [void] CreateBumpConfigFile([string] $releasePath, [string] $bumpTemplatePath) {
        $bumpConfigPath = [Path]::Combine($releasePath, [PSScriptBuilderWellKnownFileNames]::BumpConfig)
        $escapedPath    = $bumpTemplatePath.Replace('\', '\\')

        $stringBuilder = [StringBuilder]::new()

        [void] $stringBuilder.AppendLine('{')
        [void] $stringBuilder.AppendLine('    "bumpFiles": [')
        [void] $stringBuilder.AppendLine('        {')
        [void] $stringBuilder.AppendLine("            `"description`": `"$($this.Request.Name) script template`",")
        [void] $stringBuilder.AppendLine("            `"path`": `"$escapedPath`",")
        [void] $stringBuilder.AppendLine('            "items": [')
        [void] $stringBuilder.AppendLine('                {')
        [void] $stringBuilder.AppendLine('                    "pattern": "# Version:\\s+({REGEX_VERSION})",')
        [void] $stringBuilder.AppendLine('                    "tokens": ["VERSION"]')
        [void] $stringBuilder.AppendLine('                },')
        [void] $stringBuilder.AppendLine('                {')
        [void] $stringBuilder.AppendLine('                    "pattern": "# Timestamp:\\s+({REGEX_BUILD_TIMESTAMP})",')
        [void] $stringBuilder.AppendLine('                    "tokens": ["BUILD_TIMESTAMP"]')
        [void] $stringBuilder.AppendLine('                }')
        [void] $stringBuilder.AppendLine('            ]')
        [void] $stringBuilder.AppendLine('        }')
        [void] $stringBuilder.AppendLine('    ]')
        [void] $stringBuilder.AppendLine('}')

        $this.SaveFile($bumpConfigPath, $stringBuilder.ToString())
        Write-Verbose "  Created bump configuration file: $bumpConfigPath"
    }

    <#
    .SYNOPSIS
        Creates the release script.
    .DESCRIPTION
        Generates a Release-<Name>.ps1 script with -Major, -Minor, and -Patch switches
        that updates release data, bumps files, and triggers the build.
    .PARAMETER projectPath
        The absolute path to the project root directory.
    #>
    hidden [void] CreateReleaseScript([string] $projectPath) {
        $releaseScriptName = "Release-$($this.Request.Name).ps1"
        $releaseScriptPath = [Path]::Combine($projectPath, $releaseScriptName)
        $buildScriptName   = "Build-$($this.Request.Name).ps1"

        $stringBuilder = [StringBuilder]::new()

        [void] $stringBuilder.AppendLine('using module PSScriptBuilder')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine("[CmdletBinding(DefaultParameterSetName = 'None')]")
        [void] $stringBuilder.AppendLine('param(')
        [void] $stringBuilder.AppendLine("    [Parameter(Mandatory = `$false, ParameterSetName = 'Major')]")
        [void] $stringBuilder.AppendLine('    [switch] $Major,')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine("    [Parameter(Mandatory = `$false, ParameterSetName = 'Minor')]")
        [void] $stringBuilder.AppendLine('    [switch] $Minor,')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine("    [Parameter(Mandatory = `$false, ParameterSetName = 'Patch')]")
        [void] $stringBuilder.AppendLine('    [switch] $Patch')
        [void] $stringBuilder.AppendLine(')')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine('Set-PSScriptBuilderProjectRoot -Path $PSScriptRoot')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine('$releaseParams = @{')
        [void] $stringBuilder.AppendLine('    UpdateBuildDetails = $true')
        [void] $stringBuilder.AppendLine('}')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine("switch (`$PSCmdlet.ParameterSetName) {")
        [void] $stringBuilder.AppendLine("    'Major' { `$releaseParams.Major = `$true }")
        [void] $stringBuilder.AppendLine("    'Minor' { `$releaseParams.Minor = `$true }")
        [void] $stringBuilder.AppendLine("    'Patch' { `$releaseParams.Patch = `$true }")
        [void] $stringBuilder.AppendLine('}')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine('Update-PSScriptBuilderReleaseData @releaseParams | Format-PSScriptBuilderReleaseDataResult')
        [void] $stringBuilder.AppendLine('Update-PSScriptBuilderBumpFiles | Format-PSScriptBuilderBumpResult')
        [void] $stringBuilder.AppendLine('')
        [void] $stringBuilder.AppendLine(". `"`$PSScriptRoot\$buildScriptName`"")

        $this.SaveFile($releaseScriptPath, $stringBuilder.ToString())
        Write-Verbose "  Created release script: $releaseScriptPath"
    }

    <#
    .SYNOPSIS
        Writes content to a file, respecting the Force flag.
    .DESCRIPTION
        Writes the specified content to the given path using UTF-8 encoding with BOM.
        Throws an IOException if the file already exists and Force is not set.
    .PARAMETER path
        The absolute path to the file to write.
    .PARAMETER content
        The text content to write.
    #>
    hidden [void] SaveFile([string] $path, [string] $content) {
        if ([File]::Exists($path) -and -not $this.Request.Force) {
            $format  = "The file '{0}' already exists. Use -Force to overwrite existing files."
            $message = $format -f $path
            throw [IOException]::new($message)
        }

        [PSScriptBuilderFileIOHelper]::WriteAllTextUTF8WithBOM($path, $content)
        $this.CreatedFiles.Add($path)
    }

    <#
    .SYNOPSIS
        Rolls back all created files and directories.
    .DESCRIPTION
        Deletes all files and directories created during the scaffold operation, in reverse order.
        Directories are only removed if they are empty after file deletion.
        If no files or directories were created, the method returns immediately.
    #>
    hidden [void] Rollback() {
        if ($this.CreatedFiles.Count -eq 0 -and $this.CreatedDirectories.Count -eq 0) {
            return
        }

        Write-Verbose "Rolling back scaffold operation..."

        for ($i = $this.CreatedFiles.Count - 1; $i -ge 0; $i--) {
            $file = $this.CreatedFiles[$i]

            if ([File]::Exists($file)) {
                [File]::Delete($file)
                Write-Verbose "  Removed file: $file"
            }
        }

        for ($i = $this.CreatedDirectories.Count - 1; $i -ge 0; $i--) {
            $dir = $this.CreatedDirectories[$i]

            if ([Directory]::Exists($dir)) {
                $isEmpty = ([Directory]::GetFileSystemEntries($dir).Count -eq 0)

                if ($isEmpty) {
                    [Directory]::Delete($dir)
                    Write-Verbose "  Removed directory: $dir"
                }
            }
        }

        Write-Verbose "Rollback complete."
    }
    #endregion Private Methods
}
#endregion Class PSScriptBuilderScaffolder

# Build Workflow

## Normal Development Cycle

1. Make source changes
2. Run `.\Build-Module.ps1 -Verbose`
3. Validate with `.\tests\Invoke-Tests.ps1`

## Recovery: Build-Module.ps1 Fails to Load

`Build-Module.ps1` loads the compiled module at startup via `using module` and requires
`build/Output/PSScriptBuilder.psm1` to be in a loadable state. If the module becomes
unloadable due to invalid source changes (e.g. invalid type annotations in class files),
`Build-Module.ps1` itself will fail before it can produce a new build.

In this case:

1. Run `.\build.ps1 -ProjectRoot .` — bootstraps the module directly from source files
   without loading the compiled artifact
2. Then run `.\Build-Module.ps1 -Verbose` as usual

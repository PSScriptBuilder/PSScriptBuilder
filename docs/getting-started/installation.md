# Installation

PSScriptBuilder is distributed through the
[PowerShell Gallery](https://www.powershellgallery.com/packages/PSScriptBuilder) and has no
dependencies beyond the PowerShell runtime itself — see the Requirements section for exact
version support.

Getting it set up is a one-time process with three steps:

- **Install** the module from the Gallery
- **Verify** it landed correctly
- **Import** it the one specific way its classes and enums require

All three are covered in full — including the two confirmation prompts you are likely to
see the first time you install anything from the PowerShell Gallery on a given machine, and the
correct way to import a module that exposes PowerShell classes. That last part is worth reading
even if you have installed PowerShell modules many times before: most modules only export
functions, so the usual `Import-Module` habit does not raise any warning signs — it simply
produces confusing errors once you try to use a class.

---

## Requirements

| Requirement | Version |
|---|---|
| PowerShell | 5.1 or later (Windows PowerShell and PowerShell 7+) |
| Operating System | Windows, Linux, macOS |

---

## Step 1 — Install the Module

The first time you install anything from the PowerShell Gallery on a machine, `Install-Module`
commonly stops for one of two reasons before it gets to actually installing anything:

- **Untrusted repository** — PSGallery is not trusted by default; you are asked to confirm
- **Publisher verification** — only if a differently-signed copy of the module already exists locally

Neither is specific to PSScriptBuilder, and both are safe to resolve — at most, you may need to
answer a prompt or add one flag to the install command itself. Both are explained here first,
since you are reasonably likely to run into at least the first one.

**Untrusted repository.** The PowerShell Gallery is not marked as a trusted repository by
default. Unless it has already been trusted on this machine — from installing some other
module previously — `Install-Module` stops and asks for confirmation before proceeding:

```text title="Prompt shown on first install from an untrusted repository"
You are installing the modules from an untrusted repository. If you trust this
repository, change its InstallationPolicy value by running the Set-PSRepository
cmdlet. Are you sure you want to install the modules from 'PSGallery'?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"):
```

Answer `Y` (or `A` for "Yes to All" if you are installing several modules at once) to proceed
for this command only. To skip this prompt permanently for PSGallery, mark it trusted once,
before running `Install-Module`:

```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

**Publisher verification.** PSScriptBuilder is not Authenticode-signed. This only becomes a
problem if a differently-signed (or likewise unsigned) copy of a module with the same name is
already present on this machine — for example, from an earlier manual install — in which case
`Install-Module` fails outright with a publisher check error instead of merely prompting. If
that happens, add `-SkipPublisherCheck` to the install command.

Install the module:

```powershell
Install-Module -Name PSScriptBuilder -Scope CurrentUser
```

To install for all users on the machine instead (requires elevated permissions):

```powershell
Install-Module -Name PSScriptBuilder -Scope AllUsers
```

---

## Step 2 — Verify the Installation

```powershell
Get-Module -Name PSScriptBuilder -ListAvailable
```

This lists every installed version of PSScriptBuilder together with the folder it was
installed into. A successful installation shows at least one entry:

```text title="Expected output"
    Directory: C:\Users\<you>\Documents\PowerShell\Modules

ModuleType Version Name            ExportedCommands
---------- ------- ----            ----------------
Script     1.2.0   PSScriptBuilder {Add-PSScriptBuilderCollector, Compress-PSScriptBuilderScript, ...}
```

If the command returns nothing, that does not necessarily mean the installation failed.

**On Windows**, the most likely reason is that you are checking from a different PowerShell
edition than the one you used to install. Windows is the only platform where PowerShell exists
as two separate editions — Windows PowerShell (`powershell.exe`) and PowerShell 7+
(`pwsh.exe`) — each with its own default module folder, even for the same `-Scope`. A module
installed under one edition is simply not visible from the other. On Linux and macOS, where
only PowerShell 7+ exists, this particular cause does not apply.

**Fix:** run the verification command in the same PowerShell window you used for
`Install-Module`. If you need PSScriptBuilder available in both editions, install it once from
each — or see
[Troubleshooting: sharing a module path across PowerShell editions](../troubleshooting.md#how-do-i-make-a-currentuser-install-visible-to-both-powershell-editions-on-windows)
for a one-time fix that unifies the two.

---

## Step 3 — Import the Module

PSScriptBuilder exposes PowerShell classes and enums. **PowerShell only makes class and enum
definitions available when a module is imported with `using module`.**

Import PSScriptBuilder this way, as the very first statement in your script, before any other
code:

```powershell title="✅ Correct — classes and enums are available"
using module PSScriptBuilder
```

Do not import it this way:

```powershell title="❌ Wrong — classes and enums will NOT be available"
Import-Module PSScriptBuilder
```

**Why this matters:** `using module` and `Import-Module` do different things:

- **`using module`** is a parser directive  
  While parsing the script, PowerShell reads the module's class and enum definitions and
  registers them as resolvable *type literals*.
- **`Import-Module`** is an ordinary cmdlet  
  It loads the module's exported functions into the session like any other module, but it never
  performs that type-literal registration.

In practice, if you import PSScriptBuilder the wrong way and your script then references one of
its enum values:

```powershell
[PSScriptBuilderCollectorType]::ClassCollector
```

— it fails:

```text title="Result"
Unable to find type [PSScriptBuilderCollectorType].
```

Because `using module` needs to be processed by the parser, PowerShell's grammar requires it to
be the very first statement in the script. Comments and blank lines are fine before it — an
actual statement is not:

```text title="Result of a real statement before using module"
A 'using' statement must appear before any other statements in a script.
```

This applies to a script file, parsed as a whole. At an interactive PowerShell prompt, each
line you enter is parsed and run on its own, so `using module` just needs to run before you
reference one of PSScriptBuilder's types — not necessarily as the first command you've ever
typed in that session.

---

## Next Steps

With the module installed, verified, and importable, setup is complete. Head to
[Quick Start](quick-start.md) to scaffold a new project and run your first build in under a
minute.

---

## Tips

!!! tip "Keeping PSScriptBuilder up to date"
    Checks the PowerShell Gallery for a newer version and installs it:
    ```powershell
    Update-Module -Name PSScriptBuilder
    ```
    This goes through the Gallery the same way `Install-Module` does, so the same
    untrusted-repository prompt described for installing the module can reappear here too, if
    the repository has not been marked trusted.
    The new version is installed alongside any older ones already present — `Update-Module` does
    not remove them. To remove an old version once you no longer need it:
    ```powershell
    Uninstall-Module -Name PSScriptBuilder -RequiredVersion <old version>
    ```

---

## See Also

- [Troubleshooting: environment diagnostics](../troubleshooting.md#diagnosing-your-environment) — sharing a module path across PowerShell editions, and other environment questions

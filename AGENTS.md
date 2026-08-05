# Global Parameters

## PowerShell

- **ALWAYS** be compatible with PowerShell 5.1 and PowerShell 7
- **NEVER** use interfaces — PowerShell 5.1 classes do not support interface implementation
- **NEVER** use ternary operators — ternary operators are not available in PowerShell 5.1
- **ALWAYS** use `[Environment]::NewLine` instead of `` "`r`n" `` for platform-independent line endings

## Language

- **ALWAYS** use "German" in chat
- **ALWAYS** use "English" in source code

## General

- **NEVER** autonomously change code
- **NEVER** change code based on user questions
- **NEVER** change code based on user suggestions
- **ALWAYS** show planned code changes in chat only when responding to user questions
- **ALWAYS** show planned code changes in chat only when responding to user suggestions

### Date Information

- **ALWAYS** update a date with the current date

### Time Information

- **ALWAYS** update a time with the current time

### Version Information

- **NEVER** autonomously change a version

## Build

- **NEVER** run a build autonomously — not even after asking for permission
- **ALWAYS** suggest running a build manually

## Development

### Region Blocks

- **NEVER** remove region blocks
- **NEVER** move region blocks
- **NEVER** rename region blocks
- **NEVER** create region blocks

### Functions

- **ALWAYS** declare functions and cmdlets using the `Function` keyword
- **NEVER** start functions or cmdlets with `[CmdletBinding()]` — it must be declared inside the function body

### Exceptions

- **ALWAYS** throw the most specific exception possible
- **NEVER** throw an exception using only `throw`
- **ALWAYS** avoid direct assignment of longer texts for exception messages
  - **ALWAYS** format longer texts using a format string with placeholders
  - **ALWAYS** assign the formatted text to a variable, e.g. $message
  - **ALWAYS** pass the variable as the value for the message parameter to the exception

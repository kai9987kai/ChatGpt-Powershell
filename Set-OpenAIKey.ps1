#requires -Version 5.1

<#
.SYNOPSIS
    Pairs a user-owned OpenAI API key with this PowerShell CLI.

.DESCRIPTION
    Reads the key through a masked prompt. By default it is available only in
    the current process. Use -Persist to save it to the current Windows user's
    environment for future terminal sessions.
#>

[CmdletBinding()]
param(
    [switch] $Persist
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$secureKey = Read-Host 'OpenAI API key' -AsSecureString
$pointer = [IntPtr]::Zero

try {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)

    if ([string]::IsNullOrWhiteSpace($plainKey)) {
        throw 'The API key cannot be empty.'
    }

    if ($Persist) {
        [Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $plainKey, 'User')
        $env:OPENAI_API_KEY = $plainKey
        Write-Host 'OpenAI API key paired for this session and future user sessions.' -ForegroundColor Green
    } else {
        $env:OPENAI_API_KEY = $plainKey
        Write-Host 'OpenAI API key paired for this PowerShell session.' -ForegroundColor Green
    }
} finally {
    if ($pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    $plainKey = $null
    $secureKey.Dispose()
}

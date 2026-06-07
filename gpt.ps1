#requires -Version 5.1

<#
.SYNOPSIS
    Chat with OpenAI from PowerShell using the Responses API.

.DESCRIPTION
    Accepts a prompt as an argument, from the pipeline, or through an
    interactive conversation. Each user supplies their own OPENAI_API_KEY.

.EXAMPLE
    .\gpt.ps1 "Explain PowerShell runspaces simply."

.EXAMPLE
    Get-Content .\error.log -Raw | .\gpt.ps1 -Prompt "Diagnose this error:"

.EXAMPLE
    .\gpt.ps1 -Interactive
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromPipeline, ValueFromRemainingArguments)]
    [AllowEmptyString()]
    [string[]] $Prompt,

    [string] $Model = $(if ($env:OPENAI_MODEL) { $env:OPENAI_MODEL } else { 'gpt-5.5' }),

    [ValidateRange(1, 128000)]
    [int] $MaxOutputTokens = 4096,

    [ValidateSet('none', 'low', 'medium', 'high', 'xhigh')]
    [string] $ReasoningEffort,

    [string] $Instructions = 'Be accurate, concise, and helpful.',

    [switch] $Interactive,

    [string] $ApiBase = $(if ($env:OPENAI_BASE_URL) {
        $env:OPENAI_BASE_URL.TrimEnd('/')
    } else {
        'https://api.openai.com/v1'
    })
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $pipelineInput = [System.Collections.Generic.List[string]]::new()

    function Get-ApiErrorMessage {
        param([System.Management.Automation.ErrorRecord] $ErrorRecord)

        $message = $ErrorRecord.Exception.Message
        $response = $ErrorRecord.Exception.Response
        if ($null -eq $response) {
            return $message
        }

        try {
            $stream = $response.GetResponseStream()
            if ($null -eq $stream) {
                return $message
            }

            $reader = [System.IO.StreamReader]::new($stream)
            try {
                $payload = $reader.ReadToEnd() | ConvertFrom-Json
                if ($payload.error.message) {
                    return [string] $payload.error.message
                }
            } finally {
                $reader.Dispose()
            }
        } catch {
            return $message
        }

        return $message
    }

    function Get-ResponseText {
        param([Parameter(Mandatory)] $Response)

        if ($Response.PSObject.Properties.Name -contains 'output_text' -and $Response.output_text) {
            return [string] $Response.output_text
        }

        $parts = foreach ($item in @($Response.output)) {
            foreach ($content in @($item.content)) {
                if ($content.type -eq 'output_text' -and $content.text) {
                    [string] $content.text
                }
            }
        }

        return ($parts -join [Environment]::NewLine)
    }

    function Invoke-OpenAIResponse {
        param(
            [Parameter(Mandatory)] [string] $InputText,
            [string] $PreviousResponseId
        )

        $body = [ordered]@{
            model             = $Model
            instructions      = $Instructions
            input             = $InputText
            max_output_tokens = $MaxOutputTokens
            store             = $Interactive.IsPresent
        }

        if ($ReasoningEffort) {
            $body.reasoning = @{ effort = $ReasoningEffort }
        }
        if ($PreviousResponseId) {
            $body.previous_response_id = $PreviousResponseId
        }

        $headers = @{
            Authorization = "Bearer $env:OPENAI_API_KEY"
        }

        try {
            $json = $body | ConvertTo-Json -Depth 10 -Compress
            return Invoke-RestMethod `
                -Uri "$ApiBase/responses" `
                -Method Post `
                -Headers $headers `
                -ContentType 'application/json; charset=utf-8' `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($json))
        } catch {
            $detail = Get-ApiErrorMessage -ErrorRecord $_
            throw "OpenAI request failed: $detail"
        }
    }

    if ([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
        throw @'
OPENAI_API_KEY is not set. Create your own key at https://platform.openai.com/api-keys, then set it for this session:

    .\Set-OpenAIKey.ps1

To persist it for your Windows user account, use:

    .\Set-OpenAIKey.ps1 -Persist

Never paste a key into this script or commit one to Git.
'@
    }

    if ($PSVersionTable.PSVersion.Major -le 5) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
}

process {
    if ($null -ne $Prompt) {
        foreach ($part in $Prompt) {
            if (-not [string]::IsNullOrWhiteSpace($part)) {
                $pipelineInput.Add($part)
            }
        }
    }
}

end {
    $oneShotPrompt = $pipelineInput -join [Environment]::NewLine
    if (-not [string]::IsNullOrWhiteSpace($oneShotPrompt)) {
        $response = Invoke-OpenAIResponse -InputText $oneShotPrompt
        $text = Get-ResponseText -Response $response
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw 'The API returned no text output.'
        }
        Write-Output $text
        return
    }

    if (-not $Interactive) {
        $Interactive = $true
    }

    Write-Host "OpenAI PowerShell chat ($Model)" -ForegroundColor Cyan
    Write-Host 'Commands: /clear resets context, /exit quits.' -ForegroundColor DarkGray
    $previousResponseId = $null

    while ($true) {
        $userInput = Read-Host "`nYou"
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            continue
        }

        switch ($userInput.Trim().ToLowerInvariant()) {
            '/exit' { return }
            '/quit' { return }
            '/clear' {
                $previousResponseId = $null
                Write-Host 'Conversation context cleared.' -ForegroundColor DarkGray
                continue
            }
        }

        $response = Invoke-OpenAIResponse `
            -InputText $userInput `
            -PreviousResponseId $previousResponseId

        $text = Get-ResponseText -Response $response
        if ([string]::IsNullOrWhiteSpace($text)) {
            Write-Warning 'The API returned no text output.'
            continue
        }

        $previousResponseId = $response.id
        Write-Host "`nAssistant" -ForegroundColor Green
        Write-Output $text
    }
}

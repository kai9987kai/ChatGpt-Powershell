# OpenAI PowerShell CLI

A dependency-free PowerShell client for the OpenAI Responses API. It works
with Windows PowerShell 5.1 and PowerShell 7+, and every user connects with
their own OpenAI API key.

## Security notice

An API key was previously committed to this repository. That key must be
revoked from the [OpenAI API keys page](https://platform.openai.com/api-keys).
Removing a key from the latest file does not remove it from Git history.

Never place an API key in source code or commit one to Git.

## Setup

1. Create your own key at <https://platform.openai.com/api-keys>.
2. Pair it through the masked key prompt:

   ```powershell
   .\Set-OpenAIKey.ps1
   ```

3. Run the CLI:

   ```powershell
   .\gpt.ps1 "Write a PowerShell function that validates an email address."
   ```

Administrator privileges and PowerShell ISE are not required.

### Persist the key on Windows

This stores the key in your Windows user environment, not in the repository:

```powershell
.\Set-OpenAIKey.ps1 -Persist
```

Open a new terminal after setting it.

## Usage

Start an interactive conversation:

```powershell
.\gpt.ps1
```

Send a one-shot prompt:

```powershell
.\gpt.ps1 "Explain what this repository does."
```

Pipe content into a prompt:

```powershell
Get-Content .\app.log -Raw |
    .\gpt.ps1 -Prompt "Find the root cause in this log:"
```

Choose a model and reasoning effort:

```powershell
.\gpt.ps1 "Review this design" -Model gpt-5.5 -ReasoningEffort high
```

Set a default model:

```powershell
$env:OPENAI_MODEL = "gpt-5.5"
```

Interactive commands:

- `/clear` resets the conversation context.
- `/exit` or `/quit` closes the CLI.

## Options

```text
-Prompt <string[]>          Prompt text; accepts pipeline input
-Model <string>             Model ID (default: OPENAI_MODEL or gpt-5.5)
-MaxOutputTokens <int>      Maximum generated tokens (default: 4096)
-ReasoningEffort <level>    none, low, medium, high, or xhigh
-Instructions <string>      Developer-level behavior instructions
-Interactive               Start chat mode when no prompt is provided
-ApiBase <url>              API base URL (default: OPENAI_BASE_URL or OpenAI)
```

API usage is billed to the account that owns the supplied key. Model access
and rate limits depend on that account.

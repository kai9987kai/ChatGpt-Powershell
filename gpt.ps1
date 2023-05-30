# Define your API key
$apiKey = "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"

# Define your headers
$headers = @{
    'Content-Type' = 'application/json'
    'Authorization' = "Bearer $apiKey"
}

# Define your prompts
$prompts = @(
    "give me code for a basic machine learning python application with only built in modules",
    "give me code for a basic web scraping python application",
    "give me code for a basic data visualization python application"
)

# Loop through each prompt
foreach ($input in $prompts) {
    # Define your body
    $body = @{
        prompt = $input
        model = "text-davinci-003"
        max_tokens = 4000
        temperature = 1.0
    } | ConvertTo-Json

    # Make the POST request
    $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/completions" -Method Post -Body $body -Headers $headers

    # Output the response
    Write-Output $response.choices.text

    # Wait for user input before proceeding to the next prompt
    Read-Host -Prompt "Press Enter to continue to the next prompt"
}

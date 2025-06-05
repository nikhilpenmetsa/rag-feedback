# Update the config.js file with values from CloudFormation stack outputs

param(
    [string]$StackName = "feedback-stack"
)

# Run the Python script
python update_config.py $StackName

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to update config.js"
    exit 1
}

Write-Host "Successfully updated config.js with stack outputs"
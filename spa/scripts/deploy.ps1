param(
    [string]$BucketName = "ai-chat-interface-spa",
    [string]$StackName = "ai-chat-interface-stack",
    [string]$Region = "us-east-1"
)

# Set AWS region
$env:AWS_REGION = $Region

# Get the project root directory (one level up from scripts)
$projectRoot = Split-Path -Parent $PSScriptRoot

# Create dist directory if it doesn't exist
if (-not (Test-Path -Path "$projectRoot\dist")) {
    New-Item -ItemType Directory -Path "$projectRoot\dist" | Out-Null
}

# Copy public files to dist
Write-Host "Building SPA..."
Copy-Item -Path "$projectRoot\public\*" -Destination "$projectRoot\dist\" -Recurse -Force

# Check if stack exists and is in a failed state
Write-Host "Checking if stack exists and needs to be deleted first..."
$stackExists = $false
$stackStatus = $null

try {
    $stackStatus = aws cloudformation describe-stacks --stack-name $StackName --query "Stacks[0].StackStatus" --output text 2>$null
    $stackExists = $true
} catch {
    Write-Host "Stack does not exist yet. Will create a new one."
}

# If stack exists and is in a failed state, delete it
if ($stackExists) {
    $failedStates = @("ROLLBACK_COMPLETE", "CREATE_FAILED", "ROLLBACK_FAILED", "DELETE_FAILED", "UPDATE_ROLLBACK_FAILED")
    if ($failedStates -contains $stackStatus) {
        Write-Host "Stack is in $stackStatus state. Deleting it first..."
        aws cloudformation delete-stack --stack-name $StackName
        Write-Host "Waiting for stack deletion to complete..."
        aws cloudformation wait stack-delete-complete --stack-name $StackName
    }
}

# Deploy CloudFormation stack
Write-Host "Deploying CloudFormation stack..."
aws cloudformation deploy `
    --template-file "$projectRoot\cloudformation\spa-template.yaml" `
    --stack-name $StackName `
    --parameter-overrides S3BucketName=$BucketName `
    --no-fail-on-empty-changeset

# Get stack outputs
Write-Host "Getting stack outputs..."
$outputs = aws cloudformation describe-stacks --stack-name $StackName --query "Stacks[0].Outputs" | ConvertFrom-Json

# Get S3 bucket name from outputs
$s3BucketName = ($outputs | Where-Object { $_.OutputKey -eq "S3BucketName" }).OutputValue

# Upload files to S3
Write-Host "Uploading files to S3..."
aws s3 sync "$projectRoot\dist" "s3://$s3BucketName" --delete

# Display outputs
Write-Host "Deployment complete. Stack outputs:"
if ($outputs) {
    foreach ($output in $outputs) {
        Write-Host "$($output.OutputKey): $($output.OutputValue)"
    }
} else {
    Write-Host "No outputs found or stack deployment failed."
}

Write-Host "`nNote: It may take a few minutes for the CloudFront distribution to fully deploy."
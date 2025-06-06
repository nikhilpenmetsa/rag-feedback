param(
    [string]$BucketName = "feedback-stack-bucket",
    [string]$StackName = "ai-chat-backend-stack",
    [string]$Region = "us-east-1"
)

# Set AWS region
$env:AWS_REGION = $Region

# Get the project root directory (one level up from scripts)
$projectRoot = Split-Path -Parent $PSScriptRoot

# Create directories if they don't exist
if (-not (Test-Path -Path "$projectRoot\build")) {
    New-Item -ItemType Directory -Path "$projectRoot\build" | Out-Null
}

# Install dependencies and package Lambda function
Write-Host "Installing dependencies and packaging Lambda function..."
$tempDir = "$projectRoot\build\lambda_package"
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy source files
Copy-Item -Path "$projectRoot\backend\src\*" -Destination $tempDir -Recurse

# Install dependencies
Push-Location $tempDir
pip install -r requirements.txt -t .
Pop-Location

# Create zip package
Write-Host "Creating Lambda package..."
$zipPath = "$projectRoot\build\feedback-lambda.zip"
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

# Check if S3 bucket exists, create if it doesn't
Write-Host "Checking if S3 bucket exists..."
$bucketExists = aws s3api head-bucket --bucket $BucketName 2>$null
if (-not $?) {
    Write-Host "Creating S3 bucket: $BucketName"
    aws s3 mb "s3://$BucketName" --region $Region
    # Wait a moment for bucket creation to propagate
    Start-Sleep -Seconds 5
}

# Upload Lambda package to S3
Write-Host "Uploading Lambda package to S3..."
aws s3 cp $zipPath "s3://$BucketName/lambda/feedback-lambda.zip"

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
    --template-file "$projectRoot\backend\cloudformation\template.yaml" `
    --stack-name $StackName `
    --capabilities CAPABILITY_IAM `
    --parameter-overrides S3BucketName=$BucketName `
    --no-fail-on-empty-changeset

# Get stack outputs
Write-Host "Getting stack outputs..."
$outputs = aws cloudformation describe-stacks --stack-name $StackName --query "Stacks[0].Outputs" | ConvertFrom-Json

# Display outputs
Write-Host "Deployment complete. Stack outputs:"
if ($outputs) {
    foreach ($output in $outputs) {
        Write-Host "$($output.OutputKey): $($output.OutputValue)"
    }
} else {
    Write-Host "No outputs found or stack deployment failed."
}
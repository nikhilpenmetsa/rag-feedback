param(
    [string]$StackName = "feedback-stack",
    [string]$Region = "us-east-1"
)

# Set AWS region
$env:AWS_REGION = $Region

# Get the project root directory (one level up from scripts)
$projectRoot = Split-Path -Parent $PSScriptRoot

# Create build directory if it doesn't exist
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
Copy-Item -Path "$projectRoot\src\*" -Destination $tempDir -Recurse

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

# Get CloudFormation stack outputs
Write-Host "Getting CloudFormation stack outputs..."
$outputs = aws cloudformation describe-stacks --stack-name $StackName --query "Stacks[0].Outputs" | ConvertFrom-Json

# Extract bucket name from outputs
$bucketName = ($outputs | Where-Object { $_.OutputKey -eq "S3BucketName" }).OutputValue

if (-not $bucketName) {
    Write-Host "Error: Could not find S3 bucket name in CloudFormation outputs."
    exit 1
}

Write-Host "Using S3 bucket: $bucketName"

# Upload Lambda package to S3
Write-Host "Uploading Lambda package to S3..."
aws s3 cp $zipPath "s3://$bucketName/lambda/feedback-lambda.zip"

# Update Lambda functions
Write-Host "Updating Lambda functions with latest code..."
$functions = @("feedback-lambda", "feedback-writer-lambda", "feedback-reader-lambda")

foreach ($function in $functions) {
    Write-Host "Updating function: $function"
    aws lambda update-function-code --function-name $function --s3-bucket $bucketName --s3-key lambda/feedback-lambda.zip
}

Write-Host "Lambda functions updated successfully!"
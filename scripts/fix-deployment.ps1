param(
    [string]$BucketName = "feedback-stack-bucket",
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

# Update CloudFormation stack with S3BucketName output
Write-Host "Updating CloudFormation stack with S3BucketName output..."
aws cloudformation update-stack `
    --stack-name $StackName `
    --template-body file://$projectRoot\cloudformation\template.yaml `
    --capabilities CAPABILITY_IAM `
    --parameters ParameterKey=S3BucketName,ParameterValue=$BucketName `
    --no-fail-on-empty-changeset

# Wait for stack update to complete
Write-Host "Waiting for stack update to complete..."
aws cloudformation wait stack-update-complete --stack-name $StackName

# Update Lambda functions
Write-Host "Updating Lambda functions with latest code..."
$functions = @("feedback-lambda", "feedback-writer-lambda", "feedback-reader-lambda", "feedback-reviewer-lambda")

foreach ($function in $functions) {
    Write-Host "Updating function: $function"
    aws lambda update-function-code --function-name $function --s3-bucket $BucketName --s3-key lambda/feedback-lambda.zip
}

Write-Host "Lambda functions updated successfully!"
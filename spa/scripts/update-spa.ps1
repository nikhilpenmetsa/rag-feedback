param(
    [string]$StackName = "ai-chat-interface-stack",
    [string]$Region = "us-east-1"
)

# Set AWS region
$env:AWS_REGION = $Region

# Get the project root directory (one level up from scripts)
$projectRoot = Split-Path -Parent $PSScriptRoot

# Get CloudFormation stack outputs
Write-Host "Getting CloudFormation stack outputs..."
$outputs = aws cloudformation describe-stacks --stack-name $StackName --query "Stacks[0].Outputs" | ConvertFrom-Json

# Extract values from outputs
$bucketName = ($outputs | Where-Object { $_.OutputKey -eq "S3BucketName" }).OutputValue
$distributionId = ($outputs | Where-Object { $_.OutputKey -eq "CloudFrontDistributionId" }).OutputValue
$cloudFrontUrl = ($outputs | Where-Object { $_.OutputKey -eq "CloudFrontURL" }).OutputValue

if (-not $bucketName -or -not $distributionId) {
    Write-Host "Error: Could not find required values in CloudFormation outputs."
    Write-Host "Make sure the stack '$StackName' exists and has the expected outputs."
    exit 1
}

Write-Host "Found S3 bucket: $bucketName"
Write-Host "Found CloudFront distribution ID: $distributionId"
Write-Host "Found CloudFront URL: $cloudFrontUrl"

# Upload files to S3
Write-Host "Uploading files to S3..."
aws s3 sync "$projectRoot\public" "s3://$bucketName" --delete

# Create invalidation
Write-Host "Creating CloudFront invalidation..."
$invalidationId = aws cloudfront create-invalidation --distribution-id $distributionId --paths "/*" --query "Invalidation.Id" --output text

Write-Host "Invalidation created with ID: $invalidationId"
Write-Host "Waiting for invalidation to complete (this may take a few minutes)..."

# Wait for invalidation to complete
aws cloudfront wait invalidation-completed --distribution-id $distributionId --id $invalidationId

Write-Host "Update complete! Your changes should now be visible at:"
Write-Host $cloudFrontUrl
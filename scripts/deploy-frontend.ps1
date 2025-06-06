param(
    [string]$BucketName = "ai-chat-interface-spa",
    [string]$StackName = "feedback-frontend-stack",
    [string]$Region = "us-east-1"
)

# Set AWS region
$env:AWS_REGION = $Region

# Get the project root directory
$projectRoot = Split-Path -Parent $PSScriptRoot

# Deploy CloudFormation stack for S3 and CloudFront
Write-Host "Deploying CloudFormation stack for frontend..."
aws cloudformation deploy `
    --template-file "$projectRoot\frontend\cloudformation\spa-template.yaml" `
    --stack-name $StackName `
    --parameter-overrides S3BucketName=$BucketName `
    --no-fail-on-empty-changeset

# Get stack outputs
Write-Host "Getting stack outputs..."
$outputs = aws cloudformation describe-stacks --stack-name $StackName --query "Stacks[0].Outputs" | ConvertFrom-Json

# Extract S3 bucket name and CloudFront URL
$s3BucketName = ($outputs | Where-Object { $_.OutputKey -eq "S3BucketName" }).OutputValue
$cloudFrontUrl = ($outputs | Where-Object { $_.OutputKey -eq "CloudFrontURL" }).OutputValue
$distributionId = ($outputs | Where-Object { $_.OutputKey -eq "CloudFrontDistributionId" }).OutputValue

Write-Host "S3 Bucket: $s3BucketName"
Write-Host "CloudFront URL: $cloudFrontUrl"

# Upload files to S3
Write-Host "Uploading files to S3..."
aws s3 sync "$projectRoot\frontend\public" "s3://$s3BucketName" --delete

# Create invalidation to clear CloudFront cache
Write-Host "Creating CloudFront invalidation..."
aws cloudfront create-invalidation --distribution-id $distributionId --paths "/*"

Write-Host "Frontend deployment complete!"
Write-Host "Your application is available at: $cloudFrontUrl"
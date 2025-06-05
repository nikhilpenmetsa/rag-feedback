param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$true)]
    [string]$DistributionId,
    
    [string]$Region = "us-east-1"
)

# Set AWS region
$env:AWS_REGION = $Region

# Get the project root directory (one level up from scripts)
$projectRoot = Split-Path -Parent $PSScriptRoot

# Upload files to S3
Write-Host "Uploading files to S3..."
aws s3 cp "$projectRoot\public\app.js" "s3://$BucketName/app.js"

# Create invalidation
Write-Host "Creating CloudFront invalidation..."
$invalidationId = aws cloudfront create-invalidation --distribution-id $DistributionId --paths "/app.js" --query "Invalidation.Id" --output text

Write-Host "Invalidation created with ID: $invalidationId"
Write-Host "Waiting for invalidation to complete (this may take a few minutes)..."

# Wait for invalidation to complete
aws cloudfront wait invalidation-completed --distribution-id $DistributionId --id $invalidationId

Write-Host "Update complete! Your changes should now be visible at:"
Write-Host "https://$DistributionId.cloudfront.net"
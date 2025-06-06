param(
    [string]$BackendStackName = "ai-chat-backend-stack",
    [string]$FrontendStackName = "feedback-frontend-stack",
    [string]$Region = "us-east-1"
)

# Set AWS region
$env:AWS_REGION = $Region

# Get the project root directory
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = "$projectRoot\frontend\public\config.js"

# Get backend CloudFormation stack outputs
Write-Host "Getting backend CloudFormation stack outputs..."
$backendOutputs = aws cloudformation describe-stacks --stack-name $BackendStackName --query "Stacks[0].Outputs" | ConvertFrom-Json

if (-not $backendOutputs) {
    Write-Error "Failed to get outputs from backend stack: $BackendStackName"
    exit 1
}

# Extract API endpoints and Cognito information
$conversationApi = ($backendOutputs | Where-Object { $_.OutputKey -eq "ConversationApiEndpoint" }).OutputValue
$writeFeedbackApi = ($backendOutputs | Where-Object { $_.OutputKey -eq "WriteFeedbackApiEndpoint" }).OutputValue
$readFeedbackApi = ($backendOutputs | Where-Object { $_.OutputKey -eq "ReadFeedbackApiEndpoint" }).OutputValue
$reviewFeedbackApi = ($backendOutputs | Where-Object { $_.OutputKey -eq "ReviewFeedbackApiEndpoint" }).OutputValue
$userPoolId = ($backendOutputs | Where-Object { $_.OutputKey -eq "UserPoolId" }).OutputValue
$userPoolClientId = ($backendOutputs | Where-Object { $_.OutputKey -eq "UserPoolClientId" }).OutputValue

# Verify we have all required values
if (-not $conversationApi -or -not $writeFeedbackApi -or -not $readFeedbackApi -or -not $reviewFeedbackApi -or -not $userPoolId -or -not $userPoolClientId) {
    Write-Error "Missing required values from backend stack outputs"
    exit 1
}

Write-Host "Backend API endpoints:"
Write-Host "Conversation API: $conversationApi"
Write-Host "Write Feedback API: $writeFeedbackApi"
Write-Host "Read Feedback API: $readFeedbackApi"
Write-Host "Review Feedback API: $reviewFeedbackApi"
Write-Host "User Pool ID: $userPoolId"
Write-Host "User Pool Client ID: $userPoolClientId"

# Create new config.js content
$configContent = @"
// Configuration file for the SPA
// Updated from CloudFormation stack outputs

const CONFIG = {
    // API Endpoints
    API_ENDPOINTS: {
        CONVERSATION: '$conversationApi',
        SUBMIT_FEEDBACK: '$writeFeedbackApi',
        FEEDBACK_DATA: '$readFeedbackApi',
        REVIEW_FEEDBACK: '$reviewFeedbackApi'
    },
    
    // Cognito Configuration
    COGNITO: {
        USER_POOL_ID: '$userPoolId',
        CLIENT_ID: '$userPoolClientId'
    }
};

// Export the configuration
window.CONFIG = CONFIG;
"@

# Write the updated config file
Write-Host "Updating config.js file..."
Set-Content -Path $configPath -Value $configContent

# Get frontend CloudFormation stack outputs
Write-Host "Getting frontend CloudFormation stack outputs..."
$frontendOutputs = aws cloudformation describe-stacks --stack-name $FrontendStackName --query "Stacks[0].Outputs" | ConvertFrom-Json

if (-not $frontendOutputs) {
    Write-Error "Failed to get outputs from frontend stack: $FrontendStackName"
    exit 1
}

# Extract S3 bucket and CloudFront information
$bucketName = ($frontendOutputs | Where-Object { $_.OutputKey -eq "S3BucketName" }).OutputValue
$distributionId = ($frontendOutputs | Where-Object { $_.OutputKey -eq "CloudFrontDistributionId" }).OutputValue
$cloudFrontUrl = ($frontendOutputs | Where-Object { $_.OutputKey -eq "CloudFrontURL" }).OutputValue

if (-not $bucketName -or -not $distributionId) {
    Write-Error "Missing required values from frontend stack outputs"
    exit 1
}

Write-Host "Found S3 bucket: $bucketName"
Write-Host "Found CloudFront distribution ID: $distributionId"
Write-Host "Found CloudFront URL: $cloudFrontUrl"

# Upload config.js to S3
Write-Host "Uploading config.js to S3..."
aws s3 cp $configPath "s3://$bucketName/config.js"

# Create invalidation
Write-Host "Creating CloudFront invalidation..."
$invalidationId = aws cloudfront create-invalidation --distribution-id $distributionId --paths "/config.js" --query "Invalidation.Id" --output text

Write-Host "Invalidation created with ID: $invalidationId"
Write-Host "Waiting for invalidation to complete (this may take a few minutes)..."

# Wait for invalidation to complete
aws cloudfront wait invalidation-completed --distribution-id $distributionId --id $invalidationId

Write-Host "Update complete! Your changes should now be visible at:"
Write-Host "$cloudFrontUrl"
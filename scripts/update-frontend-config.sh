#!/bin/bash
# Script to update frontend config with backend stack outputs and deploy to S3/CloudFront

# Set default parameters or use provided arguments
BACKEND_STACK=${1:-ai-chat-backend-stack}
FRONTEND_STACK=${2:-feedback-frontend-stack}
REGION=${3:-us-east-1}

# Set AWS region
export AWS_REGION=$REGION

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="$PROJECT_ROOT/frontend/public/config.js"

# Get backend CloudFormation stack outputs
echo "Getting backend CloudFormation stack outputs..."
BACKEND_OUTPUTS=$(aws cloudformation describe-stacks --stack-name $BACKEND_STACK --query "Stacks[0].Outputs" --output json)

if [ -z "$BACKEND_OUTPUTS" ]; then
    echo "Failed to get outputs from backend stack: $BACKEND_STACK"
    exit 1
fi

# Extract API endpoints and Cognito information
CONVERSATION_API=$(echo "$BACKEND_OUTPUTS" | jq -r '.[] | select(.OutputKey=="ConversationApiEndpoint") | .OutputValue')
WRITE_FEEDBACK_API=$(echo "$BACKEND_OUTPUTS" | jq -r '.[] | select(.OutputKey=="WriteFeedbackApiEndpoint") | .OutputValue')
READ_FEEDBACK_API=$(echo "$BACKEND_OUTPUTS" | jq -r '.[] | select(.OutputKey=="ReadFeedbackApiEndpoint") | .OutputValue')
REVIEW_FEEDBACK_API=$(echo "$BACKEND_OUTPUTS" | jq -r '.[] | select(.OutputKey=="ReviewFeedbackApiEndpoint") | .OutputValue')
USER_POOL_ID=$(echo "$BACKEND_OUTPUTS" | jq -r '.[] | select(.OutputKey=="UserPoolId") | .OutputValue')
USER_POOL_CLIENT_ID=$(echo "$BACKEND_OUTPUTS" | jq -r '.[] | select(.OutputKey=="UserPoolClientId") | .OutputValue')

# Verify we have all required values
if [ -z "$CONVERSATION_API" ] || [ -z "$WRITE_FEEDBACK_API" ] || [ -z "$READ_FEEDBACK_API" ] || [ -z "$REVIEW_FEEDBACK_API" ] || [ -z "$USER_POOL_ID" ] || [ -z "$USER_POOL_CLIENT_ID" ]; then
    echo "Missing required values from backend stack outputs"
    exit 1
fi

echo "Backend API endpoints:"
echo "Conversation API: $CONVERSATION_API"
echo "Write Feedback API: $WRITE_FEEDBACK_API"
echo "Read Feedback API: $READ_FEEDBACK_API"
echo "Review Feedback API: $REVIEW_FEEDBACK_API"
echo "User Pool ID: $USER_POOL_ID"
echo "User Pool Client ID: $USER_POOL_CLIENT_ID"

# Create new config.js content
cat > "$CONFIG_PATH" << EOL
// Configuration file for the SPA
// Updated from CloudFormation stack outputs

const CONFIG = {
    // API Endpoints
    API_ENDPOINTS: {
        CONVERSATION: '$CONVERSATION_API',
        SUBMIT_FEEDBACK: '$WRITE_FEEDBACK_API',
        FEEDBACK_DATA: '$READ_FEEDBACK_API',
        REVIEW_FEEDBACK: '$REVIEW_FEEDBACK_API'
    },
    
    // Cognito Configuration
    COGNITO: {
        USER_POOL_ID: '$USER_POOL_ID',
        CLIENT_ID: '$USER_POOL_CLIENT_ID'
    }
};

// Export the configuration
window.CONFIG = CONFIG;
EOL

echo "Updated config.js file"

# Get frontend CloudFormation stack outputs
echo "Getting frontend CloudFormation stack outputs..."
FRONTEND_OUTPUTS=$(aws cloudformation describe-stacks --stack-name $FRONTEND_STACK --query "Stacks[0].Outputs" --output json)

if [ -z "$FRONTEND_OUTPUTS" ]; then
    echo "Failed to get outputs from frontend stack: $FRONTEND_STACK"
    exit 1
fi

# Extract S3 bucket and CloudFront information
BUCKET_NAME=$(echo "$FRONTEND_OUTPUTS" | jq -r '.[] | select(.OutputKey=="S3BucketName") | .OutputValue')
DISTRIBUTION_ID=$(echo "$FRONTEND_OUTPUTS" | jq -r '.[] | select(.OutputKey=="CloudFrontDistributionId") | .OutputValue')
CLOUDFRONT_URL=$(echo "$FRONTEND_OUTPUTS" | jq -r '.[] | select(.OutputKey=="CloudFrontURL") | .OutputValue')

if [ -z "$BUCKET_NAME" ] || [ -z "$DISTRIBUTION_ID" ]; then
    echo "Missing required values from frontend stack outputs"
    exit 1
fi

echo "Found S3 bucket: $BUCKET_NAME"
echo "Found CloudFront distribution ID: $DISTRIBUTION_ID"
echo "Found CloudFront URL: $CLOUDFRONT_URL"

# Upload config.js to S3
echo "Uploading config.js to S3..."
aws s3 cp "$CONFIG_PATH" "s3://$BUCKET_NAME/config.js"

# Create invalidation
echo "Creating CloudFront invalidation..."
INVALIDATION_ID=$(aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/config.js" --query "Invalidation.Id" --output text)

echo "Invalidation created with ID: $INVALIDATION_ID"
echo "Waiting for invalidation to complete (this may take a few minutes)..."

# Wait for invalidation to complete
aws cloudfront wait invalidation-completed --distribution-id $DISTRIBUTION_ID --id $INVALIDATION_ID

echo "Update complete! Your changes should now be visible at:"
echo "$CLOUDFRONT_URL"
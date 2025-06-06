#!/bin/bash
# Script to deploy the frontend stack

# Set default parameters or use provided arguments
BUCKET_NAME=${1:-ai-chat-interface-spa}
STACK_NAME=${2:-feedback-frontend-stack}
REGION=${3:-us-east-1}

# Set AWS region
export AWS_REGION=$REGION

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Deploy CloudFormation stack for S3 and CloudFront
echo "Deploying CloudFormation stack for frontend..."
aws cloudformation deploy \
  --template-file "$PROJECT_ROOT/frontend/cloudformation/spa-template.yaml" \
  --stack-name "$STACK_NAME" \
  --parameter-overrides S3BucketName="$BUCKET_NAME" \
  --no-fail-on-empty-changeset

# Get stack outputs
echo "Getting stack outputs..."
OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs")

# Extract S3 bucket name and CloudFront URL
S3_BUCKET_NAME=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="S3BucketName") | .OutputValue')
CLOUDFRONT_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="CloudFrontURL") | .OutputValue')
DISTRIBUTION_ID=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="CloudFrontDistributionId") | .OutputValue')

echo "S3 Bucket: $S3_BUCKET_NAME"
echo "CloudFront URL: $CLOUDFRONT_URL"

# Upload files to S3
echo "Uploading files to S3..."
aws s3 sync "$PROJECT_ROOT/frontend/public" "s3://$S3_BUCKET_NAME" --delete

# Create invalidation to clear CloudFront cache
echo "Creating CloudFront invalidation..."
aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*"

echo "Frontend deployment complete!"
echo "Your application is available at: $CLOUDFRONT_URL"
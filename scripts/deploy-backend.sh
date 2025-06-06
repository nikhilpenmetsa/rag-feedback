#!/bin/bash
# Script to deploy the backend stack

# Set default parameters or use provided arguments
BUCKET_NAME=${1:-feedback-stack-bucket}
STACK_NAME=${2:-ai-chat-backend-stack}
REGION=${3:-us-east-1}

# Set AWS region
export AWS_REGION=$REGION

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create build directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/build"

# Install dependencies and package Lambda function
echo "Installing dependencies and packaging Lambda function..."
TEMP_DIR="$PROJECT_ROOT/build/lambda_package"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copy source files
cp -r "$PROJECT_ROOT/backend/src/"* "$TEMP_DIR/"

# Install dependencies
cd "$TEMP_DIR"
pip install -r requirements.txt -t .
cd -

# Create zip package
echo "Creating Lambda package..."
ZIP_PATH="$PROJECT_ROOT/build/feedback-lambda.zip"
rm -f "$ZIP_PATH"
cd "$TEMP_DIR"
zip -r "$ZIP_PATH" .
cd -

# Check if S3 bucket exists, create if it doesn't
echo "Checking if S3 bucket exists..."
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Creating S3 bucket: $BUCKET_NAME"
  aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
  # Wait a moment for bucket creation to propagate
  sleep 5
fi

# Upload Lambda package to S3
echo "Uploading Lambda package to S3..."
aws s3 cp "$ZIP_PATH" "s3://$BUCKET_NAME/lambda/feedback-lambda.zip"

# Deploy CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file "$PROJECT_ROOT/backend/cloudformation/template.yaml" \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides S3BucketName="$BUCKET_NAME" \
  --no-fail-on-empty-changeset

# Get stack outputs
echo "Getting stack outputs..."
aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs" --output table

echo "Backend deployment completed!"
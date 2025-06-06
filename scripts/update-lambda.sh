#!/bin/bash
# Script to update Lambda functions without redeploying the entire stack

# Set default parameters or use provided arguments
STACK_NAME=${1:-ai-chat-backend-stack}
REGION=${2:-us-east-1}

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

# Get CloudFormation stack outputs
echo "Getting CloudFormation stack outputs..."
OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs")

# Extract bucket name from outputs
BUCKET_NAME=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="S3BucketName") | .OutputValue')

if [ -z "$BUCKET_NAME" ]; then
    echo "Error: Could not find S3 bucket name in CloudFormation outputs."
    exit 1
fi

echo "Using S3 bucket: $BUCKET_NAME"

# Upload Lambda package to S3
echo "Uploading Lambda package to S3..."
aws s3 cp "$ZIP_PATH" "s3://$BUCKET_NAME/lambda/feedback-lambda.zip"

# Update Lambda functions
echo "Updating Lambda functions with latest code..."
FUNCTIONS=("feedback-lambda" "feedback-writer-lambda" "feedback-reader-lambda" "feedback-reviewer-lambda")

for FUNCTION in "${FUNCTIONS[@]}"; do
    echo "Updating function: $FUNCTION"
    aws lambda update-function-code --function-name "$FUNCTION" --s3-bucket "$BUCKET_NAME" --s3-key lambda/feedback-lambda.zip
done

echo "Lambda functions updated successfully!"
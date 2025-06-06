#!/bin/bash
# Script to delete all frontend resources

# Set default stack name or use provided argument
STACK_NAME=${1:-feedback-frontend-stack}
REGION=${2:-us-east-1}

echo "Cleaning up frontend resources for stack: $STACK_NAME"

# Get S3 bucket name from CloudFormation stack
echo "Getting S3 bucket name from CloudFormation stack..."
S3_BUCKET=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" --output text)

if [ -n "$S3_BUCKET" ]; then
  # Empty the S3 bucket first (required before deletion)
  echo "Emptying S3 bucket: $S3_BUCKET"
  aws s3 rm s3://$S3_BUCKET --recursive --region $REGION
fi

# Delete the CloudFormation stack
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

# Wait for stack deletion to complete
echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

echo "Frontend cleanup completed."
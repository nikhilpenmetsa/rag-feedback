#!/bin/bash
# Script to delete all backend resources

# Set default stack name or use provided argument
STACK_NAME=${1:-ai-chat-backend-stack}
REGION=${2:-us-east-1}

echo "Cleaning up backend resources for stack: $STACK_NAME"

# Delete the CloudFormation stack
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

# Wait for stack deletion to complete
echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

# Delete any build directories created during deployment
echo "Cleaning up build directories..."
if [ -d "../build" ]; then
  rm -rf ../build
  echo "Removed build directory"
fi

echo "Backend cleanup completed."
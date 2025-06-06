#!/bin/bash

# Check if sample_users.json exists, create from template if not
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE_USERS_PATH="$SCRIPT_DIR/sample_users.json"
TEMPLATE_PATH="$SCRIPT_DIR/sample_users.template.json"

if [ ! -f "$SAMPLE_USERS_PATH" ]; then
    echo "sample_users.json not found. Creating from template..."
    cp "$TEMPLATE_PATH" "$SAMPLE_USERS_PATH"
    echo "Please edit $SAMPLE_USERS_PATH and update with real passwords before continuing."
    exit 1
fi

# Get the User Pool ID from CloudFormation outputs
USER_POOL_ID=$(aws cloudformation describe-stacks --stack-name ai-chat-backend-stack --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" --output text)

if [ -z "$USER_POOL_ID" ]; then
    echo "Could not retrieve User Pool ID from CloudFormation stack"
    exit 1
fi

echo "Using User Pool ID: $USER_POOL_ID"

# Create users from the sample_users.json file
python create_users.py --user-pool-id $USER_POOL_ID --users-file sample_users.json

# Alternatively, create default users
# python create_users.py --user-pool-id $USER_POOL_ID

# Or create users interactively
# python create_users.py --user-pool-id $USER_POOL_ID --interactive
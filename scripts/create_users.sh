#!/bin/bash

# Get the User Pool ID from CloudFormation outputs
USER_POOL_ID=$(aws cloudformation describe-stacks --stack-name feedback-stack --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" --output text)

if [ -z "$USER_POOL_ID" ]; then
    echo "Error: Could not retrieve User Pool ID from CloudFormation stack"
    exit 1
fi

echo "Using User Pool ID: $USER_POOL_ID"

# Create users from the sample_users.json file
python create_users.py --user-pool-id $USER_POOL_ID --users-file sample_users.json

# Alternatively, create default users
# python create_users.py --user-pool-id $USER_POOL_ID

# Or create users interactively
# python create_users.py --user-pool-id $USER_POOL_ID --interactive
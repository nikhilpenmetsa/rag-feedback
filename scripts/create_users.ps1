# Get the User Pool ID from CloudFormation outputs
$UserPoolId = aws cloudformation describe-stacks --stack-name feedback-stack --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" --output text

if (-not $UserPoolId) {
    Write-Error "Could not retrieve User Pool ID from CloudFormation stack"
    exit 1
}

Write-Host "Using User Pool ID: $UserPoolId"

# Create users from the sample_users.json file
python create_users.py --user-pool-id $UserPoolId --users-file sample_users.json

# Alternatively, create default users
# python create_users.py --user-pool-id $UserPoolId

# Or create users interactively
# python create_users.py --user-pool-id $UserPoolId --interactive
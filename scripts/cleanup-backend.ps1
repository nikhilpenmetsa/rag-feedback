# Script to delete all backend resources

param(
    [string]$StackName = "ai-chat-backend-stack",
    [string]$Region = "us-east-1"
)

Write-Host "Cleaning up backend resources for stack: $StackName"

# Set AWS region
$env:AWS_REGION = $Region

# Get the project root directory
$projectRoot = Split-Path -Parent $PSScriptRoot

# Delete the CloudFormation stack
Write-Host "Deleting CloudFormation stack..."
aws cloudformation delete-stack --stack-name $StackName --region $Region

# Wait for stack deletion to complete
Write-Host "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name $StackName --region $Region

# Delete any build directories created during deployment
Write-Host "Cleaning up build directories..."
$buildDir = Join-Path $projectRoot "build"
if (Test-Path $buildDir) {
    Remove-Item -Path $buildDir -Recurse -Force
    Write-Host "Removed build directory"
}

Write-Host "Backend cleanup completed."
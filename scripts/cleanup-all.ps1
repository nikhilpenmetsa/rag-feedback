# Script to delete all resources (both frontend and backend)

param(
    [string]$Region = "us-east-1",
    [string]$BackendStack = "ai-chat-backend-stack",
    [string]$FrontendStack = "feedback-frontend-stack"
)

Write-Host "Cleaning up all resources..."

# Run frontend cleanup first
Write-Host "Starting frontend cleanup..."
& "$PSScriptRoot\cleanup-frontend.ps1" -StackName $FrontendStack -Region $Region

# Then run backend cleanup
Write-Host "Starting backend cleanup..."
& "$PSScriptRoot\cleanup-backend.ps1" -StackName $BackendStack -Region $Region

Write-Host "All resources have been cleaned up."
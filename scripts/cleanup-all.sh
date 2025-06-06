#!/bin/bash
# Script to delete all resources (both frontend and backend)

# Set default region or use provided argument
REGION=${1:-us-east-1}
BACKEND_STACK=${2:-ai-chat-backend-stack}
FRONTEND_STACK=${3:-feedback-frontend-stack}

echo "Cleaning up all resources..."

# Run frontend cleanup first
echo "Starting frontend cleanup..."
./cleanup-frontend.sh $FRONTEND_STACK $REGION

# Then run backend cleanup
echo "Starting backend cleanup..."
./cleanup-backend.sh $BACKEND_STACK $REGION

echo "All resources have been cleaned up."
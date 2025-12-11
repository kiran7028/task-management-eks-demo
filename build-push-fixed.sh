#!/bin/bash
set -e  # Exit on any error

# Set registry
export REGISTRY="150965600049.dkr.ecr.ap-south-1.amazonaws.com"

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $REGISTRY

# Build and push each service
for SERVICE in frontend user-service task-service notification-service; do
  echo "=== Building and pushing $SERVICE ==="
  
  # Build with proper quoting
  docker buildx build --platform linux/amd64 --load -t "task-management/${SERVICE}" "./${SERVICE}"
  
  # Tag with proper variable expansion
  docker tag "task-management/${SERVICE}:latest" "${REGISTRY}/task-management/${SERVICE}:latest"
  
  # Push to ECR
  docker push "${REGISTRY}/task-management/${SERVICE}:latest"
  
  echo "✅ Successfully pushed $SERVICE"
done

echo "🎉 All services built and pushed successfully!"

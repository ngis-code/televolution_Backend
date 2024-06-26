#!/bin/bash

# Define the repository and target tag
TARGET_TAG="studio:latest"

docker pull node:20-slim    

# Build the Docker image for the specified target
sudo docker build . -f apps/studio/Dockerfile --target production -t $TARGET_TAG || { echo "Docker build failed"; exit 1; }

# Navigate into the docker directory
cd docker || { echo "Directory docker does not exist"; exit 1; }

# Copy the example environment file
sudo cp .env.example .env || { echo "Failed to copy .env file"; exit 1; }

# Pull the Docker images using the alternate docker-compose file
docker compose -f docker-compose2.yml pull || { echo "Docker compose pull failed"; exit 1; }

# Start the Docker containers in detached mode using the main docker-compose file
docker compose up -d || { echo "Docker compose up failed"; exit 1; }

echo "Setup completed successfully."
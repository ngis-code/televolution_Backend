#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

error_exit() {
    echo -e "${RED}$1${NC}" 1>&2
    exit 1
}

prompt_continue() {
    read -p "Do you want to proceed with $1? (y/n): " choice
    case "$choice" in 
      y|Y ) echo "Proceeding with $1...";;
      n|N ) echo "Skipping $1..."; return 1;;
      * ) echo "Invalid choice"; prompt_continue $1;;
    esac
}

# Initial setup
docker login || error_exit "Docker login failed."

if prompt_continue "deleting all builds"; then
    docker builder prune || error_exit "Docker builder prune failed."
    docker pull node:20-slim || error_exit "Docker pull failed."
fi

# Building supabase backend services
if prompt_continue "supabase backend services"; then
    docker build . -f apps/studio/Dockerfile --target production -t studio:latest || error_exit "Docker build failed."

    cd docker || error_exit "Directory docker does not exist."

    cp .env.example .env || error_exit "Failed to copy .env file."

    docker compose -f docker-compose2.yml pull || error_exit "Docker compose pull failed."

    docker compose up -d || error_exit "Docker compose up failed."

    echo "Televolution Backend setup completed successfully."

    cd ..
fi

# Building televolution monitor
if prompt_continue "televolution monitor"; then
    if [ -d "Televolution_monitor" ]; then
        echo "Directory Televolution_monitor already exists."
    else
        git clone https://github.com/ngis-code/Televolution_monitor || error_exit "Git clone failed."
    fi

    cd Televolution_monitor || error_exit "Directory Televolution_monitor does not exist."

    git pull || error_exit "Git pull failed."

    latestMonitorReleasedVersion=$(git describe --tags `git rev-list --tags --max-count=1`)

    echo "Building version: $latestMonitorReleasedVersion"

    docker build -t televolution_monitor:$latestMonitorReleasedVersion . || error_exit "Docker build failed."

    docker run -d --restart=always -p 3001:3001 -v televolution_monitor:/app/data --name televolution_monitor:$latestMonitorReleasedVersion televolution_monitor:$latestMonitorReleasedVersion

    echo "Televolution Monitor setup completed successfully."

    cd ..
fi

# Building televolution middleware
if prompt_continue "televolution middleware"; then
    if [ -d "televolution_Middleware" ]; then
        echo "Directory televolution_Middleware already exists."
    else
        git clone https://github.com/ngis-code/televolution_Middleware || error_exit "Git clone failed."
    fi

    cd televolution_Middleware || error_exit "Directory televolution_Middleware does not exist."

    git pull || error_exit "Git pull failed."

    latestMiddlewareReleasedVersion=$(git describe --tags `git rev-list --tags --max-count=1`)

    echo "Building version: $latestMiddlewareReleasedVersion"

    docker build -t televolution_middleware:$latestMiddlewareReleasedVersion . || error_exit "Docker build failed."

    docker run -d --restart=always -p 3000:3000 --name televolution_middleware televolution_middleware:$latestMiddlewareReleasedVersion

    echo "Televolution Middleware setup completed successfully."
fi
#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

error_exit() {
    echo -e "${RED}$1${NC}" 1>&2
    exit 1
}

deploy_studio=false
deploy_monitor=false
deploy_middleware=false

read -p "Do you want to deploy the backend (studio)? (y/n): " deploy_studio_choice
read -p "Do you want to deploy the monitor? (y/n): " deploy_monitor_choice
read -p "Do you want to deploy the middleware? (y/n): " deploy_middleware_choice

if [[ $deploy_studio_choice == "y" ]]; then
    deploy_studio=true
fi

if [[ $deploy_monitor_choice == "y" ]]; then
    deploy_monitor=true
fi

if [[ $deploy_middleware_choice == "y" ]]; then
    deploy_middleware=true
fi

docker login || error_exit "Docker login failed."

docker builder prune || error_exit "Docker builder prune failed."

docker pull node:20-slim || error_exit "Docker pull failed."

if $deploy_studio; then
    docker build . -f apps/studio/Dockerfile --target production -t studio:latest || error_exit "Docker build failed."

    cd docker || error_exit "Directory docker does not exist."

    cp .env.example .env || error_exit "Failed to copy .env file."

    docker compose -f docker-compose2.yml pull || error_exit "Docker compose pull failed."

    docker compose up -d || error_exit "Docker compose up failed."

    cd ..

    echo "Televolution Backend setup completed successfully."
fi

if $deploy_monitor; then
    if [ -d "Televolution_monitor" ]; then
        echo "Directory Televolution_monitor already exists."
    else
        git clone https://github.com/ngis-code/Televolution_monitor || error_exit "Git clone failed."
    fi

    cd Televolution_monitor || error_exit "Directory Televolution_monitor does not exist."

    git pull || error_exit "Git pull failed."

    latestMonitorReleasedVersion=$(git describe --tags git rev-list --tags --max-count=1)

    echo "Building version: $latestMonitorReleasedVersion"

    docker build -t televolution_monitor_$latestMonitorReleasedVersion . || error_exit "Docker build failed."

    docker run -d --restart=always -p 3001:3001 -v televolution_monitor:/app/data --name televolution_monitor televolution_monitor_$latestMonitorReleasedVersion

    echo "Televolution Monitor setup completed successfully."

    cd ..
fi

if $deploy_middleware; then
    if [ -d "televolution_Middleware" ]; then
        echo "Directory televolution_Middleware already exists."
    else
        git clone https://github.com/ngis-code/televolution_Middleware || error_exit "Git clone failed."
    fi

    cd televolution_Middleware || error_exit "Directory televolution_Middleware does not exist."

    git pull || error_exit "Git pull failed."

    latestMiddlewareReleasedVersion=$(git describe --tags git rev-list --tags --max-count=1)

    echo "Building version: $latestMiddlewareReleasedVersion"

    docker build -t televolution_middleware:$latestMiddlewareReleasedVersion . || error_exit "Docker build failed."

    docker run -d --restart=always -p 3000:3000 --name televolution_middleware televolution_middleware:$latestMiddlewareReleasedVersion

    echo "Televolution Middleware setup completed successfully."

    cd ..
fi
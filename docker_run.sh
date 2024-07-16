#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

error_exit() {
    echo -e "${RED}$1${NC}" 1>&2
    exit 1
}

docker login || error_exit "Docker login failed."

docker builder prune || error_exit "Docker builder prune failed."

docker pull node:20-slim || error_exit "Docker pull failed."

docker build . -f apps/studio/Dockerfile --target production -t studio:latest || error_exit "Docker build failed."

cd docker || error_exit "Directory docker does not exist."

cp .env.example .env || error_exit "Failed to copy .env file."

docker compose -f docker-compose2.yml pull || error_exit "Docker compose pull failed."

docker compose up -d || error_exit "Docker compose up failed."

cd .. 

echo "Televolution Backend setup completed successfully."

if [ -d "Televolution_monitor" ]; then
    echo "Directory Televolution_monitor already exists."
else
    git clone https://github.com/ngis-code/Televolution_monitor || error_exit "Git clone failed."
fi

cd Televolution_monitor || error_exit "Directory Televolution_monitor does not exist."

git pull || error_exit "Git pull failed."

docker build -t televolution_monitor . || error_exit "Docker build failed."

docker run -d --restart=always -p 3001:3001 -v televolution_monitor:/app/data --name televolution_monitor televolution_monitor

# docker run -p 3001:3001 televolution_monitor || error_exit "Docker run failed."

echo "Televolution Monitor setup completed successfully."

cd ..

if [ -d "televolution_functions" ]; then
    echo "Directory televolution_functions already exists."
else
    git clone https://github.com/ngis-code/televolution_Middleware || error_exit "Git clone failed."
fi

cd televolution_functions || error_exit "Directory televolution_functions does not exist."

git pull || error_exit "Git pull failed."

# latestReleasedVersion=$(git describe --tags `git rev-list --tags --max-count=1`)
latestReleasedVersion=$(./get-latest-release-tag.sh)

echo "Building version: $latestReleasedVersion"

docker build -t televolution_functions:$latestReleasedVersion . || error_exit "Docker build failed."

docker run -d --restart=always -p 3000:3000 --name televolution_functions televolution_functions:$latestReleasedVersion

echo "Televolution Monitor setup completed successfully."

#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

error_exit() {
    echo -e "${RED}$1${NC}" 1>&2
    exit 1
}

clean_build=false
deploy_studio=false
deploy_monitor=false
deploy_middleware=false
save_images=false
load_images=false

if [ $# -eq 0 ]; then
    read -p "Do you want to do a clean build? (y/n): " clean_build_choice
    read -p "Do you want to deploy the backend (studio)? (y/n): " deploy_studio_choice
    read -p "Do you want to deploy the monitor? (y/n): " deploy_monitor_choice
    read -p "Do you want to deploy the middleware? (y/n): " deploy_middleware_choice
    read -p "Do you want to save the images? (y/n): " save_images_choice
    read -p "Do you want to load the images? (y/n): " load_images_choice

    if [[ $clean_build_choice == "y" ]]; then
        clean_build=true
    fi

    if [[ $deploy_studio_choice == "y" ]]; then
        deploy_studio=true
    fi

    if [[ $deploy_monitor_choice == "y" ]]; then
        deploy_monitor=true
    fi

    if [[ $deploy_middleware_choice == "y" ]]; then
        deploy_middleware=true
    fi

    if [[ $save_images_choice == "y" ]]; then
        save_images=true
    fi

    if [[ $load_images_choice == "y" ]]; then
        load_images=true
    fi
else
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -c|--clean-build) clean_build=true ;;
            -t|--deploy-studio) deploy_studio=true ;;
            -m|--deploy-monitor) deploy_monitor=true ;;
            -d|--deploy-middleware) deploy_middleware=true ;;
            -s|--save-images) save_images=true ;;
            -l|--load-images) load_images=true ;;
            *) echo "Unknown parameter passed: $1"; exit 1 ;;
        esac
        shift
    done
fi

docker login || error_exit "Docker login failed."

if $clean_build; then
    docker builder prune || error_exit "Docker builder prune failed."
    rm -rf docker_image_builds || error_exit "Failed to remove directory docker_image_builds."
    docker pull node:20-slim || error_exit "Docker pull failed."
fi

if $deploy_studio; then
    docker build . -f apps/studio/Dockerfile --target production -t studio:latest || error_exit "Docker build failed."
    cd docker || error_exit "Directory docker does not exist."
    cp .env.example .env || error_exit "Failed to copy .env file."
    docker compose -f docker-compose2.yml pull || error_exit "Docker compose pull failed."
    docker compose up -d || error_exit "Docker compose up failed."
    echo "Televolution Backend setup completed successfully."
    cd ..
fi

if $deploy_monitor; then
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
    docker run -d --restart=always -p 3001:3001 -v televolution_monitor:/app/data --name televolution_monitor televolution_monitor:$latestMonitorReleasedVersion
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
    latestMiddlewareReleasedVersion=$(git describe --tags `git rev-list --tags --max-count=1`)
    echo "Building version: $latestMiddlewareReleasedVersion"
    docker build -t televolution_middleware:$latestMiddlewareReleasedVersion . || error_exit "Docker build failed."
    docker run -d --restart=always -p 3000:3000 --name televolution_middleware televolution_middleware:$latestMiddlewareReleasedVersion
    echo "Televolution Middleware setup completed successfully."
    cd ..
fi

if $save_images; then
    if [ -d "docker_image_builds" ]; then
        echo "Directory docker_image_builds already exists."
    else
        mkdir docker_image_builds || error_exit "Failed to create directory docker_image_builds."
    fi

    cd docker_image_builds || error_exit "Directory docker_image_builds does not exist."
    
    # Supabase Images
    echo "Saving image: studio"
    docker save studio > studio.tar
    echo "Saving image: runtime"
    docker save supabase/edge-runtime > edge-runtime.tar
    echo "Saving image: postgres"
    docker save supabase/postgres > postgres.tar
    echo "Saving image: gotrue"
    docker save supabase/gotrue > gotrue.tar
    echo "Saving image: realtime"
    docker save supabase/realtime > realtime.tar
    echo "Saving image: api"
    docker save supabase/storage-api > storage-api.tar
    echo "Saving image: meta"
    docker save supabase/postgres-meta > postgres-meta.tar
    echo "Saving image: postgrest"
    docker save postgrest/postgrest > postgrest.tar
    echo "Saving image: logflare"
    docker save supabase/logflare > logflare.tar
    echo "Saving image: vector"
    docker save timberio/vector > vector.tar
    echo "Saving image: kong"
    docker save kong > kong.tar
    echo "Saving image: imgproxy"
    docker save darthsim/imgproxy > imgproxy.tar
    
    # Monitor
    echo "Saving image: monitor"
    docker save televolution_monitor > televolution_monitor.tar

    # Middleware
    echo "Saving image: middleware"
    docker save televolution_middleware > televolution_middleware.tar

    echo "Images saved successfully to docker_image_builds directory."
    cd ..
fi

if $load_images; then
    cd docker_image_builds || error_exit "Directory docker_image_builds does not exist."

    # Supabase Images
    echo "Loading image: studio"
    docker load < studio.tar
    echo "Loading image: runtime"
    docker load < edge-runtime.tar
    echo "Loading image: postgres"
    docker load < postgres.tar
    echo "Loading image: gotrue"
    docker load < gotrue.tar
    echo "Loading image: realtime"
    docker load < realtime.tar
    echo "Loading image: api"
    docker load < storage-api.tar
    echo "Loading image: meta"
    docker load < postgres-meta.tar
    echo "Loading image: postgrest"
    docker load < postgrest.tar
    echo "Loading image: logflare"
    docker load < logflare.tar
    echo "Loading image: vector"
    docker load < vector.tar
    echo "Loading image: kong"
    docker load < kong.tar
    echo "Loading image: imgproxy"
    docker load < imgproxy.tar
    
    # Monitor
    echo "Loading image: monitor"
    docker load < televolution_monitor.tar

    # Middleware
    echo "Loading image: middleware"
    docker load < televolution_middleware.tar

    cd ..

    # Running Containers
    # echo "Starting supabase container..."
    # cd docker || error_exit "Directory docker does not exist."
    # cp .env.example .env || error_exit "Failed to copy .env file."
    # docker compose up -d || error_exit "Docker compose up failed."
    # cd ..
    # echo "Televolution Backend setup completed successfully."

    echo "Starting monitor container..."
    docker run -d --restart=always -p 3001:3001 -v televolution_monitor:/app/data --name televolution_monitor televolution_monitor
    echo "Televolution Monitor setup completed successfully."

    echo "Starting middleware container..."
    docker run -d --restart=always -p 3000:3000 --name televolution_middleware televolution_middleware
    echo "Televolution Middleware setup completed successfully."

    cd ..
fi

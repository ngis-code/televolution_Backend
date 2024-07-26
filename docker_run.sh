#!/bin/bash

# Usage Instructions:
# 1. If you just want to deploy and already have all the images then run the command below
#    ```
#    ./docker_run.sh load
#    ```
# 
# 2. if you want to build images, run
#    ```
#    ./docker_run.sh build
#    ```
# 
# 3. If you want to do a clean build, run
#     ```
#     ./docker_run.sh clean build
#     ```
# 
# 4. If you want to do a save as well, run
#    ```
#    ./docker_run.sh clean build save
#    ```

RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'

showSuccess() {
    echo -e "${GREEN}$1${NC}"
}

# Exit on error
error_exit() {
    echo -e "${RED}$1${NC}" 1>&2
    exit 1
}

# List all tags of a docker image
list_docker_image_tags() {
    local image_name=$1
    images=$(docker images "$image_name" --format "{{.Repository}}:{{.Tag}}")
    if [ -z "$images" ]; then
        error_exit "No images found with the name '$image_name'."
    else
        echo "$images" | head -n 1 | awk -F ':' '{print $2}'
    fi
}

# Find a file with a given prefix
find_files_with_prefix() {
    local prefix=$1
    found_files=$(find . -type f -name "${prefix}*")
    if [ -z "$found_files" ]; then
        error_exit "No files found with the prefix '$prefix'."
    else
        echo "$found_files"
    fi
}

# Extract tag from a filename
extract_tag() {
    local filename=$1
    if [ -z "$filename" ]; then
        error_exit "No filename provided."
    fi
    tag=${filename#*@}
    tag=${tag%.tar}
    if [ -z "$tag" ]; then
        error_exit "No tag found in the filename '$filename'."
    else
        echo "$tag"
    fi
}

print_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  help, -h, --help                Display this help message"
    echo "  clean, -c, --clean-build        Perform a docker clean and removes the docker_image_builds directory"
    echo "  save, -s, --save-images         Save the images to the docker_image_builds directory"
    echo "  load, -l, --load-images         Load the images from the docker_image_builds directory"
    echo "  build                           Builds studio, monitor, and middleware (same as -t -m -d)"
    echo "  -t, --deploy-studio             Builds the studio"
    echo "  -m, --deploy-monitor            Builds the monitor"
    echo "  -d, --deploy-middleware         Builds the middleware"
    echo "  -r, --create-release            Creates a new release on Github"
    echo "  -w, --download                  Downloads the latest release from Github"
}

clean_build=false
deploy_studio=false
deploy_monitor=false
deploy_middleware=false
save_images=false
load_images=false
create_release=false
download_release=false

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
            clean|-c|--clean-build) clean_build=true ;;
            build)
                deploy_studio=true
                deploy_monitor=true
                deploy_middleware=true
                ;;
            -t|--deploy-studio) deploy_studio=true ;;
            -m|--deploy-monitor) deploy_monitor=true ;;
            -d|--deploy-middleware) deploy_middleware=true ;;
            save|-s|--save-images) save_images=true ;;
            load|-l|--load-images) load_images=true ;;
            release|-r|--create-release) create_release=true ;;
            download|-w|--download) download_release=true ;;
            help|-h|--help) print_help; exit 0 ;;
            *) echo "Unknown parameter passed: $1"; exit 1 ;;
        esac
        shift
    done
fi

docker login || error_exit "Docker login failed."
git pull || echo "Git pull failed. Continuing..."

if $clean_build; then
    docker builder prune || error_exit "Docker builder prune failed."
    rm -rf docker_image_builds || error_exit "Failed to remove directory docker_image_builds."
    docker stop $(docker ps -q)
    docker rm $(docker ps -a -q)
    docker pull node:20-slim || error_exit "Docker pull failed."
fi

if $deploy_studio; then
    # Building studio
    docker build . -f apps/studio/Dockerfile --target production -t studio:latest || error_exit "Docker build failed."
    showSuccess "Studio was built successfully."

    cd docker || error_exit "Directory docker does not exist."
    cp .env.example .env || error_exit "Failed to copy .env file."

    # Pulling images
    docker compose -f docker-compose2.yml pull || error_exit "Docker compose pull failed."

    # Starting containers
    docker compose up -d || error_exit "Docker compose up failed."
    cd ..

    showSuccess "Televolution Backend was built successfully."
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
    if [ $? -ne 0 ]; then
        error_exit "Failed to start the monitor container."
    fi
    showSuccess "Televolution Monitor was built successfully."
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
    if [ -z "$latestMiddlewareReleasedVersion" ]; then
        error_exit "Failed to get the latest middleware version."
    fi
    echo "Building version: $latestMiddlewareReleasedVersion"
    docker build -t televolution_middleware:$latestMiddlewareReleasedVersion . || error_exit "Docker build failed."
    docker run -d --restart=always -p 3000:3000 --name televolution_middleware televolution_middleware:$latestMiddlewareReleasedVersion
    if [ $? -ne 0 ]; then
        error_exit "Failed to start the middleware container."
    fi
    showSuccess "Televolution Middleware was built successfully."
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
    tag=$(list_docker_image_tags "studio")
    echo "Saving image: studio:$tag"
    docker save studio > "studio@$tag.tar" || error_exit "Failed to save image studio."

    tag=$(list_docker_image_tags "supabase/edge-runtime")
    echo "Saving image: runtime:$tag"
    docker save supabase/edge-runtime > "edge-runtime@$tag.tar" || error_exit "Failed to save image edge-runtime."

    tag=$(list_docker_image_tags "supabase/postgres")
    echo "Saving image: postgres:$tag"
    docker save supabase/postgres > "postgres@$tag.tar" || error_exit "Failed to save image postgres."

    tag=$(list_docker_image_tags "supabase/gotrue")
    echo "Saving image: gotrue:$tag"
    docker save supabase/gotrue > "gotrue@$tag.tar" || error_exit "Failed to save image gotrue."
    
    tag=$(list_docker_image_tags "supabase/realtime")
    echo "Saving image: realtime:$tag"
    docker save supabase/realtime > "realtime@$tag.tar" || error_exit "Failed to save image realtime."
    
    tag=$(list_docker_image_tags "supabase/storage-api")
    echo "Saving image: api:$tag"
    docker save supabase/storage-api > "storage-api@$tag.tar"   || error_exit "Failed to save image storage-api."
    
    tag=$(list_docker_image_tags "supabase/postgres-meta")
    echo "Saving image: meta:$tag"
    docker save supabase/postgres-meta > "postgres-meta@$tag.tar" || error_exit "Failed to save image postgres-meta."
    
    tag=$(list_docker_image_tags "postgrest/postgrest")
    echo "Saving image: postgrest:$tag"
    docker save postgrest/postgrest > "postgrest@$tag.tar" || error_exit "Failed to save image postgrest."
    
    tag=$(list_docker_image_tags "supabase/logflare")
    echo "Saving image: logflare:$tag"
    docker save supabase/logflare > "logflare@$tag.tar" || error_exit "Failed to save image logflare."
    
    tag=$(list_docker_image_tags "timberio/vector")
    echo "Saving image: vector:$tag"
    docker save timberio/vector > "vector@$tag.tar" || error_exit "Failed to save image vector."
    
    tag=$(list_docker_image_tags "kong")
    echo "Saving image: kong:$tag"
    docker save kong > "kong@$tag.tar" || error_exit "Failed to save image kong."
    
    tag=$(list_docker_image_tags "darthsim/imgproxy")
    echo "Saving image: imgproxy:$tag"
    docker save darthsim/imgproxy > "imgproxy@$tag.tar" || error_exit "Failed to save image imgproxy."

    # Monitor
    echo "Saving image: monitor"
    tag=$(list_docker_image_tags "televolution_monitor")
    docker save televolution_monitor > "televolution_monitor@$tag.tar" || error_exit "Failed to save image televolution_monitor."

    # Middleware
    echo "Saving image: middleware"
    tag=$(list_docker_image_tags "televolution_middleware")
    docker save televolution_middleware > "televolution_middleware@$tag.tar" || error_exit "Failed to save image televolution_middleware."
    
    showSuccess "Images saved successfully to docker_image_builds directory."
    cd ..
fi

if $load_images; then
    cd docker_image_builds || error_exit "Directory docker_image_builds does not exist."

    # Supabase Images
    file_name=$(find_files_with_prefix "studio@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image studio."
    
    file_name=$(find_files_with_prefix "edge-runtime@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image edge-runtime."
    
    file_name=$(find_files_with_prefix "postgres@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image postgres."
    
    file_name=$(find_files_with_prefix "gotrue@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image gotrue."
    
    file_name=$(find_files_with_prefix "realtime@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image realtime."
    
    file_name=$(find_files_with_prefix "storage-api@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image storage-api."
    
    file_name=$(find_files_with_prefix "postgres-meta@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image postgres-meta."
    
    file_name=$(find_files_with_prefix "postgrest@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image postgrest."
    
    file_name=$(find_files_with_prefix "logflare@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image logflare."
    
    file_name=$(find_files_with_prefix "vector@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image vector."
    
    file_name=$(find_files_with_prefix "kong@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image kong."
    
    file_name=$(find_files_with_prefix "imgproxy@")
    echo "Loading image: $file_name"
    docker load < "$file_name" || error_exit "Failed to load image imgproxy."
    
    # Monitor
    echo "Loading image: monitor"
    televolution_monitor_file_name=$(find_files_with_prefix "televolution_monitor@")
    docker load < "$televolution_monitor_file_name" || error_exit "Failed to load image televolution_monitor."

    # Middleware
    echo "Loading image: middleware"
    televolution_middleware_file_name=$(find_files_with_prefix "televolution_middleware@")
    docker load < "$televolution_middleware_file_name" || error_exit "Failed to load image televolution_middleware."

    # Starting Monitor
    echo "Starting monitor container..."
    tag=$(extract_tag "$(find_files_with_prefix "televolution_monitor@")")
    echo "Tag: $tag"
    docker run -d --restart=always -p 3001:3001 -v televolution_monitor:/app/data --name televolution_monitor televolution_monitor:$tag
    if [ $? -ne 0 ]; then
        error_exit "Failed to start the monitor container."
    fi

    # Starting Middleware
    echo "Starting middleware container..."
    tag=$(extract_tag "$(find_files_with_prefix "televolution_middleware@")")
    echo "Tag: $tag"
    docker run -d --restart=always -p 3000:3000 --env-file .env --name televolution_middleware televolution_middleware:$tag
    if [ $? -ne 0 ]; then
        error_exit "Failed to start the middleware container."
    fi

    cd ..

    # Running Supabase Container
    echo "Starting Studio and Backend Service containers..."
    cd docker || error_exit "Directory docker does not exist."
    cp .env.example .env || error_exit "Failed to copy .env file."
    docker compose up -d || error_exit "Docker compose up failed."
    cd ..

    showSuccess "All Images loaded successfully from docker_image_builds directory."

fi

GITHUB_REPO="https://github.com/ngis-code/televolution_Backend"

check_gh_installation(){
    if ! command -v gh &> /dev/null; then
        error_exit "Github CLI is not installed. Please install it from https://github.com/cli/cli#installation."
    fi
}

if $create_release; then
    check_gh_installation

    cd docker_image_builds || error_exit "Directory docker_image_builds does not exist."

    latest_tag=$(gh release list --repo "$GITHUB_REPO" --limit 1 --json tagName -q ".[0].tagName")

    read -p "Enter the tag for the new release (latest: $latest_tag): " new_tag
    
    if [ -z "$new_tag" ]; then
        error_exit "The new tag cannot be empty."
    fi

    if [[ "$new_tag" != v* ]]; then
        new_tag="v$new_tag"
    fi

    if [[ "$latest_tag" > "$new_tag" ]]; then
        error_exit "The new tag must be greater or equal to the latest tag ($latest_tag)."
    fi

    new_tag=${new_tag#v}

    read -p "Enter the name for the new release: " release_name
    
    if [ -z "$release_name" ]; then
        error_exit "The release name cannot be empty."
    fi

    read -p "Enter the body text for the release: " release_body

    gh release create "$new_tag" --title "$release_name" --notes "$release_body" --repo "$GITHUB_REPO" || error_exit "Failed to create release."

    for file in *.tar; do
        echo "Uploading $file..."
        gh release upload "$new_tag" "$file" --repo "$GITHUB_REPO"
    done

    cd ..
    showSuccess "Release created and images uploaded successfully."
fi

if $download_release; then
    check_gh_installation

    if [ -d "docker_image_builds" ]; then
        echo "Deleting existing directory docker_image_builds..."
        rm -rf docker_image_builds || error_exit "Failed to delete directory docker_image_builds."
    fi

    mkdir docker_image_builds || error_exit "Failed to create directory docker_image_builds."
    cd docker_image_builds || error_exit "Directory docker_image_builds does not exist."

    latest_tag=$(gh release list --repo "$GITHUB_REPO" --limit 1 --json tagName -q ".[0].tagName")

    if [ -z "$latest_tag" ]; then
        error_exit "No releases found in the repository."
    fi

    read -p "Enter the tag to download (press enter for $latest_tag): " download_tag
    
    if [ -z "$download_tag" ]; then
        download_tag=$latest_tag
    fi

    echo "Downloading assets from release $download_tag..."
    gh release download "$download_tag" --repo "$GITHUB_REPO"

    cd ..
    showSuccess "All assets downloaded successfully into docker_image_builds directory."
fi
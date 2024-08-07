#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
BUILD_DIR="docker_image_builds"
GITHUB_REPO="https://github.com/ngis-code/televolution_Backend"

showSuccess() {
    echo -e "${GREEN}$1${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e 'display notification "'"$1"'" with title "Success"'
    fi
}

error_exit() {
    echo -e "${RED}$1${NC}" 1>&2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e 'display notification "'"$1"'" with title "Error"'
    fi
    exit 1
}

error_continue() {
    echo -e "${RED}$1${NC}" 1>&2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e 'display notification "'"$1"'" with title "Error"'
    fi
}

print_help(){
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  help, -h, --help    Display this help message"
    echo "  clean               Perform a docker clean and removes the docker_image_builds directory"
    echo "  save                Save the images to the docker_image_builds directory"
    echo "  load                Load the images from the docker_image_builds directory"
    echo "  build               Builds studio, monitor, and middleware (same as -t -m -d)"
    echo "  download            Downloads the latest release from Github"
}

build_appwrite(){
    # curl -L -O https://appwrite.io/install/compose appwrite/docker-compose.yml || error_exit "Failed to download docker-compose file."
    # curl -L -O https://appwrite.io/install/env appwrite/.env || error_exit "Failed to download install file."
    # cd appwrite || error_exit "Directory docker does not exist."
    # docker compose up -d --remove-orphans || error_exit "Failed to build Appwrite."
    # showSuccess "Appwrite built successfully."
    # cd ..
    docker run -it --rm \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume "$(pwd)"/appwrite:/usr/src/code/appwrite:rw \
    --entrypoint="install" \
    appwrite/appwrite:1.5.7 || error_exit "Failed to install Appwrite."
    showSuccess "Appwrite installed successfully."
}

save_appwrite_image(){
    cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."
    error_exit "Change the appwrite image name first!!!!!!!!!!!!!!!!!"
    docker save -o appwrite.tar:v0.0.1 || error_exit "Failed to save image."
    showSuccess "Image saved successfully."
    cd ..
}

load_appwrite_image(){
    error_exit "TODO: load images"
    cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."
    error_exit "Change the appwrite image file name first!!!!!!!!!!!!!!!!!"
    docker load -i appwrite.tar || error_exit "Failed to load image."
    showSuccess "Image loaded successfully."
    cd ..
}

clean_docker(){
    docker builder prune || error_exit "Docker builder prune failed."
    # rm -rf docker_image_builds || error_exit "Failed to remove directory docker_image_builds."
    docker stop $(docker ps -q) || error_continue "Failed to stop all containers."
    docker rm $(docker ps -a -q) || error_continue "Failed to remove all containers."
    docker image prune -a || error_continue "Failed to remove all images."
    docker volume prune || error_continue "Failed to remove all volumes. We will retry another way to remove volumes."
    docker volume rm $(sudo docker volume ls -q) || error_continue "Failed to remove all volumes."
    docker system prune -a || error_continue "Failed to remove all unused data."
}

download_release(){
    if [ -d "$BUILD_DIR" ]; then
        read -p "Directory $BUILD_DIR already exists. Do you want to delete it? (y/n): " delete_dir
        if [ "$delete_dir" != "y" ]; then
            error_exit "Directory $BUILD_DIR already exists. Please delete it and try again."
        fi
        echo "Deleting existing directory $BUILD_DIR..."
        rm -rf "$BUILD_DIR" || error_exit "Failed to delete directory $BUILD_DIR."
    fi
    
    mkdir "$BUILD_DIR" || error_exit "Failed to create directory $BUILD_DIR."
    cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."

    echo "Downloading file docker image..."
    error_exit "TODO: change name of tar file"
    curl -L -O "https://todo.tar" || error_exit "Failed to download release."

    showSuccess "Release downloaded successfully."
}

check_gh_installation(){
    if ! command -v gh &> /dev/null; then
        error_exit "Github CLI is not installed. Please install it from https://github.com/cli/cli#installation."
    fi
}

upload_release(){
    check_gh_installation

    cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."

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
}

build=false
save=false
load=false
clean=false
download=false
upload=false

if [ $# -eq 0 ]; then
    print_help
    exit 0
else
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            build)  build=true ;;
            save) save=true ;;
            load) load=true ;;
            clean) clean=true ;;
            upload) upload=true ;;
            download) download=true ;;
            help|-h|--help) print_help; exit 0 ;;
            *) echo "Unknown parameter passed: $1"; print_help; exit 1 ;;
        esac
        shift
    done
fi

if [ "$clean" = true ]; then
    clean_docker
fi

if [ "$build" = true ]; then
    build_appwrite
fi

if [ "$save" = true ]; then
    save_appwrite_image
fi

if [ "$load" = true ]; then
    load_appwrite_image
fi

if [ "$download" = true ]; then
    download_release
fi

if [ "$upload" = true ]; then
    upload_release
fi

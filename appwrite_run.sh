#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
BUILD_DIR="docker_image_builds"
GITHUB_REPO="https://github.com/ngis-code/televolution_Backend"

showSuccess() {
    echo -e "${GREEN}$1${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e 'beep 1'
    fi
}

error_exit() {
    echo -e "${RED}$1${NC}" 1>&2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e 'beep 2'
    fi
    exit 1
}

error_continue() {
    echo -e "${RED}$1${NC}" 1>&2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e 'beep 2'
    fi
}

print_help(){
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  help, -h, --help    Display this help message"
    echo "  clean               Perform a docker clean and removes the $BUILD_DIR directory"
    echo "  save                Save the images to the $BUILD_DIR directory"
    echo "  load                Load the images from the $BUILD_DIR directory"
    echo "  build               Pulls and builds the docker image"
    echo "  download            Downloads the latest release from Github"
}

build_appwrite(){
    # METHOD 1
    # curl -L -O https://appwrite.io/install/compose appwrite/docker-compose.yml || error_exit "Failed to download docker-compose file."
    # curl -L -O https://appwrite.io/install/env appwrite/.env || error_exit "Failed to download install file."
    # cd appwrite || error_exit "Directory docker does not exist."
    # docker compose up -d --remove-orphans || error_exit "Failed to build Appwrite."
    # showSuccess "Appwrite built successfully."
    # cd ..

    # METHOD 2
    docker run -it --rm \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume "$(pwd)"/appwrite:/usr/src/code/appwrite:rw \
    --entrypoint="install" \
    appwrite/appwrite:1.5.7 || error_exit "Failed to install Appwrite."
    showSuccess "Appwrite installed successfully."
}

save_appwrite_image(){
    if [ ! -d "$BUILD_DIR" ]; then
        mkdir "$BUILD_DIR" || error_exit "Failed to create directory $BUILD_DIR."
    fi

    cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."
    
    echo "Saving Image traefik..."
    docker save -o traefik.tar traefik:2.11 || error_continue "Cannot save traefik."
    echo "Saving Image mariadb..."
    docker save -o mariadb.tar mariadb:10.11 || error_continue "Cannot save mariadb."
    echo "Saving Image php..."
    docker save -o php.tar openruntimes/php:v3-8.0 || error_continue "Cannot save php."
    echo "Saving Image python..."
    docker save -o python.tar openruntimes/python:v3-3.9 || error_continue "Cannot save python."
    echo "Saving Image node..."
    docker save -o node.tar openruntimes/node:v3-16.0 || error_continue "Cannot save node."
    echo "Saving Image ruby..."
    docker save -o ruby.tar openruntimes/ruby:v3-3.0 || error_continue "Cannot save ruby."
    echo "Saving Image appwrite..."
    docker save -o appwrite.tar appwrite/appwrite:1.5.7 || error_continue "Cannot save appwrite."
    echo "Saving Image redis..."
    docker save -o redis.tar redis:7.2.4-alpine || error_continue "Cannot save redis."
    echo "Saving Image executor..."
    docker save -o executor.tar openruntimes/executor:0.5.5 || error_continue "Cannot save executor."
    echo "Saving Image assistant..."
    docker save -o assistant.tar appwrite/assistant:0.4.0 || error_continue "Cannot save assistant."
    
    showSuccess "All Images saved successfully."
    cd ..
}

load_appwrite_image(){
    cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."

    echo "Loading Image traefik..."
    docker load -i traefik.tar || error_continue "Cannot load traefik."
    echo "Loading Image mariadb..."
    docker load -i mariadb.tar || error_continue "Cannot load mariadb."
    echo "Loading Image php..."
    docker load -i php.tar || error_continue "Cannot load php."
    echo "Loading Image python..."
    docker load -i python.tar || error_continue "Cannot load python."
    echo "Loading Image node..."
    docker load -i node.tar || error_continue "Cannot load node."
    echo "Loading Image ruby..."
    docker load -i ruby.tar || error_continue "Cannot load ruby."
    echo "Loading Image appwrite..."
    docker load -i appwrite.tar || error_continue "Cannot load appwrite."
    echo "Loading Image redis..."
    docker load -i redis.tar || error_continue "Cannot load redis."
    echo "Loading Image executor..."
    docker load -i executor.tar || error_continue "Cannot load executor."
    echo "Loading Image assistant..."
    docker load -i assistant.tar || error_continue "Cannot load assistant."

    echo "Running Appwrite..."
    if [ ! -d "appwrite" ]; then
        mkdir appwrite || error_exit "Failed to create directory appwrite."
        cd appwrite || error_exit "Directory appwrite does not exist."
        
        curl -L -O https://appwrite.io/install/compose || error_exit "Failed to download docker-compose file."
        mv compose docker-compose.yml || error_exit "Failed to rename docker-compose file."

        curl -L -O https://appwrite.io/install/env || error_exit "Failed to download install file."
        mv env .env || error_exit "Failed to rename install file."
        
        cd ..
    fi

    cd appwrite || error_exit "Directory appwrite does not exist."

    docker compose up -d || error_exit "Failed to build Appwrite."
    showSuccess "Images loaded successfully."

    cd ..
}

clean_docker(){
    docker builder prune || error_exit "Docker builder prune failed."
    # rm -rf "$BUILD_DIR" || error_exit "Failed to remove directory $BUILD_DIR."
    docker stop $(docker ps -q) || error_continue "Failed to stop all containers."
    docker rm $(docker ps -a -q) || error_continue "Failed to remove all containers."
    docker image prune -a || error_continue "Failed to remove all images."
    docker volume prune || error_continue "Failed to remove all volumes. We will retry another way to remove volumes."
    docker volume rm $(sudo docker volume ls -q) || error_continue "Failed to remove all volumes."
    # docker system prune -a || error_continue "Failed to remove all unused data."
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

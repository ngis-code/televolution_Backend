#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
BUILD_DIR="docker_image_builds"
GITHUB_REPO="https://github.com/ngis-code/televolution_Backend"
LATEST_VERSION="0.0.5"  # This is the latest release version on Github

# Initializations
export DOCKER_DEFAULT_PLATFORM=linux/amd64

showSuccess() {
    echo -e "${GREEN}$1${NC}"
    if [[ "$OSTYPE" == darwin* ]]; then
        osascript -e 'beep 1'
    fi
}

error_exit() {
    echo -e "${RED}$1${NC}" 1>&2
    if [[ "$OSTYPE" == darwin* ]]; then
        osascript -e 'beep 2'
    fi
    exit 1
}

error_continue() {
    echo -e "${RED}$1${NC}" 1>&2
    if [[ "$OSTYPE" == darwin* ]]; then
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

# Use it choose a single option
function choose_single_menu() {
    local prompt="$1" outvar="$2"
    shift
    shift
    local options=("$@") cur=0 count=${#options[@]} index=0
    local esc=$(echo -en "\e") 
    printf "$prompt\n"
    while true
    do
        index=0 
        for o in "${options[@]}"
        do
            if [ "$index" == "$cur" ]
            then echo -e " >\e[7m$o\e[0m" 
            else echo "  $o"
            fi
            (( index++ ))
        done
        read -s -n3 key 
        if [[ $key == $esc[A ]] 
        then (( cur-- )); (( cur < 0 )) && (( cur = 0 ))
        elif [[ $key == $esc[B ]] 
        then (( cur++ )); (( cur >= count )) && (( cur = count - 1 ))
        elif [[ $key == "" ]] 
        then break
        fi
        echo -en "\e[${count}A" 
    done
    printf -v $outvar "${options[$cur]}"
}

function choose_multiple_menu() {
    local prompt="$1"
    local outvar="$2"
    shift
    shift
    local options=("$@")
    local cur=0
    local count=${#options[@]}
    local index=0
    local esc=$(printf '\033')
    local selected=("${options[@]}")
    # local selected=()

    printf "$prompt\n"

    while true; do
        index=0
        for o in "${options[@]}"; do
            if [ "$index" == "$cur" ]; then
                if [[ " ${selected[@]} " =~ " ${options[$cur]} " ]]; then
                    # echo -e " >\e[7m\e[32m$o\e[0m"
                    echo -e " >${GREEN}*$o${NC}"
                else
                    # echo -e " >\e[7m$o\e[0m"
                    echo -e " > ${NC}$o${NC}"
                fi
            else
                if [[ " ${selected[@]} " =~ " ${options[$index]} " ]]; then
                    # echo -e " *\e[32m$o\e[0m"
                    echo -e "  *${GREEN}$o${NC}"
                else
                    echo "   $o"
                fi
            fi
            (( index++ ))
        done

        read -rsn1 key
        case "$key" in
            $esc)
                read -rsn2 key
                if [[ "$key" == "[A" ]]; then
                    (( cur-- ))
                    (( cur < 0 )) && (( cur = 0 ))
                elif [[ "$key" == "[B" ]]; then
                    (( cur++ ))
                    (( cur >= count )) && (( cur = count - 1 ))
                elif [[ "$key" == "[C" ]]; then
                    if [[ " ${selected[@]} " =~ " ${options[$cur]} " ]]; then
                        selected=("${selected[@]/${options[$cur]}/}")
                    else
                        selected+=("${options[$cur]}")
                    fi
                fi
                ;;
            "")
                break
                ;;
        esac

        printf "\033c"
        printf "$prompt\n"
    done

    local selected_string
    selected_string=$(printf "%s " "${selected[@]}")
    printf -v "$outvar" "%s" "$selected_string"
}

build_middleware(){
    if [ -d "televolution_Middleware" ]; then
        echo "Directory televolution_Middleware already exists."
    else
        git clone https://github.com/ngis-code/televolution_Middleware || error_exit "Git clone failed."
    fi

    cd televolution_Middleware || error_exit "Directory televolution_Middleware does not exist."
    git pull || ./update.sh "some change" || error_exit "Git pull failed."
    latestMiddlewareReleasedVersion=$(git describe --tags `git rev-list --tags --max-count=1`)
    if [ -z "$latestMiddlewareReleasedVersion" ]; then
        error_exit "Failed to get the latest middleware version."
    fi
    echo "Building version: $latestMiddlewareReleasedVersion"
    docker build -t televolution_middleware:$latestMiddlewareReleasedVersion .  || error_exit "Docker build failed."
    docker run -d --restart=always --network host -p 3000:3000 --name televolution_middleware televolution_middleware:$latestMiddlewareReleasedVersion
    if [ $? -ne 0 ]; then
        error_exit "Failed to start the middleware container."
    fi
    showSuccess "Televolution Middleware was built successfully."
    cd ..
}

build_appwrite(){
    if [ ! -d "console" ]; then
        git clone --branch working-branch --single-branch --depth=1 https://github.com/raman04-byte/console || error_exit "Git clone failed."
    fi

    cd "console"
    git pull || error_continue "Git pull failed. Continuing with old changes."
    docker build -t televolution-console . || error_exit "Failed to do compose"
    cd ..

    cd docker
    docker compose up -d || error_exit "Failed to build Appwrite."
    cd ..

    showSuccess "Appwrite built successfully."
}

build_images(){
    options=(
        "Build Appwrite"
        "Build Middleware"
    )

    choose_multiple_menu "Please select the images to build (use arrow keys to navigate and right arrow to select):" selected_images "${options[@]}"

    if [[ " ${selected_images[@]} " =~ " Build Appwrite " ]]; then
        build_appwrite
    fi

    if [[ " ${selected_images[@]} " =~ " Build Middleware " ]]; then
        build_middleware
    fi
}

save_images(){
    latestMiddlewareReleasedVersion="v0.0.1"
    
    if [ ! -d "$BUILD_DIR" ]; then
        mkdir "$BUILD_DIR" || error_exit "Failed to create directory $BUILD_DIR."
    fi

    cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."

    options=(
        "appwrite-dev:latest"
        "mariadb:10.11"
        "traefik:2.11"
        "redis:7.2.4-alpine"
        "openruntimes/executor:0.5.7"
        "appwrite/assistant:0.4.0"
        "openruntimes/php:v3-8.0"
        "openruntimes/python:v3-3.9"
        "openruntimes/node:v3-16.0"
        "openruntimes/ruby:v3-3.0"
        "appwrite/appwrite:1.5.10"
        "televolution_middleware:$latestMiddlewareReleasedVersion"
    )

    choose_multiple_menu "Please select the Docker images to save (use arrow keys to navigate and right arrow to select):" selected_images "${options[@]}"

    for image in $selected_images; do
        image_name=$(echo "$image" | cut -d':' -f1)
        image_name=$(echo "$image_name" | awk -F'/' '{print $NF}')
        echo "Saving Image $image as ${image_name}.tar ..."
        docker save -o "${image_name}.tar" "$image" || { error_continue "Cannot save $image."; continue; }
    done
    
    showSuccess "All Images saved successfully."
    cd ..
}

load_appwrite_image(){
    cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."
    options=(
        "appwrite-dev"
        "mariadb"
        "traefik"
        "redis"
        "executor"
        "assistant"
        "php"
        "python"
        "node"
        "ruby"
        "appwrite"
        "televolution_middleware"
    )
    choose_multiple_menu "Please select the Docker images to load (use arrow keys to navigate and right arrow to select):" selected_images "${options[@]}"

    for image in $selected_images; do
        echo "Loading Image $image..."
        docker load -i "${image}.tar" || { error_continue "Cannot load $image."; continue; }
    done

    cd ..

    echo "Running Backend..."

    cd docker || error_exit "Directory 'docker' does not exist."

    docker compose up -d || error_exit "Failed to start Backend."

    cd ..

    # if option has middleware
    if [[ " ${selected_images[@]} " =~ " televolution_middleware " ]]; then
        echo "Running Middleware..."
        docker run -d --restart=always --network host -p 3000:3000 --name televolution_middleware televolution_middleware:v0.0.1
        if [ $? -ne 0 ]; then
            error_exit "Failed to start the middleware container."
        fi
        showSuccess "Middleware started successfully."
    fi
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
    echo "Downloading release $LATEST_VERSION..."

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

    options=(
        "appwrite-dev"
        "mariadb"
        "traefik"
        "redis"
        "executor"
        "assistant"
        "php"
        "python"
        "node"
        "ruby"
        "appwrite"
        "televolution_middleware"
        "projectxsource-latest.zip"
    )

    choose_multiple_menu "Please select the Docker images to download (use arrow keys to navigate and right arrow to select):" selected_images "${options[@]}"

    failed_downloads=()

    for image in $selected_images; do
        download_image "$image" || failed_downloads+=("$image")
    done

    if [ ${#failed_downloads[@]} -ne 0 ]; then
        error_continue "Retrying failed downloads..."
        for failed_image in "${failed_downloads[@]}"; do
            download_image "$failed_image" || error_exit "Failed to download $failed_image again."
        done
    fi

    showSuccess "All releases downloaded successfully."
    cd ..
}

download_image() {
    image=$1
    if [ "$image" == "projectxsource-latest.zip" ]; then
        cd ..
        echo "Downloading Image $image..."
        curl -L -O "https://github.com/ngis-code/televolution_Backend/releases/download/${LATEST_VERSION}/projectxsource-latest.zip" || {
            error_continue "Failed to download $image."
            cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."
            return 1
        }
        unzip projectxsource-latest.zip || {
            error_continue "Failed to unzip $image."
            cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."
            return 1
        }
        cd "$BUILD_DIR" || error_exit "Directory $BUILD_DIR does not exist."
    else
        echo "Downloading Image $image..."
        curl -L -O "https://github.com/ngis-code/televolution_Backend/releases/download/${LATEST_VERSION}/${image}.tar" || {
            error_continue "Failed to download $image."
            return 1
        }
    fi
    return 0
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
    build_images
fi

if [ "$save" = true ]; then
    save_images
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

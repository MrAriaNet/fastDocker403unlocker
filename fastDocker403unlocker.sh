#!/usr/bin/env bash
DATABASE=fastDocker403unlocker_database_"$(date +%s)"
DATABASE_PATH=/tmp/"$DATABASE"
CONFIG_FILE=/etc/fastDocker403unlocker.conf
LOG_FILE=/tmp/fastDocker403unlocker.log
trap 'echo "\n Exiting..."; exit' SIGINT
# Functions
get_dockerimages(){
    images=$(grep 'image:' "$1" | awk '{print $2}')

    # Save the images in a variable
    images_variable=$(echo "$images" | tr '\n' ' ')

    # Output the variable
    echo "$images_variable"
}

check_and_source_env() {
    if [ ! -f "$CONFIG_FILE" ]; then
        wget -c https://raw.githubusercontent.com/ArmanTaheriGhaleTaki/fastDocker403unlocker/main/fastDocker403unlocker.conf -O "$CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

download() {
    echo analyzing "$2"
    timeout "$timeout" skopeo copy docker://"$2"/"$1" dir:/tmp/"$2"
}

download_speed() {
    du -s /tmp/"$1" >>"$DATABSE_FILE"
    rm -fr /tmp/"$1"
}

loggin(){
    echo "$(date '+%Y-%m-%d %H:%M:%S') "
    sed -i s/"\/tmp\/"//g "$DATABSE_FILE"
}

check_required_packages_is_installed(){
    if ! [ -x "$(command -v skopeo)" ]; then
        echo "skopeo is not installed" >&2
        exit 1
    fi
}

find_fast_registry(){
    check_and_source_env
    check_required_packages_is_installed
    sanitized_image_name=$(echo "$1" | sed 's/\//_/g')
    DATABSE_FILE="$DATABASE_PATH""$sanitized_image_name"
    touch "$DATABSE_FILE"
    for i in $registries; do
        download "$1" "$i"
        download_speed "$i"
    done
    BEST_REGISTRY=$(sort -rn "$DATABSE_FILE" | head -1 | cut -d'/' -f3)
    echo '******************************************************************'
    echo best docker registry for "$1" is "$BEST_REGISTRY"
    echo '******************************************************************'
    loggin >> "$LOG_FILE"
    rm -rf "$DATABSE_FILE"
}

# Execute the functions
if [ $# -lt 1 ]; then
    echo -e "Error: No argument provided.\n"
    echo -e "You need to give the image name and it's tag as argument [image]:tag like this fastdocker403unlocker nginx:alpine\n"
    echo -e "You need to give the docker compose file as argument like this fastdocker403unlocker -i docker-compose.yml\n"
    echo -e "You need to give the docker compose file as argument like this fastdocker403unlocker -i docker-compose.yml -o fast-docker-compose.yml\n"
    exit 1 # Exit with a non-zero status to indicate an error
fi

while getopts ":i:o:" opt; do
    case ${opt} in
        i )
            if [ -z "$OPTARG" ]; then
                echo "Option -i requires an argument"
                exit 1
            fi
            INPUT_NAME=$OPTARG
            ;;
        o )
            if [ -z "$OPTARG" ]; then
                echo "Option -o requires an argument"
                exit 1
            fi
            OUTPUT_NAME=$OPTARG
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            exit 1
            ;;
        : )
            echo "Invalid option: -$OPTARG requires an argument" 1>&2
            exit 1
            ;;
    esac
done

if [[ -z "$INPUT_NAME" && -n "$OUTPUT_NAME" ]]; then
    echo "Error: -i option is required when -o is set."
    exit 1
elif [[ -z "$INPUT_NAME" && -z "$OUTPUT_NAME" ]]; then
    if [[ $# -eq 1 ]]; then
        IMAGE="$1"
        echo "Processing single image: ""$IMAGE"""
        find_fast_registry "$IMAGE"

    else
        echo "Error: -i option is required when processing a docker-compose file."
        exit 1
    fi
else
    cp "$INPUT_NAME" "$OUTPUT_NAME" 2>/dev/null
fi

if [[ -n "$INPUT_NAME" ]]; then
    get_dockerimages "$INPUT_NAME"
    for image in $images_variable; do
        find_fast_registry "$image"
        if [ -n "$OUTPUT_NAME" ]; then
            sed  -i s/"$image"/"$BEST_REGISTRY"/"$image"/g "$OUTPUT_NAME"
        else
            sed  -i s/"$image"/"$BEST_REGISTRY"/"$image"/g "$INPUT_NAME"
        fi
    done
fi

# Exit if script is empty
if [ -z "$images_variable" ] && [ -z "$IMAGE" ]; then
    echo "Error: No images found to process."
    exit 1
fi

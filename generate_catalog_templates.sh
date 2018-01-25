#!/bin/bash

# First fetch the rancher/server tags
./fetch_registry_tags.sh
if [ $? -ne 0 ]; then
    echo "Error: couldn't fetch tags from registry"
    exit 1
fi



TAGS_FILE="tags.txt"


if [ ! -d output ]; then
    mkdir -p output
fi

i=10

function generate_folder_and_files() {
    folder=$1
    version=$2

    if [ -d output/$folder ]; then
        echo "directory: output/$folder already exists"
        return
    fi

    echo "Generating: output/$folder with version $version"
    mkdir -p output/$folder

    sed -e "s/__RANCHER_SERVER_VERSION__/$version/g" \
        templates/docker-compose.yml.tpl.in > output/$folder/docker-compose.yml.tpl

    sed -e "s/__RANCHER_SERVER_VERSION__/$version/g" \
        templates/rancher-compose.yml.in > output/$folder/rancher-compose.yml

    sed -e "s/__RANCHER_SERVER_VERSION__/$version/g" \
        templates/config.yml.in > output/config.yml
}


while IFS='' read -r version || [[ -n "$version" ]]; do
    generate_folder_and_files $i $version
    i=$(($i + 1))
done < ${TAGS_FILE}


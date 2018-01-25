#!/bin/bash

# References:
#   - https://success.docker.com/Cloud/Solve/How_do_I_authenticate_with_the_V2_API%3F
#   - https://stackoverflow.com/questions/32605556/how-to-find-the-creation-date-of-an-image-in-a-private-docker-registry-api-v2
#   - https://gist.github.com/alex-bender/55fefa42f47ca4e3013a8c51afa8f3d2

set -e

if [[ ("${DOCKERHUB_USERNAME}" == "") || ("${DOCKERHUB_PASSWORD}" == "") ]]; then
    echo "Please enter your docker hub credentials"
fi

if [[ "${DOCKERHUB_USERNAME}" == "" ]]; then
    read -p 'Username: ' _UNAME
else
    _UNAME=${DOCKERHUB_USERNAME}
fi


if [[ "${DOCKERHUB_PASSWORD}" == "" ]]; then
    read -sp 'Password: ' _UPASS
    printf "\n"
else
    _UPASS=${DOCKERHUB_PASSWORD}
fi

if [[ ("${DOCKERHUB_USERNAME}" == "") || ("${DOCKERHUB_PASSWORD}" == "") ]]; then
    echo "Error: couldn't get login credentials"
    exit 1
fi


# get token to be able to talk to Docker Hub
TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${_UNAME}'", "password": "'${_UPASS}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)
#echo "TOKEN=${TOKEN}"

if [[ "${TOKEN}" == "null" ]]; then
    echo "Error: Invalid login credentials"
    exit 1
fi

echo "Login successful"

TAGS_LIMIT=10000
IMAGE="rancher/server"
echo "Fetching tags for ${IMAGE}"
IMAGE_TAGS=$(curl -s -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/${IMAGE}/tags/?page_size=${TAGS_LIMIT} | jq -r '.results|.[]|.name')
#echo "${IMAGE_TAGS}"

echo "Fetching timestamps for tags"

BASE64_AUTH=$(echo -n "${_UNAME}:${_UPASS}" | base64)
#echo ${BASE64_AUTH}
BEARER_TOKEN=`curl -s -H "Authorization: Basic ${BASE64_AUTH}" 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:rancher/server:pull' | jq -r .token`
#echo "BEARER_TOKEN=${BEARER_TOKEN}"

getTimestampForTag() {
    local TAG="$1"
    curl -s -X GET \
        -H "Authorization: Bearer ${BEARER_TOKEN}" \
        https://index.docker.io/v2/rancher/server/manifests/${TAG} | \
    jq -r '[.history[]]|map(.v1Compatibility|fromjson|.created)|sort|reverse|.[0]'
}

RESULT=""
for aTag in ${IMAGE_TAGS}; do
    echo "${aTag}" | grep -q "v1.2\|v1.3|v1.4"
    if [ $? -eq 0 ]; then
        continue
    fi
    aTagTS=$(getTimestampForTag ${aTag})
    #echo "${aTagTS}    ${aTag}"
    RESULT=$(echo -e "${RESULT}"; printf "${aTagTS} ${aTag}\n")
done

TAGS_FILE="tags.txt"
echo "$RESULT" | sort -u | awk '{print $2}' | grep -v "latest\|master\|stable" > ${TAGS_FILE}
echo "Saved tags to ${TAGS_FILE}"
exit 0

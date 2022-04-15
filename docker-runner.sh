#!/bin/bash

#
# Copyright 2019, 2020, 2021 Mani Sarkar
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e
set -u
set -o pipefail

findImage() {
	IMAGE_NAME=$1
	echo $(docker images ${IMAGE_NAME} -q | head -n1 || true)
}

getOpenCommand() {
  if [[ "$(uname)" = "Linux" ]]; then
     echo "xdg-open"
  elif [[ "$(uname)" = "Darwin" ]]; then
     echo "open"
  fi
}

runContainer() {
	askDockerUserNameIfAbsent
	setVariables

	## When run in the console mode (command-prompt available)
	TOGGLE_ENTRYPOINT=""
	VOLUMES_SHARED="--volume "$(pwd)":${WORKDIR}/work --volume "$(pwd)"/shared:${WORKDIR}/shared"

	echo "";
	echo "Running container ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION}"; echo ""

	pullImage chatbot
	time docker run                                      \
	            --rm                                           \
                ${INTERACTIVE_MODE}                            \
                ${TOGGLE_ENTRYPOINT}                           \
                -p ${HOST_PORT}:${CONTAINER_PORT}              \
                --workdir ${WORKDIR}                           \
                --env JDK_TO_USE=${JDK_TO_USE:-}               \
                --env JAVA_OPTS=${JAVA_OPTS:-}                 \
                ${VOLUMES_SHARED}                              \
                "${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION}"
}

buildImage() {
	askDockerUserNameIfAbsent
	setVariables
	
	echo "Building image ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION}"; echo ""

	echo "* Fetching Chatbot docker image ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION} from Docker Hub"
	time docker pull ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION} || true
	time docker build                                                   \
	             --build-arg WORKDIR=${WORKDIR}                         \
	             --build-arg JAVA_11_HOME="/opt/java/openjdk"           \
	             --build-arg GRAALVM_HOME="/opt/java/graalvm"           \
	             --build-arg IMAGE_VERSION=${IMAGE_VERSION}             \
	             --build-arg CHATBOT_VERSION=${CHATBOT_VERSION}         \
                 --build-arg GRAALVM_VERSION=${GRAALVM_VERSION}         \
                 --build-arg GRAALVM_JDK_VERSION=${GRAALVM_JDK_VERSION} \
	             -t ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION} \
	             "${IMAGES_DIR}/."
	echo "* Finished building Chatbot docker image ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION}"
	
	cleanup
	pushImageToHub
	cleanup
}

pushImage() {
	IMAGE_NAME="chatbot"
	IMAGE_VERSION=$(cat docker-image/version.txt)
	FULL_DOCKER_TAG_NAME="${DOCKER_USER_NAME}/${IMAGE_NAME}"

	IMAGE_FOUND="$(findImage ${FULL_DOCKER_TAG_NAME})"
	IS_FOUND="found"
	if [[ -z "${IMAGE_FOUND}" ]]; then
		IS_FOUND="not found"        
	fi
	echo "Docker image '${DOCKER_USER_NAME}/${IMAGE_NAME}' is ${IS_FOUND} in the local repository"

	docker tag ${IMAGE_FOUND} ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION}
	docker push ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION}
}

pullImage() {
	IMAGE_NAME="chatbot"
	IMAGE_VERSION=$(cat docker-image/version.txt)
	FULL_DOCKER_TAG_NAME="${DOCKER_USER_NAME}/${IMAGE_NAME}"
	
	docker pull ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION} || true
}


pushImageToHub() {
	askDockerUserNameIfAbsent
	setVariables

	echo "Pushing image ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION} to Docker Hub"; echo ""

	docker login --username=${DOCKER_USER_NAME}
	pushImage chatbot
}

pullImageFromHub() {
	askDockerUserNameIfAbsent
	setVariables

	echo "Pulling image ${FULL_DOCKER_TAG_NAME}:${IMAGE_VERSION} from Docker Hub"; echo ""

	pullImage chatbot
}


cleanup() {
	containersToRemove=$(docker ps --quiet --filter "status=exited")
	[ ! -z "${containersToRemove}" ] && \
	    echo "Remove any stopped container from the local registry" && \
	    docker rm ${containersToRemove} || true

	imagesToRemove=$(docker images --quiet --filter "dangling=true")
	[ ! -z "${imagesToRemove}" ] && \
	    echo "Remove any dangling images from the local registry" && \
	    docker rmi -f ${imagesToRemove} || true
}

showUsageText() {
    cat << HEREDOC

       Usage: $0 --dockerUserName [Docker user name]
                                 --detach
                                 --jdk [GRAALVM]
                                 --javaopts [java opt arguments]
                                 --hostport [1024-65535]
                                 --cleanup
                                 --buildImage
                                 --runContainer
                                 --pushImageToHub
                                 --pullImageFromHub								 
                                 --help

       --dockerUserName      your Docker user name as on Docker Hub
                             (mandatory with build, run and push commands)
       --detach              run container and detach from it,
                             return control to console
       --jdk                 name of the JDK to use (currently supports
                             GRAALVM only, default is blank which
                             enables the traditional JDK)
       --javaopts            sets the JAVA_OPTS environment variable
                             inside the container as it starts
       --hostport            specify an available port between 0 and 65535,
                             handy when running multiple Jupyter sessions.
                             (default: 8080)
       --cleanup             (command action) remove exited containers and
                             dangling images from the local repository
       --buildImage          (command action) build the docker image
       --runContainer        (command action) run the docker image as a docker container
       --pushImageToHub      (command action) push the docker image built to Docker Hub
       --pullImageFromHub    (command action) pull the latest docker image from Docker Hub	   
       --help                shows the script usage help text

HEREDOC

	exit 1
}

askDockerUserNameIfAbsent() {
	if [[ -z ${DOCKER_USER_NAME:-""} ]]; then
	  read -p "Enter Docker username (must exist on Docker Hub): " DOCKER_USER_NAME
	fi	
}

setVariables() {
	IMAGE_NAME=${IMAGE_NAME:-chatbot}
	IMAGE_VERSION=${IMAGE_VERSION:-$(cat docker-image/version.txt)}
	CHATBOT_VERSION=${CHATBOT_VERSION:-$(cat docker-image/chatbot_version.txt)}
	GRAALVM_VERSION=${GRAALVM_VERSION:-$(cat docker-image/graalvm_version.txt)}
	GRAALVM_JDK_VERSION=${GRAALVM_JDK_VERSION:-$(cat docker-image/graalvm_jdk_version.txt)}
	FULL_DOCKER_TAG_NAME="${DOCKER_USER_NAME}/${IMAGE_NAME}"
}

#### Start of script
SCRIPT_CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="${SCRIPT_CURRENT_DIR}/docker-image"

FULL_DOCKER_TAG_NAME=""
DOCKER_USER_NAME="${DOCKER_USER_NAME:-neomatrix369}"

WORKDIR=/home/jovyan
JDK_TO_USE="GRAALVM"  ### we are defaulting to GraalVM

INTERACTIVE_MODE="--interactive --tty"
TIME_IT="time"

HOST_PORT=8080
CONTAINER_PORT=8080

if [[ "$#" -eq 0 ]]; then
	echo "No parameter has been passed. Please see usage below:"
	showUsageText
fi

while [[ "$#" -gt 0 ]]; do case $1 in
  --help)                showUsageText;
                         exit 0;;
  --cleanup)             cleanup;
                         exit 0;;
  --dockerUserName)      DOCKER_USER_NAME="${2:-}";
                         shift;;
  --detach)              INTERACTIVE_MODE="--detach";
                         TIME_IT="";;
  --jdk)                 JDK_TO_USE="${2:-}";
                         shift;;
  --javaopts)            JAVA_OPTS="${2:-}";
                         shift;;
  --hostport)            HOST_PORT=${2:-${HOST_PORT}};
                         shift;;
  --buildImage)          buildImage;
                         exit 0;;
  --runContainer)        runContainer;
                         exit 0;;
  --pushImageToHub)      pushImageToHub;
                         exit 0;;
  --pullImageFromHub)    pullImageFromHub;
                         exit 0;;
  *) echo "Unknown parameter passed: $1";
     showUsageText;
esac; shift; done

if [[ "$#" -eq 0 ]]; then
	echo "No command action passed in as parameter. Please see usage below:"
	showUsageText
fi
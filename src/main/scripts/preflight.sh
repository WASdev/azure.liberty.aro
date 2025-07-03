#!/bin/bash

#      Copyright (c) Microsoft Corporation.
#      Copyright (c) IBM Corporation. 
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#           http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

set -Euo pipefail

# Test Azure CLI authentication
echo "Testing Azure CLI authentication..."
az account show > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Azure CLI authentication test failed. Attempting to authenticate with managed identity..."
    az login --identity
    if [ $? -ne 0 ]; then
        echo "Failed to authenticate with managed identity." >&2
        exit 1
    fi
fi
echo "Azure CLI authentication successful."
# Check if image specified by SOURCE_IMAGE_PATH is publically accessible and supports amd64 architecture
if [[ "${DEPLOY_APPLICATION,,}" == "true" ]]; then
  # Install docker-cli to inspect the image
  apk update
  apk add docker-cli
  export DOCKER_CLI_EXPERIMENTAL=enabled
  docker manifest inspect $SOURCE_IMAGE_PATH > inspect_output.txt 2>&1
  if [ $? -ne 0 ]; then
    echo "Failed to inspect image $SOURCE_IMAGE_PATH." $(cat inspect_output.txt) >&2
    exit 1
  else
    arches=$(cat inspect_output.txt | jq -r '.manifests[].platform.architecture')
    if echo "$arches" | grep -q '^amd64$'; then
      echo "Image $SOURCE_IMAGE_PATH supports amd64 architecture." $(cat inspect_output.txt)
    else
      echo "Image $SOURCE_IMAGE_PATH does not support amd64 architecture." $(cat inspect_output.txt) >&2
      exit 1
    fi
  fi
fi

if [[ "${CREATE_CLUSTER,,}" == "true" ]]; then
  # Fail fast the deployment if object Id of the service principal is empty
  if [[ -z "$AAD_OBJECT_ID" ]]; then
    echo "The object Id of the service principal you just created is not successfully retrieved, please retry another deployment using its client id ${AAD_CLIENT_ID}." >&2
    exit 1
  fi

  # Wait 60s for service principal available after creation
  # See https://github.com/WASdev/azure.liberty.aro/issues/59 & https://github.com/WASdev/azure.liberty.aro/issues/79
  sleep 60
fi

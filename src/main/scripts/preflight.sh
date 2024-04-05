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

set -Eeuo pipefail

if [[ "${CREATE_CLUSTER,,}" == "true" ]]; then
  # Fail fast the deployment if object Id of the service principal is empty
  if [[ -z "$AAD_OBJECT_ID" ]]; then
    echo "The object Id of the service principal you just created is not successfully retrieved, please retry another deployment using its client id ${AAD_CLIENT_ID}." >&2
    exit 1
  fi

  # Wait 30s for service principal available after creation
  # See https://github.com/WASdev/azure.liberty.aro/issues/59 & https://github.com/WASdev/azure.liberty.aro/issues/79
  sleep 30
fi

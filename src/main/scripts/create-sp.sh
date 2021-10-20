#!/bin/bash

#      Copyright (c) Microsoft Corporation.
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

# Create client application and service principal
app=$(az ad app create --display-name ${AAD_CLIENT_NAME} --password ${AAD_CLIENT_SECRET})
if [[ $? != 0 ]]; then
  echo "Failed to register application ${AAD_CLIENT_NAME}." >&2
  exit 1
fi
appClientId=$(echo $app | jq -r '.appId')

az ad sp create --id ${appClientId}
if [[ $? != 0 ]]; then
  echo "Failed to create service principal for ${appClientId}." >&2
  exit 1
fi

# Get service principal object IDs
appSpObjectId=$(az ad sp show --id ${appClientId} --query 'objectId' -o tsv)
if [[ $? != 0 ]]; then
  echo "Failed to get service principal object ID for ${appClientId}."
  exit 1
fi
aroRpSpObjectId=$(az ad sp list --display-name "Azure Red Hat OpenShift RP" --query '[0].objectId' -o tsv)
if [[ $? != 0 ]]; then
  echo "Failed to get service principal object ID for \"Azure Red Hat OpenShift RP\"."
  exit 1
fi

# Write outputs to deployment script output path
result=$(jq -n -c --arg appClientId "$appClientId" '{appClientId: $appClientId}')
result=$(echo "$result" | jq --arg appSpObjectId "$appSpObjectId" '{"appSpObjectId": $appSpObjectId} + .')
result=$(echo "$result" | jq --arg aroRpSpObjectId "$aroRpSpObjectId" '{"aroRpSpObjectId": $aroRpSpObjectId} + .')
echo $result > $AZ_SCRIPTS_OUTPUT_PATH

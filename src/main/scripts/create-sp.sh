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

# Get the type of managed identity
uamiType=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "type" -o tsv)
if [ $? == 1 ]; then
    echo "The user-assigned managed identity may not exist or has no access to the subscription, please check ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}" >&2
    exit 1
fi

# Check if the managed identity is a user-assigned managed identity
if [[ "${uamiType}" != "Microsoft.ManagedIdentity/userAssignedIdentities" ]]; then
    echo "You must select a user-assigned managed identity instead of other types, please check ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}" >&2
    exit 1
fi

# Query principal Id of the user-assigned managed identity
principalId=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "principalId" -o tsv)

# Check if the user assigned managed identity has Contributor or Owner role
roleLength=$(az role assignment list --assignee ${principalId} | jq '.[] | [select(.roleDefinitionName=="Contributor" or .roleDefinitionName=="Owner")] | length')
if [ ${roleLength} -lt 1 ]; then
    echo "The user-assigned managed identity must has Contributor or Owner role in the subscription, please check ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}" >&2
    exit 1
fi

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
  echo "Failed to get service principal object ID for ${appClientId}." >&2
  exit 1
fi
aroRpSpObjectId=$(az ad sp list --display-name "Azure Red Hat OpenShift RP" --query '[0].objectId' -o tsv)
if [[ $? != 0 ]]; then
  echo "Failed to get service principal object ID for \"Azure Red Hat OpenShift RP\"." >&2
  exit 1
fi

# Write outputs to deployment script output path
result=$(jq -n -c --arg appClientId "$appClientId" '{appClientId: $appClientId}')
result=$(echo "$result" | jq --arg appSpObjectId "$appSpObjectId" '{"appSpObjectId": $appSpObjectId} + .')
result=$(echo "$result" | jq --arg aroRpSpObjectId "$aroRpSpObjectId" '{"aroRpSpObjectId": $aroRpSpObjectId} + .')
echo $result > $AZ_SCRIPTS_OUTPUT_PATH

#!/usr/bin/env bash
# Copyright (c) IBM Corporation.
# Copyright (c) Microsoft Corporation.

set -Eeuo pipefail

CURRENT_FILE_NAME="azure-credential-setup.sh"
echo "Execute $CURRENT_FILE_NAME - Start------------------------------------------"

## Create Azure Credentials
REPO_NAME=$(basename `git rev-parse --show-toplevel`)
AZURE_CREDENTIALS_SP_NAME="sp-${REPO_NAME}-$(date +%s)"
echo "Creating Azure Service Principal with name: $AZURE_CREDENTIALS_SP_NAME"
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv| tr -d '\r\n')
AZURE_CREDENTIALS=$(az ad sp create-for-rbac --name "$AZURE_CREDENTIALS_SP_NAME" --role owner --scopes /subscriptions/"$AZURE_SUBSCRIPTION_ID" --sdk-auth)
echo "Azure Credentials created successfully"
SP_ID=$(az ad sp list --display-name $AZURE_CREDENTIALS_SP_NAME --query [0].id -o tsv)
az rest -m POST \
  --uri 'https://graph.microsoft.com/v1.0/directoryRoles/roleTemplateId=9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3/members/$ref' \
  --body "{\"@odata.id\":\"https://graph.microsoft.com/v1.0/directoryObjects/${SP_ID}\"}"

## Set the Azure Credentials as a secret in the repository
gh --repo ${PARAM_USER_NAME}/azure.liberty.aro secret set "AZURE_CREDENTIALS" -b"${AZURE_CREDENTIALS}"
gh --repo ${PARAM_USER_NAME}/azure.liberty.aro variable set "AZURE_CREDENTIALS_SP_NAME" -b"${AZURE_CREDENTIALS_SP_NAME}"

echo "Execute $CURRENT_FILE_NAME - End--------------------------------------------"

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

wait_subscription_created() {
    subscriptionName=$1
    namespaceName=$2
    logFile=$3

    oc get packagemanifests -n openshift-marketplace | grep -q ${subscriptionName}
    while [ $? -ne 0 ]
    do
        echo "Wait until the Operator ${subscriptionName} is available to the cluster from OperatorHub..." >> $logFile
        sleep 5
        oc get packagemanifests -n openshift-marketplace | grep -q ${subscriptionName}
    done

    oc apply -f open-liberty-operator-subscription.yaml >> $logFile
    while [ $? -ne 0 ]
    do
        echo "Failed to create subscription ${subscriptionName}, retry..." >> $logFile
        sleep 5
        oc apply -f open-liberty-operator-subscription.yaml >> $logFile
    done

    oc get subscription ${subscriptionName} -n ${namespaceName}
    while [ $? -ne 0 ]
    do
        echo "Wait until the subscription ${subscriptionName} is created..." >> $logFile
        sleep 5
        oc get subscription ${subscriptionName} -n ${namespaceName}
    done
    echo "Subscription ${subscriptionName} created." >> $logFile
}

wait_deployment_complete() {
    deploymentName=$1
    namespaceName=$2
    logFile=$3

    oc get deployment ${deploymentName} -n ${namespaceName}
    while [ $? -ne 0 ]
    do
        echo "Wait until the deployment ${deploymentName} created..." >> $logFile
        sleep 5
        oc get deployment ${deploymentName} -n ${namespaceName}
    done
    read -r -a replicas <<< `oc get deployment ${deploymentName} -n ${namespaceName} -o=jsonpath='{.spec.replicas}{" "}{.status.readyReplicas}{" "}{.status.availableReplicas}{" "}{.status.updatedReplicas}{"\n"}'`
    while [[ ${#replicas[@]} -ne 4 || ${replicas[0]} != ${replicas[1]} || ${replicas[1]} != ${replicas[2]} || ${replicas[2]} != ${replicas[3]} ]]
    do
        # Delete pods in ImagePullBackOff status
        podIds=`oc get pod -n ${namespaceName} | grep ImagePullBackOff | awk '{print $1}'`
        read -r -a podIds <<< `echo $podIds`
        for podId in "${podIds[@]}"
        do
            echo "Delete pod ${podId} in ImagePullBackOff status" >> $logFile
            oc delete pod ${podId} -n ${namespaceName}
        done

        sleep 5
        echo "Wait until the deployment ${deploymentName} completes..." >> $logFile
        read -r -a replicas <<< `oc get deployment ${deploymentName} -n ${namespaceName} -o=jsonpath='{.spec.replicas}{" "}{.status.readyReplicas}{" "}{.status.availableReplicas}{" "}{.status.updatedReplicas}{"\n"}'`
    done
    echo "Deployment ${deploymentName} completed." >> $logFile
}

clusterRGName=$1
clusterName=$2
projMgrUsername=$3
projMgrPassword=$4
scriptLocation=$5
deployApplication=$6
sourceImagePath=$7
export Application_Name=$8
export Project_Name=$9
export Application_Image=${10}
export Application_Replicas=${11}
logFile=deployment.log

# Install utilities
apk update
apk add gettext
apk add apache2-utils

# Install the OpenShift CLI
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz -P ~
mkdir ~/openshift
tar -zxvf ~/openshift-client-linux.tar.gz -C ~/openshift
echo 'export PATH=$PATH:~/openshift' >> ~/.bash_profile && source ~/.bash_profile

# Sign in to cluster
credentials=$(az aro list-credentials -g $clusterRGName -n $clusterName  -o json)
kubeadminUsername=$(echo $credentials | jq -r '.kubeadminUsername')
kubeadminPassword=$(echo $credentials | jq -r '.kubeadminPassword')
apiServerUrl=$(az aro show -g $clusterRGName -n $clusterName --query 'apiserverProfile.url' -o tsv)
consoleUrl=$(az aro show -g $clusterRGName -n $clusterName --query 'consoleProfile.url' -o tsv)
oc login -u $kubeadminUsername -p $kubeadminPassword --server="$apiServerUrl" >> $logFile

# Install Open Liberty Operator V0.7.0
wait_subscription_created open-liberty-certified openshift-operators ${logFile}
wait_deployment_complete open-liberty-operator openshift-operators ${logFile}

# Configure an HTPasswd identity provider
oc get secret htpass-secret -n openshift-config
if [ $? -ne 0 ]; then
    htpasswd -c -B -b users.htpasswd $projMgrUsername $projMgrPassword
    oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config >> $logFile
else
    oc get secret htpass-secret -ojsonpath={.data.htpasswd} -n openshift-config | base64 -d > users.htpasswd
    htpasswd -bB users.htpasswd $projMgrUsername $projMgrPassword
    oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd --dry-run=client -o yaml -n openshift-config | oc replace -f - >> $logFile
fi
oc apply -f htpasswd-cr.yaml >> $logFile

# Configure built-in container registry
oc project openshift-image-registry
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
oc policy add-role-to-user registry-viewer $projMgrUsername
oc policy add-role-to-user registry-editor $projMgrUsername
registryHost=$(oc get route default-route --template='{{ .spec.host }}')
echo "registryHost: $registryHost" >> $logFile

# Create a new project and grant its admin role to the user
oc new-project $Project_Name
oc project $Project_Name
oc adm policy add-role-to-user admin $projMgrUsername

# Get access token of the user
oc logout
sleep 10
oc login -u $projMgrUsername -p $projMgrPassword --server="$apiServerUrl"
while [ $? -ne 0 ]
do
    echo "Login failed, retry..." >> $logFile
    sleep 5
    oc login -u $projMgrUsername -p $projMgrPassword --server="$apiServerUrl"
done
registryUsername=$(oc whoami)
registryPassword=$(oc whoami -t)
echo "registryUsername: $registryUsername" >> $logFile

# Build application image or use default base image
if [ "$deployApplication" = True ]; then
    # Create vm to build docker image
    vmName="VM-UBUNTU-IMAGE-BUILDER-$(date +%s)"
    vmGroupName=${Application_Name}-$(date +%s)
    vmRegion=$(az aro show -g $clusterRGName -n $clusterName --query 'location' -o tsv)

    az group create -n ${vmGroupName} -l ${vmRegion}
    echo "VM group created at $(date)." >> $logFile

    az vm create \
    --resource-group ${vmGroupName} \
    --name ${vmName} \
    --image "Canonical:UbuntuServer:18.04-LTS:latest" \
    --admin-username azureuser \
    --generate-ssh-keys \
    --nsg-rule NONE \
    --enable-agent true \
    --vnet-name ${vmName}VNET \
    --enable-auto-update false \
    --tags SkipASMAzSecPack=true SkipNRMSCorp=true SkipNRMSDatabricks=true SkipNRMSDB=true SkipNRMSHigh=true SkipNRMSMedium=true SkipNRMSRDPSSH=true SkipNRMSSAW=true SkipNRMSMgmt=true --verbose
    echo "VM created and vm extension execution started at $(date)." >> $logFile

    az vm extension set --name CustomScript \
    --extension-instance-name liberty-aro-image-script \
    --resource-group ${vmGroupName} \
    --vm-name ${vmName} \
    --publisher Microsoft.Azure.Extensions \
    --version 2.0 \
    --settings "{\"fileUris\": [\"${scriptLocation}import-image.sh\"]}" \
    --protected-settings "{\"commandToExecute\":\"bash import-image.sh \'${sourceImagePath}\' ${registryHost} ${registryUsername} ${registryPassword} ${Project_Name} ${Application_Image}\"}"
    echo "VM extension execution completed and start to delete vm at $(date)." >> $logFile

    az group delete -n ${vmGroupName} -y
    echo "VM deleted at $(date)." >> $logFile

    # Deploy open liberty application
    envsubst < "open-liberty-application.yaml.template" > "open-liberty-application.yaml"
    appDeploymentYaml=$(cat open-liberty-application.yaml | base64)
    oc apply -f open-liberty-application.yaml >> $logFile

    # Wait until the application deployment completes
    oc project ${Project_Name}
    wait_deployment_complete ${Application_Name} ${Project_Name} ${logFile}

    # Get the host of the route to visit the deployed application
    oc get route ${Application_Name}
    while [ $? -ne 0 ]
    do
        sleep 5
        oc get route ${Application_Name}
    done
    appEndpoint=$(oc get route ${Application_Name} --template='{{ .spec.host }}')
fi

# Write outputs to deployment script output path
result=$(jq -n -c --arg consoleUrl $consoleUrl '{consoleUrl: $consoleUrl}')
result=$(echo "$result" | jq --arg containerRegistryUrl "$registryHost" '{"containerRegistryUrl": $containerRegistryUrl} + .')
if [ "$deployApplication" = True ]; then
    result=$(echo "$result" | jq --arg appDeploymentYaml "$appDeploymentYaml" '{"appDeploymentYaml": $appDeploymentYaml} + .')
    result=$(echo "$result" | jq --arg appEndpoint "$appEndpoint" '{"appEndpoint": $appEndpoint} + .')
fi
echo "Result is: $result" >> $logFile
echo $result > $AZ_SCRIPTS_OUTPUT_PATH

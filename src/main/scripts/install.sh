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

# See https://github.com/WASdev/azure.liberty.aro/issues/60
MAX_RETRIES=299

wait_login_complete() {
    username=$1
    password=$2
    apiServerUrl="$3"
    logFile=$4

    cnt=0
    oc login -u $username -p $password --server="$apiServerUrl" >> $logFile 2>&1
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Login failed with ${username}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc login -u $username -p $password --server="$apiServerUrl" >> $logFile 2>&1
    done
}

wait_subscription_created() {
    subscriptionName=$1
    namespaceName=$2
    logFile=$3

    cnt=0
    oc get packagemanifests -n openshift-marketplace | grep -q ${subscriptionName}
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to get the operator package manifest ${subscriptionName} from OperatorHub, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get packagemanifests -n openshift-marketplace | grep -q ${subscriptionName}
    done

    cnt=0
    oc apply -f open-liberty-operator-subscription.yaml >> $logFile
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Failed to create the operator subscription ${subscriptionName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc apply -f open-liberty-operator-subscription.yaml >> $logFile
    done

    cnt=0
    oc get subscription ${subscriptionName} -n ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to get the operator subscription ${subscriptionName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get subscription ${subscriptionName} -n ${namespaceName} 2>/dev/null
    done
    echo "Subscription ${subscriptionName} created." >> $logFile
}

wait_deployment_complete() {
    deploymentName=$1
    namespaceName=$2
    logFile=$3

    cnt=0
    oc get deployment ${deploymentName} -n ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to get the deployment ${deploymentName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get deployment ${deploymentName} -n ${namespaceName} 2>/dev/null
    done

    cnt=0
    read -r -a replicas <<< `oc get deployment ${deploymentName} -n ${namespaceName} -o=jsonpath='{.spec.replicas}{" "}{.status.readyReplicas}{" "}{.status.availableReplicas}{" "}{.status.updatedReplicas}{"\n"}'`
    while [[ ${#replicas[@]} -ne 4 || ${replicas[0]} != ${replicas[1]} || ${replicas[1]} != ${replicas[2]} || ${replicas[2]} != ${replicas[3]} ]]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        # Delete pods in ImagePullBackOff status
        podIds=`oc get pod -n ${namespaceName} | grep ImagePullBackOff | awk '{print $1}'`
        read -r -a podIds <<< `echo $podIds`
        for podId in "${podIds[@]}"
        do
            echo "Delete pod ${podId} in ImagePullBackOff status" >> $logFile
            oc delete pod ${podId} -n ${namespaceName}
        done

        sleep 5
        echo "Wait until the deployment ${deploymentName} completes, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        read -r -a replicas <<< `oc get deployment ${deploymentName} -n ${namespaceName} -o=jsonpath='{.spec.replicas}{" "}{.status.readyReplicas}{" "}{.status.availableReplicas}{" "}{.status.updatedReplicas}{"\n"}'`
    done
    echo "Deployment ${deploymentName} completed." >> $logFile
}

wait_project_created() {
    projectName=$1
    logFile=$2

    cnt=0
    oc new-project ${projectName} 2>/dev/null
    oc get project ${projectName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to create the project ${projectName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc new-project ${projectName} 2>/dev/null
        oc get project ${projectName} 2>/dev/null
    done
}

wait_image_imported() {
    appImage=$1
    sourceImagePath=$2
    projectName=$3
    logFile=$4

    cnt=0
    oc import-image ${appImage} --from=${sourceImagePath} --namespace ${projectName} --reference-policy=local --confirm 2>/dev/null
    oc get imagestreamtag ${appImage} --namespace ${projectName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to import source image ${sourceImagePath}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc import-image ${appImage} --from=${sourceImagePath} --namespace ${projectName} --reference-policy=local --confirm 2>/dev/null
        oc get imagestreamtag ${appImage} --namespace ${projectName} 2>/dev/null
    done
}

wait_route_available() {
    routeName=$1
    namespaceName=$2
    logFile=$3

    cnt=0
    oc get route ${routeName} -n ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to get the route ${routeName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc get route ${routeName} -n ${namespaceName} 2>/dev/null
    done
}

clusterRGName=$1
clusterName=$2
scriptLocation=$3
deployApplication=$4
sourceImagePath=$5
export Application_Name=$6
export Project_Name=$7
export Application_Image=$8
export Application_Replicas=$9
logFile=deployment.log

# Install utilities
apk update
apk add gettext
apk add apache2-utils

# Install the OpenShift CLI
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz -q -P ~
mkdir ~/openshift
tar -zxvf ~/openshift-client-linux.tar.gz -C ~/openshift
echo 'export PATH=$PATH:~/openshift' >> ~/.bash_profile && source ~/.bash_profile

# Sign in to cluster
credentials=$(az aro list-credentials -g $clusterRGName -n $clusterName -o json)
kubeadminUsername=$(echo $credentials | jq -r '.kubeadminUsername')
kubeadminPassword=$(echo $credentials | jq -r '.kubeadminPassword')
apiServerUrl=$(az aro show -g $clusterRGName -n $clusterName --query 'apiserverProfile.url' -o tsv)
consoleUrl=$(az aro show -g $clusterRGName -n $clusterName --query 'consoleProfile.url' -o tsv)
wait_login_complete $kubeadminUsername $kubeadminPassword "$apiServerUrl" $logFile
if [[ $? -ne 0 ]]; then
  echo "Failed to sign into the cluster with ${kubeadminUsername}." >&2
  exit 1
fi

# Install Open Liberty Operator
wait_subscription_created open-liberty-certified openshift-operators ${logFile}
if [[ $? -ne 0 ]]; then
  echo "Failed to install the Open Liberty Operator from the OperatorHub." >&2
  exit 1
fi
wait_deployment_complete olo-controller-manager openshift-operators ${logFile}
if [[ $? -ne 0 ]]; then
  echo "The Open Liberty Operator is not available." >&2
  exit 1
fi

# Create a new project for managing workload of the user
wait_project_created $Project_Name ${logFile}
if [[ $? -ne 0 ]]; then
  echo "Failed to create project ${Project_Name}." >&2
  exit 1
fi
oc project $Project_Name

# Deploy application image if it's requested by the user
if [ "$deployApplication" = True ]; then
    # Import container image to the built-in container registry of the OpenShift cluster
    wait_image_imported ${Application_Image} ${sourceImagePath} ${Project_Name} ${logFile}
    if [[ $? != 0 ]]; then
        echo "Unable to import source image ${sourceImagePath} to the built-in container registry of the OpenShift cluster. Please check if it's a public image and the source image path is correct" >&2
        exit 1
    fi

    # Deploy open liberty application and output its base64 encoded deployment yaml file content
    envsubst < "open-liberty-application.yaml.template" > "open-liberty-application.yaml"
    appDeploymentYaml=$(cat open-liberty-application.yaml | base64)
    oc apply -f open-liberty-application.yaml >> $logFile

    # Wait until the application deployment completes
    wait_deployment_complete ${Application_Name} ${Project_Name} ${logFile}
    if [[ $? != 0 ]]; then
        echo "The OpenLibertyApplication ${Application_Name} is not available." >&2
        exit 1
    fi

    # Get the host of the route to visit the deployed application
    wait_route_available ${Application_Name} ${Project_Name} $logFile
    if [[ $? -ne 0 ]]; then
        echo "The route ${Application_Name} is not available." >&2
        exit 1
    fi
    appEndpoint=$(oc get route ${Application_Name} --namespace ${Project_Name} --template='{{ .spec.host }}')
else
    # Output base64 encoded deployment template yaml file content
    appDeploymentYaml=$(cat open-liberty-application.yaml.template | sed -e "s/\${Project_Name}/${Project_Name}/g" -e "s/\${Application_Replicas}/${Application_Replicas}/g" | base64)
fi

# Write outputs to deployment script output path
result=$(jq -n -c --arg consoleUrl $consoleUrl '{consoleUrl: $consoleUrl}')
result=$(echo "$result" | jq --arg appDeploymentYaml "$appDeploymentYaml" '{"appDeploymentYaml": $appDeploymentYaml} + .')
if [ "$deployApplication" = True ]; then
    result=$(echo "$result" | jq --arg appEndpoint "$appEndpoint" '{"appEndpoint": $appEndpoint} + .')
fi
echo "Result is: $result" >> $logFile
echo $result > $AZ_SCRIPTS_OUTPUT_PATH

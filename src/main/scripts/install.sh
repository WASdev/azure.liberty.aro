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
    deploymentYaml=$3
    logFile=$4

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
    oc apply -f ${deploymentYaml} >> $logFile
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Failed to create the operator subscription ${subscriptionName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc apply -f ${deploymentYaml} >> $logFile
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

wait_resource_applied() {
    resourceYamlName=$1
    logFile=$2

    cnt=0
    oc apply -f $resourceYamlName >> $logFile
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Failed to apply the resource YAML file ${resourceYamlName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc apply -f $resourceYamlName >> $logFile
    done
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
    namespaceName=$1
    logFile=$2

    cnt=0
    oc new-project ${namespaceName} 2>/dev/null
    oc get project ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to create the project ${namespaceName}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc new-project ${namespaceName} 2>/dev/null
        oc get project ${namespaceName} 2>/dev/null
    done
}

wait_image_imported() {
    appImage=$1
    sourceImagePath=$2
    namespaceName=$3
    logFile=$4

    cnt=0
    oc import-image ${appImage} --from=${sourceImagePath} --namespace ${namespaceName} --reference-policy=local --confirm 2>/dev/null
    oc get imagestreamtag ${appImage} --namespace ${namespaceName} 2>/dev/null
    while [ $? -ne 0 ]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))

        echo "Unable to import source image ${sourceImagePath}, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        sleep 5
        oc import-image ${appImage} --from=${sourceImagePath} --namespace ${namespaceName} --reference-policy=local --confirm 2>/dev/null
        oc get imagestreamtag ${appImage} --namespace ${namespaceName} 2>/dev/null
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

    cnt=0
    appEndpoint=$(oc get route ${routeName} -n ${namespaceName} -o=jsonpath='{.spec.host}')
    echo "appEndpoint is ${appEndpoint}"
    while [[ -z $appEndpoint ]]
    do
        if [ $cnt -eq $MAX_RETRIES ]; then
            echo "Timeout and exit due to the maximum retries reached." >> $logFile 
            return 1
        fi
        cnt=$((cnt+1))
        sleep 5
        echo "Wait until the host of route ${routeName} is available, retry ${cnt} of ${MAX_RETRIES}..." >> $logFile
        appEndpoint=$(oc get route ${routeName} -n ${namespaceName} -o=jsonpath='{.spec.host}')
        echo "appEndpoint is ${appEndpoint}"
    done
}

deploy_cluster_autoscaler() {
    Max_Nodes=$1

cat <<EOF | oc apply -f -
apiVersion: autoscaling.openshift.io/v1
kind: ClusterAutoscaler
metadata:
  name: default
spec:
  podPriorityThreshold: -10
  resourceLimits:
    maxNodesTotal: ${Max_Nodes}
  scaleDown:
    enabled: true
    delayAfterAdd: 2m
    delayAfterDelete: 1m
    delayAfterFailure: 15s
    unneededTime: 1m
EOF

    if [[ $? -ne 0 ]]; then
        echo "Failed to deploy cluster autoscaler." >&2
        exit 1
    fi
}

deploy_machine_autoscalers() {
    allocatableNodes=$1

    # The output from your command (assuming it's saved in a variable)
    output=$(oc get machineset -n openshift-machine-api)

    # Read the output into an array of lines
    IFS=$'\n' read -r -d '' -a lines <<< "$output"

    # Remove the header line
    unset lines[0]

    # Initialize an empty array for storing 'name' and 'desired' pairs
    machineset_array=()

    # Read each line and extract the 'name' and 'desired' columns
    for line in "${lines[@]}"; do
        # Read the columns into an array
        read -r -a cols <<< "$line"
        
        # Append 'name' and 'desired' pair to the machineset_array
        machineset_array+=("${cols[0]} ${cols[1]}")
    done

    # Get the array size
    array_size=${#machineset_array[@]}

    # Calculate the quotient and remainder
    quotient=$((allocatableNodes / array_size))
    remainder=$((allocatableNodes % array_size))

    # Iterate over the array in reverse order
    for (( idx=${#machineset_array[@]}-1 ; idx>=0 ; idx-- )) ; do
        # Calculate allocatable nodes for the current machine set
        allocatable=$((quotient))
        if [[ $remainder -gt 0 ]]; then
            allocatable=$((allocatable + 1))
            remainder=$((remainder - 1))
        fi

        # Extract 'MachineSet_Name' and 'Min_Worker_Nodes' from the current machine set
        read -r MachineSet_Name Min_Worker_Nodes <<< "${machineset_array[idx]}"
        Max_Worker_Nodes=$((Min_Worker_Nodes + allocatable))
    
cat <<EOF | oc apply -f -
apiVersion: autoscaling.openshift.io/v1beta1
kind: MachineAutoscaler
metadata:
  name: ${MachineSet_Name}-autoscaler
  namespace: "openshift-machine-api"
spec:
  minReplicas: ${Min_Worker_Nodes}
  maxReplicas: ${Max_Worker_Nodes}
  scaleTargetRef:
    apiVersion: machine.openshift.io/v1beta1
    kind: MachineSet
    name: ${MachineSet_Name}
EOF
        if [[ $? -ne 0 ]]; then
            echo "Failed to deploy machine autoscaler for machineset ${MachineSet_Name}." >&2
            exit 1
        fi
    done

    unset IFS
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

# Retrieve cluster credentials and api/console URLs
credentials=$(az aro list-credentials -g $clusterRGName -n $clusterName -o json)
kubeadminUsername=$(echo $credentials | jq -r '.kubeadminUsername')
kubeadminPassword=$(echo $credentials | jq -r '.kubeadminPassword')
apiServerUrl=$(az aro show -g $clusterRGName -n $clusterName --query 'apiserverProfile.url' -o tsv)
consoleUrl=$(az aro show -g $clusterRGName -n $clusterName --query 'consoleProfile.url' -o tsv)

# Install the OpenShift CLI
downloadUrl=$(echo $consoleUrl | sed -e "s/https:\/\/console/https:\/\/downloads/g")
wget --no-check-certificate ${downloadUrl}amd64/linux/oc.tar -q -P ~
mkdir ~/openshift
tar xvf ~/oc.tar -C ~/openshift 
echo 'export PATH=$PATH:~/openshift' >> ~/.bash_profile && source ~/.bash_profile

# Sign in to cluster
wait_login_complete $kubeadminUsername $kubeadminPassword "$apiServerUrl" $logFile
if [[ $? -ne 0 ]]; then
  echo "Failed to sign into the cluster with ${kubeadminUsername}." >&2
  exit 1
fi

# Install cluster autoscaler and machine autoscalers for the new cluster
if [ "$CREATE_CLUSTER" = True ]; then
    deploy_cluster_autoscaler $MAX_NODES
    deploy_machine_autoscalers $ALLOCATABLE_WORKER_NODES
fi

operatorDeploymentName=
if [ "$DEPLOY_WLO" = False ]; then
    # Install Open Liberty Operator
    operatorDeploymentName=olo-controller-manager
    wait_subscription_created open-liberty-certified openshift-operators open-liberty-operator-subscription.yaml ${logFile}
else
    # Add the IBM operator catalog
    wait_resource_applied catalog-source.yaml $logFile
    # Install WebSphere Liberty Operator
    operatorDeploymentName=wlo-controller-manager
    wait_subscription_created ibm-websphere-liberty openshift-operators websphere-liberty-operator-subscription.yaml ${logFile}
fi
if [[ $? -ne 0 ]]; then
  echo "Failed to install the Open/WebSphere Liberty Operator from the OperatorHub." >&2
  exit 1
fi
wait_deployment_complete ${operatorDeploymentName} openshift-operators ${logFile}
if [[ $? -ne 0 ]]; then
  echo "The Open/WebSphere Liberty Operator is not available." >&2
  exit 1
fi

# Create a new project for managing workload of the user
wait_project_created $Project_Name ${logFile}
if [[ $? -ne 0 ]]; then
  echo "Failed to create project ${Project_Name}." >&2
  exit 1
fi
oc project $Project_Name

# Choose right template & protocol
appDeploymentTemplate=open-liberty-application
protocol=https
if [ "$DEPLOY_WLO" = True ]; then
    appDeploymentTemplate=websphere-liberty-application
    protocol=http
fi
if [ "$AUTO_SCALING" = True ]; then
    appDeploymentTemplate=${appDeploymentTemplate}-autoscaling.yaml.template
else
    appDeploymentTemplate=${appDeploymentTemplate}.yaml.template
fi

appDeploymentFile=liberty-application.yaml
export WLA_Edition="${WLA_EDITION}"
export WLA_Product_Entitlement_Source="${WLA_PRODUCT_ENTITLEMENT_SOURCE}"
export WLA_Metric="${WLA_METRIC}"
export Min_Replicas="${MIN_REPLICAS}"
export Max_Replicas="${MAX_REPLICAS}"
export Cpu_Utilization_Percentage="${CPU_UTILIZATION_PERCENTAGE}"
export Request_Cpu_Millicore="${REQUEST_CPU_MILLICORE}"

# Deploy application image if it's requested by the user
if [ "$deployApplication" = True ]; then
    # Import container image to the built-in container registry of the OpenShift cluster
    wait_image_imported ${Application_Image} ${sourceImagePath} ${Project_Name} ${logFile}
    if [[ $? != 0 ]]; then
        echo "Unable to import source image ${sourceImagePath} to the built-in container registry of the OpenShift cluster. Please check if it's a public image and the source image path is correct" >&2
        exit 1
    fi

    # Deploy Open/WebSphere Liberty application and output its base64 encoded deployment yaml file content
    envsubst < "$appDeploymentTemplate" > "$appDeploymentFile"
    appDeploymentYaml=$(cat $appDeploymentFile | base64)
    wait_resource_applied $appDeploymentFile $logFile
    if [[ $? != 0 ]]; then
        echo "Failed to create Open/WebSphere Liberty application." >&2
        exit 1
    fi

    # Wait until the application deployment completes
    wait_deployment_complete ${Application_Name} ${Project_Name} ${logFile}
    if [[ $? != 0 ]]; then
        echo "The Open/WebSphere Liberty application ${Application_Name} is not available." >&2
        exit 1
    fi

    # Get the host of the route which is assigned to variable 'appEndpoint' inside function 'wait_route_available'
    appEndpoint=
    wait_route_available ${Application_Name} ${Project_Name} $logFile
    if [[ $? -ne 0 ]]; then
        echo "The route ${Application_Name} is not available." >&2
        exit 1
    fi
    echo "appEndpoint is ${appEndpoint}"
else
    # Output base64 encoded deployment template yaml file content
    appDeploymentYaml=$(cat $appDeploymentTemplate \
        | sed -e "s/\${Project_Name}/${Project_Name}/g" \
        | sed -e "s/\${Application_Replicas}/${Application_Replicas}/g" \
        | sed -e "s#\${WLA_Edition}#${WLA_Edition}#g" \
        | sed -e "s#\${WLA_Product_Entitlement_Source}#${WLA_Product_Entitlement_Source}#g" \
        | sed -e "s#\${WLA_Metric}#${WLA_Metric}#g" \
        | base64)
fi

# Write outputs to deployment script output path
result=$(jq -n -c --arg consoleUrl $consoleUrl '{consoleUrl: $consoleUrl}')
result=$(echo "$result" | jq --arg appDeploymentYaml "$appDeploymentYaml" '{"appDeploymentYaml": $appDeploymentYaml} + .')
if [ "$deployApplication" = True ]; then
    result=$(echo "$result" | jq --arg appEndpoint "$protocol://$appEndpoint" '{"appEndpoint": $appEndpoint} + .')
fi
echo "Result is: $result" >> $logFile
echo $result > $AZ_SCRIPTS_OUTPUT_PATH

# Delete uami generated before
az identity delete --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}

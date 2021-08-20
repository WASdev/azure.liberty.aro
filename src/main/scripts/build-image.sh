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

appPackageUrl=$1
export Application_Name=$2
export Application_Package=${Application_Name}.war
export Context_Root=$3
export Base_Image=$4
dockerFileTemplate=$5
registryHost=$6
registryUsername=$7
registryPassword=$8
appProjName=$9
appImage=${10}

# Install docker and start docker daemon
apt-get -q update
apt-get -y -q install apt-transport-https
curl -m 120 -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
apt-get -q update
apt-get -y -q install docker-ce docker-ce-cli containerd.io
systemctl start docker

# Download application package and prepare other artifacts
wget -O ${Application_Package} "$appPackageUrl"
envsubst < "server.xml.template" > "server.xml"
envsubst < "${dockerFileTemplate}" > "Dockerfile"

# Build and tag image
docker build -t ${appImage} --pull .
docker tag ${appImage} ${registryHost}/${appProjName}/${appImage}

# Sign in to the built-in container image registry and push image
docker login -u ${registryUsername} -p ${registryPassword} ${registryHost}
docker push ${registryHost}/${appProjName}/${appImage}

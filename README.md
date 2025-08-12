<!-- Copyright (c) Microsoft Corporation. -->
<!-- Copyright (c) IBM Corporation. -->

# Related Repositories

* [tWAS cluster on Azure VMs](https://github.com/WASdev/azure.websphere-traditional.cluster)
* [Base images used in tWAS cluster](https://github.com/WASdev/azure.websphere-traditional.image)
* [Liberty on AKS](https://github.com/WASdev/azure.liberty.aks)

# Integration tests report
[![IT Validation Workflows](https://github.com/WASdev/azure.liberty.aro/actions/workflows/it-validation-workflows.yaml/badge.svg)](https://github.com/WASdev/azure.liberty.aro/actions/workflows/it-validation-workflows.yaml)

# Deploy a Java application with Open Liberty/WebSphere Liberty on an Azure Red Hat OpenShift 4 cluster

## Prerequisites

1. Register an [Azure subscription](https://azure.microsoft.com/).
   1. Azure Red Hat OpenShift requires a minimum of 40 cores to create and run an OpenShift cluster. The default Azure resource quota for a new Azure subscription does not meet this requirement. To request an increase in your resource limit, see [Standard quota: Increase limits by VM series](https://docs.microsoft.com/en-us/azure/azure-portal/supportability/per-vm-quota-requests). Note that the free trial subscription isn't eligible for a quota increase, [upgrade to a Pay-As-You-Go subscription](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/upgrade-azure-subscription) before requesting a quota increase.
   1. You must have either Contributor and User Access Administrator permissions, or Owner permissions on the subscription.
1. Install [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest).
1. Install [PowerShell Core](https://docs.microsoft.com/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1).
1. Install [Maven](https://maven.apache.org/download.cgi).
1. Install [`jq`](https://stedolan.github.io/jq/download/).

## Local Build Setup and Requirements
This project utilizes [GitHub Packages](https://github.com/features/packages) for hosting and retrieving some dependencies. To ensure you can smoothly run and build the project in your local environment, specific configuration settings are required.

GitHub Packages requires authentication to download or publish packages. Therefore, you need to configure your Maven `settings.xml` file to authenticate using your GitHub credentials. The primary reason for this is that GitHub Packages does not support anonymous access, even for public packages.

Please follow these steps:

1. Create a Personal Access Token (PAT)
    - Go to [Personal access tokens](https://github.com/settings/tokens).
    - Click on Generate new token.
    - Give your token a descriptive name, set the expiration as needed, and select the scopes (read:packages, write:packages).
    - Click Generate token and make sure to copy the token.

2. Configure Maven Settings
    - Locate or create the settings.xml file in your .m2 directory(~/.m2/settings.xml).
    - Add the GitHub Package Registry server configuration with your username and the PAT you just created. It should look something like this:
       ```xml
        <settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 
                               https://maven.apache.org/xsd/settings-1.2.0.xsd">
         
       <!-- other settings
       ...
       -->
      
         <servers>
           <server>
             <id>github</id>
             <username>YOUR_GITHUB_USERNAME</username>
             <password>YOUR_PERSONAL_ACCESS_TOKEN</password>
           </server>
         </servers>
      
       <!-- other settings
       ...
       -->
      
        </settings>
       ```
      
## Steps of deployment

1. Checkout [azure-javaee-iaas](https://github.com/Azure/azure-javaee-iaas)
   1. Change to directory hosting the repo project & run `mvn clean install`
1. Checkout [arm-ttk](https://github.com/Azure/arm-ttk) under the specified parent directory
1. Checkout this repo under the same parent directory and change to directory hosting the repo project
1. Build the project by replacing all placeholder `${<place_holder>}` with valid values
   1. Create a new ARO 4 cluster:
      ```bash
      mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -DcreateCluster=true -DdeployWLO=<true|false> -Dedition=<edition> -DproductEntitlementSource=<productEntitlementSource> -DdeployApplication=<true|false> -DappImagePath=<app-image-path> -DappReplicas=<app-replicas> -Dtest.args="-Test All" -Ptemplate-validation-tests clean install
      ```

   1. Use an existing ARO 4 cluster:
      ```bash
      mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -DcreateCluster=false -DclusterName=<cluste-name> -DclusterRGName=<cluster-resource-group-name> -DdeployWLO=<true|false> -Dedition=<edition> -DproductEntitlementSource=<productEntitlementSource> -DdeployApplication=<true|false> -DappImagePath=<app-image-path> -DappReplicas=<app-replicas> -Dtest.args="-Test All" -Ptemplate-validation-tests clean install
      ```

1. Change to `./target/cli` directory
1. Using `deploy.azcli` to deploy

   ```bash
   ./deploy.azcli -n <deploymentName> -g <resourceGroupName> -l eastus -p <pull-secret-path> -c <aadClientId> -s <aadClientSecret> -a <aadObjectId> -r <rpObjectId>
   ```

## After deployment

1. If you check the resource group in [azure portal](https://portal.azure.com/), you will see a deploymentScript and/or a virtual network, an OpenShift cluster depending on if you choose to create a new ARO 4 cluster.
1. For further administration:
   1. Login to Azure Portal
   1. Open the resource group you specified to deploy an application on the ARO 4 cluster
   1. Navigate to "Deployments > specified_deployment_name > Outputs"
   1. To visit Red Hat OpenShift Container Platform web console: copy value of property `clusterConsoleUrl` > browse it in your browser and sign in with cluster project manager credentials you specified in cluster configuration
   1. To visit application deployed to the ARO 4 cluster: copy value of property `appEndpoint` > append context root defined in the 'server.xml' of your application if it's not equal to '/' > open it in your browser

## Deployment Description

The offer provisions the WebSphere Liberty Operator or Open Liberty Operator and supporting Azure resources.

* Computing resources
  * Azure Red Hat OpenShift (ARO) cluster
     * Dynamically created ARO cluster with
       * Red Hat pull secrets.
       * Service principal client ID.
       * Service principal client secret.
     * You can also choose to deploy into a pre-existing ARO cluster.
* Network resources
  * A virtual network and two subnets.
* Key software components
  * A WebSphere Liberty Operator version 1.1.0 or Open Liberty Operator version 0.8.1 installed and running on the ARO cluster, per user selection.
  * An WebSphere Liberty or Open Liberty application deployed and running on the ARO cluster, per user selection:
    * User can select to deploy an application or not.
    * User can deploy own application or a sample application.
    * User need to provide additional entitlement info to deploy the application if a WebSphere Liberty Operator (IBM supported) is deployed.

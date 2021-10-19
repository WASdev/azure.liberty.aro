# Related Repositories

* [tWAS cluster on Azure VMs](https://github.com/WASdev/azure.websphere-traditional.cluster)
* [Base images used in tWAS cluster](https://github.com/WASdev/azure.websphere-traditional.image)
* [Liberty on AKS](https://github.com/WASdev/azure.liberty.aks)

# Deploy a Java application with Open Liberty/WebSphere Liberty on an Azure Red Hat OpenShift 4 cluster

## Prerequisites

1. Register an [Azure subscription](https://azure.microsoft.com/).
   1. Azure Red Hat OpenShift requires a minimum of 40 cores to create and run an OpenShift cluster. The default Azure resource quota for a new Azure subscription does not meet this requirement. To request an increase in your resource limit, see [Standard quota: Increase limits by VM series](https://docs.microsoft.com/en-us/azure/azure-portal/supportability/per-vm-quota-requests). Note that the free trial subscription isn't eligible for a quota increase, [upgrade to a Pay-As-You-Go subscription](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/upgrade-azure-subscription) before requesting a quota increase.
   1. You must have either Contributor and User Access Administrator permissions, or Owner permissions on the subscription.
1. Install [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest).
1. Install [PowerShell Core](https://docs.microsoft.com/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1).
1. Install [Maven](https://maven.apache.org/download.cgi).
1. Install [`jq`](https://stedolan.github.io/jq/download/).

## Steps of deployment

1. Checkout [azure-javaee-iaas](https://github.com/Azure/azure-javaee-iaas)
   1. Change to directory hosting the repo project & run `mvn clean install`
1. Checkout [arm-ttk](https://github.com/Azure/arm-ttk) under the specified parent directory
1. Checkout this repo under the same parent directory and change to directory hosting the repo project
1. Build the project by replacing all placeholder `${<place_holder>}` with valid values
   1. Create a new ARO 4 cluster:
      ```bash
      mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -DidentityId=<user-assigned-managed-identity-id> -DcreateCluster=true -DuamiHasAppAdminRole=<true|false> -DprojMgrUsername=<project-mgr-username> -DprojMgrPassword=<project-mgr-username> -DuploadAppPackage=<true|false> -DuseOpenLibertyImage=<true|false> -DuseJava8=<true|false> -DcontextRoot=<context-root>  -DappReplicas=<app-replicas> -Dtest.args="-Test All" -Ptemplate-validation-tests clean install
      ```

   1. Use an existing ARO 4 cluster:
      ```bash
      mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -DidentityId=<user-assigned-managed-identity-id> -DcreateCluster=false -DclusterName=<cluste-name> -DclusterRGName=<cluster-resource-group-name> -DprojMgrUsername=<project-mgr-username> -DprojMgrPassword=<project-mgr-username> -DuploadAppPackage=<true|false> -DuseOpenLibertyImage=<true|false> -DuseJava8=<true|false> -DcontextRoot=<context-root>  -DappReplicas=<app-replicas> -Dtest.args="-Test All" -Ptemplate-validation-tests clean install
      ```

1. Change to `./target/cli` directory
1. Using `deploy.azcli` to deploy

   ```bash
   ./deploy.azcli -n <deploymentName> -i <subscriptionId> -g <resourceGroupName> -l eastus -f <app-package-path> -p <pull-secret-path> -c <aadClientId> -s <aadClientSecret> -a <aadObjectId> -r <rpObjectId>
   ```

## After deployment

1. If you check the resource group in [azure portal](https://portal.azure.com/), you will see a deploymentScript and/or a virtual network, an OpenShift cluster depending on if you choose to create a new ARO 4 cluster.
1. For further administration:
   1. Login to Azure Portal
   1. Open the resource group you specified to deploy an application on the ARO 4 cluster
   1. Navigate to "Deployments > specified_deployment_name > Outputs"
   1. To visit Red Hat OpenShift Container Platform web console: copy value of property `clusterConsoleUrl` > browse it in your browser and sign in with cluster project manager credentials you specified in cluster configuration
   1. To visit applicatoin deployed to the ARO 4 cluster: copy value of property `appEndpoint` > open it in your browser

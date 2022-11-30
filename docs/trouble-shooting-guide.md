## Inspect the runtime log

The runtime log of the primary deployment script is stored in the Azure storage account which is mounted to the Azure container instance. Both Azure storage account and Azure container instance are created by the Azure deployment script at runtime. However, they will be removed immediately once the deployment script successfully completed. 

To monitor the deployment process and check the log data, you can inspect the runtime log by following the steps below:

1. Kick off the deployment after providing all necessary inputs in [Create IBM WebSphere Liberty and Open Liberty on Azure Red Hat OpenShift](https://portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.20210823-liberty-aroliberty-aro);
1. Watch the deployment page until the resource prefixed with **aroscript** is created:

   ![Primary deployment script is created](./media/trouble-shooting-guide/primary-deployment-script-created.png)

1. Click **resource group name** > **resource prefixed with aroscript** > Click the name of **Container instance**:

   ![Open container instance of the deployment script](./media/trouble-shooting-guide/open-container-instance.png)

1. Click **Containers** > **Connect** > Click **Connect** in the pop window

   ![Connect to container instance of the deployment script](./media/trouble-shooting-guide/connect-to-container-instance.png)

1. Wait until the container is running and connection is ready. The path of runtime log file is `/mnt/azscripts/azscriptinput/deployment.log`. You can monitor the deployment process using `tail` command as below:

   ![Monitor the runtime log of the container instance ](./media/trouble-shooting-guide/inspect-log-of-container-instance.png)

1. Once the deployment script completed successfully, the connection will be automatically closed:

   ![Container instance is terminated and the connection is closed](./media/trouble-shooting-guide/container-instance-terminated.png)

Besides, the Azure storage account and Azure container instance will be kept for one day if the deployment script finished with errors. So, user can inspect the runtime log after the deployment, starting from step #3.
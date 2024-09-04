<!-- Copyright (c) Microsoft Corporation. -->
<!-- Copyright (c) IBM Corporation. -->

# How to update IBM WebSphere Liberty and Open Liberty on Azure Red Hat OpenShift solution template offer in partner center

Please follow sections below in order to update the solution template offer in partner center.

## Preconditions

### 1. Set the GitHub Actions secrets for the repository running the workflows

The recommended way to set the secrets is to run the scripts.  Setting the secrets manually is beyond the scope of this guide.

#### Preconditions for running the scripts to set the secrets

1. Ensure the Azure ID that is currently logged in when running the scripts has the `Global Administrator` Azure AD role.
1. Ensure the Azure CLI is installed on a supported UNIX-like environment. See [How to install the Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli). **Sign in to Azure using the Azure CLI**. After installation, sign in to the correct tenant. The actions will create Azure resources in this signed-in tenant.
1. Ensure the GitHub CLI is installed on the same environment as the preceding step. See [Installation](https://cli.github.com/manual/installation). Note: If working on macOS, we highly recommend Homebrew. Visit https://brew.sh/ for instructions on installing Homebrew. **Authenticate to GitHub**. After installation, use `gh auth login` to sign in to GitHub. You'll need a sufficiently empowered `PERSONAL ACCESS TOKEN` for this repository.
1. Clone this repository into the environment from the preceding steps.

#### Setting the secrets

- Follow guidance on top of [setup-credentials.sh](../.github/workflows/setup-credentials.sh#L6) to run the shell scripts. The scripts will set the necessary secrets for the repository running the workflows.
- If you want to tear down the secrets, follow the guidance on top of [teardown-credentials.sh](../.github/workflows/teardown-credentials.sh#L6) to run the shell scripts. The scripts will remove the necessary secrets for the repository running the workflows.


## When should I update the offer in partner center?

If you make any changes for files located in the following path:

* `src/main/arm`
* `src/main/bicep`
* `src/main/scripts`

## Update the version of the solution template

If you haven't incremented the version, pls do so before publishing the solution template to partner center. 

1. Increase the [version number](https://github.com/WASdev/azure.liberty.aro/blob/main/pom.xml#L23) which is specified in the `pom.xml`.
1. If creating a new Plan, update the `pid` value as described in [How Azure customer usage attribution works in the IBM Partner Center offers](https://github.com/WASdev/azure.websphere-traditional.image/blob/main/docs/howto-update-pids.md).
1. Get the PR merged.

## How do I increment the version of the open-liberty-operator installed by the offer?

- The version pattern is `Major.Minor.Patch`. Normally the new patch is automatically installed for the specified `Major.Minor` in the property `channel` from the file `src/main/scripts/open-liberty-operator-subscription.yaml`. If the new patch failed to be installed automatcially (see [this](https://github.com/WASdev/azure.liberty.aro/pull/97#issuecomment-1626388789) as an example), please follow [this commit](https://github.com/WASdev/azure.liberty.aro/pull/97/commits/14058d802bacba0099e3d4c7e7e8961a0cc1330e) to manually increment the value of the property `startingCSV` according to the existing pattern in that property value.
- If the new version is released with new `Major.Minor`, please specify the appropriate values for both properties `channel` and `startingCSV` after consulting with Open Liberty Operator team.

## Run integration test workflow to verify the changes

There is an `integration-test` workflow which will deploy the Azure resources defined in the solution template, deploy a sample app to the ARO and verify the deployment.
It's strongly recommended to run the `integration-test` workflow to verify the code changes before publishing the offer.

1. Go to [Actions](https://github.com/WASdev/azure.liberty.aro/actions) > Click `integration-test` > Click to expand `Run workflow`.
1. You will see a popup listing all inputs you can customize, select appropriately. For example, select **WebSphere Liberty Operator** if your changes relate to WebSphere Liberty Operator.

   ![integration-test workflow inputs](./media/integration-test-workflow-inputs.png)

1. Click `Run workflow` > Refresh the page.
1. Wait until the run of workflow `integration-test` successfully completes. If any failures are observed, you must triage and fix before proceeding.

## Upload the artificat to partner center

Once the run of workflow `integration-test` succeeds, you can choose manually or automatically upload the artifact to partner center and save it as a draft.

### Manually upload the artifact and save as draft

You can leverage the output of workflow `integration-test` run to manaully upload the generated artifact and save it as a draft in partner center.

1. Click to open details of the run of workflow `integration-test` > Scroll to the bottom of the page.
1. Click `azure.liberty.aro-<version>-arm-assembly` to download the zip file `azure.liberty.aro-<version>-arm-assembly.zip`.
1. Sign into [Microsoft Partner Center](https://partner.microsoft.com/dashboard/commercial-marketplace/overview).
   * Click to open the offer for the solution (likely `20210823-liberty-aro`) > Click `Plan overview`.
   * Click to open the plan > Click `Technical configuration`.
   * Specify the increased version number for `Version` (note, the version is in the zip file name).
   * Click `Remove` to remove the previous package file.
   * Click `browse your file(s)` to upload the downloaded zip package generated by the CI/CD pipeline before.
   * Scroll to the bottom of the page.
   * Click `Save draft`.

### Automatically upload the artifact and save as draft

You can also run another workflow `Package ARM` to automatically upload the generated artifact and save it as a draft in partner center.

1. Go to [Actions](https://github.com/WASdev/azure.liberty.aro/actions) > Click `Package ARM` > Click to expand `Run workflow` > Click `Run workflow` > Refresh the page.
1. Wait until the CI/CD workflow for `Package ARM` successfully completes. The workflow will update the offer with the generated artifact and save it as draft in partner center. 
1. Sign into [Microsoft Partner Center](https://partner.microsoft.com/dashboard/commercial-marketplace/overview), find the offer (`20210823-liberty-aro`) and its plan, you should see a new version of draft exists from page **Technical configuration**.

## Review and publish the offer

Once the new version of draft is saved, you can start review and publish process. Make sure you're in the page **Technical configuration** of the offer's plan.

1. Click `Review and publish`.
1. In the "Notes for certification" section enter the `integration-test` URL.
1. Click `Publish`.
1. Wait until solution offer is in `Publisher signoff` (aka "preview") stage and "Go Live" button appears(it could take few hours).
1. Before clicking "Go Live" use the preview link to test the solution. If any issues are observed, you must triage, fix and re-go through the previous steps before proceeding.
1. Click "Go Live".
1. Wait for remaining steps to complete (may take couple of days).
1. Make sure to delete your test deployments.
1. Once the solution is in "Publish" stage, new version is publicly available.
1. To verify the version number, launch the solution in Azure portal and hover over "Issue tracker" and it should display the version number. For example, https://aka.ms/azure-liberty-aro-issues?version=1.0.44.

## Create a release and a tag with the GA code

It's recommended to create a new release if significant changes are introduced.

1. Create a [release](https://github.com/WASdev/azure.liberty.aro/releases) for this GA code and tag with the `pom.xml` version number.

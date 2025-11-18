# apiops-demo
This is the implementation of the [APIOps repo](https://github.com/Azure/apiops) that I use to demo the apiops process.  I've also merged in the pipelines from the [apim-dev-portal-migration](https://github.com/anotherRedbeard/apim-dev-portal-migration) repo that I forked and modified slightly from [@seenu433](https://github.com/seenu433/apim-dev-portal-migration) so that I can have a one stop repo for all of my Azure Api Management (APIM) deployment examples.

For more information on the automation of developer portal deployments you can go to the [Automate developer portal deployments](https://learn.microsoft.com/en-us/azure/api-management/automate-portal-deployments) document page.

## Prerequisites

- You will need to create a new client_id and secret on an existing or new service principal. Keep in mind if you delete the resource group and re-run the [bicep] modules to create the infrastructure, you will need to go back and grant permissions to this service principal. That is because when you remove the resource group it will remove the RBAC assignments.
  - Here is the command to create the new service principal. I would recommend using 2 service principals, named something similiar to this:  spAPIOpsDemoDev and spAPIOpsDemoPrd.

    ```# Bash script
      az ad sp create-for-rbac --name myServicePrincipalName1 --role reader --scopes /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myRG1
    ```

- Create environments for each of the APIM instances under *{repository} -> Settings -> Environments* with the below secrets and variables:

    | Secret Name | Description |
    | ------------- | ----------- |
    |ALLOWED_IP_ADDRESS|IP address to check for in one of the policies|
    |APP_INSIGHTS_LOGGER_KEY|InstrumentationKey from the application insights resource that is created with the bicep modules. You will need to update this each time you re-create the resource|
    |AZURE_CLIENT_ID|The client id of the service principal|
    |AZURE_CLIENT_SECRET|The client secret of the service principal|
    |AZURE_SUBSCRIPTION_ID|The subscription id of the APIM resource |
    |AZURE_TENANT_ID|The tenant id of the service principal|
    |KEYVAULT_NAME|The name of the key vault so it can be used in the APIOps process|

    | Variable Name | Description |
    | ------------- | ----------- |
    |APIM_INSTANCE_NAME |The name of the APIM instance to migrate from |
    |APIOPS_VERSION |Version of APIOps you want to use |
    |LOG_LEVEL |Level you want to set for the logging |
    |RESOURCE_GROUP_NAME|The name of the resource group the APIM instance is in|
    |ARM_API_VERSION|(Optional)If you need to use a different api version you can set this variable|

    *Note:* The names of the environments can be dev, stage etc. If using different names, update the run-extractor.yaml and run-publisher-with-env.yaml for the environment names. This would also be a good time to setup [deployment protection rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#deployment-protection-rules) if you wish in the environment settings of GitHub.

- Grant permissions for the actions to create a PR. Set *Read and write permissions* and "Allow GitHub Actions to create and approve pull requests" under *{repository} -> Settings -> Actions -> General -> Workflow permissions*.

## APIOps Steps

For full documentation steps of how to setup and run APIOps, it would be best to check the [Official Documentation](https://azure.github.io/apiops/apiops/3-apimTools/), but since I've already done all of that here are the steps I use to deploy.

### Portal First Deployment

  1. Run the extractor.yaml
    a. This will create a PR for you to approve, once you approve the PR the publisher.yaml pipeline will execute which will deploy your code to all the environments

### Code First Deployment

  1. Create a PR for the changes that you've made.
  2. Approve the PR
    a. Once you approve the PR the publisher.yaml pipeline will execute which will deploy your code to all the environments

## APIM Developer Portal Deploy Steps

1. Update the *release.yaml* to reflect the stages you want to deploy to. 

2. By default the folder used to store the Developer Portal artifacts in this repo is `artifacts` as referenced in the [release-with-env.yaml file](.github/workflows/release-with-env.yaml#L22). If you would like to use a different folder name, you will need to update that file first.

3. Create url overwrite files for each environment in the format ***urls.{env}.json***. The contents of the file should be as

    ```json
    {
        uri: "https://uri1.com,https://uri2.com"
    }
    ```

    Update the existing uris in the snapshot in the file ***existingUrls.json***

    *Note*: This is an optional step and is only required if you want to overwrite the urls in the snapshot with the urls in the file.

4. Run the `capture.yaml` pipeline and provide a folder to store the artifacts in, the default is `artifacts`. That will pull in the Developer Portal artifacts that are in the current dev environment (this is set in the [capture.yaml](.github/workflows/capture.yaml#L15) file, so if you want to pull from a different environment update that). Once that is complete, you can see the PR that was created so you can merge it. Once that is merged the `release.yaml` pipeline will automatically trigger.

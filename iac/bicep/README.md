# Bicep

This directory contains bicep templates that are used to create the dev and production instance of APIM so I can simulate APIOps. If you want to use your own parameter files, this repo is setup to copy the `*.bicepparam` files and create your own with the `dev.bicepparam` extension. They will be ignored from check-in. I'm using [Azure Verifed Modules](https://azure.github.io/Azure-Verified-Modules/indexes/bicep/bicep-resource-modules/) where they exist to create these bicep files.

## Deploying with Bicep

Bicep is an Infrastructure as Code (IaC) language developed by Microsoft for deploying Azure resources in a declarative manner. It simplifies the deployment process and enhances readability and maintainability of your infrastructure code. Here is the [official Bicep documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

### Prerequisites

Before you begin, ensure you have the following installed:

- Azure CLI: Bicep is integrated directly into the Azure CLI and provides first-class support for deploying Bicep files.
- Bicep CLI: While not strictly necessary due to Azure CLI integration, the Bicep CLI can be useful for compiling, decompiling, and validating Bicep files.

### Steps to Deploy

1. **Login to Azure**

    Start by logging into Azure with the Azure CLI:

    ```bash
    az login
    ```

2. **Set your subscription**

    Make sure you're working with the correct Azure subscription:

    ```bash
    az account set --subscription "<Your-Subscription-ID>"
    ```

3. **Create Resource Group (Optional)

    Make sure the resource group has already been created:

    ```base
    az group create --name <resource-group-name> --location <location>
    ```

4. **Compile Bicep file (Optional)

    If you have Bicep CLI installed, you can manually compile your Bicep file to an ARM template. This step is optional because Azure CLI compiles Bicep files automatically on deployment.

    ```bash
    bicep build <your-file>.bicep
    ```

5. **Deploy the Bicep file**

    Use the Azure CLI to deploy your Bicep file. Replace `<your-resource-group>` with your Azure Resource Group name, and `<your-deployment-name>` with a name for your deployment.  **Note**: since we are using bicep parameter files and they are tied to one bicep file we don't need the --template-file switch.  See [Bicep file with parameters file](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameter-files?tabs=Bicep#deploy-bicep-file-with-parameters-file) for more info.

    ```bash
    az deployment group create --resource-group <your-resource-group> --name <your-deployment-name> --parameters <your-file>.bicepparam
    ```

### Deploying examples in this repo

1. **Base APIM resource in both dev and production environment**

    Prerequisites:
    - None, everything should get created using the bicep file

    `create-base-apim.bicep` is the main template for this. Here we are creating an Application Insights and a KeyVault resource. Then we will use APIOps to configure the rest.

    What's Included in each subscription:

    - Developer sku of API management
    - Application Insights
    - Azure Key Vault
    - Identities for the developer portal
      - This will require an app registration with at least `User.Read.All` and `Group.Read.All`. You can read more here to create the [app registrations](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-aad#manually-enable-microsoft-entra-application-and-identity-provider) to this setup if you have questions.
    - OAuth2.0 servers to handle authentication
    - Diagnostic Loggers

    **Command to deploy via bicep:**

    ```bash
    #dev
    az deployment sub create --subscription <subscriptionId> --location <location> --name apiops-demo-deployment --parameters ./iac/bicep/create-base-apim.dev.bicepparam
    #prd
    az deployment sub create --subscription <subscriptionId> --location <location> --name apiops-demo-deployment --parameters ./iac/bicep/create-base-apim.prd.bicepparam
    ```

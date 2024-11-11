targetScope = 'subscription'

@description('Provide the id of the subscription.')
param subscriptionId string = 'subscriptionId'

@description('Provide the name of the resource group.')
param rgName string = 'rgName'

@description('Provide the name of the apim instance.')
param apimName string = 'apimName'

@description('Provide the location of the apim instance.')
param location string = 'southcentralus'

@description('Provide the name of the organization.')
param orgName string = 'Organization Name'

@description('Provide the administrator email address.')
param adminEmail string = 'admin@email.com'

@allowed([
  'Basic'
  'BasicV2'
  'Consumption'
  'Developer'
  'Premium'
  'Standard'
  'StandardV2'
])
@description('The name of the api management sku.')
param apimSku string = 'Developer'

@description('The number of scale units to deployname of the api management sku.')
param apimCapacity int = 1

@description('Name of the APIM keyvault.')
param apimKeyVaultName string = '<apimKeyVaultName>'

@description('Name of the log analytics workspace.')
param lawName string = '<lawName>'

@description('Name of the app insights resource.')
param appInsightsName string = '<appInsightsName>'

@description('Unlimited subscription primary key.')
param unlimitedSubPrimaryKey string = '<secret-value>'

@description('Unlimited subscription secondary key.')
param unlimitedSubSecondaryKey string = '<secret-value>'

@description('Client Id of the service principal that will run the deployment.')
param spAPIOpsDemoObjectId string = '<clientId>'

// Nested deployment to create resources in another subscription and resource group
module resourceGroupResource 'br/public:avm/res/resources/resource-group:0.3.0' = {
  name: 'createResourceGroup'
  scope: subscription(subscriptionId)
  params: {
    name: rgName
    location: location
  }
}

//apim service resource
module service 'br/public:avm/res/api-management/service:0.1.7' = {
  name: 'apimServiceDeployment'
  scope: resourceGroup(rgName)
  dependsOn: [ resourceGroupResource ]
  params: {
    // Required parameters
    name: apimName
    publisherEmail: adminEmail
    publisherName: orgName
    // Non-required parameters
    sku: apimSku
    skuCount: apimCapacity 
    location: location
    managedIdentities: {
      systemAssigned: true
    }
  }
}

//key vault resource
module vault 'br/public:avm/res/key-vault/vault:0.7.1' = {
  name: 'vaultDeployment'
  scope: resourceGroup(rgName)
  dependsOn: [ resourceGroupResource, service ]
  params: {
    // Required parameters
    name: apimKeyVaultName
    // Non-required parameters
    enablePurgeProtection: false
    enableRbacAuthorization: true
    location: location
    roleAssignments: [
      {
        principalId: service.outputs.systemAssignedMIPrincipalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
      {
        principalId: spAPIOpsDemoObjectId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
    ]
    secrets: [
      {
        contentType: 'Key'
        name: 'APIM-signing-key'
        value: '123'
      }
      {
        contentType: 'Key'
        name: 'APIM-Unlimited-Subscription-Primary-Key'
        value: unlimitedSubPrimaryKey
      }
      {
        contentType: 'Key'
        name: 'APIM-Unlimited-Subscription-Secondary-Key'
        value: unlimitedSubSecondaryKey
      }
    ]
  }
}

//log analytics workspace resource
module workspace 'br/public:avm/res/operational-insights/workspace:0.5.0' = {
  name: 'workspaceDeployment'
  scope: resourceGroup(rgName)
  dependsOn: [ resourceGroupResource ]
  params: {
    // Required parameters
    name: lawName
    // Non-required parameters
    location: location
  }
}

//app insights resource
module component 'br/public:avm/res/insights/component:0.4.0' = {
  name: 'componentDeployment'
  scope: resourceGroup(rgName)
  dependsOn: [ resourceGroupResource, workspace ]
  params: {
    // Required parameters
    name: appInsightsName
    workspaceResourceId: workspace.outputs.resourceId
    // Non-required parameters
    location: location
  }
}

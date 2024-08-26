using './create-base-apim.bicep'

param subscriptionId = 'subscriptionId'
param rgName = 'rgName'
param apimName = '<your-apim-name>'
param location = '<azure-region>'
param orgName = '<orginization-name>'
param adminEmail = '<administrator-email>'
param apimSku = 'Developer'
param apimCapacity = 1
param apimKeyVaultName = '<apimKeyVaultName>'
param lawName = '<lawName>'
param appInsightsName = '<appInsightsName>'

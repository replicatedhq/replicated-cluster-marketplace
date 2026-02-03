targetScope = 'resourceGroup'

param namePrefix string

param tenantId string = tenant().tenantId

param location string = resourceGroup().location

param subnetResourceId string

@secure()
@description('KOTS password')
param kotsPassword string

@description('Tags to apply to resources created for this node.')
param tags object

resource kv 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: '${namePrefix}-kv' 
  location: location
  properties: {
    enableRbacAuthorization: true
    tenantId: tenantId
    networkAcls: {
      defaultAction: 'Deny' 
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: subnetResourceId
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
    sku: {
      name: 'Standard'
      family: 'A'
    }

    tags: tags
  }
}

resource kotsPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: kv
  name: 'kotsPassword'
  properties: {
      value: kotsPassword
    }
}

output keyVaultResourceId string = kv.id

output kotsSecretUri string = kotsPasswordSecret.properties.secretUri

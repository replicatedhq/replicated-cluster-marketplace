targetScope = 'resourceGroup'

param application string

@description('Azure region for networking resources.')
param location string

@description('Tags to apply to all network resources created by this module.')
param tags object = {}

@description('Base tags from the setup-azure-networking script.')
param networkTags object = {}

@description('Resource ID of an existing VNet. Leave empty to create one.')
param existingVnetId string = ''

@description('Resource ID of an existing subnet for the nodes. Leave empty to create one.')
param existingSubnetId string = ''

@description('Resource ID of an existing Network Security Group (NSG). Leave empty to create one.')
param existingNsgId string = ''

@description('Name of the VNet to create when not using an existing VNet.')
param vnetName string = '${application}-vnet'

@description('Address prefix for the VNet to create when not using an existing VNet.')
param vnetAddressPrefix string = '10.0.0.0/8'

@description('Name of the subnet to create for the nodes when not using an existing subnet.')
param subnetName string = 'default'

@description('Address prefix for the node subnet to create when not using an existing subnet.')
param subnetAddressPrefix string = '10.254.0.0/24'

@description('Name of the NSG to create when not using an existing NSG.')
param nsgName string = '${application}-nsg'

@description('Source address prefixes allowed to access the node subnet.')
param allowedIngressSourcePrefixes array = [
  '0.0.0.0/0'
]

@description('Ingress ports to allow from Internet to the node subnet.')
param allowedIngressPorts array = [
  80
  443
  30000
]

@description('Whether to create an Azure Bastion host and subnet.')
param enableBastion bool = false

@description('Address prefix for AzureBastionSubnet when Bastion is enabled.')
param bastionSubnetPrefix string = '10.254.1.0/26'

@description('Name of the Bastion host to create when Bastion is enabled.')
param bastionHostName string = 'platform-core-bastion'

@description('Name of the Bastion public IP to create when Bastion is enabled.')
param bastionPublicIpName string = 'platform-core-bastion-pip'

@description('Optional DNS label for the Bastion public IP.')
param bastionPublicIpDnsLabel string = ''

var mergedTags = union(networkTags, tags)
var useExistingVnet = !empty(existingVnetId)
var useExistingSubnet = !empty(existingSubnetId)
var useExistingNsg = !empty(existingNsgId)
var useExistingVnetScope = useExistingVnet || useExistingSubnet

var existingVnetIdParts = split(existingVnetId, '/')
var existingSubnetIdParts = split(existingSubnetId, '/')
var existingNsgIdParts = split(existingNsgId, '/')

var existingVnetSubscriptionId = useExistingVnet ? existingVnetIdParts[2] : (useExistingSubnet ? existingSubnetIdParts[2] : '')
var existingVnetResourceGroupName = useExistingVnet ? existingVnetIdParts[4] : (useExistingSubnet ? existingSubnetIdParts[4] : '')
var existingVnetName = useExistingVnet ? existingVnetIdParts[8] : (useExistingSubnet ? existingSubnetIdParts[8] : '')

var existingSubnetSubscriptionId = useExistingSubnet ? existingSubnetIdParts[2] : ''
var existingSubnetResourceGroupName = useExistingSubnet ? existingSubnetIdParts[4] : ''
var existingSubnetVnetName = useExistingSubnet ? existingSubnetIdParts[8] : ''
var existingSubnetName = useExistingSubnet ? existingSubnetIdParts[10] : ''

var existingNsgSubscriptionId = useExistingNsg ? existingNsgIdParts[2] : ''
var existingNsgResourceGroupName = useExistingNsg ? existingNsgIdParts[4] : ''
var existingNsgName = useExistingNsg ? existingNsgIdParts[8] : ''

var derivedVnetId = useExistingSubnet ? join(take(existingSubnetIdParts, 9), '/') : ''
var vnetIdMatch = !(useExistingVnet && useExistingSubnet) || (toLower(existingVnetId) == toLower(derivedVnetId))

var targetVnetSubscriptionId = useExistingVnetScope ? existingVnetSubscriptionId : subscription().subscriptionId
var targetVnetResourceGroupName = useExistingVnetScope ? existingVnetResourceGroupName : resourceGroup().name
var targetVnetName = useExistingVnetScope ? existingVnetName : vnetName

resource vnetSubnetMismatch 'Microsoft.Resources/deployments@2021-04-01' = if (!vnetIdMatch) {
  name: 'vnet-subnet-mismatch'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
      outputs: {
        error: {
          type: 'string'
          value: '[error(\'existingSubnetId must belong to existingVnetId.\')]'
        }
      }
    }
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (!useExistingVnet && !useExistingSubnet) {
  name: vnetName
  location: location
  tags: mergedTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = if (useExistingVnet || useExistingSubnet) {
  name: existingVnetName
  scope: resourceGroup(existingVnetSubscriptionId, existingVnetResourceGroupName)
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (!useExistingNsg) {
  name: nsgName
  location: location
  tags: mergedTags
}

resource existingNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = if (useExistingNsg) {
  name: existingNsgName
  scope: resourceGroup(existingNsgSubscriptionId, existingNsgResourceGroupName)
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = if (useExistingSubnet) {
  name: '${existingSubnetVnetName}/${existingSubnetName}'
  scope: resourceGroup(existingSubnetSubscriptionId, existingSubnetResourceGroupName)
}

var effectiveNsgId = useExistingNsg ? existingNsgId : nsg.id
var workloadSubnetAddressPrefixes = useExistingSubnet
  ? (empty(existingSubnet.properties.addressPrefixes) ? [existingSubnet.properties.addressPrefix] : existingSubnet.properties.addressPrefixes)
  : [subnetAddressPrefix]

module existingVnetSubnets 'existing-vnet-subnets.bicep' = {
  name: 'existing-vnet-subnets'
  scope: resourceGroup(targetVnetSubscriptionId, targetVnetResourceGroupName)
  params: {
    vnetName: targetVnetName
    createWorkloadSubnet: useExistingVnetScope && !useExistingSubnet
    subnetName: subnetName
    subnetAddressPrefix: subnetAddressPrefix
    nsgId: effectiveNsgId
    createBastionSubnet: enableBastion && useExistingVnetScope
    bastionSubnetPrefix: bastionSubnetPrefix
  }
}

resource workloadSubnetNewVnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (!useExistingSubnet && !useExistingVnet) {
  name: subnetName
  parent: vnet
  properties: {
    addressPrefix: subnetAddressPrefix
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [location]
      }
    ]
    networkSecurityGroup: empty(effectiveNsgId) ? null : {
      id: effectiveNsgId
    }
  }
}

resource allowSshRuleNew 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = if (!useExistingNsg) {
  name: 'allow-ssh'
  parent: nsg
  properties: {
    priority: 100
    access: 'Allow'
    direction: 'Inbound'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '22'
    sourceAddressPrefixes: allowedIngressSourcePrefixes
    destinationAddressPrefixes: workloadSubnetAddressPrefixes
  }
}

resource allowPlatformPortsNew 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = if (!useExistingNsg) {
  name: 'allow-${application}-ports'
  parent: nsg
  properties: {
    priority: 110
    access: 'Allow'
    direction: 'Inbound'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRanges: [for port in allowedIngressPorts: string(port)]
    sourceAddressPrefixes: allowedIngressSourcePrefixes
    destinationAddressPrefixes: workloadSubnetAddressPrefixes
  }
}

resource allowBastionAccessNew 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = if (enableBastion && !useExistingNsg) {
  name: 'allow-bastion-access'
  parent: nsg
  properties: {
    priority: 120
    access: 'Allow'
    direction: 'Inbound'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRanges: [
      '22'
    ]
    sourceAddressPrefixes: [
      bastionSubnetPrefix
    ]
    destinationAddressPrefixes: workloadSubnetAddressPrefixes
  }
}

module existingNsgRules 'existing-nsg-rules.bicep' = if (useExistingNsg) {
  name: '${existingNsgName}-rules'
  scope: resourceGroup(existingNsgSubscriptionId, existingNsgResourceGroupName)
  params: {
    nsgName: existingNsgName
    workloadSubnetAddressPrefixes: workloadSubnetAddressPrefixes
    allowedIngressSourcePrefixes: allowedIngressSourcePrefixes
    allowedIngressPorts: allowedIngressPorts
    enableBastion: enableBastion
    bastionSubnetPrefix: bastionSubnetPrefix
  }
}

resource bastionSubnetNewVnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (enableBastion && !useExistingVnet && !useExistingSubnet) {
  name: 'AzureBastionSubnet'
  parent: vnet
  properties: {
    addressPrefix: bastionSubnetPrefix
  }
}

var bastionSubnetId = enableBastion
  ? (useExistingVnetScope ? existingVnetSubnets.outputs.bastionSubnetId : bastionSubnetNewVnet.id)
  : ''

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (enableBastion) {
  name: bastionPublicIpName
  location: location
  tags: mergedTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: empty(bastionPublicIpDnsLabel) ? null : {
      domainNameLabel: bastionPublicIpDnsLabel
    }
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = if (enableBastion) {
  name: bastionHostName
  location: location
  tags: mergedTags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

var workloadSubnetId = useExistingSubnet
  ? existingSubnet.id
  : (useExistingVnetScope ? existingVnetSubnets.outputs.workloadSubnetId : workloadSubnetNewVnet.id)

output vnetId string = (useExistingVnet || useExistingSubnet) ? existingVnet.id : vnet.id
output workloadSubnetId string = workloadSubnetId
output nsgId string = effectiveNsgId
output bastionHostId string = enableBastion ? bastionHost.id : ''
output bastionPublicIpId string = enableBastion ? bastionPublicIp.id : ''
output bastionPublicIpAddress string = enableBastion ? bastionPublicIp.properties.ipAddress : ''

targetScope = 'resourceGroup'

@description('Name of the existing VNet to add subnets to.')
param vnetName string

@description('Whether to create the workload subnet in the existing VNet.')
param createWorkloadSubnet bool = true

@description('Name of the workload subnet to create when enabled.')
param subnetName string

@description('Address prefix for the workload subnet to create when enabled.')
param subnetAddressPrefix string

@description('NSG resource ID to associate to the workload subnet (optional).')
param nsgId string = ''

@description('Whether to create AzureBastionSubnet in the existing VNet.')
param createBastionSubnet bool = false

@description('Address prefix for AzureBastionSubnet when enabled.')
param bastionSubnetPrefix string = '10.254.1.0/26'

resource existingVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource workloadSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (createWorkloadSubnet) {
  name: subnetName
  parent: existingVnet
  properties: {
    addressPrefix: subnetAddressPrefix
    networkSecurityGroup: empty(nsgId) ? null : {
      id: nsgId
    }
  }
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (createBastionSubnet) {
  name: 'AzureBastionSubnet'
  parent: existingVnet
  properties: {
    addressPrefix: bastionSubnetPrefix
  }
}

output workloadSubnetId string = createWorkloadSubnet ? workloadSubnet.id : ''
output bastionSubnetId string = createBastionSubnet ? bastionSubnet.id : ''

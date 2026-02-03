targetScope = 'resourceGroup'

@description('Name of the existing Network Security Group.')
param nsgName string

@description('Destination address prefixes for rules (workload subnet).')
param workloadSubnetAddressPrefixes array

@description('Source address prefixes allowed to access the workload subnet.')
param allowedIngressSourcePrefixes array = [
  '0.0.0.0/0'
]

@description('Ingress ports to allow from Internet to the workload subnet.')
param allowedIngressPorts array = [
  80
  443
  2746
  6443
  8888
  9090
  9093
  9443
  30000
]

@description('Whether to add a Bastion-to-workload rule.')
param enableBastion bool = false

@description('Address prefix for AzureBastionSubnet when Bastion is enabled.')
param bastionSubnetPrefix string = '10.254.1.0/26'

var allowedIngressPortStrings = [for port in allowedIngressPorts: string(port)]
var bastionAccessPorts = [
  '22'
  '3389'
  '5985'
  '5986'
]

resource existingNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = {
  name: nsgName
}

resource allowSshRule 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = {
  name: 'allow-ssh'
  parent: existingNsg
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

resource allowPlatformPorts 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = {
  name: 'allow-application-ports'
  parent: existingNsg
  properties: {
    priority: 110
    access: 'Allow'
    direction: 'Inbound'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRanges: allowedIngressPortStrings
    sourceAddressPrefixes: allowedIngressSourcePrefixes
    destinationAddressPrefixes: workloadSubnetAddressPrefixes
  }
}

resource allowBastionAccess 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = if (enableBastion) {
  name: 'allow-bastion-access'
  parent: existingNsg
  properties: {
    priority: 120
    access: 'Allow'
    direction: 'Inbound'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRanges: bastionAccessPorts
    sourceAddressPrefixes: [
      bastionSubnetPrefix
    ]
    destinationAddressPrefixes: workloadSubnetAddressPrefixes
  }
}

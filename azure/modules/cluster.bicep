targetScope = 'resourceGroup'

@description('Azure region for the deployment. Ideally should support Availability Zones.')
param location string = resourceGroup().location

@description('Name prefix used for all controller VMs. VM names will be {prefix}-controller-{n}.')
@minLength(1)
@maxLength(16)
param namePrefix string

@description('Number of control plane VMs to create.')
@minValue(1)
param controlPlaneNodeCount int = 3

@description('Default VM size/SKU to use for all nodes unless overridden per node pool.')
param vmSku string = 'Standard_D2ds_v4'
//param vmSku string = 'Standard_D8s_v6'

@description('Optional node pools to create. Each entry must include poolName and vmCount. Optional overrides: nodeRoles (default worker), vmSku, dataDiskCountPerVm, dataDiskSizeTiB, dataDiskIOPSReadWrite, dataDiskMBpsReadWrite.')
param nodePools array = []

@description('Resource ID of an existing VNet. Leave empty to create one.')
param existingVnetId string = ''

@description('Resource ID of an existing subnet to which all VM NICs will be attached. Leave empty to create one.')
param existingSubnetId string = ''

@description('Resource ID of an existing Network Security Group (NSG). Leave empty to create one.')
param existingNsgId string = ''

@description('Name of the VNet to create when not using an existing VNet.')
param vnetName string = '${application}-vnet'

@description('Address prefix for the VNet to create when not using an existing VNet.')
param vnetAddressPrefix string = '10.0.0.0/8'

@description('Name of the subnet to create for nodes when not using an existing subnet.')
param subnetName string = 'default'

@description('Address prefix for the subnet to create for nodes when not using an existing subnet.')
param subnetAddressPrefix string = '10.254.0.0/24'

@description('Name of the NSG to create when not using an existing NSG.')
param nsgName string = '${application}-nsg'

@secure()
@description('Base64 encoded yaml for Replicated application')
param license string

@description('Ingress ports to allow from Internet to the node subnet.')
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

@description('Tags to apply to network resources, merged with common tags.')
param networkTags object = {
  Owner: ''
  Ephemeral: 'no'
}

@description('Whether to create an Azure Bastion host and subnet.')
param enableBastion bool = false

@description('Address prefix for AzureBastionSubnet when Bastion is enabled.')
param bastionSubnetPrefix string = '10.254.1.0/26'

@description('Optional override for the Bastion host name when Bastion is enabled.')
param bastionHostName string = ''

@description('Optional override for the Bastion public IP name when Bastion is enabled.')
param bastionPublicIpName string = ''

@description('Optional DNS label for the Bastion public IP when Bastion is enabled.')
param bastionPublicIpDnsLabel string = ''

@description('Optional override for the load balancer name.')
param loadBalancerName string = ''

@description('Optional override for the load balancer public IP name.')
param loadBalancerPublicIpName string = ''

@description('Optional DNS label for the load balancer public IP.')
param loadBalancerPublicIpDnsLabel string = ''

@description('Ports to expose through the public load balancer.')
param loadBalancerPorts array = [
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

@description('Health probe port for the load balancer backend.')
param loadBalancerProbePort int = 30000

@description('Idle timeout in minutes for load balancer rules.')
param loadBalancerIdleTimeoutMinutes int = 15

@description('Enable Secure Boot on the VMs.')
param enableSecureBoot bool = true

@description('Whether to attempt to enable Accelerated Networking on node NICs. Note that the deployment will fail if the chosen VM size/region does not support it.')
param enableAcceleratedNetworking bool = true

@description('Admin username for all VMs.')
@minLength(1)
param adminUsername string = 'ubuntu'

@description('Public key that will be installed as an authorized key for the admin user on all VMs.')
@minLength(1)
param sshPublicKey string

@description('Number of Premium SSD v2 data disks to attach to each VM.')
@minValue(1)
param dataDiskCountPerVm int = 2

@description('Size of each Premium SSD v2 data disk in TiB (1 TiB = 1024 GiB).')
@minValue(1)
param dataDiskSizeTiB int = 2

@description('Provisioned disk IOPS for each Premium SSD v2 data disk.')
@minValue(1)
param dataDiskIOPSReadWrite int = 6000

@description('Provisioned disk throughput (MBps) for each Premium SSD v2 data disk. Note: VM-level uncached throughput limits may cap effective throughput; adjust or use a larger VM size as needed.')
@minValue(1)
param dataDiskMBpsReadWrite int = 300

@description('Common tags to apply to all resources created by this module.')
param tags object = {}

@description('Image reference for the VMs.')
param imageReference object = {
  id: '{IMAGE_ID}'
}

@description('Replicated release channel')
param releaseChannel string = '{CHANNEL}'

@description('Replicated application')
param application string = '{APPLICATION}'

@secure()
@description('KOTS password')
param kotsPassword string

var resolvedNodePools = [for pool in nodePools: {
  poolName: pool.poolName
  vmCount: json(pool.vmCount)
  nodeRoles: contains(pool, 'nodeRoles') ? pool.nodeRoles : 'worker'
  vmSku: contains(pool, 'vmSku') ? pool.vmSku : vmSku
  dataDiskCountPerVm: contains(pool, 'dataDiskCountPerVm') ? pool.dataDiskCountPerVm : dataDiskCountPerVm
  dataDiskSizeTiB: contains(pool, 'dataDiskSizeTiB') ? pool.dataDiskSizeTiB : dataDiskSizeTiB
  dataDiskIOPSReadWrite: contains(pool, 'dataDiskIOPSReadWrite') ? pool.dataDiskIOPSReadWrite : dataDiskIOPSReadWrite
  dataDiskMBpsReadWrite: contains(pool, 'dataDiskMBpsReadWrite') ? pool.dataDiskMBpsReadWrite : dataDiskMBpsReadWrite
}]

var resolvedBastionHostName = empty(bastionHostName) ? '${namePrefix}-bastion' : bastionHostName
var resolvedBastionPublicIpName = empty(bastionPublicIpName) ? '${resolvedBastionHostName}-pip' : bastionPublicIpName

module network 'network.bicep' = {
  name: '${namePrefix}-network'
  params: {
    application: application
    location: location
    tags: tags
    networkTags: networkTags
    existingVnetId: existingVnetId
    existingSubnetId: existingSubnetId
    existingNsgId: existingNsgId
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    subnetName: subnetName
    subnetAddressPrefix: subnetAddressPrefix
    nsgName: nsgName
    allowedIngressPorts: allowedIngressPorts
    enableBastion: enableBastion
    bastionSubnetPrefix: bastionSubnetPrefix
    bastionHostName: resolvedBastionHostName
    bastionPublicIpName: resolvedBastionPublicIpName
    bastionPublicIpDnsLabel: bastionPublicIpDnsLabel
  }
}

module keyVault 'key-vault.bicep' = {
  name: '${namePrefix}-key-vault'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    kotsPassword: kotsPassword
    subnetResourceId: network.outputs.workloadSubnetId
  }
}

module loadBalancer 'load-balancer.bicep' = {
  name: '${namePrefix}-lb'
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    loadBalancerName: loadBalancerName
    publicIpName: loadBalancerPublicIpName
    publicIpDnsLabel: loadBalancerPublicIpDnsLabel
    lbPorts: loadBalancerPorts
    probePort: loadBalancerProbePort
    idleTimeoutMinutes: loadBalancerIdleTimeoutMinutes
  }
}

module controlPlane 'control-plane.bicep' = {
  name: 'control-plane'
  params: {
    namePrefix: namePrefix
    location: location
    vmCount: controlPlaneNodeCount
    vmSku: vmSku
    subnetResourceId: network.outputs.workloadSubnetId
    nsgId: network.outputs.nsgId
    backendPoolId: loadBalancer.outputs.backendPoolId
    imageReference: imageReference
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    dataDiskCountPerVm: dataDiskCountPerVm
    dataDiskSizeTiB: dataDiskSizeTiB
    dataDiskIOPSReadWrite: dataDiskIOPSReadWrite
    dataDiskMBpsReadWrite: dataDiskMBpsReadWrite
    enableSecureBoot: enableSecureBoot
    enableAcceleratedNetworking: enableAcceleratedNetworking
    tags: tags
    releaseChannel: releaseChannel
    application: application
    kotsPassword: keyVault.outputs.kotsSecretUri 
    license: license
  }
}

module nodePoolModules 'node-pool.bicep' = [for pool in resolvedNodePools: {
  name: '${namePrefix}-${pool.poolName}-pool'
  params: {
    location: location
    namePrefix: namePrefix
    poolName: pool.poolName
    vmCount: pool.vmCount
    vmSku: pool.vmSku
    subnetResourceId: network.outputs.workloadSubnetId
    nsgId: network.outputs.nsgId
    imageReference: imageReference
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    dataDiskCountPerVm: pool.dataDiskCountPerVm
    dataDiskSizeTiB: pool.dataDiskSizeTiB
    dataDiskIOPSReadWrite: pool.dataDiskIOPSReadWrite
    dataDiskMBpsReadWrite: pool.dataDiskMBpsReadWrite
    enableSecureBoot: enableSecureBoot
    enableAcceleratedNetworking: enableAcceleratedNetworking
    tags: tags
    nodeRoles: pool.nodeRoles
    kotsJoinIp: controlPlane.outputs.primaryPrivateIpAddress
    kotsPassword: keyVault.outputs.kotsSecretUri
  }
}]

@description('Names of all controller VMs.')
output controlPlaneNodeNames array = controlPlane.outputs.vmNames

@description('Primary private IP addresses of all controller VMs.')
output controlPlanePrivateIpAddresses array = controlPlane.outputs.vmPrivateIpAddresses

@description('Names of all node pool VMs, grouped by pool in the same order as nodePools.')
output nodePoolVmNames array = [
  for i in range(0, length(resolvedNodePools)): nodePoolModules[i].outputs.vmNames
]

@description('Primary private IP addresses of all node pool VMs, grouped by pool in the same order as nodePools.')
output nodePoolPrivateIpAddresses array = [
  for i in range(0, length(resolvedNodePools)): nodePoolModules[i].outputs.vmPrivateIpAddresses
]

@description('Load balancer public IP address.')
output loadBalancerPublicIpAddress string = loadBalancer.outputs.publicIpAddress

@description('Load balancer public FQDN.')
output loadBalancerPublicFqdn string = loadBalancer.outputs.publicFqdn

@description('VNet resource ID used for the cluster.')
output vnetId string = network.outputs.vnetId

@description('Subnet resource ID used for the cluster nodes.')
output workloadSubnetId string = network.outputs.workloadSubnetId

@description('NSG resource ID applied to node NICs.')
output nsgId string = network.outputs.nsgId

@description('Bastion host resource ID (empty when not enabled).')
output bastionHostId string = network.outputs.bastionHostId

@description('Bastion public IP address (empty when not enabled).')
output bastionPublicIpAddress string = network.outputs.bastionPublicIpAddress

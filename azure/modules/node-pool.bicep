targetScope = 'resourceGroup'

@description('Azure region for the control plane resources.')
param location string

@description('Name prefix used for all VMs in the node pool. VM names will be {prefix}-{poolName}-{n}.')
@minLength(1)
@maxLength(16)
param namePrefix string

@description('Node pool name formatted in after the name prefix used for all VMs. VM names will be {prefix}-{poolName}-{n}.')
@minLength(1)
@maxLength(8)
param poolName string

@description('Number of VMs to create in the pool.')
@minValue(1)
param vmCount int

@description('VM size/SKU to use for all node pool VMs.')
param vmSku string

@description('Resource ID of the subnet to attach node pool NICs to.')
param subnetResourceId string

@description('Resource ID of the Network Security Group (NSG) to associate with node pool NICs.')
param nsgId string

@description('Image reference for the node pool VMs.')
param imageReference object

@description('Admin username for all node pool VMs.')
param adminUsername string

@description('Resource ID of an existing Microsoft.Compute/sshPublicKeys resource containing the SSH public key to use for all VMs.')
param sshPublicKeyResourceId string

@description('Number of Premium SSD v2 data disks to attach to each node pool VM.')
param dataDiskCountPerVm int

@description('Size of each Premium SSD v2 data disk in TiB (1 TiB = 1024 GiB).')
param dataDiskSizeTiB int

@description('Provisioned disk IOPS for each Premium SSD v2 data disk.')
param dataDiskIOPSReadWrite int

@description('Provisioned disk throughput (MBps) for each Premium SSD v2 data disk.')
param dataDiskMBpsReadWrite int

@description('Enable Secure Boot on the node pool VMs.')
param enableSecureBoot bool

@description('Whether to attempt to enable Accelerated Networking on node pool NICs.')
param enableAcceleratedNetworking bool

@description('Tags to apply to resources created by this module.')
param tags object = {}

@description('KOTS Space-separated Node Roles')
param nodeRoles string = 'worker'

@description('KOTS Join IP Address')
param kotsJoinIp string

@secure()
@description('KOTS password')
param kotsPassword string

var zoneAssignments = pickZones('Microsoft.Compute', 'virtualMachines', location, vmCount)

var cloudInitNodesRaw = loadTextContent('cloud-init-nodes.yaml')
var cloudInitExtraControllerRendered = replace(
  replace(
    replace(
      replace(cloudInitNodesRaw, 'KOTS_URL', 'https://${kotsJoinIp}:30000'),
      'KOTS_PASSWORD', kotsPassword
    ),
    'NODE_ROLES', nodeRoles
  ),
  'ADMIN_USERNAME', adminUsername
)

module nodes 'node.bicep' = [for i in range(0, vmCount): {
  name: '${namePrefix}-${poolName}-${i}'
  params: {
    namePrefix: namePrefix
    poolName: poolName
    vmIndex: i
    location: location
    vmSku: vmSku
    subnetResourceId: subnetResourceId
    nsgId: nsgId
    imageReference: imageReference
    adminUsername: adminUsername
    sshPublicKeyResourceId: sshPublicKeyResourceId
    cloudInitData: cloudInitExtraControllerRendered
    dataDiskCount: dataDiskCountPerVm
    dataDiskSizeTiB: dataDiskSizeTiB
    dataDiskIOPSReadWrite: dataDiskIOPSReadWrite
    dataDiskMBpsReadWrite: dataDiskMBpsReadWrite
    enableSecureBoot: enableSecureBoot
    enableAcceleratedNetworking: enableAcceleratedNetworking
    zone: zoneAssignments[i]
    createPublicIp: false
    tags: tags
  }
}]

@description('Names of all node pool VMs.')
output vmNames array = [
  for i in range(0, vmCount): nodes[i].outputs.vmName
]

@description('Primary private IP addresses of all node pool VMs.')
output vmPrivateIpAddresses array = [
  for i in range(0, vmCount): nodes[i].outputs.privateIpAddress
]

@description('Availability Zones used for each node pool VM.')
output vmZones array = [
  for i in range(0, vmCount): nodes[i].outputs.zone
]

@description('Resource IDs of Premium SSD v2 data disks, grouped per node pool VM.')
output dataDiskIdsPerVm array = [
  for i in range(0, vmCount): nodes[i].outputs.dataDiskIds
]

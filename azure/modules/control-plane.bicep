targetScope = 'resourceGroup'

@description('Azure region for the control plane resources.')
param location string

@description('Name prefix used for all controller VMs. VM names will be {prefix}-controller-{n}.')
@minLength(1)
@maxLength(16)
param namePrefix string

@description('Number of controller VMs to create.')
@minValue(1)
param vmCount int = 3

@description('VM size/SKU to use for all controller nodes.')
param vmSku string

@description('Resource ID of the subnet to attach controller NICs to.')
param subnetResourceId string

@description('Resource ID of the Network Security Group (NSG) to associate with controller NICs.')
param nsgId string

@description('Optional load balancer backend pool ID to associate with controller NICs.')
param backendPoolId string = ''

@description('Image reference for the controller VMs.')
param imageReference object

@description('Admin username for all controller VMs.')
param adminUsername string

@description('Resource ID of an existing Microsoft.Compute/sshPublicKeys resource containing the SSH public key to use for all VMs.')
param sshPublicKeyResourceId string

@description('Number of Premium SSD v2 data disks to attach to each controller VM.')
param dataDiskCountPerVm int

@description('Size of each Premium SSD v2 data disk in TiB (1 TiB = 1024 GiB).')
param dataDiskSizeTiB int

@description('Provisioned disk IOPS for each Premium SSD v2 data disk.')
param dataDiskIOPSReadWrite int

@description('Provisioned disk throughput (MBps) for each Premium SSD v2 data disk.')
param dataDiskMBpsReadWrite int

@description('Enable Secure Boot on the controller VMs.')
param enableSecureBoot bool

@description('Whether to attempt to enable Accelerated Networking on controller NICs.')
param enableAcceleratedNetworking bool

@description('Tags to apply to resources created by this module.')
param tags object = {}

@description('Replicated release channel')
param releaseChannel string = 'development'

@description('Replicated application name')
param application string

@secure()
param license string

@secure()
@description('KOTS password')
param kotsPassword string

var zoneAssignments = pickZones('Microsoft.Compute', 'virtualMachines', location, vmCount)

var cloudInitControllerRaw = loadTextContent('cloud-init-controller.yaml')
var cloudInitPrimaryControllerRendered = replace(
  replace(
    replace(
      replace(
        replace(cloudInitControllerRaw, 'RELEASE_CHANNEL', releaseChannel),
        'KOTS_PASSWORD', kotsPassword
      ),
      'APPLICATION', application
    ),
    'ADMIN_USERNAME', adminUsername
  ),
  'LICENSE_BASE64', license
)

module primaryController 'node.bicep' = {
  name: '${namePrefix}-controller-0'
  params: {
    namePrefix: namePrefix
    poolName: 'controller'
    vmIndex: 0
    location: location
    vmSku: vmSku
    subnetResourceId: subnetResourceId
    nsgId: nsgId
    imageReference: imageReference
    adminUsername: adminUsername
    sshPublicKeyResourceId: sshPublicKeyResourceId
    cloudInitData: cloudInitPrimaryControllerRendered
    dataDiskCount: dataDiskCountPerVm
    dataDiskSizeTiB: dataDiskSizeTiB
    dataDiskIOPSReadWrite: dataDiskIOPSReadWrite
    dataDiskMBpsReadWrite: dataDiskMBpsReadWrite
    enableSecureBoot: enableSecureBoot
    enableAcceleratedNetworking: enableAcceleratedNetworking
    zone: zoneAssignments[0]
    createPublicIp: false
    backendPoolId: backendPoolId
    tags: tags
  }
}

var cloudInitNodesRaw = loadTextContent('cloud-init-nodes.yaml')
var cloudInitExtraControllerRendered = replace(
  replace(
    replace(
      replace(cloudInitNodesRaw, 'KOTS_URL', 'https://${primaryController.outputs.privateIpAddress}:30000'),
      'KOTS_PASSWORD', kotsPassword
    ),
    'NODE_ROLES', 'controller'
  ),
  'ADMIN_USERNAME', adminUsername
)

module extraControllerNodes 'node.bicep' = [for i in range(1, vmCount - 1): {
  name: '${namePrefix}-controller-${i}'
  params: {
    namePrefix: namePrefix
    poolName: 'controller'
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
    backendPoolId: backendPoolId
    tags: tags
  }
}]

@description('Name of the primary controller VM.')
output primaryVmName string = primaryController.outputs.vmName

@description('Primary private IP address of the primary controller VM.')
output primaryPrivateIpAddress string = primaryController.outputs.privateIpAddress

@description('Names of all controller VMs.')
output vmNames array = [
  for i in range(0, vmCount): i == 0
    ? primaryController.outputs.vmName
    : extraControllerNodes[i - 1].outputs.vmName
]

@description('Primary private IP addresses of all controller VMs.')
output vmPrivateIpAddresses array = [
  for i in range(0, vmCount): i == 0
    ? primaryController.outputs.privateIpAddress
    : extraControllerNodes[i - 1].outputs.privateIpAddress
]

@description('Availability Zones used for each controller VM.')
output vmZones array = [
  for i in range(0, vmCount): i == 0
    ? primaryController.outputs.zone
    : extraControllerNodes[i - 1].outputs.zone
]

@description('Resource IDs of Premium SSD v2 data disks, grouped per controller VM.')
output dataDiskIdsPerVm array = [
  for i in range(0, vmCount): i == 0
    ? primaryController.outputs.dataDiskIds
    : extraControllerNodes[i - 1].outputs.dataDiskIds
]

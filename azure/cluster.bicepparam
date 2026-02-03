using './modules/cluster.bicep'

param namePrefix = ''
param location = 'centralus'
param controlPlaneNodeCount = 1
param vmSku = 'Standard_D2ds_v4'

param vnetName = ''
param subnetName = ''
param nsgName = ''

param enableSecureBoot = false
param enableAcceleratedNetworking = true
param adminUsername = 'ubuntu'
param sshPublicKeyResourceId = ''
param dataDiskCountPerVm = 1
param dataDiskSizeTiB = 1
param dataDiskIOPSReadWrite = 6000
param dataDiskMBpsReadWrite = 300
param nodePools = [
  {
    poolName: 'gpu'
    vmCount: 1
    vmSku: 'Standard_NC4as_T4_v3'
    dataDiskCountPerVm: 0
    nodeRoles: 'gpu'
  }
]
param tags = {
  User: ''
}

param enableBastion = true

param application = 'apptest'
param releaseChannel = 'unstable'
param kotsPassword = ''

param imageReference = {
  id: ''
}

param license = loadFileAsBase64('./license.yaml')

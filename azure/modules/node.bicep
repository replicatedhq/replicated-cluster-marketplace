targetScope = 'resourceGroup'

@description('Base name prefix to use for the controller VMs. The full VM name will be {prefix}-controller-{index}.')
param namePrefix string

@description('Node pool name formatted in after the name prefix used for all VMs. VM names will be {prefix}-{poolName}-{n}.')
@minLength(1)
@maxLength(10)
param poolName string

@description('Zero-based index of this VM instance within the cluster.')
param vmIndex int

@description('Azure region for all resources in this node.')
param location string

@description('Size/SKU of the virtual machine (e.g. Standard_D8as_v6).')
param vmSku string

@description('Resource ID of an existing subnet where the NIC will be attached.')
param subnetResourceId string

@description('Optional resource ID of an existing network security group (NSG) to associate with the NIC.')
param nsgId string

@description('Image reference used for the VM. Must contain publisher, offer, sku, and version.')
param imageReference object

@description('Admin username for the VM.')
param adminUsername string

@description('SSH Public Key')
param sshPublicKey string

@description('Cloud-Init file contents.')
param cloudInitData string = ''

@description('Number of Premium SSD v2 data disks to attach to this VM.')
param dataDiskCount int

@description('Size of each Premium SSD v2 data disk in TiB (1 TiB = 1024 GiB).')
param dataDiskSizeTiB int

@description('Provisioned disk IOPS for each Premium SSD v2 data disk.')
param dataDiskIOPSReadWrite int

@description('Provisioned disk throughput (MBps) for each Premium SSD v2 data disk.')
param dataDiskMBpsReadWrite int

@description('Whether to enable Trusted Launch with Secure Boot on the VM.')
param enableSecureBoot bool

@description('Whether to attempt to enable Accelerated Networking on the NIC. Deployment will fail if the selected VM size or region does not support it.')
param enableAcceleratedNetworking bool

@description('Availability zone to place this VM and its data disks in (e.g. "1", "2", "3").')
param zone string

@description('Tags to apply to resources created for this node.')
param tags object

@description('Whether to create and associate a public IP (with FQDN) to this VM NIC.')
param createPublicIp bool = false

@description('Optional load balancer backend pool ID to associate with the NIC.')
param backendPoolId string = ''

// Derived names and sizes
var vmName = '${namePrefix}-${poolName}-${vmIndex}'
var nicName = '${vmName}-nic0'
var osDiskName = '${vmName}-osdisk'
var publicIpName = '${vmName}-pip'

// Use vmName (lowercased) as the DNS label for the public IP.
// Resulting FQDN will be {publicIpDnsLabel}.{location}.cloudapp.azure.com
var publicIpDnsLabel = toLower(vmName)

var backendPoolAssociation = empty(backendPoolId) ? [] : [
  {
    id: backendPoolId
  }
]

// Convert TiB -> GiB for diskSizeGB
// Assumption: 1 TiB = 1024 GiB
var dataDiskSizeGiB = dataDiskSizeTiB * 1024

// Premium SSD v2 data disks (zonal, LRS)
resource dataDisks 'Microsoft.Compute/disks@2025-01-02' = [for i in range(0, dataDiskCount): {
  name: '${vmName}-osd-${i}'
  location: location
  zones: [
    zone
  ]
  sku: {
    name: 'PremiumV2_LRS'
  }
  properties: {
    // Empty raw disk attached to the VM
    creationData: {
      createOption: 'Empty'
    }

    // Not that the effective performance is still capped by VM SKU limits.
    diskSizeGB: dataDiskSizeGiB
    diskIOPSReadWrite: dataDiskIOPSReadWrite
    diskMBpsReadWrite: dataDiskMBpsReadWrite
  }
  tags: tags
}]

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (createPublicIp) {
  name: publicIpName
  location: location
  zones: [
    zone
  ]
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: publicIpDnsLabel
    }
  }
  tags: tags
}

resource primaryNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: enableAcceleratedNetworking
    ipConfigurations: [
      createPublicIp ? {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetResourceId
          }
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          primary: true
          loadBalancerBackendAddressPools: backendPoolAssociation
          publicIPAddress: {
            id: publicIp.id
          }
        }
      } : {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetResourceId
          }
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          primary: true
          loadBalancerBackendAddressPools: backendPoolAssociation
        }
      }
    ]
    networkSecurityGroup: empty(nsgId) ? {} : {
      id: nsgId
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  zones: [
    zone
  ]
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSku
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      customData: base64(cloudInitData)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: osDiskName
        osType: 'Linux'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        deleteOption: 'Delete'
        diskSizeGB: 128
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [for i in range(0, dataDiskCount): {
        lun: i
        name: dataDisks[i].name
        createOption: 'Attach'
        managedDisk: {
          id: dataDisks[i].id
        }
        // Ceph OSD best practice: no host caching.
        caching: 'None'
        deleteOption: 'Delete'
      }]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: primaryNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: enableSecureBoot
        vTpmEnabled: true
      }
    }
  }
}

var secretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User 

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vmName, secretsUserRoleId)
  properties: {
    principalId: vm.identity.principalId
    roleDefinitionId: secretsUserRoleId
  }
}

@description('Name of the VM representing this node.')
output vmName string = vm.name

@description('Primary private IP address of the VM NIC.')
output privateIpAddress string = primaryNic.properties.ipConfigurations[0].properties.privateIPAddress

@description('Public IP resource ID attached to this VM (empty when createPublicIp = false).')
output publicIpId string = createPublicIp ? publicIp.id : ''

@description('Public IPv4 address of this VM (empty until allocation completes or when createPublicIp = false).')
output publicIpAddress string = createPublicIp ? publicIp.properties.ipAddress : ''

@description('Public FQDN of this VM (empty when createPublicIp = false).')
output publicFqdn string = createPublicIp ? publicIp.properties.dnsSettings.fqdn : ''

@description('Availability Zone of the VM.')
output zone string = zone

@description('Resource IDs of Premium SSD v2 data disks attached to this VM.')
output dataDiskIds array = [for i in range(0, dataDiskCount): dataDisks[i].id]

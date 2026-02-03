targetScope = 'resourceGroup'

@description('Azure region for the load balancer and public IP.')
param location string

@description('Name prefix used for derived load balancer resource names.')
param namePrefix string

@description('Tags to apply to load balancer resources.')
param tags object = {}

@description('Optional override for the load balancer name.')
param loadBalancerName string = ''

@description('Optional override for the load balancer public IP name.')
param publicIpName string = ''

@description('Optional DNS label for the load balancer public IP.')
param publicIpDnsLabel string = ''

@description('Ports to expose through the public load balancer.')
param lbPorts array = [
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
param probePort int = 30000

@description('Idle timeout in minutes for load balancer rules.')
param idleTimeoutMinutes int = 15

@description('Frontend IP configuration name for the load balancer.')
param frontendConfigName string = 'public-frontend'

@description('Backend pool name for the load balancer.')
param backendPoolName string = 'primary-backend'

@description('Probe name for the load balancer.')
param probeNamePrefix string = 'tcp-probe'

var effectiveLbName = empty(loadBalancerName) ? '${namePrefix}-lb' : loadBalancerName
var effectivePublicIpName = empty(publicIpName) ? '${effectiveLbName}-pip' : publicIpName
var effectiveDnsLabel = empty(publicIpDnsLabel) ? toLower(effectiveLbName) : publicIpDnsLabel

var frontendConfigId = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', effectiveLbName, frontendConfigName)
var backendPoolId = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', effectiveLbName, backendPoolName)

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: effectivePublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: effectiveDnsLabel
    }
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: effectiveLbName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: frontendConfigName
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    probes: [
      for port in lbPorts: {
        name: '${probeNamePrefix}-${port}'
        properties: {
          protocol: 'Tcp'
          port: probePort
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [for port in lbPorts: {
      name: 'tcp-${port}'
      properties: {
        protocol: 'Tcp'
        frontendPort: port
        backendPort: port
        enableFloatingIP: false
        idleTimeoutInMinutes: idleTimeoutMinutes
        loadDistribution: 'Default'
        frontendIPConfiguration: {
          id: frontendConfigId
        }
        backendAddressPool: {
          id: backendPoolId
        }
        probe: {
          id: resourceId('Microsoft.Network/loadBalancers/probes', effectiveLbName, '${probeNamePrefix}-${port}')
        }
      }
    }]
  }
}

output publicIpAddress string = publicIp.properties.ipAddress
output publicFqdn string = publicIp.properties.dnsSettings.fqdn
output publicIpId string = publicIp.id
output loadBalancerId string = loadBalancer.id
output backendPoolId string = backendPoolId

@description('Name of the Microsoft Foundry resource')
param foundryName string

@description('Location for Microsoft Foundry')
param location string = resourceGroup().location

@description('SKU for Microsoft Foundry')
@allowed([
  'Standard'
  'Premium'
])
param sku string = 'Standard'

@description('Tags to apply to the resource')
param tags object = {}

@description('AI model deployments')
param deployments array = [
  {
    name: 'gpt-4'
    model: {
      format: 'OpenAI'
      name: 'gpt-4'
      version: '0613'
    }
    sku: {
      name: 'Standard'
      capacity: 10
    }
  }
  {
    name: 'phi-3'
    model: {
      format: 'OpenAI'
      name: 'phi-3'
      version: 'latest'
    }
    sku: {
      name: 'Standard'
      capacity: 10
    }
  }
]

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: foundryName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: sku == 'Premium' ? 'S0' : 'S0'
  }
  properties: {
    customSubDomainName: foundryName
    publicNetworkAccess: 'Enabled'
  }
}

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: cognitiveServices
  name: deployment.name
  sku: deployment.sku
  properties: {
    model: deployment.model
  }
}]

output foundryId string = cognitiveServices.id
output foundryName string = cognitiveServices.name
output foundryEndpoint string = cognitiveServices.properties.endpoint

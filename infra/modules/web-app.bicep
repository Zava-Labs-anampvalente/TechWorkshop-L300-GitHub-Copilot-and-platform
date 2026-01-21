@description('Name of the Web App')
param webAppName string

@description('Location for the Web App')
param location string = resourceGroup().location

@description('App Service Plan ID')
param appServicePlanId string

@description('ACR Login Server')
param acrLoginServer string

@description('Docker image and tag')
param dockerImageAndTag string = 'zavastorefront:latest'

@description('Application Insights Connection String')
param appInsightsConnectionString string = ''

@description('Tags to apply to the resource')
param tags object = {}

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/${dockerImageAndTag}'
      acrUseManagedIdentityCreds: true
      alwaysOn: true
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrLoginServer}'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
      ]
    }
  }
}

output webAppId string = webApp.id
output webAppName string = webApp.name
output webAppPrincipalId string = webApp.identity.principalId
output webAppDefaultHostName string = webApp.properties.defaultHostName

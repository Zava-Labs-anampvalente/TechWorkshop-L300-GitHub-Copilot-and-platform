targetScope = 'resourceGroup'

@description('Environment name')
@minLength(1)
@maxLength(64)
param environmentName string

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Application name')
param appName string = 'zavastorefront'

@description('Docker image and tag')
param dockerImageAndTag string = 'zavastorefront:latest'

@description('ACR SKU')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Basic'

@description('App Service Plan SKU')
@allowed([
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
])
param appServicePlanSku string = 'B1'

@description('Microsoft Foundry SKU')
@allowed([
  'Standard'
  'Premium'
])
param foundrySku string = 'Standard'

@description('Deploy Microsoft Foundry')
param deployFoundry bool = true

// Variables for resource naming
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  'environment': 'dev'
  'application': appName
}

// Resource names
var acrName = 'acr${resourceToken}'
var appServicePlanName = 'asp-${appName}-${environmentName}-${resourceToken}'
var webAppName = 'app-${appName}-${environmentName}-${resourceToken}'
var logAnalyticsName = 'log-${appName}-${environmentName}-${resourceToken}'
var appInsightsName = 'appi-${appName}-${environmentName}-${resourceToken}'
var foundryName = 'cog-${appName}-${environmentName}-${resourceToken}'

// AcrPull role definition ID
var acrPullRoleDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

// Deploy Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics-deployment'
  params: {
    workspaceName: logAnalyticsName
    location: location
    tags: tags
  }
}

// Deploy Application Insights
module appInsights 'modules/app-insights.bicep' = {
  name: 'app-insights-deployment'
  params: {
    appInsightsName: appInsightsName
    location: location
    workspaceId: logAnalytics.outputs.workspaceId
    tags: tags
  }
}

// Deploy Azure Container Registry
module acr 'modules/container-registry.bicep' = {
  name: 'acr-deployment'
  params: {
    acrName: acrName
    location: location
    sku: acrSku
    tags: tags
  }
}

// Deploy App Service Plan
module appServicePlan 'modules/app-service-plan.bicep' = {
  name: 'app-service-plan-deployment'
  params: {
    appServicePlanName: appServicePlanName
    location: location
    sku: appServicePlanSku
    tags: tags
  }
}

// Deploy Web App
module webApp 'modules/web-app.bicep' = {
  name: 'web-app-deployment'
  params: {
    webAppName: webAppName
    location: location
    appServicePlanId: appServicePlan.outputs.appServicePlanId
    acrLoginServer: acr.outputs.acrLoginServer
    dockerImageAndTag: dockerImageAndTag
    appInsightsConnectionString: appInsights.outputs.appInsightsConnectionString
    tags: tags
  }
}

// Assign AcrPull role to Web App managed identity
module acrPullRoleAssignment 'modules/role-assignment.bicep' = {
  name: 'acr-pull-role-assignment'
  params: {
    principalId: webApp.outputs.webAppPrincipalId
    roleDefinitionId: acrPullRoleDefinitionId
    resourceId: acr.outputs.acrId
  }
}

// Deploy Microsoft Foundry (optional)
module foundry 'modules/foundry.bicep' = if (deployFoundry) {
  name: 'foundry-deployment'
  params: {
    foundryName: foundryName
    location: location
    sku: foundrySku
    tags: tags
  }
}

// Outputs
output resourceGroupName string = resourceGroup().name
output location string = location
output environmentName string = environmentName

output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.acrLoginServer

output webAppName string = webApp.outputs.webAppName
output webAppUrl string = 'https://${webApp.outputs.webAppDefaultHostName}'

output appInsightsName string = appInsights.outputs.appInsightsName
output appInsightsConnectionString string = appInsights.outputs.appInsightsConnectionString

output foundryName string = deployFoundry ? foundry.outputs.foundryName : ''
output foundryEndpoint string = deployFoundry ? foundry.outputs.foundryEndpoint : ''

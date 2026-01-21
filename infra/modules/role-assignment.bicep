@description('Principal ID that will be granted the role')
param principalId string

@description('Role Definition ID to assign')
param roleDefinitionId string

@description('Resource ID where the role assignment will be applied')
param resourceId string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceId, principalId, roleDefinitionId)
  scope: resourceGroup()
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id

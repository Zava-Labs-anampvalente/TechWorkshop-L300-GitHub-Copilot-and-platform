#!/bin/bash

# Azure Infrastructure Deployment Validation Script
# This script validates that all required Azure resources are deployed correctly

set -e

echo "🔍 Validating Azure Infrastructure Deployment..."
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in
if ! az account show &> /dev/null; then
    echo "❌ Not logged in to Azure. Please run 'az login'"
    exit 1
fi

echo "✅ Azure CLI is installed and logged in"
echo ""

# Get resource group name (assuming naming convention)
RG_NAME="${1:-rg-zavastore-dev-westus3}"

echo "🔍 Checking resource group: $RG_NAME"
if ! az group show --name "$RG_NAME" &> /dev/null; then
    echo "❌ Resource group '$RG_NAME' not found"
    echo "   Please provision the infrastructure first with 'azd provision'"
    exit 1
fi
echo "✅ Resource group exists"
echo ""

# Check ACR
echo "🔍 Checking Azure Container Registry..."
ACR_NAME=$(az acr list --resource-group "$RG_NAME" --query "[0].name" -o tsv)
if [ -z "$ACR_NAME" ]; then
    echo "❌ Azure Container Registry not found"
    exit 1
fi
echo "✅ ACR found: $ACR_NAME"

# Check if ACR has admin user disabled (security best practice)
ADMIN_ENABLED=$(az acr show --name "$ACR_NAME" --query "adminUserEnabled" -o tsv)
if [ "$ADMIN_ENABLED" = "true" ]; then
    echo "⚠️  Warning: ACR admin user is enabled (not recommended for production)"
else
    echo "✅ ACR admin user is disabled (security best practice)"
fi
echo ""

# Check App Service Plan
echo "🔍 Checking App Service Plan..."
ASP_NAME=$(az appservice plan list --resource-group "$RG_NAME" --query "[0].name" -o tsv)
if [ -z "$ASP_NAME" ]; then
    echo "❌ App Service Plan not found"
    exit 1
fi
echo "✅ App Service Plan found: $ASP_NAME"

# Check if it's Linux
ASP_KIND=$(az appservice plan show --name "$ASP_NAME" --resource-group "$RG_NAME" --query "kind" -o tsv)
if [[ "$ASP_KIND" == *"linux"* ]]; then
    echo "✅ App Service Plan is Linux-based"
else
    echo "❌ App Service Plan is not Linux-based"
    exit 1
fi
echo ""

# Check Web App
echo "🔍 Checking Web App..."
WEB_APP_NAME=$(az webapp list --resource-group "$RG_NAME" --query "[0].name" -o tsv)
if [ -z "$WEB_APP_NAME" ]; then
    echo "❌ Web App not found"
    exit 1
fi
echo "✅ Web App found: $WEB_APP_NAME"

# Check if managed identity is enabled
IDENTITY_TYPE=$(az webapp identity show --name "$WEB_APP_NAME" --resource-group "$RG_NAME" --query "type" -o tsv 2>/dev/null)
if [ "$IDENTITY_TYPE" = "SystemAssigned" ]; then
    echo "✅ System-assigned managed identity is enabled"
    PRINCIPAL_ID=$(az webapp identity show --name "$WEB_APP_NAME" --resource-group "$RG_NAME" --query "principalId" -o tsv)
    echo "   Principal ID: $PRINCIPAL_ID"
else
    echo "❌ System-assigned managed identity is not enabled"
    exit 1
fi

# Check if HTTPS only is enabled
HTTPS_ONLY=$(az webapp show --name "$WEB_APP_NAME" --resource-group "$RG_NAME" --query "httpsOnly" -o tsv)
if [ "$HTTPS_ONLY" = "true" ]; then
    echo "✅ HTTPS only is enabled"
else
    echo "⚠️  Warning: HTTPS only is not enabled"
fi

# Get Web App URL
WEB_APP_URL=$(az webapp show --name "$WEB_APP_NAME" --resource-group "$RG_NAME" --query "defaultHostName" -o tsv)
echo "🌐 Web App URL: https://$WEB_APP_URL"
echo ""

# Check Application Insights
echo "🔍 Checking Application Insights..."
APPI_NAME=$(az monitor app-insights component list --resource-group "$RG_NAME" --query "[0].name" -o tsv)
if [ -z "$APPI_NAME" ]; then
    echo "❌ Application Insights not found"
    exit 1
fi
echo "✅ Application Insights found: $APPI_NAME"

# Check if App Insights is configured in Web App
APPI_CONN_STRING=$(az webapp config appsettings list --name "$WEB_APP_NAME" --resource-group "$RG_NAME" --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].value" -o tsv)
if [ -n "$APPI_CONN_STRING" ]; then
    echo "✅ Application Insights is configured in Web App"
else
    echo "⚠️  Warning: Application Insights connection string not configured in Web App"
fi
echo ""

# Check Log Analytics Workspace
echo "🔍 Checking Log Analytics Workspace..."
LAW_NAME=$(az monitor log-analytics workspace list --resource-group "$RG_NAME" --query "[0].name" -o tsv)
if [ -z "$LAW_NAME" ]; then
    echo "❌ Log Analytics Workspace not found"
    exit 1
fi
echo "✅ Log Analytics Workspace found: $LAW_NAME"
echo ""

# Check Microsoft Foundry (Cognitive Services)
echo "🔍 Checking Microsoft Foundry (Cognitive Services)..."
FOUNDRY_NAME=$(az cognitiveservices account list --resource-group "$RG_NAME" --query "[?kind=='OpenAI'].name" -o tsv)
if [ -z "$FOUNDRY_NAME" ]; then
    echo "⚠️  Microsoft Foundry (OpenAI) not found (optional)"
else
    echo "✅ Microsoft Foundry found: $FOUNDRY_NAME"
    FOUNDRY_ENDPOINT=$(az cognitiveservices account show --name "$FOUNDRY_NAME" --resource-group "$RG_NAME" --query "properties.endpoint" -o tsv)
    echo "   Endpoint: $FOUNDRY_ENDPOINT"
fi
echo ""

# Check role assignments
echo "🔍 Checking role assignments..."
ACR_ID=$(az acr show --name "$ACR_NAME" --query "id" -o tsv)
ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$PRINCIPAL_ID" --scope "$ACR_ID" --query "[?roleDefinitionName=='AcrPull'].roleDefinitionName" -o tsv)
if [ -n "$ROLE_ASSIGNMENTS" ]; then
    echo "✅ AcrPull role is assigned to Web App managed identity"
else
    echo "❌ AcrPull role is NOT assigned to Web App managed identity"
    echo "   This is required for the Web App to pull images from ACR"
    exit 1
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Infrastructure Validation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   Resource Group: $RG_NAME"
echo "   ACR: $ACR_NAME"
echo "   Web App: $WEB_APP_NAME"
echo "   Web App URL: https://$WEB_APP_URL"
echo "   Application Insights: $APPI_NAME"
echo "   Log Analytics: $LAW_NAME"
if [ -n "$FOUNDRY_NAME" ]; then
    echo "   Microsoft Foundry: $FOUNDRY_NAME"
fi
echo ""
echo "🚀 Next steps:"
echo "   1. Build and push container image:"
echo "      az acr build --registry $ACR_NAME --image zavastorefront:latest --file ./src/Dockerfile ./src"
echo ""
echo "   2. Restart the Web App:"
echo "      az webapp restart --name $WEB_APP_NAME --resource-group $RG_NAME"
echo ""
echo "   3. Access the application:"
echo "      https://$WEB_APP_URL"
echo ""

#!/bin/bash

# Quick deployment script for ZavaStorefront
# This script provisions infrastructure and deploys the application

set -e

echo "🚀 ZavaStorefront Deployment Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if azd is installed
if ! command -v azd &> /dev/null; then
    echo "❌ Azure Developer CLI (azd) is not installed"
    echo "   Please install from: https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd"
    exit 1
fi

# Check if az is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed"
    echo "   Please install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

echo "✅ Prerequisites checked"
echo ""

# Check if logged in
echo "🔍 Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "⚠️  Not logged in to Azure"
    echo "   Logging in..."
    az login
fi

if ! azd auth login --check-status &> /dev/null; then
    echo "⚠️  Not logged in to Azure Developer CLI"
    echo "   Logging in..."
    azd auth login
fi

echo "✅ Authenticated with Azure"
echo ""

# Initialize azd environment if not exists
if [ ! -f ".azure/config.json" ]; then
    echo "📝 Initializing Azure Developer CLI environment..."
    azd init
fi

echo ""
echo "1️⃣  Provisioning Azure infrastructure..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
azd provision

echo ""
echo "2️⃣  Building and pushing container image..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get ACR name from azd environment
ACR_NAME=$(azd env get-values | grep ACR_NAME | cut -d'=' -f2 | tr -d '"' || true)

if [ -z "$ACR_NAME" ]; then
    echo "⚠️  Could not get ACR name from azd environment"
    echo "   Searching for ACR in resource group..."
    RG_NAME=$(azd env get-values | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"' || echo "rg-zavastore-dev-westus3")
    ACR_NAME=$(az acr list --resource-group "$RG_NAME" --query "[0].name" -o tsv)
fi

if [ -z "$ACR_NAME" ]; then
    echo "❌ Could not find ACR name"
    exit 1
fi

echo "   Using ACR: $ACR_NAME"

# Build and push image
az acr build \
    --registry "$ACR_NAME" \
    --image zavastorefront:latest \
    --file ./src/Dockerfile \
    ./src

echo ""
echo "3️⃣  Restarting Web App..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WEB_APP_NAME=$(azd env get-values | grep SERVICE_WEB_NAME | cut -d'=' -f2 | tr -d '"' || true)

if [ -z "$WEB_APP_NAME" ]; then
    RG_NAME=$(azd env get-values | grep AZURE_RESOURCE_GROUP | cut -d'=' -f2 | tr -d '"' || echo "rg-zavastore-dev-westus3")
    WEB_APP_NAME=$(az webapp list --resource-group "$RG_NAME" --query "[0].name" -o tsv)
fi

if [ -z "$WEB_APP_NAME" ]; then
    echo "❌ Could not find Web App name"
    exit 1
fi

echo "   Restarting: $WEB_APP_NAME"
RG_NAME=$(az webapp show --name "$WEB_APP_NAME" --query "resourceGroup" -o tsv)
az webapp restart --name "$WEB_APP_NAME" --resource-group "$RG_NAME"

echo ""
echo "✅ Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get Web App URL
WEB_APP_URL=$(az webapp show --name "$WEB_APP_NAME" --query "defaultHostName" -o tsv)
echo "🌐 Application URL: https://$WEB_APP_URL"
echo ""
echo "📊 View logs:"
echo "   az webapp log tail --name $WEB_APP_NAME --resource-group $RG_NAME"
echo ""
echo "🔍 Validate deployment:"
echo "   ./scripts/validate-deployment.sh $RG_NAME"
echo ""

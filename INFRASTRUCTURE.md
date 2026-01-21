# ZavaStorefront - Azure Infrastructure Deployment Guide

## Overview

This guide covers the provisioning and deployment of the ZavaStorefront web application to Azure using Infrastructure as Code (Bicep) and Azure Developer CLI (azd).

## Architecture

The infrastructure includes:
- **Azure Container Registry (ACR)**: Stores container images with no password-based authentication
- **Linux App Service (Web App for Containers)**: Hosts the containerized application
- **System-Assigned Managed Identity**: Enables secure, password-less ACR pulls with AcrPull role
- **Application Insights**: Provides monitoring and telemetry
- **Microsoft Foundry (Cognitive Services)**: Offers GPT-4 and Phi-3 AI model access
- **Log Analytics Workspace**: Centralized logging for Application Insights

All resources are provisioned in **westus3** region into a single resource group for the dev environment.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (version 2.50 or later)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- Azure subscription with appropriate permissions to create resources
- [.NET 6.0 SDK](https://dotnet.microsoft.com/download/dotnet/6.0) (for local development)

## Quick Start

### 1. Login to Azure

```bash
# Login with Azure CLI
az login

# Login with Azure Developer CLI
azd auth login
```

### 2. Provision Infrastructure

Using Azure Developer CLI (recommended):

```bash
# Initialize the environment (first time only)
azd init

# Set environment name
azd env new dev

# Provision all Azure resources
azd provision

# This will:
# - Create a resource group in westus3
# - Deploy all infrastructure using Bicep templates
# - Build and push the Docker image to ACR using cloud-side build
# - Configure the Web App with managed identity
```

### 3. Deploy Application

```bash
azd deploy
```

### 4. Access the Application

```bash
# Get the Web App URL
azd env get-values | grep WEB_APP_URL
```

## Manual Deployment (Alternative)

### Using Azure CLI Directly

```bash
# 1. Create resource group
az group create --name rg-zavastore-dev-westus3 --location westus3

# 2. Deploy Bicep template
az deployment group create \
  --resource-group rg-zavastore-dev-westus3 \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json

# 3. Build and push image to ACR (cloud-side build, no local Docker required)
ACR_NAME=$(az acr list --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)
az acr build --registry $ACR_NAME --image zavastorefront:latest --file ./src/Dockerfile ./src

# 4. Get the Web App URL
WEB_APP_NAME=$(az webapp list --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)
az webapp show --name $WEB_APP_NAME --resource-group rg-zavastore-dev-westus3 --query "defaultHostName" -o tsv
```

## Infrastructure Structure

```
infra/
├── main.bicep                      # Main orchestration template
├── main.parameters.json            # Environment-specific parameters
└── modules/
    ├── container-registry.bicep    # Azure Container Registry
    ├── app-service-plan.bicep      # App Service Plan (Linux)
    ├── web-app.bicep               # Web App for Containers
    ├── app-insights.bicep          # Application Insights
    ├── log-analytics.bicep         # Log Analytics Workspace
    ├── foundry.bicep               # Microsoft Foundry (Cognitive Services)
    └── role-assignment.bicep       # RBAC role assignments
```

## Configuration Parameters

Edit `infra/main.parameters.json` to customize:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `environmentName` | Environment name (dev, staging, prod) | `dev` |
| `location` | Azure region | `westus3` |
| `appName` | Application name | `zavastorefront` |
| `acrSku` | ACR SKU (Basic, Standard, Premium) | `Basic` |
| `appServicePlanSku` | App Service Plan SKU | `B1` |
| `foundrySku` | Microsoft Foundry SKU | `Standard` |
| `deployFoundry` | Deploy Microsoft Foundry | `true` |

## CI/CD with GitHub Actions

The repository includes a GitHub Actions workflow (`.github/workflows/acr-build.yml`) that:
1. Builds the Docker image using ACR cloud build (no local Docker required)
2. Pushes the image to Azure Container Registry
3. Updates the Web App to use the new image
4. Restarts the Web App

### Setting up GitHub Actions

Configure the following GitHub secrets:
- `AZURE_CLIENT_ID`: Service Principal client ID
- `AZURE_TENANT_ID`: Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID

Set up federated identity credentials for OIDC authentication (passwordless):

```bash
# Get your GitHub repository information
GITHUB_ORG="<your-org>"
GITHUB_REPO="<your-repo>"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create a service principal with federated credentials
az ad sp create-for-rbac \
  --name "github-actions-zavastorefront" \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID

# Add federated credential for main branch
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "github-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG/$GITHUB_REPO"':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

## Resource Naming Convention

Resources are automatically named using the pattern:
- Resource Group: `rg-{appName}-{environment}-{location}`
- ACR: `acr{uniqueString}`
- App Service Plan: `asp-{appName}-{environment}-{uniqueString}`
- Web App: `app-{appName}-{environment}-{uniqueString}`
- Application Insights: `appi-{appName}-{environment}-{uniqueString}`
- Log Analytics: `log-{appName}-{environment}-{uniqueString}`
- Foundry: `cog-{appName}-{environment}-{uniqueString}`

## Cost Estimates

Minimal-cost SKUs for dev environment:
- **ACR**: Basic tier (~$5/month)
- **App Service Plan**: B1 tier (~$13/month)
- **Application Insights**: Pay-as-you-go (first 5GB free)
- **Log Analytics**: Pay-as-you-go (first 5GB free)
- **Microsoft Foundry**: S0 tier (consumption-based pricing)

**Estimated monthly cost**: ~$20-30 for dev workloads

## Security Features

- **No password-based authentication**: ACR uses system-assigned managed identity with AcrPull role
- **HTTPS only**: Web App enforces HTTPS
- **Managed Identity**: Web App uses system-assigned identity for secure Azure service access
- **RBAC**: Least-privilege access using Azure role-based access control
- **No admin credentials**: ACR admin user is disabled

## Monitoring and Observability

Application Insights is automatically configured with:
- Request tracking
- Dependency monitoring
- Exception logging
- Performance metrics
- Live metrics stream

### Viewing Logs

```bash
# Stream Web App logs
WEB_APP_NAME=$(az webapp list --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)
az webapp log tail --name $WEB_APP_NAME --resource-group rg-zavastore-dev-westus3

# View Application Insights in Portal
az monitor app-insights component list --resource-group rg-zavastore-dev-westus3
```

## Troubleshooting

### Container fails to start
```bash
# Check Web App logs
az webapp log tail --name <web-app-name> --resource-group rg-zavastore-dev-westus3

# Check container settings
az webapp config container show --name <web-app-name> --resource-group rg-zavastore-dev-westus3
```

### ACR pull fails
```bash
# Verify managed identity is configured
az webapp identity show --name <web-app-name> --resource-group rg-zavastore-dev-westus3

# Verify role assignment
az role assignment list --assignee <principal-id>
```

### Application Insights not receiving data
```bash
# Verify connection string is configured
az webapp config appsettings list --name <web-app-name> --resource-group rg-zavastore-dev-westus3 \
  | grep APPLICATIONINSIGHTS_CONNECTION_STRING
```

### Microsoft Foundry deployment issues
```bash
# Check if region supports OpenAI models
az cognitiveservices account list-skus --kind OpenAI --location westus3

# Verify deployments
az cognitiveservices account deployment list --name <foundry-name> --resource-group rg-zavastore-dev-westus3
```

## Updating Infrastructure

To update infrastructure after making changes to Bicep files:

```bash
# Using azd
azd provision

# Or using Azure CLI
az deployment group create \
  --resource-group rg-zavastore-dev-westus3 \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json
```

## Clean Up

To delete all resources:

```bash
# Using azd (recommended)
azd down --purge

# Or using Azure CLI
az group delete --name rg-zavastore-dev-westus3 --yes --no-wait
```

## Additional Resources

- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Azure Container Registry Documentation](https://learn.microsoft.com/azure/container-registry/)
- [Azure App Service Documentation](https://learn.microsoft.com/azure/app-service/)
- [Application Insights Documentation](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Azure OpenAI Service Documentation](https://learn.microsoft.com/azure/ai-services/openai/)

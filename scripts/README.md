# Deployment Scripts

This directory contains helper scripts for deploying and validating the ZavaStorefront infrastructure.

## Scripts

### deploy.sh

Quick deployment script that:
1. Checks prerequisites (Azure CLI, azd)
2. Provisions Azure infrastructure using azd
3. Builds and pushes the container image to ACR (cloud-side build)
4. Restarts the Web App with the new image

**Usage:**
```bash
./scripts/deploy.sh
```

### validate-deployment.sh

Validates that all required Azure resources are deployed correctly. Checks:
- Resource Group existence
- Azure Container Registry (ACR) configuration
- App Service Plan (Linux)
- Web App with system-assigned managed identity
- HTTPS enforcement
- Application Insights configuration
- Log Analytics Workspace
- Microsoft Foundry (optional)
- AcrPull role assignment

**Usage:**
```bash
# Use default resource group name (rg-zavastore-dev-westus3)
./scripts/validate-deployment.sh

# Or specify a custom resource group name
./scripts/validate-deployment.sh my-resource-group-name
```

## Prerequisites

Both scripts require:
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (version 2.50 or later)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- Active Azure subscription
- Logged in to Azure (`az login` and `azd auth login`)

## Troubleshooting

If scripts fail:
1. Ensure you're logged in: `az login` and `azd auth login`
2. Check Azure subscription: `az account show`
3. Verify resource group exists: `az group list`
4. Review script output for specific error messages

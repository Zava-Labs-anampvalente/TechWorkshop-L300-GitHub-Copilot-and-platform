# Azure Infrastructure Deployment Summary

## Overview
This deployment provisions a complete Azure infrastructure for the ZavaStorefront .NET 6.0 web application in a dev environment. All resources are deployed to the **westus3** region using Infrastructure as Code (Bicep) and Azure Developer CLI (azd).

## Resources Provisioned

### Core Infrastructure
1. **Resource Group** - `rg-zavastorefront-dev-{unique}`
   - Single resource group containing all resources
   - Region: westus3

2. **Azure Container Registry (ACR)** - `acr{unique}`
   - SKU: Basic
   - Admin user: Disabled (security best practice)
   - Purpose: Store Docker container images

3. **App Service Plan** - `asp-zavastorefront-dev-{unique}`
   - SKU: B1 (Basic)
   - OS: Linux
   - Purpose: Host the Web App

4. **Web App (App Service)** - `app-zavastorefront-dev-{unique}`
   - Type: Web App for Containers
   - Identity: System-assigned managed identity
   - Configuration:
     - HTTPS only: Enabled
     - ACR integration: Via managed identity (no passwords)
     - Always on: Enabled
     - Container: Pulls from ACR using AcrPull role

### Monitoring & Observability
5. **Log Analytics Workspace** - `log-zavastorefront-dev-{unique}`
   - SKU: PerGB2018
   - Retention: 30 days
   - Purpose: Centralized logging

6. **Application Insights** - `appi-zavastorefront-dev-{unique}`
   - Type: Web application
   - Linked to: Log Analytics Workspace
   - Configured in: Web App (via connection string)

### AI Services
7. **Microsoft Foundry (Azure OpenAI)** - `cog-zavastorefront-dev-{unique}`
   - SKU: S0
   - Models deployed:
     - GPT-4 (version 0613)
     - Phi-3 (latest)
   - Region: westus3 (supports these models)

### Security & Access Control
8. **Role Assignment**
   - Principal: Web App managed identity
   - Role: AcrPull
   - Scope: Azure Container Registry
   - Purpose: Allows Web App to pull images from ACR without passwords

## Security Features

✅ **No password-based authentication**
- ACR admin user is disabled
- Web App uses managed identity to pull images
- RBAC-based access control

✅ **Managed identities**
- System-assigned identity for Web App
- Automatic credential management by Azure
- No secrets in application code

✅ **HTTPS enforcement**
- Web App configured for HTTPS only
- All HTTP traffic redirected to HTTPS

✅ **Minimal permissions**
- AcrPull role grants only the necessary permissions
- No overprivileged access

## Cost Estimate (Monthly)

| Resource | SKU/Tier | Estimated Cost |
|----------|----------|----------------|
| Azure Container Registry | Basic | ~$5 |
| App Service Plan | B1 | ~$13 |
| Application Insights | Pay-as-you-go | $0-5 (first 5GB free) |
| Log Analytics | Pay-as-you-go | $0-5 (first 5GB free) |
| Azure OpenAI (Foundry) | S0 | Consumption-based* |

**Total estimated cost: ~$20-30/month** (excluding OpenAI consumption)

*OpenAI costs depend on usage. GPT-4 and Phi-3 charges apply per token.

## Deployment Methods

### Option 1: Azure Developer CLI (Recommended)
```bash
# Initialize and provision
azd init
azd provision

# This automatically:
# - Creates all Azure resources
# - Builds and pushes container image to ACR
# - Configures Web App
```

### Option 2: Quick Deployment Script
```bash
# Run the automated deployment script
./scripts/deploy.sh
```

### Option 3: Manual Azure CLI
```bash
# Create resource group
az group create --name rg-zavastore-dev-westus3 --location westus3

# Deploy Bicep template
az deployment group create \
  --resource-group rg-zavastore-dev-westus3 \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json

# Build and push image
ACR_NAME=$(az acr list --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)
az acr build --registry $ACR_NAME --image zavastorefront:latest ./src
```

## Validation

After deployment, validate the infrastructure:

```bash
# Run validation script
./scripts/validate-deployment.sh

# Or check manually
az group show --name rg-zavastore-dev-westus3
az webapp list --resource-group rg-zavastore-dev-westus3
az acr list --resource-group rg-zavastore-dev-westus3
```

## CI/CD Integration

### GitHub Actions Workflow
The included workflow (`.github/workflows/acr-build.yml`) automates:
1. Building Docker images using ACR cloud build (no local Docker required)
2. Pushing images to ACR
3. Updating Web App with new image
4. Restarting Web App

**Setup:**
1. Configure GitHub secrets:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
2. Set up OIDC federated credentials
3. Push to main/develop branch to trigger deployment

## File Structure

```
.
├── infra/
│   ├── main.bicep                     # Main orchestration template
│   ├── main.parameters.json           # Configuration parameters
│   └── modules/
│       ├── container-registry.bicep   # ACR module
│       ├── app-service-plan.bicep     # App Service Plan module
│       ├── web-app.bicep              # Web App module
│       ├── app-insights.bicep         # Application Insights module
│       ├── log-analytics.bicep        # Log Analytics module
│       ├── foundry.bicep              # Azure OpenAI module
│       └── role-assignment.bicep      # RBAC role assignment module
├── src/
│   ├── Dockerfile                     # Container definition
│   └── [application files]
├── scripts/
│   ├── deploy.sh                      # Quick deployment script
│   └── validate-deployment.sh         # Infrastructure validation
├── .github/workflows/
│   └── acr-build.yml                  # CI/CD workflow
├── azure.yaml                         # Azure Developer CLI config
└── INFRASTRUCTURE.md                  # Detailed documentation
```

## Key Configuration Files

### infra/main.parameters.json
Controls deployment configuration:
- Environment name (dev/staging/prod)
- Region (westus3)
- SKUs for each resource
- Whether to deploy optional resources

### azure.yaml
Defines Azure Developer CLI behavior:
- Service configuration
- Deployment hooks
- Automated build/push steps

## Next Steps

1. **Deploy Infrastructure**
   ```bash
   ./scripts/deploy.sh
   ```

2. **Verify Deployment**
   ```bash
   ./scripts/validate-deployment.sh
   ```

3. **Access Application**
   - Get URL: `azd env get-values | grep WEB_APP_URL`
   - Open in browser: `https://{webapp-name}.azurewebsites.net`

4. **Monitor Application**
   - View logs: `az webapp log tail --name {webapp-name} --resource-group {rg-name}`
   - Check Application Insights in Azure Portal

5. **Update Application**
   - Make code changes
   - Push to GitHub (triggers CI/CD)
   - Or manually: `az acr build --registry {acr-name} --image zavastorefront:latest ./src`

## Troubleshooting

### Container not starting
```bash
# View Web App logs
az webapp log tail --name {webapp-name} --resource-group {rg-name}

# Check container configuration
az webapp config container show --name {webapp-name} --resource-group {rg-name}
```

### ACR pull failures
```bash
# Verify managed identity
az webapp identity show --name {webapp-name} --resource-group {rg-name}

# Check role assignments
az role assignment list --assignee {principal-id}
```

### Application Insights not receiving data
```bash
# Verify connection string is set
az webapp config appsettings list --name {webapp-name} --resource-group {rg-name} | grep APPLICATIONINSIGHTS
```

## Clean Up

To delete all resources and stop incurring charges:

```bash
# Using azd (recommended)
azd down --purge

# Or using Azure CLI
az group delete --name rg-zavastore-dev-westus3 --yes
```

## Additional Resources

- [INFRASTRUCTURE.md](./INFRASTRUCTURE.md) - Detailed deployment guide
- [scripts/README.md](./scripts/README.md) - Script documentation
- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Azure App Service Documentation](https://learn.microsoft.com/azure/app-service/)
- [Azure OpenAI Service Documentation](https://learn.microsoft.com/azure/ai-services/openai/)

## Security Summary

✅ **No vulnerabilities detected** - CodeQL security scan passed  
✅ **Best practices implemented** - Managed identities, RBAC, HTTPS enforcement  
✅ **Least privilege access** - Role assignments scoped to specific resources  
✅ **No secrets in code** - All authentication via managed identities  
✅ **Secure by default** - ACR admin disabled, HTTPS enforced  

---

**Status:** ✅ Ready for deployment  
**Environment:** Development  
**Region:** westus3  
**Deployment method:** Azure Developer CLI (azd) or manual scripts

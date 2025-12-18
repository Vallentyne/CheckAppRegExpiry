# Entra ID Certificate Expiry Monitor

Azure Function that monitors Entra ID (Azure AD) app registration certificate and client secret expiry, sending alerts to Microsoft Teams.

## Features

- ✅ Monitors both certificates and client secrets
- ✅ Configurable warning threshold (default: 30 days)
- ✅ Sends formatted alerts to Microsoft Teams
- ✅ Runs on schedule (default: daily at 9 AM UTC)
- ✅ Uses Managed Identity for secure authentication
- ✅ Color-coded alerts based on urgency

## Prerequisites

1. **Azure Subscription**
2. **Azure CLI** - [Install](https://docs.microsoft.com/cli/azure/install-azure-cli)
3. **Azure Functions Core Tools** - [Install](https://docs.microsoft.com/azure/azure-functions/functions-run-local)
4. **Python 3.9+**
5. **Teams Incoming Webhook** - [Setup Instructions](#setup-teams-webhook)

## Setup Teams Webhook

1. In Microsoft Teams, go to the channel where you want to receive alerts
2. Click the **•••** (More options) next to the channel name
3. Select **Connectors** (or **Workflows** in newer Teams)
4. Search for **Incoming Webhook** and click **Add** or **Configure**
5. Give it a name like "Certificate Expiry Alerts"
6. Copy the webhook URL (starts with `https://outlook.office.com/webhook/...` or similar)
7. Save the URL for later configuration

## Local Development

### 1. Install Dependencies

```powershell
cd c:\Code\JDCP\Alerts
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2. Configure Settings

Edit `local.settings.json`:
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "WARNING_DAYS": "30",
    "TEAMS_WEBHOOK_URL": "https://your-teams-webhook-url"
  }
}
```

### 3. Authenticate with Azure

```powershell
az login
```

### 4. Run Locally

```powershell
func start
```

To manually trigger the function:
```powershell
# In another terminal
curl http://localhost:7071/admin/functions/CertExpiryMonitor
```

## Deploy to Azure

### 1. Create Azure Resources

```powershell
# Set variables
$resourceGroup = "rg-cert-monitor"
$location = "eastus"
$storageAccount = "stcertmonitor$(Get-Random -Maximum 9999)"
$functionApp = "func-cert-expiry-monitor"

# Create resource group
az group create --name $resourceGroup --location $location

# Create storage account
az storage account create `
  --name $storageAccount `
  --resource-group $resourceGroup `
  --location $location `
  --sku Standard_LRS

# Create function app (Python 3.11)
az functionapp create `
  --resource-group $resourceGroup `
  --consumption-plan-location $location `
  --runtime python `
  --runtime-version 3.11 `
  --functions-version 4 `
  --name $functionApp `
  --storage-account $storageAccount `
  --os-type Linux
```

### 2. Enable Managed Identity

```powershell
# Enable system-assigned managed identity
az functionapp identity assign `
  --name $functionApp `
  --resource-group $resourceGroup

# Get the principal ID (save this)
$principalId = az functionapp identity show `
  --name $functionApp `
  --resource-group $resourceGroup `
  --query principalId -o tsv

Write-Host "Managed Identity Principal ID: $principalId"
```

### 3. Grant Permissions to Managed Identity

```powershell
# Assign "Application.Read.All" permission in Microsoft Graph
# This requires Global Administrator or Privileged Role Administrator

# Get the Microsoft Graph service principal ID
$graphAppId = "00000003-0000-0000-c000-000000000000"
$graphSp = az ad sp show --id $graphAppId | ConvertFrom-Json

# Get the Application.Read.All role ID
$appRoleId = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"  # Application.Read.All

# Grant the permission
az rest --method POST `
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($graphSp.id)/appRoleAssignments" `
  --headers "Content-Type=application/json" `
  --body "{`"principalId`":`"$principalId`",`"resourceId`":`"$($graphSp.id)`",`"appRoleId`":`"$appRoleId`"}"
```

### 4. Configure Application Settings

```powershell
# Set the Teams webhook URL (replace with your actual webhook)
az functionapp config appsettings set `
  --name $functionApp `
  --resource-group $resourceGroup `
  --settings "TEAMS_WEBHOOK_URL=https://your-teams-webhook-url" "WARNING_DAYS=30"
```

### 5. Deploy the Function

```powershell
# From the project directory
func azure functionapp publish $functionApp
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TEAMS_WEBHOOK_URL` | Microsoft Teams incoming webhook URL | *Required* |
| `WARNING_DAYS` | Days before expiry to trigger alert | 30 |

### Timer Schedule

The function runs based on a cron expression in [function.json](CertExpiryMonitor/function.json):

```json
"schedule": "0 0 9 * * *"
```

**Current: Daily at 9:00 AM UTC**

Common schedules:
- `0 0 9 * * *` - Daily at 9 AM UTC
- `0 0 9 * * 1` - Weekly on Monday at 9 AM UTC
- `0 0 9 1 * *` - Monthly on the 1st at 9 AM UTC
- `0 */6 * * *` - Every 6 hours

## Monitoring

### View Logs in Azure

```powershell
# Stream logs in real-time
az webapp log tail --name $functionApp --resource-group $resourceGroup

# Or view in Azure Portal
# Navigate to Function App > Functions > CertExpiryMonitor > Monitor
```

### Application Insights

For production monitoring, enable Application Insights:

```powershell
az monitor app-insights component create `
  --app $functionApp `
  --location $location `
  --resource-group $resourceGroup

# Get the instrumentation key
$aiKey = az monitor app-insights component show `
  --app $functionApp `
  --resource-group $resourceGroup `
  --query instrumentationKey -o tsv

# Configure the function app
az functionapp config appsettings set `
  --name $functionApp `
  --resource-group $resourceGroup `
  --settings "APPINSIGHTS_INSTRUMENTATIONKEY=$aiKey"
```

## Teams Alert Example

When certificates are expiring, you'll receive a Teams message like:

```
🔐 Entra ID Certificate Expiry Alert

Found 3 app registration credentials expiring within 30 days

My API Application
App ID: 12345678-1234-1234-1234-123456789abc
Credential: Production Certificate
Status: EXPIRING SOON
Expires: 2025-12-25 10:30:00 UTC
Days Remaining: 7

[View App Registrations]
```

## Troubleshooting

### "No applications found"
- Ensure the Managed Identity has `Application.Read.All` permission
- Wait 5-10 minutes after granting permissions for changes to propagate

### "TEAMS_WEBHOOK_URL environment variable is not set"
- Add the webhook URL to application settings (see Configuration section)

### Authentication Errors
- For local development, ensure you're logged in with `az login`
- For Azure deployment, verify Managed Identity is enabled and has correct permissions

### Manual Test
```powershell
# Trigger the function manually via HTTP
$functionKey = az functionapp keys list `
  --name $functionApp `
  --resource-group $resourceGroup `
  --query functionKeys.default -o tsv

Invoke-RestMethod -Uri "https://$functionApp.azurewebsites.net/admin/functions/CertExpiryMonitor" `
  -Headers @{"x-functions-key"=$functionKey} `
  -Method Post
```

## Security Best Practices

1. ✅ **Use Managed Identity** - No passwords or keys in code
2. ✅ **Least Privilege** - Only `Application.Read.All` permission granted
3. ✅ **Secure Webhook** - Store Teams webhook URL in App Settings, not code
4. ✅ **Private Endpoints** - Consider using VNet integration for production
5. ✅ **Monitor Access** - Review Activity Logs regularly

## Cost Estimation

- **Azure Function (Consumption Plan)**: ~$0.20/month (minimal executions)
- **Storage Account**: ~$0.05/month
- **Total**: ~$0.25/month

## Next Steps

- [ ] Set up Application Insights for advanced monitoring
- [ ] Add email notifications as backup
- [ ] Create Azure Dashboard for certificate inventory
- [ ] Implement automated certificate renewal (if applicable)
- [ ] Add exception list for certain apps

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Azure Function logs
3. Verify Microsoft Graph API permissions

## License

MIT

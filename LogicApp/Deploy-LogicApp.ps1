# Deploy Logic App for Certificate Expiry Monitoring
# This script creates a Logic App that monitors Entra ID certificate expiry

param(
    [string]$ResourceGroup = "rg-cert-monitor",
    [string]$Location = "canadacentral",
    [Parameter(Mandatory=$true)]
    [string]$EmailRecipient,
    [int]$WarningDays = 30
)

Write-Host "🚀 Deploying Certificate Expiry Logic App..." -ForegroundColor Cyan
Write-Host ""

# Deploy the Logic App
Write-Host "Creating Logic App..." -ForegroundColor Yellow
$deployment = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "LogicApp/logic-app-template.json" `
    --parameters emailRecipient=$EmailRecipient warningDays=$WarningDays `
    --query "{Name:properties.outputs.logicAppName.value, PrincipalId:properties.outputs.principalId.value}" `
    -o json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy Logic App"
    exit 1
}

$logicAppName = $deployment.Name
$principalId = $deployment.PrincipalId

Write-Host "✓ Logic App created: $logicAppName" -ForegroundColor Green
Write-Host "✓ Managed Identity Principal ID: $principalId" -ForegroundColor Green

# Grant Microsoft Graph permissions
Write-Host ""
Write-Host "Granting Microsoft Graph permissions..." -ForegroundColor Yellow

$graphSpId = (az ad sp show --id "00000003-0000-0000-c000-000000000000" | ConvertFrom-Json).id
$appRoleId = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"  # Application.Read.All

$body = @{
    principalId = $principalId
    resourceId = $graphSpId
    appRoleId = $appRoleId
} | ConvertTo-Json

$body | Out-File -FilePath "temp-graph-permission.json" -Encoding utf8

try {
    az rest --method POST `
        --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$graphSpId/appRoleAssignments" `
        --headers "Content-Type=application/json" `
        --body "@temp-graph-permission.json" | Out-Null
    
    Write-Host "✓ Microsoft Graph permissions granted" -ForegroundColor Green
} catch {
    Write-Warning "Failed to grant Graph permissions automatically. You'll need to do this manually."
    Write-Host "Run this in Azure Portal > Enterprise Applications > $logicAppName > Permissions" -ForegroundColor Yellow
} finally {
    Remove-Item "temp-graph-permission.json" -ErrorAction SilentlyContinue
}

# Authorize Office 365 connection
Write-Host ""
Write-Host "⚠️  MANUAL STEP REQUIRED:" -ForegroundColor Yellow
Write-Host "You need to authorize the Office 365 connection:" -ForegroundColor White
Write-Host "1. Open: https://portal.azure.com/#resource/subscriptions/3ec06fc7-1fa1-4d12-b1df-33f5a5153d0a/resourceGroups/$ResourceGroup/providers/Microsoft.Web/connections/office365" -ForegroundColor Cyan
Write-Host "2. Click 'Edit API connection' in the left menu" -ForegroundColor White
Write-Host "3. Click 'Authorize' button" -ForegroundColor White
Write-Host "4. Sign in with your Office 365 account" -ForegroundColor White
Write-Host "5. Click 'Save'" -ForegroundColor White

Write-Host ""
Write-Host "✅ Logic App deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Logic App URL:" -ForegroundColor Cyan
Write-Host "https://portal.azure.com/#resource/subscriptions/3ec06fc7-1fa1-4d12-b1df-33f5a5153d0a/resourceGroups/$ResourceGroup/providers/Microsoft.Logic/workflows/$logicAppName" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Authorize the Office 365 connection (see above)" -ForegroundColor White
Write-Host "2. Test the Logic App by clicking 'Run Trigger' → 'Recurrence'" -ForegroundColor White
Write-Host "3. Logic App will run daily at 9 AM UTC" -ForegroundColor White

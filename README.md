# Certificate Expiry Monitor - Logic App Solution

This solution uses **Azure Logic App** to monitor Entra ID app registration certificate and client secret expiry, sending email alerts when credentials are expiring soon.

## ✅ Benefits of Logic App Approach

- ✅ **No code deployment issues** - Created entirely in Azure Portal
- ✅ **Built-in email connector** - Uses Office 365 Outlook (no SMTP config)
- ✅ **Visual workflow** - Easy to understand and modify
- ✅ **Managed Identity** - Secure authentication to Microsoft Graph
- ✅ **Native Microsoft Graph** - Direct API calls without SDK dependencies

## 🚀 Quick Deployment

### Prerequisites
- Azure subscription with permissions to create Logic Apps
- Email address to receive alerts (Office 365/Outlook account recommended)

### Deploy

```powershell
cd c:\Code\JDCP\Alerts\LogicApp

# Deploy the Logic App
.\Deploy-LogicApp.ps1 -EmailRecipient "your.email@yourdomain.com" -WarningDays 30
```

### Manual Steps After Deployment

1. **Authorize Office 365 Connection**
   - Portal will provide the URL
   - Click "Edit API connection" → "Authorize"
   - Sign in with your Office 365 account
   - Click "Save"

2. **Test the Logic App**
   - Go to Logic App in Azure Portal
   - Click "Run Trigger" → "Recurrence"
   - Check your email for the alert

## 📋 What It Does

1. **Runs Daily at 9 AM UTC** (configurable in the Logic App designer)
2. **Queries Microsoft Graph** for all app registrations
3. **Checks Certificates & Secrets** for expiry within threshold
4. **Sends Email** if any credentials are expiring
5. **Includes Details**: App name, credential type, expiry date, days remaining

## 🎨 Email Format

The email includes:
- Total count of expiring credentials
- HTML table with full details
- Color-coded by urgency
- Direct link to Azure Portal

## ⚙️ Configuration

### Change Schedule
In Azure Portal → Logic App → Logic App Designer:
- Click the "Recurrence" trigger
- Modify frequency, interval, time zone, hours/minutes

### Change Warning Days
In Azure Portal → Logic App → Logic App Designer:
- Go to "Parameters" section
- Modify `warningDays` parameter value

### Change Email Recipient
In Azure Portal → Logic App → Logic App Designer:
- Click "Send Email" action
- Modify "To" field

## 🔧 Troubleshooting

### No email received
- Check Logic App run history for errors
- Verify Office 365 connection is authorized
- Check Microsoft Graph permissions (Application.Read.All)

### Permission errors
- Ensure Managed Identity has Application.Read.All permission
- Wait 5-10 minutes after granting permissions
- Verify in Azure Portal → Enterprise Applications

### Email shows empty table
- Logic App found no expiring credentials (good news!)
- Or check run history for API call errors

## 📊 Monitoring

View execution history:
1. Azure Portal → Logic App
2. Click "Runs history"
3. Click any run to see detailed execution

## 🔐 Security

- Uses Managed Identity (no passwords/secrets)
- Least privilege (Application.Read.All only)
- Office 365 connection secured per-user

## 💰 Cost

- Logic App: ~$0.10 per day (standard pricing)
- Executions: Very low (once per day)
- Estimated monthly cost: **~$3/month**

## 🔄 Alternative Email Options

If you don't have Office 365, you can modify the Logic App to use:
- **SendGrid** connector
- **Gmail** connector  
- **HTTP** action to any SMTP API

## 📝 Files

- `logic-app-template.json` - ARM template for deployment
- `Deploy-LogicApp.ps1` - PowerShell deployment script
- `README-LogicApp.md` - This file

---

**Next**: Run the deployment script with your email address!

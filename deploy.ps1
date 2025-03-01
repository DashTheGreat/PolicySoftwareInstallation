$params = @{
    resourceGroupName     = "RG-UKHSA-UKS-PRE-AVD-APOL-01" # <-- Change this value for the Resource Group Name
    storageAccountName    = "saukhsaukspreapol01" # <-- Change this value - must be globally unique
    location              = "uksouth" # <-- Change this value to a location you want
    automationAccountName = "ATM-UKHSA-UKS-PRE-AVD-APOL-01" # <-- Change this value for the Automation Account Name
}

New-AzResourceGroup -Name $params.resourceGroupName -Location $params.location -Force

Write-Host "Deploying Infrastructure" -ForegroundColor Green
New-AzResourceGroupDeployment -ResourceGroupName $params.resourceGroupName -TemplateFile "C:\Users\Darshit.Patel\OneDrive - UK Health Security Agency\DashTheGreat_GitRepo\PolicySoftwareInstallation\deploy.bicep" -TemplateParameterObject $params -Verbose

$ctx = (Get-AzStorageAccount -ResourceGroupName $params.resourceGroupName -StorageAccountName $params.storageAccountName).Context

$automationAccount = Get-AzAutomationAccount -ResourceGroupName $params.resourceGroupName -Name $params.automationAccountName

#Write-Host "Downloading PowerShell 7-x64" -ForegroundColor Green
#Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v7.1.3/PowerShell-7.1.3-win-x64.msi" -OutFile "$env:TEMP\PowerShell-7.1.3-win-x64.msi"

Write-Host "Uploading file to storage account" -ForegroundColor Green
Set-AzStorageBlobContent -File "$env:TEMP\TeamViewer_Host.msi" -Blob "TeamViewer_Host.msi" -Container software -Context $ctx -Force

Write-Host "Publishing runbook to automation account" -ForegroundColor Green
$automationAccount | Import-AzAutomationRunbook -Name deployTeamViewer -Path .\deployPowerShell.ps1 -Type PowerShell -Force -Published

Write-Host "Generating webhook" -ForegroundColor Green
$wh = $automationAccount | New-AzAutomationWebhook -Name WH1 -ExpiryTime (Get-Date).AddYears(1) -RunbookName deployTeamViewer -IsEnabled $true -Force

Write-Host "Deploying event grid subscription and software installation policy" -ForegroundColor Green
New-AzResourceGroupDeployment -ResourceGroupName $params.resourceGroupName `
    -TemplateFile .\eventgrid.bicep `
    -uri ($wh.WebhookURI | ConvertTo-SecureString -AsPlainText -Force) `
    -location $params.location `
    -topicName "PolicyStateChanges" `
    -Verbose
   
Start-AzPolicyComplianceScan -ResourceGroupName "RG-UKHSA-UKS-PRE-AVD-APOL-01"
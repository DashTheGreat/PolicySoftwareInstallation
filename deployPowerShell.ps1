Param([object]$WebhookData)

$eventData = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

if ($eventData.subject -match 'microsoft.compute/virtualmachines') {
    $vmName = $eventData.subject.Split('/')[8]
    $vmResourceGroupName = $eventData.subject.Split('/')[4]

    Connect-AzAccount -Identity

    $storageAccountName = Get-AutomationVariable "saukhsaukspreapol01"
    $resourceGroupName = Get-AutomationVariable "RG-UKHSA-UKS-PRE-AVD-APOL-01"

    $ctx = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName).Context

    $sasUri = New-AzStorageBlobSASToken -Blob 'TeamViewer_Host.msi' -Container software -Permission r -ExpiryTime (Get-Date).AddMinutes(30) -Context $ctx -FullUri


    $scriptBlock = @'
$sasUri = "VALUE"

Invoke-WebRequest -Uri $sasUri -OutFile "$env:TEMP\TeamViewer_Host.msi" -Verbose

Start-Process 'msiexec.exe' -ArgumentList '/i', "$env:Temp\TeamViewer_Host.msi", '/qn DESKTOPSHORTCUTS=0 CUSTOMCONFIGID=6b65jzf APITOKEN=14590208-wIdpxsxFUNXRKoa8trAU ASSIGNMENTOPTIONS="--reassign --alias %ComputerName% --grant-easy-access --group AVD"' -Wait
'@

    $scriptBlock | Out-File $env:Temp\script.ps1

    (Get-Content $env:Temp\script.ps1 -Raw) -replace "VALUE", $sasUri | Set-Content $env:Temp\script.ps1 -Force

    Invoke-AzVMRunCommand -ResourceGroupName $vmResourceGroupName -VMName $vmName -ScriptPath $env:Temp\script.ps1 -CommandId 'RunPowerShellScript' -Verbose
}
else {
    Write-Output "Event subject does not match microsoft.compute"
}



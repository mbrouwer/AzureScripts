[CmdLetBinding()]
Param(
    [string]$importFolder = ".\runbooks",
    [string]$automationAccountName = "",
    [string]$resourceGroupName = "",
    [string]$hybridWorker = "",
    [switch]$deleteHook = $false,
    [string]$keyVaultName = ""
)
Function Get-Password {
    param($passwordLength = 15)
    $null = [Reflection.Assembly]::LoadWithPartialName("System.Web")
    return [System.Web.Security.Membership]::GeneratePassword($passwordLength, 2)
}

$deleteHook = $true
$contextFile = "C:\Users\marco\outlook.json"
if (test-path $contextFile) {
    $null = Import-AzureRmContext -Path $contextFile
}

$localRunBooks = Get-ChildItem $importFolder -Filter *.ps1
foreach ($localRunbook in $localRunBooks) {
    write-host $localRunbook.BaseName
    $azureRunbook = Get-AzureRmAutomationRunbook  -Name $localRunbook.BaseName `
        -ResourceGroupName $resourceGroupName `
        -AutomationAccountName $automationAccountName `
        -ErrorAction SilentlyContinue

    $azureHash = $azureRunbook.Tags.MD5
    $localHash = (Get-FileHash -Path $localRunbook.FullName -Algorithm MD5).hash

    if (($azureHash -ne $localHash) -or !$azureRunbook) {
        Write-Host " - MD5 hash doesnt match or Runbook doesn't yet exist. Importing."
        $generatedPassword = Get-Password -passwordLength 25
        Write-host " - Changing Authorization Key"
        (Get-Content $localRunbook.FullName).replace("##AuthKey##", $generatedPassword) | Set-Content $localRunbook.FullName

        Write-Host " - Adding Authorization Key $($localRunbook.BaseName) to KeyVault." -ForegroundColor Green
        $null = Set-AzureKeyVaultSecret -VaultName $keyVaultName `
            -Name "rb-$($localRunbook.BaseName)-auth" `
            -SecretValue (ConvertTo-SecureString -String $generatedPassword -AsPlainText -Force)

        Write-Host " - Uploading Runbook $($localRunbook.BaseName)." -ForegroundColor Green
        $null = Import-AzureRmAutomationRunbook -Path "$($localRunbook.FullName)" `
            -AutomationAccountName $automationAccountName `
            -ResourceGroupName $resourceGroupName `
            -Type PowerShell `
            -Force -Published `
            -Name $localRunbook.BaseName `
            -Tags @{"MD5" = "$($localHash)"} `

        Write-Host " - Looking for WebHook $($localRunbook.BaseName)." -ForegroundColor Green
        $webHook = Get-AzureRmAutomationWebhook -Name $localRunbook.BaseName `
            -ResourceGroupName $resourceGroupName `
            -AutomationAccountName $automationAccountName `
            -ErrorAction SilentlyContinue

        $createHook = $true
        if ($webHook) {
            if ($deleteHook) {
                $webHook | Remove-AzureRmAutomationWebhook
            }
            else {
                $createHook = $false
            }
        } 

        if ($createHook) {
            Write-Host " - Creating WebHook $($localRunbook.BaseName)." -ForegroundColor Green
            $result = New-AzureRmAutomationWebhook -RunbookName $localRunbook.BaseName `
                -ResourceGroupName $resourceGroupName `
                -Name $localRunbook.BaseName -IsEnabled $true `
                -ExpiryTime (Get-Date).AddYears(1) `
                -AutomationAccountName $automationAccountName `
                -Force -RunOn $hybridWorker -ErrorAction SilentlyContinue
        
            if ($result) {
                Write-Host " - Adding webhook $($localRunbook.BaseName) to KeyVault." -ForegroundColor Green
                $null = Set-AzureKeyVaultSecret -VaultName $keyVaultName `
                    -Name "rb-$($localRunbook.BaseName)-hook" `
                    -SecretValue (ConvertTo-SecureString -String $result.WebhookURI -AsPlainText -Force)
            }
            else {
                write-host " - Error creating webhook." -ForegroundColor Red
            }
        }
    } else {
        write-host " - MD5 identical, not importing."
    }
}



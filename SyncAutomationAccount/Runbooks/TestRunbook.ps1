param([object]$WebHookData)

if($WebHookData)
{
    $requestBody = ($WebHookData.RequestBody | ConvertFrom-JSON)
    $requestHeader = $WebHookData.RequestHeader
}

if ($requestHeader.AuthKey -eq '##AuthKey##')
{
    Write-Output "Webhook authenticated"
} else {
    Write-Output "Got unauthenticated request"
    exit
}

write-output $requestBody.Message

Write-Output "Logging in to Azure..."
$connectionName = "AzureRunAsConnection"
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         
# Add-AzureRmAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 

# $automationCredential = Get-AutomationPSCredential -Name 'MyAccount'
# Add-AzureRmAccount -Credential $automationCredential

# Get-AzureRMResource

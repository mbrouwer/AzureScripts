[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$true)][string]$keyVaultName = "",
    [Parameter(Mandatory=$true)][string]$runBookName = "",
    [Parameter(Mandatory=$true)][string]$resourceGroupName = "",
    [Parameter(Mandatory=$true)][string]$automationAccountName = ""
)


$hookURLName = "rb-$($runBookName)-hook"
$hookURL = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $hookURLName).SecretValueText
$hookAuthName = "rb-$($runBookName)-auth"
$hookAuth = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $hookAuthName).SecretValueText

write-host "Starting Automation Runbook $($runBookName)." -ForegroundColor Green
$body = (@{"AuthKey"="$hookAuth"} | ConvertTo-Json)
$headers = (@{"AuthKey"="$hookAuth"} )
$jobIDs = (Invoke-RestMethod -Method Post -Uri $hookURL -Body $body -Headers $headers).JobIDs

foreach($jobID in $jobIDs)
{
    write-host "Checking Job $($jobID)." -ForegroundColor Green
    do {
        $jobStatus = (Get-AzureRmAutomationJob -Id $jobID -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName).Status
        Write-Verbose "JobID : $($jobID), JobStatus : $($jobStatus)"
        start-sleep -Seconds 2
    } while ($jobStatus -ne "Completed")

    if($jobStatus -eq "Completed")
    {
        (Get-AzureRmAutomationJobOutput -Id $jobID -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName)
    }
    
}
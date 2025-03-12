$vms = Get-Content ".\serverlist.txt"
$dates = Get-Content ".\dates.txt" #One date per line in the format dd/mm/yyyy
$vault = Get=AzRecoveryServicesVault -ResourceGroupName "RG" -Name "Name"
$jobsArray = @()

foreach ($vm in $vms) {

    foreach ($date in $dates) {
        $JobsCompleted = Get-AzRecoveryServicesBackupJob -VaultId $vault.ID -Status Completed -From (Get-Date -Date $date).ToUniversalTime() -To (Get-Date -Date $date).AddDays(1).ToUniversalTime() -BackupManagementType AzureVM | Where-Object {$_.WorkloadName -eq $vm}
        $JobsFailed = Get-AzRecoveryServicesBackupJob -VaultId $vault.ID -Status Failed -From (Get-Date -Date $date).ToUniversalTime() -To (Get-Date -Date $date).AddDays(1).ToUniversalTime() -BackupManagementType AzureVM | Where-Object {$_.WorkloadName -eq $vm}
        $JobsArray += $JobsCompleted
        $JobsArray += $JobsFailed
        Write-Host "Getting details for server $vm and date $date"
    }    
}

Write-Host "Done!"

$JobsArray | Export-Csv BackupDetails.csv -NoTypeInformation

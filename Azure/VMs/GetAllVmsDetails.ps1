param(
    [string]$tenantId = "SUB_ID",
    [string]$file=".\AzureVMsFullDetails.csv"
)

$vmobjs = @()

$subs = Get-AzSubscription -tenantId

foreach ($sub in $subs) {
    Write-Host Processing subscription $sub.SubscriptionName

    Set-AzContext -SubscriptionId $sub.SubscriptionId

    $vms = Get-AzVM 

    foreach ($vm in $vms) {
        $vmInfo = [pscustomobject]@{
            'VmName' = $vm.Name
            'Subscription' = $sub.SubscriptionName
            'Location' = $vm.Location
            'ResourceGroup' = $vm.ResourceGroupName
            'LocalHostName' = $vm.OSProfile.ComputerName
            'VMSize' = $vm.HardwareProfile.VmSize
            'DiskCount' = $vm.StorageProfile.DataDisks.Count
            'Status' = $null
            'IpAddress' = $null
            'ProvisioningState' = $vm.ProvisioningState
            'Publisher' = $vm.StorageProfile.ImageReference.Publisher
            'Offer' = $vm.StorageProfile.ImageReference.Offer
            'SKU' = $vm.StorageProfile.ImageReference.Sku
            'Version' = $vm.StorageProfile.ImageReference.Version
            'RAMinMB' = $null
            'CPUCores' = $null
            'VM_Tags' = $null
            'Ddrive' = $null
            'Backup' = $null
            'BK_Vault' = $null
        }
    }

    $vmStatus = $vm | Get-AzVM -Status
    $vmInfo.Status = $vmStatus.Statuses[1].DisplayStatus

    $sizedetails = Get-AzVMSize -VMName $vm.Name -ResourceGroupName $vm.ResourceGroupName | where{$_.Name -eq $vm.HardwareProfile.VmSize}
    $vmInfo.RAMinMB = $sizedetails.MemoryInMB
    $vmInfo.CPUCores = $sizedetails.NumberOfCores

    $vmInfo.Tags = ($vm | Select-Object -ExpandProperty Tags | converto-json).Replace("{","").Replace("}","").Replace("`"","").Replace("  ","").Trim()

    $bkstatus = Get-AzRecoveryServicesBackupStatus -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Type AzureVM

    #If the value of the backedup is false then saving its not protected, else specify otherwise
    if ($bkstatus.BackedUp -eq $false) {
        $vmInfo.Backup = "False"
        $vmInfo.BK_Vault = "N/A"
    } else {
        $vmInfo.Backup = "True"
        $vmInfo.BK_Vault = $bkstatus.VaultId.Split('/')[-1]
    }

    $vmobjs += $vmInfo

    Write-Host $vmInfo.Subscription $vmInfo.VmName
}

$vmobjs | Select-Object Name, ResourceGroup, Subscription, Location, ComputerName, IpAddress, Status, ProvisioningState, Offer, Publisher, SKU, Version, VMSize, RAMinMB, CPUCores, Ddrive, VM_Tags, Backup, BK_Vault | Export-Csv -NoTypeInformation -Path $file
Write-Host "VM list written to $file"
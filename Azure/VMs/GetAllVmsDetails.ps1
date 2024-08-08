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
            'Tags' = $null
        }
    }

    $vmStatus = $vm | Get-AzVM -Status
    $vmInfo.Status = $vmStatus.Statuses[1].DisplayStatus

    $sizedetails = Get-AzVMSize -VMName $vm.Name -ResourceGroupName $vm.ResourceGroupName | where{$_.Name -eq $vm.HardwareProfile.VmSize}
    $vmInfo.RAMinMB = $sizedetails.MemoryInMB
    $vmInfo.CPUCores = $sizedetails.NumberOfCores

    $vmInfo.Tags = ($vm.Tags | Out-String)

    $vmobjs += $vmInfo

    Write-Host $vmInfo.Subscription $vmInfo.VmName
}
param(
    [string]$tenantId = "Tenant_ID",
    [string]$file = ".\UnatachedDisksAzure.csv"
)

$subscriptions = Get-AzSubscription -TenantId $tenantId

$vmobjs = @()

foreach ($subscription in $subscriptions) {
    $sink = Set-AzContext -Subscription $subscription

    $VMs = Get-AzVM
    foreach ($vm in $VMs) {
        #Get VM data disks
        $datadisks = $vm.StorageProfile.DataDisks

        Write-Host 'Procesing VM '$vm.Name
        $detail = @{
            VMName          = $vm.Name
            Subscription    = $subscription.Name
            Location        = $vm.Location
            ResourceGroup   = $vm.ResourceGroupName
            Name            = $vm.StorageProfile.OsDisk.Name
            Type            = "OS Disk"
            Size            = $vm.StorageProfile.OsDisk.DiskSizeGB
        }
        $vmobjs += New-Object PSObject -Property $detail

        foreach ($dd in $datadisks) {
            $detail = @{
                VMName          = $vm.Name
                Subscription    = $subscription.Name
                Location        = $vm.Location
                ResourceGroup   = $vm.ResourceGroupName
                Name            = $dd.Name
                Type            = "Data Disk"
                Size            = $dd.DiskSizeGB
            }
            $vmobjs += New-Object psobject -Property $detail
        }
    }
}

#Export into CSV file the variable vmobjs
$vmobjs | Select-Object VM, Subscription, ResourceGroup, Location, Name, Type, Size | Export-Csv -NoTypeInformation -Path $file
Write-Host "VM list written to $file"
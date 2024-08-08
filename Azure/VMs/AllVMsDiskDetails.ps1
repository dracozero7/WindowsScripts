param(
    [string]$tenantId = "Tenant_ID",
    [string]$file = ".\AllAzureVMsDiskDetails.csv"
)

$vmobjs = @()
$detail = @()

$subs = Get-AzSubscription -TenantId $tenantId

foreach ($sub in $subs) {
    $sink = Set-AzContext -Subscription $sub
    Write-Output "Working Subscription: " $sub.Name

    $vms = Get-AzVM

    foreach ($vm in $vms) {
       #Get all Data disks from the VM
       $datadisks = $vm.StorageProfile.DataDisks
       
       Write-Host "Procesing VM " $vm.Name

       $detail = @{
            VM = $vm.Name
            Subscription = $sub.Name
            Location = $vm.Location
            ResourceGroup = $vm.ResourceGroupName
            DiskName = $vm.StorageProfile.OsDisk.Name
            Type = "OS Disk"
            Size = $vm.StorageProfile.OsDisk.DiskSizeGB
       }
       $vmobjs += New-Object psobject -Property $detail

       #Loop every Data drive
       foreach ($dd in $datadisks) {
            $detail = @{
                VM = $vm.Name
                Subscription = $sub.Name
                Location = $vm.Location
                ResourceGroup = $vm.ResourceGroupName
                DiskName = $dd.Name
                Type = "Data Disk"
                Size = $dd.DiskSizeGB
            }
            $vmobjs += New-Object psobject -Property $detail
       }

    }

}

$vmobjs | Select-Object VM, Subscription, ResourceGroup, Location, Name, Type, Size | Export-Csv -NoTypeInformation -Path $file
Write-Host "VM list written to file " $file
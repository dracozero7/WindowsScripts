Set-AzContext -Subscription "sub"

$vmResourcesAll = @()
$storageResourcesAll = @()
$file = ".\StorageResults.csv"

$storageResourcesAll = Get-AzStorageAccount

foreach ($SA in $StorageAccountsAll) {
    $UserCapacity = (Get-AzMetric -WarningAction Ignore -ResourceId $SA.ID -MetricName "UsedCapacity").Data
    $UsedCapacityInTB = $UserCapacity.Avarage / 1024 / 1024 / 1024 /1024
    $RoundedValue = [math]::Round($UsedCapacityInTB,6)

    $ReportLine = New-Object -TypeName pscustomobject -Property @{
        ResourceGroup = $SA.ResourceGroupName
        ResourceType = "StorageAccount"
        Name = $SA.StorageAccountName
        AllocatedTB = "$RoundedValue"
        AllocatedGB = ""
        Subscription = $SA.SubscriptionName
    }
    $storageResourcesAll += $ReportLine
}

$DisksAll = Get-AzDisk
foreach ($disk in $DisksAll) {
    $diskSizeTB = $disk.DiskSizeGB /1024
    $RoundedValue = [math]::Round($diskSizeTB,6)
    
    $ReportLine = New-Object -TypeName pscustomobject -Property @{
        ResourceGroup = $disk.ResourceGroupName
        ResourceType = "ManagedDisk"
        Name = $disk.Name
        AllocatedTB = "$RoundedValue"
        AllocatedGB = ""
        Subscription = $disk.SubscriptionName
    }
    $storageResourcesAll += $ReportLine
}
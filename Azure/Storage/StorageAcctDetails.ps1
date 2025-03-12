$file = ".\StorageAccountDetails.csv"
$tenantId = "TenantID Here"
$storageResourceAll = @()

$sub = Get-AZSubscription -TenantId $tenantId

foreach ($sub in $subs) {
    Set-AzContext -SubscriptionId $sub.SubscriptionId

    $StorageAccountsAll = Get-AzStorageAccount

    foreach ($SA in $StorageAccountsAll) {
        $rg = Get-AzResourceGroup -ResourceGroupName $SA.ResourceGroupName
        $sd = $SA | Get-AzStorageServiceProperty -ServiceType Blob

        $ReportLine = New-Object -TypeName pscustomobject -Property @{
            Name = $SA.StorageAccountName
            ResourceGroup = $SA.ResourceGroupName
            Location = $SA.PrimaryLocation
            Subscription = $sub.Name
            SoftDelete = $sd.DeleteRetentionPolicy.Enabled
            StorageAccountTags = ($SA | select-Object -ExpandProperty Tags | convertto-json).Replace("{","").Replace("}","").Replace("`"","").Replace("  ","").Trim()
            ResourceGroupTags = ($rg | select-Object -ExpandProperty Tags | convertto-json).Replace("{","").Replace("}","").Replace("`"","").Replace("  ","").Trim()
        }
        $storageResourceAll += $ReportLine
    }
}

$storageResourceAll | Select-Object Name, ResourceGroup, Location, Subscription, SoftDelete, StorageAccountTags, ResourceGroupTags | Export-Csv -NoTypeInformation -Path $file

Write-Host "Written to $file"
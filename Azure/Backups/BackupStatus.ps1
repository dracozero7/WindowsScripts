param( 
    [string]$tenantId="TenantID",
    [string]$file="C:\temp\BackupResults.csv"
) 
$subs = Get-AzSubscription -TenantId $tenantId 
$vmobjs = @()foreach ($sub in $subs){ 
    Set-AzContext -SubscriptionId $sub.SubscriptionId 
    #Obtaining all VMs in subscription and Itarating through all of them    
    $vms = Get-AzVM 
    foreach ($vm in $vms) {
    #Obtaining the recovery vauld for each VM        
    $status = Get-AzRecoveryServicesBackupStatus -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Type AzureVM 
    #If a Vault ID exists, then saving the vault ID        
    If ($status.VaultId) {
        $rsv = $status.VaultId.Split('/')[-1]
        Write-Output "The VM" $vm.Name "is member of RSV" $rsv
    }
    #If the balue of BackedUp is false then saving its not protected        
    If ($status.BackedUp -eq $false) {
        Write-Output "The VM" $vm.Name "is not protected with Azure Backup"
        $rsv="NotProtected"
    }  
    #Building String for Tags Key Pairs        
    $Tagsstring = "{"
        try {
            $resource = Get-AzResource -Name $vm.Name
            $alltags = Get-AzTag -ResourceId $resource.ResourceId
            foreach($tagKey in $alltags.Properties.TagsProperty.Keys) {
                $Tagsstring += """" + $tagkey + ":" + $alltags.Properties.TagsProperty[$tagKey] + ""","
            }
        } catch {
            Write-Host $error[0]
        }
        $Tagsstring += "}"
        #Finish building the string for value key paris
        #Building Object to export to CSV file        
        $detail = @{
            Subscription = $sub.Name
            VM = $vm.Name
            ResourceGroup = $vm.ResourceGroupName
            Backup = $rsv
            Tags = $Tagsstring
        }
        $vmobjs += New-Object PSObject -Property $detail
    }
}
$vmobjs | Export-Csv -NoTypeInformation -Path $fileWrite-Host "VM list written to $file"

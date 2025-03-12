param (
    [string]$tenantId = "Tenant ID here"
    [string]$file = "./FailoverGroupReport.csv"
)

$sub = Get-AzSubscription -TenantId $tenantId
$Report = @()

foreach ($sub in $subs) {
    Set-AzContext -SubscriptionId $sub.SubscriptionId
    Write-Host "Procesing Subscription: " $sub.SubscriptionName
    $sqlservers = Get-AzSqlServer

    if (!($null -eq $sqlservers)) {
        foreach ($srv in $sqlservers) {
            $fogroup = Get-AzSqlDatabaseFailoverGroup -ResourceGroupName $srv.ResourceGroupName -ServerName $srv.ServerName

            #Validate Failover Groups exists and if this is a Primary Server. If not a primary server go to the next one
            if (!($null -eq $fogroup) -and ($fogroup.ReplicationRole -eq "Primary")) {
                Write-Host "Obtaining failover groups for SQL server: " $srv.ServerName

                foreach ($group in $fogroup) {

                    foreach ($DB in $group.DatabaseNames) {
                        $ElasticPoolDB = Get-AzSqlDatabase -ResourceGroupName $srv.ResourceGroupName -ServerName $srv.ServerName -DatabaseName $DB

                        #Validate if there are elastic Pools as they are shown in a different way in the FailoverGroup
                        if (!($null -eq $ElasticPoolDB.ElasticPoolName)) {
                            $ElasticPool = $ElasticPoolDB.ElasticPoolName
                        } else {
                            $ElasticPool = ""
                        }

                        #Filling Row with respective values
                        $ReportLine = New-Object -TypeName pscustomobject -Property @{
                            PrimaryServer = $group.ServerName
                            PrimaryServerRG = $srv.ResourceGroupName
                            LocationPrimaryServer = $group.Location
                            ElasticPool = $ElasticPool
                            PartnerServer = $group.PartnerServerName
                            PartnerServerRG = $group.PartnerResourceGroupName
                            LoctionPartner = $group.PartnerLocation
                            FailoverGroupName = $group.FailoverGroupName
                            DBList = $DB
                            SubscriptionName = $sub.Name
                        }
                        $Report += $ReportLine
                    }                    
                }
            } else {
                Write-Host "Server is not a primary Replication server or no failover groups found on " $srv. ServerName
            }
        }
    } else {
        write-host "No SQL Server found on subscription " $sub.SubscriptionName
    }
}

$Report | Export-Csv -Path $file -NoTypeInformation
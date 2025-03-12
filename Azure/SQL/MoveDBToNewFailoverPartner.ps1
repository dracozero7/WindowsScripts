#Specify primary SRV and new partner details
$primarysrv = "mydbsrv01"
$primaryrg = "srv01 RG"
$newpartner = "mydbsrv03"
$partnerrg = "srv03 RG"

#Saving all failover groups from primary server on variable fogroup
$fogroup = Get-AzSqlDatabaseFailoverGroup -ResourceGroupName $primaryrg -ServerName $primarysrv

#Validating that we are working on a primary server and the new Partner is actually a different server from the current partner
if (!($fogroup.PartnerServerName -eq $newpartner)) {
    if ($fogroup.ReplicationRole -eq "Primary") {

        foreach ($group in $fogroup) {
            $elasticpool = $null
            #Destroying Failover group, waiting 60 seconds and recreating it on new partner
            Write-Host "Breaking current failover group and waiting 60 seconds for " $group.FailoverGroupName
            Remove-AzSqlDatabaseFailoverGroup -ResourceGroupName $primaryrg -ServerName $primarysrv -FailoverGroupName $group.FailoverGroupName
            Start-Sleep -Seconds 60

            #Creating New Failover group for new partner
            Write-Host "Creating in the new partner the failover group " $group.FailoverGroupName
            New-AzSqlDatabaseFailoverGroup -ResourceGroupName $primaryrg -ServerName $primarysrv -PartnerResourceGroupName $partnerrg -PartnerServerName $newpartner -FailoverGroupName $group.FailoverGroupName -FailoverPolicy Automatic -GracePeriodWithDataLossHours 1

            #Now we proceed to add each DB to the recreated Failover Group
            foreach ($DB in $group.DatabaseNames) {
                $dbobject = Get-AzSqlDatabase -ResourceGroupName $primaryrg -ServerName $primarysrv -DatabaseName $DB

                if ($null -eq $dbobject.ElasticPoolName) {
                    $addDB = Get-AzSqlDatabase -ResourceGroupName $primaryrg -ServerName $primarysrv -DatabaseName $DB | Add-AzSqlDatabaseToFailoverGroup -ResourceGroupName $primaryrg -ServerName $primarysrv -FailoverGroupName $group.FailoverGroupName
                    Write-Host "Added succesfully to the Failover group the DB " $DB
                } else {
                    if ($null -eq $elasticpool) {
                        try {
                            $elasticpool = Get-AzSqlElasticPool -ResourceGroupName $partnerrg -ServerName $newpartner -ElasticPoolName $dbobject.ElasticPoolName
                        } catch {
                            Write-Host "Partner server doesnt have the elastic Pool, creating the pool on " $newpartner
                        }

                        #if the previous try and catch was able to obtain the elastic pool from the partner, it writes it already exists, otherwise it creates it
                        if (!($null -eq $elasticpool)) {
                            #Elastic pool already exists on partner server
                            Write-Host "ElasticPool already exists on partner server " $newpartner
                        } else {
                            $elasticpool = Get-AzSqlElasticPool -ResourceGroupName $primaryrg -ServerName $primarysrv -ElasticPoolName $dbobject.ElasticPoolName
                            $addDB = New-AzSqlElasticPool -ResourceGroupName $partnerrg -ServerName $newpartner -ElasticPoolName $dbobject.ElasticPoolName -Edition $elasticpool.Edition -Dtu $elasticpool.Dtu -DatabaseDtuMin $elasticpool.DatabaseDtuMin -DatabaseDtuMax $elasticpool.DatabaseDtuMax -StorageMB $elasticpool.StorageMB
                        }

                        #After we have obtained the Elastic Pool or created it, we proceed to add the DB to the failover group
                        $addDB = Get-AzSqlDatabase -ResourceGroupName $primaryrg -ServerName $primarysrv -DatabaseName $DB | Add-AzSqlDatabaseToFailoverGroup -ResourceGroupName $primaryrg -ServerName $primarysrv -FailoverGroupName $group.FailoverGroupName
                        Write-Host $DB "Added succesfully to the failover group"
                    } else {
                        #if have already obtained the elastic pool on the first run then we jump directly to this part to add the DB
                        $addDB = Get-AzSqlDatabase -ResourceGroupName $primaryrg -ServerName $primarysrv -DatabaseName $DB | Add-AzSqlDatabaseToFailoverGroup -ResourceGroupName $primaryrg -ServerName $primarysrv -FailoverGroupName $group.FailoverGroupName
                        Write-Host $DB "Added succesfully to the failover group"
                    }
                }
            }
        }
    }
}
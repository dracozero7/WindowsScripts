$sub = "sub"
Set-AzContext -Subscription $sub
$rg = "Resource Group"
$vms = Get-AzVm -ResourceGroupName $rg

$startTime = (Get-Date).AddDays(-1)
$endTime = Get-Date

$result = foreach ($vm in $vms) {
    $cpuMetricAvg = Get-AzMetric -ResourceId $vm.Id -MetricName "Percentage CPU" -StartTime $startTime -EndTime $endTime -AggregationType Average -TimeGrain 01:00:00
    $cpuMetricMax = Get-AzMetric -ResourceId $vm.Id -MetricName "Maximum CPU" -StartTime $startTime -EndTime $endTime -AggregationType Maximum -TimeGrain 01:00:00

    Write-Host "Procesing VM " $vm

    $cpuMetricAvg.Data | ForEach-Object {
        [PSCustomObject]@{
            ServerName = $vm.Name
            Subscription = $sub
            ResourceGroup = $rg
            TimeStamp = $_.TimeStamp
            CPU = $_.Average
            Metric = "Avarage"
        }
    }

    $cpuMetricMax.Data | ForEach-Object {
        [PSCustomObject]@{
            ServerName = $vm.Name
            Subscription = $sub
            ResourceGroup = $rg
            TimeStamp = $_.TimeStamp
            CPU = $_.Maximum
            Metric = "Maximum"
        }
    }
}

#Export results to CSV
$result | Export-Csv -Path "C:\temp\VmResults.csv" -NoTypeInformation -Force
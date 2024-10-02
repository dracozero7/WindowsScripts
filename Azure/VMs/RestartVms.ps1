$vms = Get-Content ".\serverlist.csv"

foreach ($vm in $vms) {
    $charArray = $vm.Split(",")
    $resource = Restart-AzVM -Name $charArray[0] -ResourceGroupName $charArray[1]
    Write-Host "Restarted VM" $charArray
}

Write-Host "Done!"
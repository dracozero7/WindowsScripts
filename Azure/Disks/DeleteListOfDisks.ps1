$vms = Get-Content ".\disklist.csv"

foreach ($vm in $vms) {
    $charArray = $vm.Split(",")
    Remove-AzDisk -ResourceGroupName $charArray[1] -DiskName $charArray[0] -Force
    Write-Host "Deleted disk" $charArray[0]
}
Write-Host "List completed"
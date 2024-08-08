$server = Get-Content ".\server-list.txt"

foreach ($server in $servers) {
    $charArray = $server.Split(",")
    $resource = Get-AzResource -Name $charArray[0] -ResourceGroupName $charArray[1]
    $tags = @{"Application"=$charArray[2]}
    Update-AzTag -ResourceId $resource.id -Tag $tags -Operation Merge
}
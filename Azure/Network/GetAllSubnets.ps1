$list = @()
$vnets = Get-AzVirtualNetwork

foreach ($vnet in $vnets) {
    $subnets = $vnet.Subnets.name

    foreach ($subnet in $subnets) {
        $subnetDetails = Get-AzVirtualNetworkSubnetConfig -Name $subnet -VirtualNetwork $vnet

        $list += [PSCustomObject]@{
            VNETName = $vnet.Name
            VNETAddressSpaces = $vnet.AddressSpace.AddressPrefixes -join ', '
            SubnetName = $SubnetDetails.Name
            SubnetPrefix = $subnetDetails.AddressPrefix -join ''
            SubnetNSG = if($null -eq $SubnetDetails.NetworkSecurityGroup) {"No NSG"} else {$subnetDetails.NetworkSecurityGroup.Id.Split('/')[8]}
            SubnetNSGID = IF($null -eq $subnetDetails.NetworkSecurityGroup) {"No NSG"} else {$subnetDetails.NetworkSecurityGroup.Id}
        }
    }
}

$list | ogv

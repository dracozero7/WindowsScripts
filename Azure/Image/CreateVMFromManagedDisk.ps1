$subscription = "sub"
$rg = "ResourceGroup" #For the new VM
$diskname = "NAME"
$location = "Location"
$virtualNetworkName = "VNET Name"
$VirtualNetworkRG = "Network RG"
$subnetID = "Subnet ID"
$virtualMachineName = "VM Name"
$virtualMachineSize = "Size"

#Get the managed Disk based on the resource group and the disk name
$disk = Get-Azdisk -ResourceGroupName $rg -DiskName $diskname

#Initialize virtual machine configuration
$vm = New-AzVMConfig -VMName $virtualNetworkName -VMSize $virtualMachineSize

#Use the Managed Disk Resource ID to attach it to the virtual machine.
#Change the OS type to linux if OS disk has Linux os
$vm = Set-AzVMOSDisk -VM $vm -ManagedDiskId $disk.Id -CreateOption Attach -Windows

#Get the virtual network where the VM will be hosted
$vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $VirtualNetworkRG

#Create NIC in the subnet
$nic = New-AzNetworkInterface -Name ($virtualMachineName.ToLower()+'_nic') -ResourceGroupName $rg -Location $location -SubnetId $subnetID

#Add nic to the vm
$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id

#Create the virtual machine with managed disk
New-AzVM -VM $vm -ResourceGroupName $rg -Location $location

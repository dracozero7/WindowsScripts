#Required Modules
Install-Module Az.Monitor
Install-Module Az.Compute

#Variables declaration
$subscription = "Subscription here"
$resourceGroup = "RG here"
$location = "East Us 2"
$vmName = "VMName here"
$size = "D4ads_v5"
$securityType = "Standard"
$Requestor = "Owner"
$subnetid = "subnetid"
$bootDiagnosticStorage = "StorageAccountName"
$PublisherName = "RedHat"
$Offer = "RHEL"
$Skus = "9-lvm-gen2"
$Version = "latest"

#Set subscription
Set-AzContext -Subscription $subscription

#Create user object
$securePassword = ConvertTo-SecureString -String "Password" -AsPlainText -Force
$user = "admin"
$credential = New-Object System.Management.Automation.PSCredential ($user, $securePassword)

#Network Pieces
$nic = New-AzNetworkInterface -Name $vmname"_NIC" -ResourceGroupName $resourceGroup -Location $location -SubnetId $subnetid

#Create a virtual machine configuration using the $image variable to specify the image
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $size | Set-AzVMOperatingSystem -Linux -ComputerName $vmName -Credential $credential | Add-AzVMNetworkInterface -Id $nic.Id

#Set Image for Linux Server
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $PublisherName -Offer $Offer -Skus $Skus -Version $Version

#Set security type, boot diagnostics
$vmConfig = Set-AzVMSecurityProfile -VM $vmConfig -SecurityType $securityType
$vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Enable -ResourceGroupName $resourceGroup -StorageAccountName $bootDiagnosticStorage

#Create a virtual machine
$vm = New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig -Tag @{"Owner"=$Requestor}

#Add into monitor collection Rule for monitoring
$ext = Set-AzVMExtension -Name AzureMonitorWindowsAgent -ExtensionType AzureMonitorWindowsAgent -Publisher Microsoft.Azure.Monitor -ResourceGroupName $resourceGroup -VMName $vmName -Location $location -TypeHandlerVersion "1.1" -EnableAutomaticUpgrade $true
$dcr = New-AzDataCollectionRuleAssociation -TargetResourceId $vm.Id -DataCollectionRuleId 'DataCollectionRule ID here' -AssociationName $vmName
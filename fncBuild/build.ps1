param($params)

#Allow detailed tracing
Set-PSDebug -Trace 0

write-verbose "Entering build.ps1"
$global:erroractionpreference = 1


# switch to the cloud desktop 02 sub
Set-AzContext -SubscriptionObject (Get-AzSubscription -SubscriptionName $params.vmBuildSub)
$rg = $params.rg
$location =  $params.location
$localusername = $params.localAdminName
$localpassword = (ConvertTo-SecureString $($params.localAdminPassword) -Force -AsPlainText)
$vmName = $params.vmname
$vmSize = $params.vmsize
$localcredential = New-Object System.Management.Automation.PScredential ($localusername, $localpassword)
$vNicName = $vmName + "-nic"
$virtualNetwork = $params.vmVnet
$subnet = $params.vmSubnet
$vnetResourceGroupName = $params.rg
$version = If ($params.OSVersion -eq "2016") {"2016-Datacenter"} elseif ($params.OSVersion -eq "2019") {"2019-Datacenter"} elseif ($params.OSVersion -eq "2022") {"2022-Datacenter"}

# Create the VM
Write-Host "Get vnet"
$vNet = Get-AzVirtualNetwork -Name $virtualNetwork -ResourceGroupName $vnetResourceGroupName
$subnetId = $vNet.Subnets | Where-Object Name -eq $subnet | Select-Object -ExpandProperty Id
Write-Host "Create nic for $($params.vmname)"
$vNic = New-AzNetworkInterface -Name $vNicName -ResourceGroupName $rg -location $location -SubnetId $subnetId 
$vm = New-AzVMConfig -vmName $vmName -vmSize $vmSize
$vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -credential $localcredential -ProvisionVMAgent -EnableAutoUpdate
$vm = Add-AzVMNetworkInterface -VM $vm -Id $vNic.Id
#$vm = Set-AZVMSourceImage $imageVersion
$vm = Set-AzVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus $version -Version "latest"
$vm = Set-AzVMOSDisk -VM $vm -StorageAccountType StandardSSD_LRS -CreateOption fromImage
Write-Host "Creating VM $($params.vmname)"
$z = 1,2,3 | get-random
Write-Host "Random availabilty zone $($z)"
New-AzVM -ResourceGroupName $rg -location $location -VM $vm -Verbose -Zone $z

#Create machine tags   
#Application Tag 
$machineTags = @{"Assigned_User"=$($params.emailTag)}

$resourceDetails = Get-AzResource -Name $vmName -ResourceGroup $rg
New-AzTag -ResourceId $resourceDetails.id -Tag $machineTags

Write-Host "Finished creating VM $($params.vmname)"

#Output the results of the script
$output = @{ScriptOutput = "Virtual Machine Created Successfully - VMName: $($params.vmname) - Login Name: $($params.localAdminName) - Password: $($params.localAdminPassword) - SAVE THIS INFORMATION"}

$output
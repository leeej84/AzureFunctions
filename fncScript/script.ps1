param($params)

#Allow detailed tracing
Set-PSDebug -Trace 0

write-verbose "Entering resizeVM.ps1"
$global:erroractionpreference = 1

#Import Modules
#Import-Module Microsoft.Graph.InTune

#Spit out all parameters
Write-Information "All parameters supplied - $($params | Out-String)"

#Loop through resource groups to find the VM
#Get all subscriptions available
$allSubscriptons = Get-AzSubscription

Write-Host "All subscriptions available"
Write-Host $allSubscriptons

#Loop through all subscriptions and hostpools looking for our wvd vm
$allSubscriptons = Get-AzSubscription | Where-Object { ($_.Name -eq "DLG-Cloud-Desktop-01") -or ($_.Name -eq $params.vmBuildSub) }
$vmWVDDetails = foreach ($subscription in $allSubscriptons) {
    $temp = Select-AzSubscription -Subscription $subscription.Id
    $allResourceGroups = Get-AzResourceGroup
    foreach ($rg in $allResourceGroups) {
        Write-Host "Searching subscription - $subscription for $($rg.ResourceGroupName)"
        $hostPools = Get-AzWvdHostPool -SubscriptionId $subscription.Id -ResourceGroupName $rg.ResourceGroupName
        if ($hostPools) {            
            foreach ($hostPool in $hostPools) {
                Write-Host "Searching hostpool - $($hostpool.Name) for $($params.vmname)"
                $vms = Get-AzWvdSessionHost -HostPoolName $hostpool.Name -ResourceGroupName $rg.ResourceGroupName -SubscriptionId $subscription.Id -ErrorAction SilentlyContinue | Where-Object {$_.Name -match $($params.vmname)} | Select-Object -ExpandProperty Name
                    foreach ($vm in $vms) {
                    [PSCustomObject]@{
                        vmName = $vm.Split("/")[1].Split(".")[0]
                        vmFQDN = $vm.Split("/")[1]
                        hostPool = $vm.Split("/")[0]
                        hostPoolRg = $rg.ResourceGroupName
                        subscription = $subscription.Id
                        #InTuneID = Get-IntuneManagedDevice -Filter "deviceName eq '$($vm.Split('.')[0])'" -ErrorAction SilentlyContinue | Select -ExpandProperty id             
                    }
                }
            }
            break
        }
    }
}

#Found the WVD VM
Write-Host "The WVD VM was found - $($vmWVDDetails)"

If ([string]::IsNullOrEmpty($vmWVDDetails.vmName)) {
    Write-Host "$($vmWVDDetails.vmName) does not exist in Azure."
} else {

    #Make sure we're talking in the right tenant and subscription
    Write-Host "Switch to subscription $($vmWVDDetails.Subscription)"
    Set-AzContext -Subscription $vmWVDDetails.subscription -Verbose

    #Write out our script to remove from the domain
    $psOutput = @"
    `$null = Start-Transcript -Path 'C:\Temp\Domain_Removal.log' 

    `$domainusername = "$($params.domainJoinAccount)@$($params.domain)"
    `$domainpassword = (ConvertTo-SecureString "$($params.avdDomainJoin)" -Force -AsPlainText)
    `$domaincredential = New-Object System.Management.Automation.PScredential (`$domainusername, `$domainpassword)

    `#Remove the computer from the domain
    `$result = Remove-Computer -UnjoinDomaincredential `$domaincredential -Force -Restart -Passthru -Confirm:`$false -WarningAction SilentlyContinue
    `#`$result = Remove-Computer -UnjoinDomaincredential `$domaincredential -Force -Passthru -Confirm:`$false -WarningAction SilentlyContinue

    `$result
    `$null = Stop-Transcript 
"@     

$psOutput | Out-File "$env:temp\Domain_Remove.ps1"

#Loop through resource groups to find the VM
#Get all subnscriptions available
$allSubscriptons = Get-AzSubscription

Write-Information "All subscriptions available"
Write-Information "$allSubscriptons"

#Search for the vm in each resource group within each subscription
$vmDetails = foreach ($subscription in $allSubscriptons) {
    $temp = Select-AzSubscription -Subscription $subscription
    Write-Host "Searching subscription - $subscription for $($params.vmname)"
    $allResourceGroups = Get-AzResourceGroup
    foreach ($rg in $allResourceGroups) {
        $azVMResult = Get-AzVM -Name $($params.vmname) -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
        if ($azVMResult) {
            $azVMResult
            $selectedSub = $subscription
            break
        }
    }
}

#Set the subscription to action
Set-AzContext -Subscription $selectedSub

#Check VM power state and power on if necessary
If (($($vmDetails | Get-AzVM -Status).Statuses[1].DisplayStatus) -eq "VM running") {
    $results = Invoke-AzVMRunCommand -VM $vmDetails -CommandId 'RunPowerShellScript' -ScriptPath "$env:temp\Domain_Remove.ps1" -Verbose
} else {
    $vmDetails | Start-AzVM -Verbose

    #Wait for 30 seconds for the VM to settle
    Start-Sleep -Seconds 30
    $results = Invoke-AzVMRunCommand -VM $vmDetails -CommandId 'RunPowerShellScript' -ScriptPath "$env:temp\Domain_Remove.ps1" -Verbose
}

#Check the result of the domain removal
if ($($results.value[0].message) -match "True") {
    #Output the results of the script
    $output = @{ScriptOutput = "Domain removal successful"}
} else {
    $output = @{ScriptOutput = "Domain removal failed"}
}

$output
}


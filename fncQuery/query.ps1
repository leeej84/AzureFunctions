param($params)

#Allow detailed tracing
Set-PSDebug -Trace 0

Write-Verbose "Entering Query.ps1"
$global:erroractionpreference = 1

#Spit out all parameters
Write-Host "All parameters supplied - $($params | Out-String)"

#Loop through resource groups to find the VM
#Get all subnscriptions available
$allSubscriptons = Get-AzSubscription

#Search for the vm in each resource group within each subscription
$vmDetails = foreach ($subscription in $allSubscriptons) {
    $null = Select-AzSubscription -Subscription $subscription
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

#Found the VM
Write-Host "The VM was found - $($vmDetails.name)"

#Get all the details of the VM
$machineDetails = Get-AzTag -ResourceId $vmDetails.Id -Verbose

#Output the results of the script
$output = @{ScriptOutput = $($machineDetails | ConvertTo-Json)}

$output
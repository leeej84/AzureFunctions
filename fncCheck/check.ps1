param($params)

#Allow detailed tracing
Set-PSDebug -Trace 1

write-verbose "Entering check.ps1"
$ErrorActionPreference = "Stop"

#Get VM Details
$vmDetails = Get-AzVM -Name $($Params.vmname)
if ($vmDetails) {Write-Host "Found VM - $($vmDetails.Name)"} else {Write-Host "VM Not Found"}
if ($vmDetails) {$vmExists = 1} else {$vmExists = 0}

#Output the results of the script
$details = @{VMExists = $vmExists}
$output = @{CheckOutput = $details}

$output

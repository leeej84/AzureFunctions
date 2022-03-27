using namespace System.Net
param($context)

#Allow detailed tracing
Set-PSDebug -Trace 1

$ErrorActionPreference = "Stop"

$status = [HttpStatusCode]::OK
$body = ""
$params = @{}

##### Set Subscription ID to work with #####
$subscriptionId = "8817c809-4996-4b1c-a7c2-41e960bae57d"
##### Set Subscription ID to work with #####

try
{
    $azcontext = Get-AzContext
    if($null -eq $azcontext) {
        Write-Error "No available Azure Context"
        return
    } else {
        Write-Host $azcontext.Subscription
    }

    $context | Select-Object * | write-host
    write-host "Type of $context.input is $($context.input.GetType())"
    write-host $context.input

    $functionParams = ConvertFrom-Json -InputObject $context.input

    #Switch to the relevant subscription
    $null = Set-AzContext -SubscriptionObject $(Get-AzSubscription -SubscriptionId $subscriptionId)

    $VMSize = switch ($functionParams.vmsize) {
        ("standard") { "Standard_D2s_v4" }
        ("large") { "Standard_D4s_v4" }
        ("xlarge") { "Standard_D8s_v4" }
        Default { "Standard_D2s_v4" }
    }

    #Get VM Details if a name is specified otherwise we need to generate a vmname
    if ($functionParams.vmname) {
        $vmDetails = Get-AzVM -Name $($functionParams.vmname)
        if ($vmDetails) {Write-Host "Found VM - $($vmDetails.Name)"} else {Write-Host "VM Not Found"}
        $vmname = $functionParams.vmname
    } else {
        Write-Host "No VM Name specified, generating one"
        #Generate a machine name
        # Set allowed ASCII character codes to Uppercase letters (65..90), 
        $charcodes = 65..90
        
        # Convert allowed character codes to characters
        $allowedChars = $charcodes | ForEach-Object { [char][byte]$_ }

        # Computer name length
        $LengthOfName = 10

        # Generate computer name
        if (!($vmName)) {
            $vmName = ($allowedChars | Get-Random -Count $LengthOfName) -join ""
            Write-Host "VM Name generated $($vmname)"
        } else {
            Write-Host "VM name from first orchestrator run being reused"
        }
    }

    #Generate a random password for the machine
    $vmPassword = ("!@#$%^&*0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".tochararray() | sort {Get-Random})[0..12] -join ''

    #Create parameter object to be passed to other functions
    $params = @{
        subscriptionid = $subscriptionId
        vmname   = $vmName      
        rg = "rg-cugc"
        location = "UKSouth"
        vmsize = $VMSize
        localAdminName = "local_admin"
        localAdminPassword = $vmPassword
        vmVnet = "vnet-cugc"
        vmSubnet = "subnet1"
        emailTag = $functionParams.email
        OSVersion = $functionParams.version
    }

    #Perform a check to see if the VM exists or not
    $check = Invoke-DurableActivity -FunctionName 'fncCheck' -Input $params
    Write-Host "Output from check function"
    Write-Host "The VM Exists Value - $($check.CheckOutput.VMExists)"

    #If the VM specified exists then we need to do some logic
    if ($check.CheckOutput.VMExists -eq 1) {        
        if ($functionParams.type -eq "query") {
            #Call the function to query the VM because it exists
            $res = Invoke-DurableActivity -FunctionName 'fncQuery' -Input $params
            $output = $res.ScriptOutput
        }
        if ($functionParams.type -eq "remove") {
            #Run VM Removal because the machine exists
            $res = Invoke-DurableActivity -FunctionName 'fncRemove' -Input $params
            $output = $res.ScriptOutput
        }
        if ($functionParams.type -eq "new") {
            Write-Host "The VM already exists and cannot be created"
            $output = "The VM already exists and cannot be created"
            $code = 2
        }
    } else {
        if ($functionParams.type -eq "query") {
            Write-Host "The VM cannot be queried because it does not exist"
            $output = "The VM cannot be queried because it does not exist"
            $code = 1
        }
        if ($functionParams.type -eq "remove") {
            Write-Host "The VM does not exist and cannot be removed"
            $output = "The VM does not exist and cannot be removed"
            $code = 1
        }
        if ($functionParams.type -eq "new") {
            #Run VM creation
            $res = Invoke-DurableActivity -FunctionName 'fncBuild' -Input $params
            #$res1 = Invoke-DurableActivity -FunctionName 'fncScript' -Input $params
            $output = $res.ScriptOutput + $res1.ScriptOutput
        }
    } 
} catch {
    $allOutput = [PSCustomObject]@{
    StatusCode = [HttpStatusCode]::InternalServerError
        Body = [PSCustomObject]@{ 
            FriendlyError = "Undefined Error - review Detailed Error"
            DetailedError = $_.Exception.ToString()
        }
    }
}

# pass the output object back
$allOutput = [PSCustomObject]@{
    StatusCode = If($code -eq 1){[HttpStatusCode]::NotFound}elseif($code -eq 2){[HttpStatusCode]::InternalServerError}else{[HttpStatusCode]::OK}
    Body = $output
}

$allOutput | ConvertTo-Json
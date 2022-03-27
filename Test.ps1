####Test
$requri = "https://fa-cugc.azurewebsites.net/api/orchestrators/Orchestration"

#Test to build a new machine
#$body = @{type="new";vmsize="standard";email="leee.jeffries@leeejeffries.com";version="2016"}  | ConvertTo-Json #standard, large, xlarge - 2016,2019,2022
##Test to query a machines details
#$body = @{type="query";vmname="VEXYRWTKGA"}  | ConvertTo-Json #vmname is mandatory
#Test to remove a machine
$body = @{type="remove";vmname="VEXYRWTKGA"}  | ConvertTo-Json #vmname is mandatory

try {
    $initialresp = Invoke-RestMethod -Uri $requri -Body $body -Method Post -ContentType "application/json" -UseBasicParsing
    $checkUri = $initialresp.statusQuerygetUri
    write-host $checkUri
    $status = ""
    while($status -ne "Completed") {
        Start-Sleep 15
        $checkresp = Invoke-RestMethod -Uri $checkUri -Method Get
        $status = $checkresp.runtimeStatus
        write-host "$([System.DateTime]::Now.ToLongTimeString()) $status"
        $checkresp
    }
} catch {
    "You broke your function app"
    $Error
}
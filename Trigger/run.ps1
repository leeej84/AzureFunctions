using namespace System.Net

param($Request, $TriggerMetadata)

$FunctionName = $Request.Params.FunctionName
$InstanceId = Start-NewOrchestration -FunctionName $FunctionName -InputObject $Request.RawBody
Write-Host "Started orchestration with ID = '$InstanceId'"

$response = New-OrchestrationCheckStatusResponse -Request $Request -InstanceId $InstanceId
Write-Host $response
Push-OutputBinding -Name Response -Value $response
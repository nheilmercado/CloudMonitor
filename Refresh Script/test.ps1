param (
    $BiWorspaceId,
    $vaultname,
    $PowerBiClientId,
    $PowerBiClientSecretKey,
    $tenantId
)

$password = Get-AzKeyVaultSecret -VaultName $vaultname -Name 'DBReadPassword' -AsPlainText
$username = Get-AzKeyVaultSecret -VaultName $vaultname -Name 'DBReadUserName' -AsPlainText



$applicationId = $PowerBiClientId
$TenantId = $tenantId

$clientsec =  ConvertTo-SecureString -String $PowerBiClientSecretKey -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $applicationId, $clientsec
Connect-PowerBIServiceAccount -ServicePrincipal -Credential $credential -TenantId $TenantId

#$workspace = Get-PowerBIWorkspace -Name $workspaceName
#Write-Host "Got workspace"


$dataset = Get-PowerBIDataset -WorkspaceId $BiWorspaceId -Name "Report"
Write-Host "Got dataset"

$workspaceId = $BiWorspaceId
$datasetId = $dataset.Id

$datasource = Get-PowerBIDatasource -WorkspaceId $workspaceId -DatasetId $datasetId

  
$gatewayId = $datasource.gatewayId
$datasourceId = $datasource.datasourceId
$datasourePatchUrl = "gateways/$gatewayId/datasources/$datasourceId"

Write-Host "Patching credentials"

# HTTP request body to patch datasource credentials
$userNameJson = "{""name"":""username"",""value"":""$username""}"
$passwordJson = "{""name"":""password"",""value"":""$password""}"

$patchBody = @{
"credentialDetails" = @{
  "credentials" = "{""credentialData"":[ $userNameJson, $passwordJson ]}"
  "credentialType" = "Basic"
  "encryptedConnection" =  "NotEncrypted"
  "encryptionAlgorithm" = "None"
  "privacyLevel" = "Organizational"
}
}

$patchBodyJson = ConvertTo-Json -InputObject $patchBody -Depth 6 -Compress

$patchBodyJson
Write-Host "groups/$($workspace.id)/datasets/$($dataset.Id)/Default.TakeOver"

Invoke-PowerBIRestMethod -Url "groups/$($workspaceId)/datasets/$($dataset.Id)/Default.TakeOver" -Method Post


$patchBodyJson
Write-Host "$datasourePatchUrl"

# Execute PATCH operation to set datasource credentials
Invoke-PowerBIRestMethod -Method Patch -Url $datasourePatchUrl -Body $patchBodyJson

Write-Host "Refreshing groups/$workspaceId/datasets/$datasetId/refreshes"
$datasetRefreshUrl = "groups/$workspaceId/datasets/$datasetId/refreshes"
Invoke-PowerBIRestMethod -Method Post -Url $datasetRefreshUrl 

$secureWorkspaceId = ConvertTo-SecureString "$($workspaceId)" -AsPlainText -Force
$secretWorkspaceId = Set-AzKeyVaultSecret -VaultName $vaultname -Name "PowerBiWorkspaceId" -SecretValue $secureWorkspaceId

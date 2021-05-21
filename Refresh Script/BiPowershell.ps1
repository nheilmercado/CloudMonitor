param (
    $Customer,
    $vaultname,
    $Environment,
    $PowerBiClientId,
    $PowerBiClientSecretKey,
    $tenantId
)

#Install-Module AzureRm  -Force -AllowClobber

Import-Module MicrosoftPowerBIMgmt
Import-Module newtonsoft.json
Import-Module Az.Accounts
Import-Module Az.KeyVault

Write-Host "VaultName: $($vaultname)"

#$clientsec =  ConvertTo-SecureString -String ".k_wJonJ~qXh4DO7~rwi7ETeh1F3Fu~8zn" -AsPlainText -Force
#$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "3f58cbe3-2f62-4548-b72a-914f14e54f98", $clientsec
#Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant c986e767-07af-4c9c-b2a1-08446a3c3e71
#Set-AzContext -Subscription "3b850c94-10ac-4e1b-8824-4d83a8002e5f"
#$Context = Get-AzContext

$password = Get-AzKeyVaultSecret -VaultName $vaultname -Name 'DBReadPassword' -AsPlainText
$username = Get-AzKeyVaultSecret -VaultName $vaultname -Name 'DBReadUserName' -AsPlainText

Write-Host "VaultName: $($password)"
Write-Host "VaultName: $($username)"

$workspaceName = "CloudMonitor - $($Customer) - $($Environment)"
$reportName = "CloudMonitor"

Write-Host "Workspace: $($workspaceName)"
#Write-Host "report name: $($reportName)"
#Write-Host "user: $($username)"
#Write-Host "password: $($password)"

Write-Host "29"
$applicationId = $PowerBiClientId

Write-Host "30"
$TenantId = $tenantId

Write-Host "31"
$clientsec =  ConvertTo-SecureString -String $PowerBiClientSecretKey -AsPlainText -Force

Write-Host "32"
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $applicationId, $clientsec

Write-Host "33	"
Connect-PowerBIServiceAccount -ServicePrincipal -Credential $credential -TenantId $TenantId

Write-Host "34"
Write-Host "Workspace: $($workspaceName)"
Get-PowerBIWorkspace -Name "$($workspaceName)"
$workspace = Get-PowerBIWorkspace -Name $workspaceName
Write-Host "Got workspace"
Write-Host "48"

$dataset = Get-PowerBIDataset -WorkspaceId $workspace.Id -Name $reportName
Write-Host "Got dataset"

$workspaceId = $workspace.Id
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

#$datasourePatchUrl
#$gatewayId
#$datasourceId

$patchBodyJson = ConvertTo-Json -InputObject $patchBody -Depth 6 -Compress

#$patchBody

Invoke-PowerBIRestMethod -Url "groups/$($workspace.id)/datasets/$($dataset.Id)/Default.TakeOver" -Method Post

# Execute PATCH operation to set datasource credentials
Invoke-PowerBIRestMethod -Method Patch -Url $datasourePatchUrl -Body $patchBodyJson

$datasetRefreshUrl = "groups/$workspaceId/datasets/$datasetId/refreshes"
Invoke-PowerBIRestMethod -Method Post -Url $datasetRefreshUrl 

$secureWorkspaceId = ConvertTo-SecureString "$($workspaceId)" -AsPlainText -Force
$secretWorkspaceId = Set-AzKeyVaultSecret -VaultName $vaultname -Name "PowerBiWorkspaceId" -SecretValue $secureWorkspaceId

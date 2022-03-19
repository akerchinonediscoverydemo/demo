# Variables
$azureUser = "akerchin@viacode.com"
$azurePassword = ""
$azureSubscription = "2ad8bb56-c476-44ab-99b1-66ca58501a62"
$azureTenant = "5860fa2f-95eb-447f-b1b8-8901c6e4b5b9"
$azureResourceGroup = "onediscoverydemo"
$azureLocation = "eastus"
$acrName = "onediscoverydemo"
$aksName = "onediscoverydemo"
$aksNodeSize = "standard_b4ms"
$aksNodeCount = "1"
$currentPath = (Get-Location).Path

Write-Host "1. Login to Azure" -fore green
az account clear
az login -u $azureUser -p $azurePassword --tenant $azureTenant
az account set --subscription $azureSubscription

Write-Host "2. Create Resource Group" -fore green
$rgIsCreated = az group exists -n $azureResourceGroup
if ($rgIsCreated -eq 'false') {
  Write-Host "Creating.."
  az group create --name $azureResourceGroup --location $azureLocation
}
else
{
  Write-Host "Already created."
}

Write-Host "3. Create ACR for Images and Helm Charts" -fore green
$acrIsExist = (az acr list --query "[?name =='$acrName'] | length(@)")
if($acrIsExist -eq 0){
  Write-Host "Creating.."
  az acr create --name $acrName --resource-group $azureResourceGroup --sku Basic --location $azureLocation --zone-redundancy Disabled --admin-enabled true
}
else
{
  Write-Host "Already created."
}

Write-Host "4. Get ACR credentials" -fore green
$acrCredentials = (az acr credential show -n $acrName | ConvertFrom-Json)
$acrUser = $acrCredentials.username
$acrPassword = $acrCredentials.passwords[0].value
Write-Host $acrUser $acrPassword
$acrSettingsContent = "# Container Registry for Docker Images`r"
$acrSettingsContent = $acrSettingsContent + "`$containerRegistryUserName" + " = '$acrUser'" + "`r`n"
$acrSettingsContent = $acrSettingsContent + "`$containerRegistryPassword" + " = '$acrPassword'" + "`r`n"
$acrSettingsContent = $acrSettingsContent + "`$containerRegistryPath" + " = '$acrName.azurecr.io'" + "`r`n"
[System.IO.File]::WriteAllText("$currentPath\AcrSettings.ps1", $acrSettingsContent)


Write-Host "5. Create AKS instance" -fore green
$aksIsExist = (az aks list --query "[?name == '$aksName'] | length(@)")
if($aksIsExist -eq 0){
  Write-Host "Creating.."
  az aks create --resource-group $azureResourceGroup --name $aksName --node-count $aksNodeCount --generate-ssh-keys --location $azureLocation --node-vm-size $aksNodeSize --enable-node-public-ip
}
else
{
  Write-Host "Already created."
}

Write-Host "6. Install kubectl" -fore green
az aks install-cli

Write-Host "7. Get credentials for AKS" -fore green
if (Test-Path $currentPath\kubeconfig) {
  Remove-Item $currentPath\kubeconfig
}
az aks get-credentials --resource-group $azureResourceGroup --name $aksName --file $currentPath\kubeconfig
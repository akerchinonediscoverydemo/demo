# Container Registry for Docker Images, import settings
.  ./AcrSettings.ps1

# Constants
$uiImageNameWithTag = "onediscoverydemoui:latest"
$apiImageNameWithTag = "onediscoverydemoapi:latest"
$domain = "onediscoverydemo.akerchin.site"
$version = (Get-Date).ToString("yyyyMMdd.hhmmss.0")
$build = (Get-Date).ToString("yyyy-MM-dd-hh-mm-ss")
$namespace = "onediscoverydemo"
$currentPath = (Get-Location).Path
$serviceName = "one-discovery-demo"

Write-Host "1. Login to Container Registry" -fore green
$env:DOCKER_BUILDKIT=0
docker login $containerRegistryPath --username $containerRegistryUserName --password $containerRegistryPassword

Write-Host "2. Build Image for API" -fore green
cd ../OneDiscoveryDemoApi/
docker build -t $apiImageNameWithTag .
cd ../CICD/

Write-Host "3. Push Image for API to Container Registry" -fore green
docker image tag $apiImageNameWithTag "$containerRegistryPath/$apiImageNameWithTag"
docker push "$containerRegistryPath/$apiImageNameWithTag"

Write-Host "4. Build Image for UI" -fore green
cd ../
docker build -t $uiImageNameWithTag -f OneDiscoveryDemoUi/Dockerfile .
cd ./CICD/

Write-Host "5. Push Image for UI to Container Registry" -fore green
docker image tag $uiImageNameWithTag "$containerRegistryPath/$uiImageNameWithTag"
docker push "$containerRegistryPath/$uiImageNameWithTag"

Write-Host "6. Login to Helm Repository" -fore green
Set-Item -Path Env:HELM_EXPERIMENTAL_OCI -Value 1
helm registry login $containerRegistryPath --username $containerRegistryUserName --password $containerRegistryPassword

Write-Host "7. Copy Helm Template to the temporary data folder" -fore green
Copy-Item -Path $currentPath/helmChartTemplate/ -Destination $currentPath/temp/helmChart -Recurse -Force

Write-Host "8. Create secret for Container Registry" -fore green
kubectl create secret docker-registry secretname --docker-server=$containerRegistryPath --docker-username=$containerRegistryUserName --docker-password=$containerRegistryPassword --kubeconfig ./kubeconfig --dry-run=client > ./temp/secret.yaml -o=json
$secretFile = Get-Content './temp/secret.yaml' | Out-String | ConvertFrom-Json
$containerRegistryAuth = $secretFile.data.{.dockerconfigjson}
Write-Host $containerRegistryAuth

Write-Host "9. Fill parameters for helm chart" -fore green
$templateValues = @{
  NAMESPACE = $namespace
  BUILD = $build
  API_SERVICE_IMAGE = "$containerRegistryPath/$apiImageNameWithTag"
  UI_SERVICE_IMAGE = "$containerRegistryPath/$uiImageNameWithTag"
  CONTAINER_REGISTRY_SECRET = $containerRegistryAuth
  DOMAIN = $domain
}
$instanceFilePath = "$currentPath/temp/helmChart/values.yaml"
$instanceContent = [System.IO.File]::ReadAllText($instanceFilePath)
foreach ($templateValue in $templateValues.GetEnumerator()) {
  $templateValueName = $templateValue.Name
  $templateValueValue = $templateValue.Value
  $instanceContent = $instanceContent.Replace(("%"+$templateValueName+"%"),$templateValueValue)
  Write-Host "${templateValueName} = ${templateValueValue}"
}
[System.IO.File]::WriteAllText($instanceFilePath, $instanceContent)

Write-Host "10. Create Helm Chart archive localy" -fore green
helm package $currentPath/temp/helmChart --version $version --app-version $build -d $currentPath/temp

Write-Host "11. Push Helm Chart to Repository" -fore green
helm push $currentPath/temp/$serviceName-$version.tgz oci://$containerRegistryPath/helm

Write-Host "12. Run instance in Kubernetes" -fore green
helm repo update
helm uninstall $serviceName --kubeconfig $currentPath/kubeconfig --namespace $namespace
helm install $serviceName oci://$containerRegistryPath/helm/$serviceName --version $version --kubeconfig $currentPath/kubeconfig --namespace $namespace --create-namespace --set service.build=$build

Write-Host "13. Clear temporary data" -fore green
Remove-Item -LiteralPath $currentPath/temp -Force -Recurse -ErrorAction Ignore
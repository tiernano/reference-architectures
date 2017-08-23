#
# Deploy_ReferenceArchitecture.ps1
#
param(
    [Parameter(Mandatory = $true)]
    $SubscriptionId,
    [Parameter(Mandatory = $true)]
    $Location,
    [Parameter(Mandatory = $true)]
    [ValidateSet("All","Infrastructure", "Workload")]
    $Mode
)

$ErrorActionPreference = "Stop"

$templateRootUriString = $env:TEMPLATE_ROOT_URI
if ($templateRootUriString -eq $null) {
    $templateRootUriString = "https://raw.githubusercontent.com/mspnp/template-building-blocks/v1.0.0/"
}

if (![System.Uri]::IsWellFormedUriString($templateRootUriString, [System.UriKind]::Absolute)) {
    throw "Invalid value for TEMPLATE_ROOT_URI: $env:TEMPLATE_ROOT_URI"
}

Write-Host
Write-Host "Using $templateRootUriString to locate templates"
Write-Host

# Deployer templates for respective resources
$templateRootUri = New-Object System.Uri -ArgumentList @($templateRootUriString)

$virtualNetworkTemplateUri = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/vnet-n-subnet/azuredeploy.json")
$virtualNetworkGatewayTemplateUri = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/vpn-gateway-vpn-connection/azuredeploy.json")
$virtualMachineTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, 'templates/buildingBlocks/multi-vm-n-nic-m-storage/azuredeploy.json')
$loadBalancedVmSetTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, 'templates/buildingBlocks/loadBalancer-backend-n-vm/azuredeploy.json')
$virtualMachineExtensionsTemplate = New-Object System.Uri -ArgumentList @($templateRootUri, "templates/buildingBlocks/virtualMachine-extensions/azuredeploy.json")

# Template parameters for respective deployments
$virtualNetworkParametersPath = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', 'virtualNetwork.parameters.json')
$virtualNetworkGatewayParametersPath = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', 'virtualNetworkGateway.parameters.json')
$jumpboxParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', 'jumpbox.parameters.json')
$wdpParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', 'sapWdp.parameters.json')
$appsParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', 'sapApps.parameters.json')
$scsParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', 'sapScs.parameters.json')
$hanaParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', 'sapHana.parameters.json')
$fsWitnessParametersFile = [System.IO.Path]::Combine($PSScriptRoot, 'parameters', 'sapFsWitness.parameters.json')

# Azure ADDS Parameter Files
$domainControllersParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\adds\ad.parameters.json")
$virtualNetworkDNSParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\adds\virtualNetwork-adds-dns.parameters.json")
$addAddsDomainControllerExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\adds\add-adds-domain-controller.parameters.json")
$createAddsDomainControllerForestExtensionParametersFile = [System.IO.Path]::Combine($PSScriptRoot, "parameters\adds\create-adds-forest-extension.parameters.json")

$infrastructureResourceGroupName = "sap-hana-infrastructure"
$workloadResourceGroupName = "sap-hana-workload"

$adVM1Name = "RA-SAP-AD-VM1"
$adVM2Name = "RA-SAP-AD-VM2"

# Login to Azure and select the subscription
Login-AzureRmAccount -SubscriptionId $SubscriptionId | Out-Null

if ($Mode -eq "Infrastructure" -or $Mode -eq "All") {
    Write-Host "Creating infrastructure resource group..."
    $infrastructureResourceGroup = New-AzureRmResourceGroup -Name $infrastructureResourceGroupName -Location $Location

    Write-Host "Deploying virtual network..."
    New-AzureRmResourceGroupDeployment -Name "vnet-deployment" -ResourceGroupName $infrastructureResourceGroup.ResourceGroupName `
        -TemplateUri $virtualNetworkTemplateUri.AbsoluteUri -TemplateParameterFile $virtualNetworkParametersPath

    Write-Host "Deploying jumpbox server..."
    New-AzureRmResourceGroupDeployment -Name "jumpbox-deployment" -ResourceGroupName $infrastructureResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $jumpboxParametersFile

    Write-Host "Deploying ADDS servers..."
    New-AzureRmResourceGroupDeployment -Name "ad-deployment" -ResourceGroupName $infrastructureResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $domainControllersParametersFile

    Write-Host "Updating virtual network DNS servers..."
    New-AzureRmResourceGroupDeployment -Name "update-dns" -ResourceGroupName $infrastructureResourceGroup.ResourceGroupName `
        -TemplateUri $virtualNetworkTemplateUri.AbsoluteUri -TemplateParameterFile $virtualNetworkDNSParametersFile

    Write-Host "Creating ADDS forest..."
    New-AzureRmResourceGroupDeployment -Name "primary-ad-ext" -ResourceGroupName $infrastructureResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $createAddsDomainControllerForestExtensionParametersFile

    Write-Host "Restarting primary and secondary Active Directory servers..."
    Restart-AzureRmVM -ResourceGroupName $infrastructureResourceGroup.ResourceGroupName -Name $adVM1Name
    Restart-AzureRmVM -ResourceGroupName $infrastructureResourceGroup.ResourceGroupName -Name $adVM2Name

    Write-Host "Creating ADDS domain controller..."
    New-AzureRmResourceGroupDeployment -Name "secondary-ad-ext" -ResourceGroupName $infrastructureResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineExtensionsTemplate.AbsoluteUri -TemplateParameterFile $addAddsDomainControllerExtensionParametersFile
}

if ($Mode -eq "Workload" -or $Mode -eq "All") {
    Write-Host "Creating workload resource group..."
    $workloadResourceGroup = New-AzureRmResourceGroup -Name $workloadResourceGroupName -Location $Location 

    Write-Host "Deploying SAP Web Dispatcher cluster..."
    New-AzureRmResourceGroupDeployment -Name "sap-wdp-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
        -TemplateUri $loadBalancedVmSetTemplate.AbsoluteUri -TemplateParameterFile $wdpParametersFile

    Write-Host "Deploying SAP Application cluster..."
    New-AzureRmResourceGroupDeployment -Name "sap-app-server-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $appsParametersFile

    Write-Host "Deploying SAP Central Service cluster..."
    New-AzureRmResourceGroupDeployment -Name "sap-scs-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
        -TemplateUri $loadBalancedVmSetTemplate.AbsoluteUri -TemplateParameterFile $scsParametersFile

    Write-Host "Deploying SAP Central Service cluster file share witness..."
    New-AzureRmResourceGroupDeployment -Name "sap-fs-witness-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $fsWitnessParametersFile

    Write-Host "Deploying SAP HANA Server..."
    New-AzureRmResourceGroupDeployment -Name "sap-hana-deployment" -ResourceGroupName $workloadResourceGroup.ResourceGroupName `
        -TemplateUri $virtualMachineTemplate.AbsoluteUri -TemplateParameterFile $hanaParametersFile
}



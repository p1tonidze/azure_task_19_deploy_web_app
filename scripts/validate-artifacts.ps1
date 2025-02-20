param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [bool]$DownloadArtifacts=$true
)


# default script values 
$taskName = "task19"

$artifactsConfigPath = "$PWD/artifacts.json"
$resourcesTemplateName = "exported-template.json"
$tempFolderPath = "$PWD/temp"

if ($DownloadArtifacts) { 
    Write-Output "Reading config" 
    $artifactsConfig = Get-Content -Path $artifactsConfigPath | ConvertFrom-Json 

    Write-Output "Checking if temp folder exists"
    if (-not (Test-Path "$tempFolderPath")) { 
        Write-Output "Temp folder does not exist, creating..."
        New-Item -ItemType Directory -Path $tempFolderPath
    }

    Write-Output "Downloading artifacts"

    if (-not $artifactsConfig.resourcesTemplate) { 
        throw "Artifact config value 'resourcesTemplate' is empty! Please make sure that you executed the script 'scripts/generate-artifacts.ps1', and commited your changes"
    } 
    Invoke-WebRequest -Uri $artifactsConfig.resourcesTemplate -OutFile "$tempFolderPath/$resourcesTemplateName" -UseBasicParsing

}

Write-Output "Validating artifacts"
$TemplateFileText = [System.IO.File]::ReadAllText("$tempFolderPath/$resourcesTemplateName")
$TemplateObject = ConvertFrom-Json $TemplateFileText -AsHashtable

$acr = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.ContainerRegistry/registries" )
if ($acr ) {
    if ($acr.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if Azure Container Registry resource exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Azure Container Registry resource was found in the task resource group. Please make sure you have only one ACR resource, and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Azure Container Registry resource in the task resource group. Please make sure that you created the ACR and try again."
}

$registryName = $acr.name.Replace("[parameters('registries_", "").Replace("_name')]", "")
Write-Output "Registry name: $registryName"
$imageName = "$($registryName).azurecr.io/todoapp"
Write-Output "Expected docker image name: $imageName"

if ($acr.sku.name -eq 'Basic') { 
    Write-Output "`u{2705} Checked the ACR SKU - OK."
} else { 
    Write-Output `u{1F914}
    throw "ACR SKU is not set to 'Basic'. Please re-create ACR with SKU 'Basic' and try again."
}

$asp = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Web/serverfarms" )
if ($asp ) {
    if ($acr.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if App Service Plan for the Web App exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one App Service Plan resource was found in the task resource group. App service plan is created automatically with the Web App - please clean-up un-used app service plans and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find App Service Plan resource. Please make sure that you created the Web App in the task resource group and try agian."
}

if ($asp.sku.name -eq 'F1') { 
    Write-Output "`u{2705} Checked the Web App SKU - OK."
} else { 
    Write-Output `u{1F914}
    throw "Unable to validate the Web App SKU. Please make sure that you used Free SKU when creating the web app and try again."
}

$webApp = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Web/sites" )
if ($webApp ) {
    if ($acr.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the Web App exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Web App resource was found in the task resource group. Please make sure that you have only one web app in the task resource group and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find the Web App resource. Please make sure that you created the Web App in the task resource group and try agian."
}

if ($webApp.kind.Contains('container')) { 
    Write-Output "`u{2705} Checked if the Web App has a type 'container' - OK."
} else { 
    Write-Output `u{1F914}
    throw "Unable to validate the web app type. Please make sure that Web App type is set to 'Container' (for that, recreate the web app) and try again."
}

if ($webApp.properties.siteConfig.linuxFxVersion.Contains($imageName)) { 
    Write-Output "`u{2705} Checked if the Web App is using docker image, published to the task ACR - OK."
} else { 
    Write-Output `u{1F914}
    throw "Unable to validate, that the web app is using Docker image from the ACR. Please make sure that the web app is loading docker image from the ACR you deployed for this task, and try again."
}

Write-Output ""
Write-Output "`u{1F973} Congratulations! All tests passed!"


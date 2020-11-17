<# 
 .Synopsis
  Produces the Azure AD Connect Config Documenter report

 .Description
  This cmdlet downloads and executes the Azure AD Config Documenter tool against supplied input files, and returns the 
  full path of the HTML report to the powershell pipeline.
  This cmdlet also will create subdirectories and files under the root output directory supplied as a parameter.

  .PARAMETER AADConnectProdConfigZipFilePath
    Full path of the ZIP file that from the Azure AD Connect environment in production

  .PARAMETER AADConnectProdStagingZipFilePath
    Full path of the ZIP file that from the Azure AD Connect environment in staging

  .PARAMETER OutputRootPath
    Full path of an output directory where the tool will be downloaded, and ZIP files will be expanded. 
    This cmdlet will NOT clean up the files there. 

   .PARAMETER CustomerName
    String lable that identifies the customer. This is used to create folder names and report filenames.

    .EXAMPLE
    .\Expand-AADAssessAADConnectConfig -AADConnectProdConfigZipFilePath "c:\temp\contoso\prod.zip" ` 
                                        -AADConnectProdStagingZipFilePath "c:\temp\contoso\staging.zip" `
                                        -OutputRootPath "c:\temp\contoso"`
                                        -CustomerName "contoso"
    
    This command will return a string with full path of the report "C:\Temp\Contoso\Report\Contoso_Production_AppliedTo_Contoso_Staging_AADConnectSync_report.html"

    .EXAMPLE
    .\Expand-AADAssessAADConnectConfig -AADConnectProdConfigZipFilePath "c:\temp\contoso\prod.zip" ` 
                                        -OutputRootPath "c:\temp\contoso" `
                                        -CustomerName "contoso"
    
    This command will return a string with full path of the report "C:\Temp\Contoso\Report\Contoso_Production_AppliedTo_Contoso_Production_AADConnectSync_report.html"


#>
Function Expand-AADAssessAADConnectConfig {
    param(
        [Parameter(Mandatory = $true)]
        [String]$AADConnectProdConfigZipFilePath,
        [Parameter(Mandatory = $false)]
        [String]$AADConnectProdStagingZipFilePath,
        [Parameter(Mandatory = $true)]
        [String]$OutputRootPath,
        [Parameter(Mandatory = $true)]
        [String]$CustomerName
    )
    
    #Step 1: Create SubFolder
    $WorkingPath = mkdir -Path $OutputRootPath -Name $CustomerName

    #Step 2: Download the AAD Config Documenter
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ConfigToolPath = Join-Path $WorkingPath.FullName  "AzureADConnectSyncDocumenter.zip"

    Invoke-WebRequest -Uri "https://aka.ms/aadcfgdocumenter/release" -OutFile $ConfigToolPath

    Expand-Archive -Path $ConfigToolPath -DestinationPath $WorkingPath.FullName

    #Step 3: Expand input files 
    $ConfigToolDataPath = Join-Path $WorkingPath.FullName "Data"

    $ConfigtoolCustomerDataPath = (mkdir -Path $ConfigToolDataPath -Name "$CustomerName").FullName
    Expand-Archive -Path $AADConnectProdConfigZipFilePath -DestinationPath $ConfigtoolCustomerDataPath
    Rename-Item -Path (Join-Path $ConfigtoolCustomerDataPath  "AzureADConnectSyncConfig") -NewName "Production"

    #Craft the names of the relative paths that will be called by the tool. Setting both to prod to start, and then
    #override the second argument if staging is provided
    $ToolArgument1 = Join-Path $CustomerName "Production"
    $ToolArgument2 = $ToolArgument1

    if (-not [String]::IsNullOrWhiteSpace($AADConnectProdStagingZipFilePath)) {
        Expand-Archive -Path $AADConnectProdStagingZipFilePath -DestinationPath $ConfigtoolCustomerDataPath
        Rename-Item -Path (Join-Path $ConfigtoolCustomerDataPath  "AzureADConnectSyncConfig") -NewName "Staging"
        $ToolArgument2 = Join-Path $CustomerName "Staging"
    }

    Set-Location $WorkingPath

    Invoke-Expression ('.\AzureADConnectSyncDocumenterCmd.exe "{1}" "{0}"' -f $ToolArgument1, $ToolArgument2)

    $report = (Get-ChildItem -Path (Join-Path $WorkingPath "Report") | Select-Object -First 1)

    Write-Output $report.FullName
}

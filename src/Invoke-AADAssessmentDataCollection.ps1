<# 
 .Synopsis
  Produces the Azure AD Configuration reports required by the Azure AD assesment
 .Description
  This cmdlet reads the configuration information from the target Azure AD Tenant and produces the output files 
  in a target directory

.EXAMPLE
   .\Invoke-AADAssessmentDataCollection -OutputDirectory "C:\Temp" 

#>
function Invoke-AADAssessmentDataCollection {
    [CmdletBinding()]
    param
    (
        # Full path of the directory where the output files will be generated.
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory = $env:SystemDrive
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        $OutputDirectory = Join-Path $OutputDirectory "AzureADAssessment"
        $OutputDirectoryData = Join-Path $OutputDirectory "Data"
        $AssessmentDetailPath = Join-Path $OutputDirectoryData "AzureADAssessment.json"
        $PackagePath = Join-Path $OutputDirectory "AzureADAssessmentData.zip"

        $OrganizationData = Get-MsGraphResults -ApiVersion 'v1.0' -RelativeUri 'organization'
        $InitialTenantDomain = $OrganizationData.verifiedDomains | Where-Object isInitial -EQ $true | Select-Object -ExpandProperty name -First 1
        $PackagePath = $PackagePath.Replace("AzureADAssessmentData.zip", "AzureADAssessmentData-$InitialTenantDomain.zip")

        ## Generate Assessment Data
        Assert-DirectoryExists $OutputDirectoryData
        ConvertTo-Json -InputObject @{
            AssessmentId       = if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) { $script:AppInsightsRuntimeState.OperationStack.Peek().Id } else { New-Guid }
            AssessmentVersion  = $MyInvocation.MyCommand.Module.Version.ToString()
            AssessmentTenantId = $OrganizationData.id
        } | Set-Content $AssessmentDetailPath

        ## Azure AD Data Collection
        $OutputDirectoryAAD = Join-Path $OutputDirectoryData "AAD-$InitialTenantDomain"
        Assert-DirectoryExists $OutputDirectoryAAD
        Get-AADAssessmentReports -OutputDirectory $OutputDirectoryAAD

        ## Package Output
        Compress-Archive (Join-Path $OutputDirectoryData '\*') -DestinationPath $PackagePath -Force

        ## Write Custom Event
        Write-AppInsightsEvent 'AAD Assessment Data Collection Complete' -OverrideProperties -Properties @{
            AssessmentId       = if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) { $script:AppInsightsRuntimeState.OperationStack.Peek().Id } else { New-Guid }
            AssessmentVersion  = $MyInvocation.MyCommand.Module.Version.ToString()
            AssessmentTenantId = $OrganizationData.id
        }
    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $true }
}

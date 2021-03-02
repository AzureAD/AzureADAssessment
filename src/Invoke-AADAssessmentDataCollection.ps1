<# 
 .Synopsis
  Produces the Azure AD Configuration reports required by the Azure AD assesment
 .Description
  This cmdlet reads the configuration information from the target Azure AD Tenant and produces the output files 
  in a target directory

 .PARAMETER OutputDirectory
    Full path of the directory where the output files will be generated.

.EXAMPLE
   .\Get-AADAssessmentReports -OutputDirectory "c:\temp\contoso" 

#>
Function Invoke-AADAssessmentDataCollection {
    [CmdletBinding()]
    param
    (
        # Path to output package file
        [Parameter(Mandatory = $true)]
        [string] $OutputDirectory
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        $OutputDirectoryReports = Join-Path $OutputDirectory "Reports"
        $AssessmentDetailPath = Join-Path $OutputDirectoryReports "AADAssessment.json"
        $OutputPath = Join-Path $OutputDirectory "AADAssessmentData.zip"

        $OrganizationData = Get-MsGraphResults -ApiVersion 'v1.0' -RelativeUri 'organization'
        $InitialTenantDomain = $OrganizationData.verifiedDomains | Where-Object isInitial -EQ $true | Select-Object -ExpandProperty name -First 1
        $OutputPath = $OutputPath.Replace("AADAssessmentData.zip", "AADAssessmentData - $InitialTenantDomain.zip")

        Assert-DirectoryExists $OutputDirectoryReports

        ## Generate Assessment Data
        ConvertTo-Json -InputObject @{
            AssessmentId       = if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) { $script:AppInsightsRuntimeState.OperationStack.Peek().Id } else { New-Guid }
            AssessmentVersion  = $MyInvocation.MyCommand.Module.Version.ToString()
            AssessmentTenantId = $OrganizationData.id
        } | Set-Content $AssessmentDetailPath

        ## Generate Reports
        Get-AADAssessmentReports -OutputDirectory $OutputDirectoryReports

        ## Package Output
        Compress-Archive (Join-Path $OutputDirectoryReports '\*') -DestinationPath $OutputPath -Force

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

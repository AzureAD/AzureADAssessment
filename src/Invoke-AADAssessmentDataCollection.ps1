<#
 .Synopsis
  Produces the Azure AD Configuration reports required by the Azure AD assesment
 .Description
  This cmdlet reads the configuration information from the target Azure AD Tenant and produces the output files
  in a target directory

.EXAMPLE
   .\Invoke-AADAssessmentDataCollection -OutputDirectory "C:\"

#>
function Invoke-AADAssessmentDataCollection {
    [CmdletBinding()]
    param(
        # Full path of the directory where the output files will be generated.
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory = (Join-Path $env:SystemDrive 'AzureADAssessment')
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        ## Initalize Directory Paths
        #$OutputDirectory = Join-Path $OutputDirectory "AzureADAssessment"
        $OutputDirectoryData = Join-Path $OutputDirectory "AzureADAssessmentData"
        $AssessmentDetailPath = Join-Path $OutputDirectoryData "AzureADAssessment.json"
        $PackagePath = Join-Path $OutputDirectory "AzureADAssessmentData.zip"

        $OrganizationData = Get-MsGraphResults 'organization' -Select 'id', 'verifiedDomains'
        $InitialTenantDomain = $OrganizationData.verifiedDomains | Where-Object isInitial -EQ $true | Select-Object -ExpandProperty name -First 1
        $PackagePath = $PackagePath.Replace("AzureADAssessmentData.zip", "AzureADAssessmentData-$InitialTenantDomain.zip")

        ## Generate Assessment Data
        Assert-DirectoryExists $OutputDirectoryData
        ConvertTo-Json -InputObject @{
            AssessmentId       = if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) { $script:AppInsightsRuntimeState.OperationStack.Peek().Id } else { New-Guid }
            AssessmentVersion  = $MyInvocation.MyCommand.Module.Version.ToString()
            AssessmentTenantId = $OrganizationData.id
            AssessmentTenantDomain = $InitialTenantDomain
        } | Set-Content $AssessmentDetailPath

        ## Azure AD Data Collection
        $OutputDirectoryAAD = Join-Path $OutputDirectoryData "AAD-$InitialTenantDomain"
        Assert-DirectoryExists $OutputDirectoryAAD

        $reportsToRun = [ordered]@{
            "Get-AADAssessNotificationEmailAddresses"     = "NotificationsEmailAddresses.csv"
            "Get-AADAssessAppAssignmentReport"            = "AppAssignments.csv"
            "Get-AADAssessApplicationKeyExpirationReport" = "AppKeysReport.csv"
            #"Get-AADAssessConsentGrantList"               = "ConsentGrantList.csv"
        }

        $totalReports = $reportsToRun.Count + 1 #to include conditional access
        $processedReports = 0

        foreach ($reportKvP in $reportsToRun.GetEnumerator()) {
            $functionName = $reportKvP.Name
            $outputFileName = $reportKvP.Value
            $percentComplete = 100 * $processedReports / $totalReports
            Write-Progress -Activity "Reading Azure AD Configuration" -CurrentOperation "Running Report $functionName" -PercentComplete $percentComplete
            Get-AADAssessmentSingleReport -FunctionName $functionName -OutputDirectory $OutputDirectoryAAD -OutputCSVFileName $outputFileName
            $processedReports++
        }

        $percentComplete = 100 * $processedReports / $totalReports
        Write-Progress -Activity "Reading Azure AD Configuration" -CurrentOperation "Running Report Get-AADAssessCAPolicyReports" -PercentComplete $percentComplete

        Get-AADAssessCAPolicyReports -OutputDirectory $OutputDirectoryAAD


        ## Write Custom Event
        Write-AppInsightsEvent 'AAD Assessment Data Collection Complete' -OverrideProperties -Properties @{
            AssessmentId       = if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) { $script:AppInsightsRuntimeState.OperationStack.Peek().Id } else { New-Guid }
            AssessmentVersion  = $MyInvocation.MyCommand.Module.Version.ToString()
            AssessmentTenantId = $OrganizationData.id
        }

        ## Package Output
        Compress-Archive (Join-Path $OutputDirectoryData '\*') -DestinationPath $PackagePath -Force -ErrorAction Stop

        ## Clean-Up Data Files
        Remove-Item $OutputDirectoryData -Recurse -Force

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

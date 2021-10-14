<#
.SYNOPSIS
    Produces the Azure AD Configuration reports required by the Azure AD assesment
.DESCRIPTION
    This cmdlet reads the configuration information from the target Azure AD Tenant and produces the output files in a target directory
.EXAMPLE
    PS C:\> Complete-AADAssessmentReports
    Expand assessment data and reports to "C:\AzureADAssessment".
.EXAMPLE
    PS C:\> Complete-AADAssessmentReports -OutputDirectory "C:\Temp"
    Expand assessment data and reports to "C:\Temp".
#>
function Complete-AADAssessmentReports {
    [CmdletBinding()]
    param
    (
        # Specifies a path
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string] $Path,
        # Full path of the directory where the output files will be copied.
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory = (Join-Path $env:SystemDrive 'AzureADAssessment'),
        # Skip copying data and PowerBI dashboards to "C:\AzureADAssessment\PowerBI"
        [Parameter(Mandatory = $false)]
        [switch] $SkipPowerBIWorkingDirectory,
        # Includes the new recommendations report in the output
        [Parameter(Mandatory = $false)]
        [switch] $IncludeRecommendations,
        # Path to the spreadsheet with the interview answers
        [Parameter(Mandatory = $false)]
        [string] $InterviewSpreadsheetPath
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        ## Return Immediately when Telemetry is Disabled
        if(!($script:ModuleConfig.'ai.disabled'))
        {
            if (!$script:ConnectState.MsGraphToken) {
                #Connect-AADAssessment
                if (!$script:ConnectState.ClientApplication) {
                    $script:ConnectState.ClientApplication = New-MsalClientApplication -ClientId $script:ModuleConfig.'aad.clientId' -ErrorAction Stop
                    $script:ConnectState.CloudEnvironment = 'Global'
                }
                $CorrelationId = New-Guid
                if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) {
                    $CorrelationId = $script:AppInsightsRuntimeState.OperationStack.Peek().Id
                }
                ## Authenticate with Lightweight Consent
                $script:ConnectState.MsGraphToken = Get-MsalToken -PublicClientApplication $script:ConnectState.ClientApplication -Scopes 'openid' -UseEmbeddedWebView:$true -CorrelationId $CorrelationId -Verbose:$false -ErrorAction Stop
            }
        }

        if ($MyInvocation.CommandOrigin -eq 'Runspace') {
            ## Reset Parent Progress Bar
            New-Variable -Name stackProgressId -Scope Script -Value (New-Object 'System.Collections.Generic.Stack[int]') -ErrorAction SilentlyContinue
            $stackProgressId.Clear()
            $stackProgressId.Push(0)
        }

        ## Initalize Directory Paths
        #$OutputDirectory = Join-Path (Split-Path $Path) ([IO.Path]::GetFileNameWithoutExtension($Path))
        #$OutputDirectory = Join-Path $OutputDirectory "AzureADAssessment"
        $OutputDirectoryData = Join-Path $OutputDirectory ([IO.Path]::GetFileNameWithoutExtension($Path))
        $AssessmentDetailPath = Join-Path $OutputDirectoryData "AzureADAssessment.json"

        ## Expand Data Package
        Write-Progress -Id 0 -Activity 'Microsoft Azure AD Assessment Complete Reports' -Status 'Expand Data' -PercentComplete 0
        Expand-Archive $Path -DestinationPath $OutputDirectoryData -Force -ErrorAction Stop
        $AssessmentDetail = Get-Content $AssessmentDetailPath -Raw | ConvertFrom-Json

        ## Load Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Complete Reports - {0}' -f $AssessmentDetail.AssessmentTenantDomain) -Status 'Load Data' -PercentComplete 10
        $OutputDirectoryAAD = Join-Path $OutputDirectoryData 'AAD-*' -Resolve -ErrorAction Stop

        ## Generate Reports
        [array] $DataFiles = Get-Item -Path (Join-Path $OutputDirectoryAAD "*") -Include "*Data.xml"
        if ($DataFiles -and $DataFiles.Count -eq 7) {
            Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Complete Reports - {0}' -f $AssessmentDetail.AssessmentTenantDomain) -Status 'Output Report Data' -PercentComplete 20
            Export-AADAssessmentReportData -SourceDirectory $OutputDirectoryAAD -OutputDirectory $OutputDirectoryAAD

            Remove-Item -Path (Join-Path $OutputDirectoryAAD "*") -Include "*Data.xml" -ErrorAction Ignore
        }

        ## Generate Recommendations
        if($IncludeRecommendations) {
            Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Complete Reports - {0}' -f $AssessmentDetail.AssessmentTenantDomain) -Status 'Generating Recommendations' -PercentComplete 30
            New-AADAssessmentRecommendations -Path $OutputDirectory -OutputDirectory $OutputDirectory -InterviewSpreadsheetPath $InterviewSpreadsheetPath -SkipExpand
        }

        ## Report Complete
        Write-AppInsightsEvent 'AAD Assessment Report Generation Complete' -OverrideProperties -Properties @{
            AssessmentId       = $AssessmentDetail.AssessmentId
            AssessmentVersion  = $AssessmentDetail.AssessmentVersion
            AssessmentTenantId = $AssessmentDetail.AssessmentTenantId
            AssessorTenantId   = if ((Get-ObjectPropertyValue $script:ConnectState.MsGraphToken 'Account') -and $script:ConnectState.MsGraphToken.Account) { $script:ConnectState.MsGraphToken.Account.HomeAccountId.TenantId } else { if (Get-ObjectPropertyValue $script:ConnectState.MsGraphToken 'AccessToken') { Expand-JsonWebTokenPayload $script:ConnectState.MsGraphToken.AccessToken | Select-Object -ExpandProperty tid } }
            AssessorUserId     = if ((Get-ObjectPropertyValue $script:ConnectState.MsGraphToken 'Account') -and $script:ConnectState.MsGraphToken.Account -and $script:ConnectState.MsGraphToken.Account.HomeAccountId.TenantId -in ('72f988bf-86f1-41af-91ab-2d7cd011db47', 'cc7d0b33-84c6-4368-a879-2e47139b7b1f')) { $script:ConnectState.MsGraphToken.Account.HomeAccountId.ObjectId }
        }

        ## Rename
        #Rename-Item $OutputDirectoryData -NewName $AssessmentDetail.AssessmentTenantDomain -Force
        #$OutputDirectoryData = Join-Path $OutputDirectory $AssessmentDetail.AssessmentTenantDomain

        ## Download Additional Tools
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Complete Reports - {0}' -f $AssessmentDetail.AssessmentTenantDomain) -Status 'Download Reporting Tools' -PercentComplete 80

        $AdfsAadMigrationModulePath = Join-Path $OutputDirectoryData 'ADFSAADMigrationUtils.psm1'
        Invoke-WebRequest -Uri $script:ModuleConfig.'tool.ADFSAADMigrationUtilsUri' -UseBasicParsing -OutFile $AdfsAadMigrationModulePath

        ## Download PowerBI Dashboards
        $PBITemplateAssessmentPath = Join-Path $OutputDirectoryData 'AzureADAssessment.pbit'
        Invoke-WebRequest -Uri $script:ModuleConfig.'pbi.assessmentTemplateUri' -UseBasicParsing -OutFile $PBITemplateAssessmentPath

        $PBITemplateConditionalAccessPath = Join-Path $OutputDirectoryData 'AzureADAssessment-ConditionalAccess.pbit'
        Invoke-WebRequest -Uri $script:ModuleConfig.'pbi.conditionalAccessTemplateUri' -UseBasicParsing -OutFile $PBITemplateConditionalAccessPath

        ## Copy to PowerBI Default Working Directory
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Complete Reports - {0}' -f $AssessmentDetail.AssessmentTenantDomain) -Status 'Copy to PowerBI Working Directory' -PercentComplete 90
        if (!$SkipPowerBIWorkingDirectory) {
            $PowerBIWorkingDirectory = Join-Path "C:\AzureADAssessment" "PowerBI"
            Assert-DirectoryExists $PowerBIWorkingDirectory
            Copy-Item -Path (Join-Path $OutputDirectoryAAD '*') -Destination $PowerBIWorkingDirectory -Force
            Copy-Item -LiteralPath $PBITemplateAssessmentPath, $PBITemplateConditionalAccessPath -Destination $PowerBIWorkingDirectory -Force
            #Invoke-Item $PowerBIWorkingDirectory
        }

        ## Expand AAD Connect

        ## Expand other zips?

        ## Complete
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Complete Reports - {0}' -f $AssessmentDetail.AssessmentTenantDomain) -Completed
        Invoke-Item $OutputDirectoryData

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}


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
        [switch] $SkipPowerBIWorkingDirectory
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

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
        # [array] $OrganizationData = Get-Content (Join-Path $OutputDirectoryAAD "OrganizationData.json") -Raw | ConvertFrom-Json
        # [array] $DirectoryRoleData = Get-Content (Join-Path $OutputDirectoryAAD "DirectoryRoleData.json") -Raw | ConvertFrom-Json
        # [array] $ApplicationData = Get-Content (Join-Path $OutputDirectoryAAD "ApplicationData.json") -Raw | ConvertFrom-Json
        # [array] $ServicePrincipalData = Get-Content (Join-Path $OutputDirectoryAAD "ServicePrincipalData.json") -Raw | ConvertFrom-Json
        # [array] $AppRoleAssignmentData = Get-Content (Join-Path $OutputDirectoryAAD "AppRoleAssignmentData.json") -Raw | ConvertFrom-Json
        # [array] $OAuth2PermissionGrantData = Get-Content (Join-Path $OutputDirectoryAAD "OAuth2PermissionGrantData.json") -Raw | ConvertFrom-Json
        # [array] $UserData = Get-Content (Join-Path $OutputDirectoryAAD "UserData.json") -Raw | ConvertFrom-Json
        # [array] $GroupData = Get-Content (Join-Path $OutputDirectoryAAD "GroupData.json") -Raw | ConvertFrom-Json
        #Remove-Item -Path (Join-Path $OutputDirectoryAAD "*") -Include "OrganizationData.json", "DirectoryRoleData.json", "ApplicationData.json", "ServicePrincipalData.json", "AppRoleAssignmentData.json", "OAuth2PermissionGrantData.json", "UserData.json", "GroupData.json"

        #[array] $OrganizationData = Import-Clixml (Join-Path $OutputDirectoryAAD "OrganizationData.xml")
        #[array] $DirectoryRoleData = Import-Clixml (Join-Path $OutputDirectoryAAD "DirectoryRoleData.xml")
        #[array] $ApplicationData = Import-Clixml (Join-Path $OutputDirectoryAAD "ApplicationData.xml")
        #[array] $ServicePrincipalData = Import-Clixml (Join-Path $OutputDirectoryAAD "ServicePrincipalData.xml")
        #[array] $AppRoleAssignmentData = Import-Clixml (Join-Path $OutputDirectoryAAD "AppRoleAssignmentData.xml")
        #[array] $OAuth2PermissionGrantData = Import-Clixml (Join-Path $OutputDirectoryAAD "OAuth2PermissionGrantData.xml")
        #[array] $UserData = Import-Clixml (Join-Path $OutputDirectoryAAD "UserData.xml")
        #[array] $GroupData = Import-Clixml (Join-Path $OutputDirectoryAAD "GroupData.xml")
        #Remove-Item -Path (Join-Path $OutputDirectoryAAD "*") -Include "OrganizationData.xml", "DirectoryRoleData.xml", "ApplicationData.xml", "ServicePrincipalData.xml", "AppRoleAssignmentData.xml", "OAuth2PermissionGrantData.xml", "UserData.xml", "GroupData.xml"

        ## Generate Reports
        #Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Complete Reports - {0}' -f $AssessmentDetail.AssessmentTenantDomain) -Status 'Complete Reports' -PercentComplete 30
        #Get-AADAssessNotificationEmailsReport -OrganizationData $OrganizationData -UserData $UserData -GroupData $GroupData -DirectoryRoleData $DirectoryRoleData | Export-Csv -Path (Join-Path $OutputDirectoryAAD "NotificationsEmailsReport.csv") -NoTypeInformation
        #Get-AADAssessAppAssignmentReport -ServicePrincipalData $ServicePrincipalData -AppRoleAssignmentData $AppRoleAssignmentData | Export-Csv -Path (Join-Path $OutputDirectoryAAD "AppAssignmentsReport.csv") -NoTypeInformation
        #Get-AADAssessApplicationKeyExpirationReport -ApplicationData $ApplicationData -ServicePrincipalData $ServicePrincipalData | Export-Csv -Path (Join-Path $OutputDirectoryAAD "AppCredentialsReport.csv") -NoTypeInformation
        #Get-AADAssessConsentGrantReport -UserData $UserData -ServicePrincipalData $ServicePrincipalData -OAuth2PermissionGrantData $OAuth2PermissionGrantData -AppRoleAssignmentData $AppRoleAssignmentData | Export-Csv -Path (Join-Path $OutputDirectoryAAD "ConsentGrantReport.csv") -NoTypeInformation

        ## Report Complete
        Write-AppInsightsEvent 'AAD Assessment Report Generation Complete' -OverrideProperties -Properties @{
            AssessmentId       = $AssessmentDetail.AssessmentId
            AssessmentVersion  = $AssessmentDetail.AssessmentVersion
            AssessmentTenantId = $AssessmentDetail.AssessmentTenantId
            AssessorTenantId   = if ($script:ConnectState.MsGraphToken.Account) { $script:ConnectState.MsGraphToken.Account.HomeAccountId.TenantId } else { Expand-JsonWebTokenPayload $script:ConnectState.MsGraphToken.AccessToken | Select-Object -ExpandProperty tid }
            AssessorUserId     = if ($script:ConnectState.MsGraphToken.Account -and $script:ConnectState.MsGraphToken.Account.HomeAccountId.TenantId -in ('72f988bf-86f1-41af-91ab-2d7cd011db47', 'cc7d0b33-84c6-4368-a879-2e47139b7b1f')) { $script:ConnectState.MsGraphToken.Account.HomeAccountId.ObjectId }
        }

        ## Rename
        #Rename-Item $OutputDirectoryData -NewName $AssessmentDetail.AssessmentTenantDomain -Force
        #$OutputDirectoryData = Join-Path $OutputDirectory $AssessmentDetail.AssessmentTenantDomain

        ## Download Additional Tools
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Complete Reports - {0}' -f $AssessmentDetail.AssessmentTenantDomain) -Status 'Download Reporting Tools' -PercentComplete 80

        $AdfsAadMigrationModulePath = Join-Path $OutputDirectoryData 'ADFSAADMigrationUtils.psm1'
        Invoke-WebRequest -Uri $script:ModuleConfig.'tool.ADFSAADMigrationUtilsUri' -UseBasicParsing -OutFile $AdfsAadMigrationModulePath

        ## Download PowerBI Dashboards
        $PBITemplatePowerShellPath = Join-Path $OutputDirectoryData 'AzureADAssessment-PowerShell.pbit'
        Invoke-WebRequest -Uri $script:ModuleConfig.'pbi.powershellTemplateUri' -UseBasicParsing -OutFile $PBITemplatePowerShellPath

        $PBITemplateConditionalAccessPath = Join-Path $OutputDirectoryData 'AzureADAssessment-ConditionalAccess.pbit'
        Invoke-WebRequest -Uri $script:ModuleConfig.'pbi.conditionalAccessTemplateUri' -UseBasicParsing -OutFile $PBITemplateConditionalAccessPath

        ## Copy to PowerBI Default Working Directory
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Complete Reports - {0}' -f $AssessmentDetail.AssessmentTenantDomain) -Status 'Copy to PowerBI Working Directory' -PercentComplete 90
        if (!$SkipPowerBIWorkingDirectory) {
            $PowerBIWorkingDirectory = Join-Path "C:\AzureADAssessment" "PowerBI"
            Assert-DirectoryExists $PowerBIWorkingDirectory
            Copy-Item -Path (Join-Path $OutputDirectoryAAD '*') -Destination $PowerBIWorkingDirectory -Force
            Copy-Item -LiteralPath $PBITemplatePowerShellPath, $PBITemplateConditionalAccessPath -Destination $PowerBIWorkingDirectory -Force
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

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
    param (
        # Full path of the directory where the output files will be generated.
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory = (Join-Path $env:SystemDrive 'AzureADAssessment'),
        # Generate Reports
        [Parameter(Mandatory = $false)]
        [switch] $SkipReportOutput
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        ## Initalize Directory Paths
        #$OutputDirectory = Join-Path $OutputDirectory "AzureADAssessment"
        $OutputDirectoryData = Join-Path $OutputDirectory "AzureADAssessmentData"
        $AssessmentDetailPath = Join-Path $OutputDirectoryData "AzureADAssessment.json"
        $PackagePath = Join-Path $OutputDirectory "AzureADAssessmentData.zip"

        ## Organization Data
        Write-Progress -Id 0 -Activity 'Microsoft Azure AD Assessment Data Collection' -Status 'Organization Details' -PercentComplete 0
        $OrganizationData = Get-MsGraphResults 'organization?$select=id,verifiedDomains,technicalNotificationMails' -ErrorAction Stop
        $InitialTenantDomain = $OrganizationData.verifiedDomains | Where-Object isInitial -EQ $true | Select-Object -ExpandProperty name -First 1
        $PackagePath = $PackagePath.Replace("AzureADAssessmentData.zip", "AzureADAssessmentData-$InitialTenantDomain.zip")
        $OutputDirectoryAAD = Join-Path $OutputDirectoryData "AAD-$InitialTenantDomain"
        Assert-DirectoryExists $OutputDirectoryAAD

        #Export-Clixml -InputObject $OrganizationData -Path (Join-Path $OutputDirectoryAAD "OrganizationData.xml")
        #ConvertTo-Json -InputObject $OrganizationData -Depth 10 | Set-Content (Join-Path $OutputDirectoryAAD "OrganizationData.json")

        ## Generate Assessment Data
        Assert-DirectoryExists $OutputDirectoryData
        ConvertTo-Json -InputObject @{
            AssessmentId       = if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) { $script:AppInsightsRuntimeState.OperationStack.Peek().Id } else { New-Guid }
            AssessmentVersion  = $MyInvocation.MyCommand.Module.Version.ToString()
            AssessmentTenantId = $OrganizationData.id
            AssessmentTenantDomain = $InitialTenantDomain
        } | Set-Content $AssessmentDetailPath

        ## Directory Role Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Directory Roles' -PercentComplete 10
        [array] $DirectoryRoleData = Get-MsGraphResults 'directoryRoles?$select=id,displayName&$expand=members'
        #Export-Clixml -InputObject $DirectoryRoleData -Path (Join-Path $OutputDirectoryAAD "DirectoryRoleData.xml")
        #ConvertTo-Json -InputObject $DirectoryRoleData -Depth 10 -Compress | Set-Content (Join-Path $OutputDirectoryAAD "DirectoryRoleData.json")

        ## Application Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Applications' -PercentComplete 20
        [array] $ApplicationData = Get-MsGraphResults 'applications?$select=id,appId,displayName,appRoles,keyCredentials,passwordCredentials' -Top 999
        #Export-Clixml -InputObject $ApplicationData -Path (Join-Path $OutputDirectoryAAD "ApplicationData.xml")
        #ConvertTo-Json -InputObject $ApplicationData -Depth 10 -Compress | Set-Content (Join-Path $OutputDirectoryAAD "ApplicationData.json")

        ## Service Principal Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Service Principals' -PercentComplete 30
        [array] $ServicePrincipalData = Get-MsGraphResults 'serviceprincipals?$select=id,servicePrincipalType,appId,displayName,accountEnabled,appOwnerOrganizationId,appRoles,oauth2PermissionScopes,keyCredentials,passwordCredentials' -Top 999
        #Export-Clixml -InputObject $ServicePrincipalData -Path (Join-Path $OutputDirectoryAAD "ServicePrincipalData.xml")
        #ConvertTo-Json -InputObject $ServicePrincipalData -Depth 10 -Compress | Set-Content (Join-Path $OutputDirectoryAAD "ServicePrincipalData.json")

        ## App Role Assignments Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'App Role Assignments' -PercentComplete 40
        [array] $AppRoleAssignmentData = Get-MsGraphResults 'serviceprincipals/{0}/appRoleAssignedTo' -UniqueId $ServicePrincipalData.id -Top 999
        #Export-Clixml -InputObject $AppRoleAssignmentData -Path (Join-Path $OutputDirectoryAAD "AppRoleAssignmentData.xml")
        #ConvertTo-Json -InputObject $AppRoleAssignmentData -Depth 10 -Compress | Set-Content (Join-Path $OutputDirectoryAAD "AppRoleAssignmentData.json")

        ## OAuth2 Permission Grants Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'OAuth2 Permission Grants' -PercentComplete 50
        #[array] $OAuth2PermissionGrantData = Get-MsGraphResults 'oauth2PermissionGrants' -Top 999
        [array] $OAuth2PermissionGrantData = Get-MsGraphResults 'serviceprincipals/{0}/oauth2PermissionGrants' -UniqueId $ServicePrincipalData.id -Top 999
        #Export-Clixml -InputObject $OAuth2PermissionGrantData -Path (Join-Path $OutputDirectoryAAD "OAuth2PermissionGrantData.xml")
        #ConvertTo-Json -InputObject $OAuth2PermissionGrantData -Depth 10 -Compress | Set-Content (Join-Path $OutputDirectoryAAD "OAuth2PermissionGrantData.json")

        ## User Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Users' -PercentComplete 60
        [array] $UserData = Get-MsGraphResults 'users?$select=id,userPrincipalName,displayName,mail,otherMails,proxyAddresses' -UniqueId $OAuth2PermissionGrantData.principalId -Top 999
        if ($OrganizationData) {
            foreach ($technicalNotificationMail in $OrganizationData.technicalNotificationMails) {
                $user = Get-MsGraphResults 'users?$select=id,userPrincipalName,displayName,mail,otherMails,proxyAddresses' -Filter "proxyAddresses/any(c:c eq 'smtp:$technicalNotificationMail') or otherMails/any(c:c eq '$technicalNotificationMail')" | Select-Object -First 1
                if ($user -and !($UserData | Where-Object id -EQ $user.id)) { $UserData += $user }
            }
        }
        #Export-Clixml -InputObject $UserData -Path (Join-Path $OutputDirectoryAAD "UserData.xml")
        #ConvertTo-Json -InputObject $UserData -Depth 10 -Compress | Set-Content (Join-Path $OutputDirectoryAAD "UserData.json")

        ## Group Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Groups' -PercentComplete 70
        [array] $GroupData = @()
        if ($OrganizationData) {
            foreach ($technicalNotificationMail in $OrganizationData.technicalNotificationMails) {
                $group = Get-MsGraphResults 'groups?$select=id,displayName,mail,proxyAddresses' -Filter "proxyAddresses/any(c:c eq 'smtp:$technicalNotificationMail')" | Select-Object -First 1
                if ($group -and !($GroupData | Where-Object id -EQ $group.id)) { $GroupData += $group }
            }
        }
        #Export-Clixml -InputObject $GroupData -Path (Join-Path $OutputDirectoryAAD "GroupData.xml")
        #ConvertTo-Json -InputObject $GroupData -Depth 10 -Compress | Set-Content (Join-Path $OutputDirectoryAAD "GroupData.json")

        ## Conditional Access Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Groups' -PercentComplete 80
        Export-AADAssessConditionalAccessData -OutputDirectory $OutputDirectoryAAD

        ## Generate Reports
        if (!$SkipReportOutput) {
            Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Generating Reports' -PercentComplete 90
            Get-AADAssessNotificationEmailsReport -OrganizationData $OrganizationData -UserData $UserData -GroupData $GroupData -DirectoryRoleData $DirectoryRoleData | Export-Csv -Path (Join-Path $OutputDirectoryAAD "NotificationsEmailsReport.csv") -NoTypeInformation
            Get-AADAssessAppAssignmentReport -ServicePrincipalData $ServicePrincipalData -AppRoleAssignmentData $AppRoleAssignmentData | Export-Csv -Path (Join-Path $OutputDirectoryAAD "AppAssignmentsReport.csv") -NoTypeInformation
            Get-AADAssessApplicationKeyExpirationReport -ApplicationData $ApplicationData -ServicePrincipalData $ServicePrincipalData | Export-Csv -Path (Join-Path $OutputDirectoryAAD "AppCredentialsReport.csv") -NoTypeInformation
            Get-AADAssessConsentGrantReport -UserData $UserData -ServicePrincipalData $ServicePrincipalData -OAuth2PermissionGrantData $OAuth2PermissionGrantData -AppRoleAssignmentData $AppRoleAssignmentData | Export-Csv -Path (Join-Path $OutputDirectoryAAD "ConsentGrantReport.csv") -NoTypeInformation
        }

        ## Complete
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Completed

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

        ## Open Directory
        Invoke-Item $OutputDirectory

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

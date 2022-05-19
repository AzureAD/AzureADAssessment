
function Export-AADAssessmentReportData {
    [CmdletBinding()]
    param
    (
        # Full path of the directory where the source xml files are located.
        [Parameter(Mandatory = $true)]
        [string] $SourceDirectory,
        # Full path of the directory where the output files will be generated.
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory,
        # Force report generation even if target is already present
        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = $SourceDirectory
    }

    $LookupCache = New-LookupCache

    if (!(Test-Path -Path (Join-Path $OutputDirectory "applications.json")) -or $Force) {
        Import-Clixml -Path (Join-Path $SourceDirectory "applicationData.xml") `
        | Use-Progress -Activity 'Exporting applications' -Property displayName -PassThru -WriteSummary `
        | Export-JsonArray (Join-Path $OutputDirectory "applications.json") -Depth 5 -Compress
    }

    # Import-Clixml -Path (Join-Path $SourceDirectory "directoryRoleData.xml") `
    # | Use-Progress -Activity 'Exporting directoryRoles' -Property displayName -PassThru -WriteSummary `
    # | Export-JsonArray (Join-Path $OutputDirectory "directoryRoles.json") -Depth 5 -Compress

    if (!(Test-Path -Path (Join-Path $OutputDirectory "appRoleAssignments.csv")) -or $Force) {
        Set-Content -Path (Join-Path $OutputDirectory "appRoleAssignments.csv") -Value 'id,appRoleId,createdDateTime,principalDisplayName,principalId,principalType,resourceDisplayName,resourceId'
        Import-Clixml -Path (Join-Path $SourceDirectory "appRoleAssignmentData.xml") `
        | Use-Progress -Activity 'Exporting appRoleAssignments' -Property id -PassThru -WriteSummary `
        | Format-Csv `
        | Export-Csv (Join-Path $OutputDirectory "appRoleAssignments.csv") -NoTypeInformation
    }

    if (!(Test-Path -Path (Join-Path $OutputDirectory "oauth2PermissionGrants.csv")) -or $Force) {
        Set-Content -Path (Join-Path $OutputDirectory "oauth2PermissionGrants.csv") -Value 'id,consentType,clientId,principalId,resourceId,scope'
        Import-Clixml -Path (Join-Path $SourceDirectory "oauth2PermissionGrantData.xml") `
        | Use-Progress -Activity 'Exporting oauth2PermissionGrants' -Property id -PassThru -WriteSummary `
        | Export-Csv (Join-Path $OutputDirectory "oauth2PermissionGrants.csv") -NoTypeInformation
    }

    if (!(Test-Path -Path (Join-Path $OutputDirectory "servicePrincipals.json")) -or $Force) {
        Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") `
        | Use-Progress -Activity 'Exporting servicePrincipals (JSON)' -Property displayName -PassThru -WriteSummary `
        | Export-JsonArray (Join-Path $OutputDirectory "servicePrincipals.json") -Depth 5 -Compress
    }

    if (!(Test-Path -Path (Join-Path $OutputDirectory "servicePrincipals.csv")) -or $Force) {
        Set-Content -Path (Join-Path $OutputDirectory "servicePrincipals.csv") -Value 'id,appId,servicePrincipalType,displayName,accountEnabled,appOwnerOrganizationId,appRoles,oauth2PermissionScopes,keyCredentials,passwordCredentials'
        Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") `
        | Use-Progress -Activity 'Exporting servicePrincipals (CSV)' -Property displayName -PassThru -WriteSummary `
        | Select-Object -Property id, appId, servicePrincipalType, displayName, accountEnabled, appOwnerOrganizationId `
        | Export-Csv (Join-Path $OutputDirectory "servicePrincipals.csv") -NoTypeInformation
    }

    # Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") `
    # | Use-Progress -Activity 'Exporting users' -Property displayName -PassThru -WriteSummary `
    # | Export-JsonArray (Join-Path $OutputDirectory "users.json") -Depth 5 -Compress

    ## Comment out to generate user data via report
    #Set-Content -Path (Join-Path $OutputDirectory "users.csv") -Value 'id,userPrincipalName,userType,displayName,accountEnabled,onPremisesSyncEnabled,onPremisesImmutableId,mail,otherMails,AADLicense,lastSigninDateTime'
    #Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") `
    #| Use-Progress -Activity 'Exporting users' -Property displayName -PassThru -WriteSummary `
    #| Select-Object -Property id, userPrincipalName, userType, displayName, accountEnabled,
    #    @{ Name = "onPremisesSyncEnabled"; Expression = { [bool]$_.onPremisesSyncEnabled } },
    #    @{ Name = "onPremisesImmutableId"; Expression = {![string]::IsNullOrWhiteSpace($_.onPremisesImmutableId)}},
    #    mail,
    #    @{ Name = "otherMails"; Expression = { $_.otherMails -join ';' } },
    #    @{ Name = "AADLicense"; Expression = {$plans = $_.assignedPlans | foreach-object { $_.servicePlanId }; if ($plans -contains "eec0eb4f-6444-4f95-aba0-50c24d67f998") { "AADP2" } elseif ($plans -contains "41781fb2-bc02-4b7c-bd55-b576c07bb09d") { "AADP1" } else { "None" }}} `
    #| Export-Csv (Join-Path $OutputDirectory "users.csv") -NoTypeInformation

    # Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") `
    # | Use-Progress -Activity 'Exporting groups' -Property displayName -PassThru -WriteSummary `
    # | Export-JsonArray (Join-Path $OutputDirectory "groups.json") -Depth 5 -Compress

    if (!(Test-Path -Path (Join-Path $OutputDirectory "groups.csv")) -or $Force) {
        Set-Content -Path (Join-Path $OutputDirectory "groups.csv") -Value 'id,groupTypes,mailEnabled,securityEnabled,groupType,displayName,onPremisesSyncEnabled,mail'
        Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") `
        | Use-Progress -Activity 'Exporting groups' -Property displayName -PassThru -WriteSummary `
        | Select-Object -Property id, groupTypes, mailEnabled, securityEnabled,
            @{ Name = "groupType"; Expression = {
                if ($_.groupTypes -contains "Unified") { "Microsoft 365" }
                elseif ($_.securityEnabled) {
                    if ($_.mailEnabled) { "Mail-enabled Security" }
                    else { "Security" }
                }
                elseif ($_.mailEnabled) { "Distribution" }
                else { "Unknown" } # not mail enabled neither security enabled
            }},
            displayName,
            @{ Name = "onPremisesSyncEnabled"; Expression = { [bool]$_.onPremisesSyncEnabled } },
            mail `
        | Export-Csv (Join-Path $OutputDirectory "groups.csv") -NoTypeInformation
    }

    ## Option 1 from Data Collection: Expand Group Membership to get transitiveMembers.
    # Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") | Add-AadObjectToLookupCache -Type group -LookupCache $LookupCache
    # Set-Content -Path (Join-Path $OutputDirectory "groupTransitiveMembers.csv") -Value 'id,memberId,memberType'
    # $LookupCache.group.Values `
    # | Use-Progress -Activity 'Exporting group memberships' -Property displayName -Total $LookupCache.group.Count -PassThru -WriteSummary `
    # | ForEach-Object {
    #         $group = $_
    #         Expand-GroupTransitiveMembership $group.id -LookupCache $LookupCache | ForEach-Object {
    #             [PSCustomObject]@{
    #                 id         = $group.id
    #                 #'@odata.type' = $group.'@odata.type'
    #                 memberId   = $_.id
    #                 memberType = $_.'@odata.type' -replace '#microsoft.graph.', ''
    #                 #direct     = $group.members.id.Contains($_.id)
    #             }
    #         }
    #     } `
    # | Export-Csv (Join-Path $OutputDirectory "groupTransitiveMembers.csv") -NoTypeInformation

    # Set-Content -Path (Join-Path $OutputDirectory "administrativeUnits.csv") -Value 'id,displayName,visibility,users,groups'
    # Import-Clixml -Path (Join-Path $SourceDirectory "administrativeUnitsData.xml") `
    # | Use-Progress -Activity 'Exporting Administrative Units' -Property displayName -PassThru -WriteSummary `
    # | Select-Object id, displayName, visibility, `
    # @{Name = "users"; Expression = { ($_.members | Where-Object { $_."@odata.type" -like "*.user" }).count } }, `
    # @{Name = "groups"; Expression = { ($_.members | Where-Object { $_."@odata.type" -like "*.group" }).count } }`
    # | Export-Csv -Path (Join-Path $OutputDirectory "administrativeUnits.csv") -NoTypeInformation


    ### Execute Report Commands

    # user report
    if (!(Test-Path -Path (Join-Path $OutputDirectory "users.csv")) -or $Force) {
        # load data if cache empty
        if ($LookupCache.user.Count -eq 0) {
            Write-Output "Loading users in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
        }
        if ($LookupCache.userRegistrationDetails.Count -eq 0) {
            Write-Output "Loading users registration details in lookup cache"
            # In PS5 loading directly from ConvertFrom-Json fails
            $userRegistrationDetails = Get-Content -Path (Join-Path $SourceDirectory "userRegistrationDetails.json") -Raw | ConvertFrom-Json
            $userRegistrationDetails | Add-AadObjectToLookupCache -Type userRegistrationDetails -LookupCache $LookupCache
        }

        # generate the report
        Get-AADAssessUserReport -Offline -UserData $LookupCache.user -RegistrationDetailsData  $LookupCache.userRegistrationDetails`
        | Use-Progress -Activity 'Exporting UserReport' -Property id -PassThru -WriteSummary `
        | Format-Csv `
        | Export-Csv -Path (Join-Path $OutputDirectory "users.csv") -NoTypeInformation

        # clean what is not used by other reports
        $LookupCache.userRegistrationDetails.Clear()
    }

    # notificaiton emails report
    if (!(Test-Path -Path (Join-Path $OutputDirectory "NotificationsEmailsReport.csv")) -or $Force) {
        # load unique data
        $OrganizationData = Get-Content -Path (Join-Path $SourceDirectory "organization.json") -Raw | ConvertFrom-Json
        [array] $DirectoryRoleData = Import-Clixml -Path (Join-Path $SourceDirectory "directoryRoleData.xml")
        # load data if cache empty
        if ($LookupCache.user.Count -eq 0) {
            Write-Output "Loading users in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
        }
        if ($LookupCache.group.Count -eq 0) {
            Write-Output "Loading groups in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") | Add-AadObjectToLookupCache -Type group -LookupCache $LookupCache
        }

        # generate the report
        Get-AADAssessNotificationEmailsReport -Offline -OrganizationData $OrganizationData -UserData $LookupCache.user -GroupData $LookupCache.group -DirectoryRoleData $DirectoryRoleData `
        | Use-Progress -Activity 'Exporting NotificationsEmailsReport' -Property recipientEmail -PassThru -WriteSummary `
        | Export-Csv -Path (Join-Path $OutputDirectory "NotificationsEmailsReport.csv") -NoTypeInformation

        # clean unique data
        Remove-Variable DirectoryRoleData
    }

    # role assignment report
    if (!(Test-Path -Path (Join-Path $OutputDirectory "RoleAssignmentReport.csv")) -or $Force) {
        # load unique data
        [array] $roleAssignmentSchedulesData = Import-Clixml -Path (Join-Path $SourceDirectory "roleAssignmentSchedulesData.xml")
        [array] $roleEligibilitySchedulesData = Import-Clixml -Path (Join-Path $SourceDirectory "roleEligibilitySchedulesData.xml")
        # load data if cache empty
        if ($LookupCache.user.Count -eq 0) {
            Write-Output "Loading users in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
        }
        if ($LookupCache.group.Count -eq 0) {
            Write-Output "Loading groups in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") | Add-AadObjectToLookupCache -Type group -LookupCache $LookupCache
        }
        if ($LookupCache.administrativeUnit.Count -eq 0) {
            Write-Output "Loading administrative units in lookup cache"
            Import-Csv -Path (Join-Path $SourceDirectory "administrativeUnits.csv") | Add-AadObjectToLookupCache -Type administrativeUnit -LookupCache $LookupCache
        }
        if ($LookupCache.application.Count -eq 0) {
            Write-Output "Loading applications in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "applicationData.xml") | Add-AadObjectToLookupCache -Type application -LookupCache $LookupCache
        }
        if ($LookupCache.servicePrincipal.Count -eq 0) {
            Write-Output "Loading service principals in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache
        }

        # generate the report
        Get-AADAssessRoleAssignmentReport -Offline -RoleAssignmentSchedulesData $roleAssignmentSchedulesData -RoleEligibilitySchedulesData $roleEligibilitySchedulesData -OrganizationData $OrganizationData -AdministrativeUnitsData $LookupCache.administrativeUnit -UsersData $LookupCache.user -GroupsData $LookupCache.group -ApplicationsData $LookupCache.application -ServicePrincipalsData $LookupCache.servicePrincipal `
        | Use-Progress -Activity 'Exporting RoleAssignmentReport' -Property id -PassThru -WriteSummary `
        | Format-Csv `
        | Export-Csv -Path (Join-Path $OutputDirectory "RoleAssignmentReport.csv") -NoTypeInformation

        # clear unique data
        Remove-Variable roleAssignmentSchedulesData, roleEligibilitySchedulesData
        # clear cache as data is not further used by other reports
        $LookupCache.group.Clear()
        $LookupCache.administrativeUnit.Clear()
    }

    # app credential report
    if (!(Test-Path -Path (Join-Path $OutputDirectory "AppCredentialsReport.csv")) -or $Force) {
        # load data in cache if empty
        if ($LookupCache.application.Count -eq 0) {
            Write-Output "Loading applications in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "applicationData.xml") | Add-AadObjectToLookupCache -Type application -LookupCache $LookupCache
        }
        if ($LookupCache.servicePrincipal.Count -eq 0) {
            Write-Output "Loading service principals in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache
        }

        # generate the report
        Get-AADAssessAppCredentialExpirationReport -Offline -ApplicationData $LookupCache.application -ServicePrincipalData $LookupCache.servicePrincipal `
        | Use-Progress -Activity 'Exporting AppCredentialsReport' -Property displayName -PassThru -WriteSummary `
        | Format-Csv `
        | Export-Csv -Path (Join-Path $OutputDirectory "AppCredentialsReport.csv") -NoTypeInformation

        # clear cache as data in bot further used by other reports
        $LookupCache.application.Clear()
    }

    # consent grant report
    if (!(Test-Path -Path (Join-Path $OutputDirectory "ConsentGrantReport.csv")) -or $Force) {
        # load unique data
        [array] $AppRoleAssignmentData = Import-Clixml -Path (Join-Path $SourceDirectory "appRoleAssignmentData.xml")
        [array] $OAuth2PermissionGrantData = Import-Clixml -Path (Join-Path $OutputDirectory "oauth2PermissionGrantData.xml")
        # load data if cache empty
        if ($LookupCache.user.Count -eq 0) {
            Write-Output "Loading users in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
        }
        if ($LookupCache.servicePrincipal.Count -eq 0) {
            Write-Output "Loading service principals in lookup cache"
            Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache
        }

        # generate the report
        Get-AADAssessConsentGrantReport -Offline -AppRoleAssignmentData $AppRoleAssignmentData -OAuth2PermissionGrantData $OAuth2PermissionGrantData -UserData $LookupCache.user -ServicePrincipalData $LookupCache.servicePrincipal `
        | Use-Progress -Activity 'Exporting ConsentGrantReport' -Property clientDisplayName -PassThru -WriteSummary `
        | Export-Csv -Path (Join-Path $OutputDirectory "ConsentGrantReport.csv") -NoTypeInformation
    }

}

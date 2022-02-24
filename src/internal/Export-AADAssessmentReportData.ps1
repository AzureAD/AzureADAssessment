
function Export-AADAssessmentReportData {
    [CmdletBinding()]
    param
    (
        # Full path of the directory where the source xml files are located.
        [Parameter(Mandatory = $true)]
        [string] $SourceDirectory,
        # Full path of the directory where the output files will be generated.
        [Parameter(Mandatory = $true)]
        [string] $OutputDirectory
    )

    $LookupCache = New-LookupCache

    Import-Clixml -Path (Join-Path $SourceDirectory "applicationData.xml") `
    | Use-Progress -Activity 'Exporting applications' -Property displayName -PassThru -WriteSummary `
    | Export-JsonArray (Join-Path $OutputDirectory "applications.json") -Depth 5 -Compress

    Import-Clixml -Path (Join-Path $SourceDirectory "directoryRoleData.xml") `
    | Use-Progress -Activity 'Exporting directoryRoles' -Property displayName -PassThru -WriteSummary `
    | Export-JsonArray (Join-Path $OutputDirectory "directoryRoles.json") -Depth 5 -Compress

    Set-Content -Path (Join-Path $OutputDirectory "appRoleAssignments.csv") -Value 'id,appRoleId,createdDateTime,principalDisplayName,principalId,principalType,resourceDisplayName,resourceId'
    Import-Clixml -Path (Join-Path $SourceDirectory "appRoleAssignmentData.xml") `
    | Use-Progress -Activity 'Exporting appRoleAssignments' -Property id -PassThru -WriteSummary `
    | Format-Csv `
    | select-object *,@{Name="createdDateTime"; Expression={$_.creationTimestamp}} -ExcludeProperty creationTimestamp -ErrorAction SilentlyContinue `
    | Export-Csv (Join-Path $OutputDirectory "appRoleAssignments.csv") -NoTypeInformation

    # ## roleAssignments
    # Set-Content -Path (Join-Path $OutputDirectory "roleAssignments.csv") -Value 'id,directoryScopeId,roleDefinitionId,roleDefinitionTemplateId,principalId,principalType,memberType,scheduleInfo,status,assignmentType'
    # Import-Clixml -Path (Join-Path $SourceDirectory "roleAssignmentSchedulesData.xml") `
    # | Use-Progress -Activity 'Exporting roleAssignmentSchedules' -Property id -PassThru -WriteSummary `
    # | Select-Object -Property id, directoryScopeId,
    #     @{ Name = 'roleDefinitionId'; Expression = { $_.roleDefinition.id } },
    #     @{ Name = 'roleDefinitionTemplateId'; Expression = { $_.roleDefinition.templateid } },
    #     @{ Name = 'principalId'; Expression = { $_.principal.id } },
    #     @{ Name = 'principalType'; Expression = { $_.principal.'@odata.type' -replace '#microsoft.graph.', '' } },
    #     memberType, status, assignmentType,
    #     @{ Name = 'endDateTime'; Expression = { $_.scheduleInfo.expiration.endDateTime } } `
    # | Export-Csv (Join-Path $OutputDirectory "roleAssignments.csv") -NoTypeInformation

    # Import-Clixml -Path (Join-Path $SourceDirectory "roleEligibilitySchedulesData.xml") `
    # | Use-Progress -Activity 'Exporting roleEligibilitySchedules' -Property id -PassThru -WriteSummary `
    # | Select-Object -Property id, directoryScopeId,
    #     @{ Name = 'roleDefinitionId'; Expression = { $_.roleDefinition.id } },
    #     @{ Name = 'roleDefinitionTemplateId'; Expression = { $_.roleDefinition.templateid } },
    #     @{ Name = 'principalId'; Expression = { $_.principal.id } },
    #     @{ Name = 'principalType'; Expression = { $_.principal.'@odata.type' -replace '#microsoft.graph.', '' } },
    #     memberType, status, @{ Name = 'assignmentType'; Expression = { 'Eligible' } },
    #     @{ Name = 'endDateTime'; Expression = { $_.scheduleInfo.expiration.endDateTime } } `
    # | Export-Csv (Join-Path $OutputDirectory "roleAssignments.csv") -NoTypeInformation -Append

    # ## $Expand group roleAssignments
    # [array] $groupTransitiveMembership = Import-Csv -Path (Join-Path $OutputDirectory "groupTransitiveMembers.csv")
    # Import-Csv (Join-Path $OutputDirectory "roleAssignments.csv") `
    # | Use-Progress -Activity 'Exporting expanded roleAssignments' -Property id -PassThru -WriteSummary `
    # | Where-Object principalType -eq 'group' `
    # | Foreach-Object {
    #     $groupId = $_.principalId
    #     # prefill resulting assignment
    #     $transitiveAssignment = $_
    #     $transitiveAssignment.memberType = "Group"
    #     $transitiveAssignment.principalType = ""
    #     $transitiveAssignment.principalId = ""
    #     # look for memberships
    #     $groupTransitiveMembership | Where-Object { $_.id -eq $groupId } | ForEach-Object {
    #         $transitiveAssignment.principalType = $_.memberType
    #         $transitiveAssignment.principalId = $_.memberId
    #         $transitiveAssignment
    #     }
    # } `
    # | Export-Csv (Join-Path $OutputDirectory "roleAssignments.csv") -NoTypeInformation -Append

    Set-Content -Path (Join-Path $OutputDirectory "oauth2PermissionGrants.csv") -Value 'id,consentType,clientId,principalId,resourceId,scope'
    Import-Clixml -Path (Join-Path $SourceDirectory "oauth2PermissionGrantData.xml") `
    | Use-Progress -Activity 'Exporting oauth2PermissionGrants' -Property id -PassThru -WriteSummary `
    | Export-Csv (Join-Path $OutputDirectory "oauth2PermissionGrants.csv") -NoTypeInformation

    Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") `
    | Use-Progress -Activity 'Exporting servicePrincipals (JSON)' -Property displayName -PassThru -WriteSummary `
    | Export-JsonArray (Join-Path $OutputDirectory "servicePrincipals.json") -Depth 5 -Compress

    Set-Content -Path (Join-Path $OutputDirectory "servicePrincipals.csv") -Value 'id,appId,servicePrincipalType,displayName,accountEnabled,appOwnerOrganizationId,appRoles,oauth2PermissionScopes,keyCredentials,passwordCredentials'
    Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") `
    | Use-Progress -Activity 'Exporting servicePrincipals (CSV)' -Property displayName -PassThru -WriteSummary `
    | Select-Object -Property id, appId, servicePrincipalType, displayName, accountEnabled, appOwnerOrganizationId `
    | Export-Csv (Join-Path $OutputDirectory "servicePrincipals.csv") -NoTypeInformation

    # Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") `
    # | Use-Progress -Activity 'Exporting users' -Property displayName -PassThru -WriteSummary `
    # | Export-JsonArray (Join-Path $OutputDirectory "users.json") -Depth 5 -Compress

    Set-Content -Path (Join-Path $OutputDirectory "users.csv") -Value 'id,userPrincipalName,userType,displayName,accountEnabled,onPremisesSyncEnabled,onPremisesImmutableId,mail,otherMails,AADLicense'
    Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") `
    | Use-Progress -Activity 'Exporting users' -Property displayName -PassThru -WriteSummary `
    | Select-Object -Property id,userPrincipalName,userType,displayName,accountEnabled, `
        @{ Name = "onPremisesSyncEnabled"; Expression = {[bool]$_.onPremisesSyncEnabled}}, `
        @{ Name = "onPremisesImmutableId"; Expression = {![string]::IsNullOrWhiteSpace($_.onPremisesImmutableId)}},mail, `
        @{ Name = "otherMails"; Expression = { $_.otherMails -join ';' } }, `
        @{ Name = "AADLicense"; Expression = {$plans = $_.assignedPlans | foreach-object { $_.servicePlanId }; if ($plans -contains "eec0eb4f-6444-4f95-aba0-50c24d67f998") { "AADP2" } elseif ($plans -contains "41781fb2-bc02-4b7c-bd55-b576c07bb09d") { "AADP1" } else { "None" }}} `
    | Export-Csv (Join-Path $OutputDirectory "users.csv") -NoTypeInformation
    #

    # Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") `
    # | Use-Progress -Activity 'Exporting groups' -Property displayName -PassThru -WriteSummary `
    # | Export-JsonArray (Join-Path $OutputDirectory "groups.json") -Depth 5 -Compress

    Set-Content -Path (Join-Path $OutputDirectory "groups.csv") -Value 'id,groupTypes,displayName,mail,groupType'
    Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") `
    | Use-Progress -Activity 'Exporting groups' -Property displayName -PassThru -WriteSummary `
    | Select-Object -Property id, groupTypes, displayName, mail, `
    @{ Name = "groupType"; Expression = {
        if ($_.groupTypes -contains "Unified") {
            "Microsoft 365"
        } else {
            if ($_.securityEnabled) {
                if ($_.mailEnabled) {
                    "Mail-enabled Security"
                } else {
                    "Security"
                }
            } else {
                if ($_.mailEnabled) {
                    "Distribution"
                } else {
                    "Unknown" # not mail enabled neither security enabled
                }
            }
        }
    }} `
    | Export-Csv (Join-Path $OutputDirectory "groups.csv") -NoTypeInformation

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
    $OrganizationData = Get-Content -Path (Join-Path $SourceDirectory "organization.json") -Raw | ConvertFrom-Json
    [array] $DirectoryRoleData = Import-Clixml -Path (Join-Path $SourceDirectory "directoryRoleData.xml")
    Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
    Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") | Add-AadObjectToLookupCache -Type group -LookupCache $LookupCache

    Get-AADAssessNotificationEmailsReport -Offline -OrganizationData $OrganizationData -UserData $LookupCache.user -GroupData $LookupCache.group -DirectoryRoleData $DirectoryRoleData `
    | Use-Progress -Activity 'Exporting NotificationsEmailsReport' -Property recipientEmail -PassThru -WriteSummary `
    | Export-Csv -Path (Join-Path $OutputDirectory "NotificationsEmailsReport.csv") -NoTypeInformation
    Remove-Variable DirectoryRoleData

    #[array] $ApplicationData = Import-Clixml -Path (Join-Path $SourceDirectory "applicationData.xml")
    [array] $groupTransitiveMembership = Import-Csv -Path (Join-Path $SourceDirectory "groupTransitiveMembers.csv")
    Import-Csv -Path (Join-Path $SourceDirectory "administrativeUnits.csv") | Add-AadObjectToLookupCache -Type administrativeUnit -LookupCache $LookupCache
    Import-Clixml -Path (Join-Path $SourceDirectory "applicationData.xml") | Add-AadObjectToLookupCache -Type application -LookupCache $LookupCache
    Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache
    [array] $roleAssignmentSchedulesData = Import-Clixml -Path (Join-Path $SourceDirectory "roleAssignmentSchedulesData.xml")
    [array] $roleEligibilitySchedulesData = Import-Clixml -Path (Join-Path $SourceDirectory "roleEligibilitySchedulesData.xml")

    Get-AADAssessRoleAssignmentReport -Offline -RoleAssignmentSchedulesData $roleAssignmentSchedulesData -RoleEligibilitySchedulesData $roleEligibilitySchedulesData -GroupTransitiveMembershipData $groupTransitiveMembership -OrganizationData $OrganizationData -AdministrativeUnitsData $LookupCache.administrativeUnit -UsersData $LookupCache.user -GroupsData $LookupCache.group -ApplicationsData $LookupCache.application -ServicePrincipalsData $LookupCache.servicePrincipal `
    | Use-Progress -Activity 'Exporting RoleAssignmentReport' -Property id -PassThru -WriteSummary `
    | Format-Csv `
    | Export-Csv -Path (Join-Path $OutputDirectory "RoleAssignmentReport.csv") -NoTypeInformation
    $LookupCache.group.Clear()
    $LookupCache.administrativeUnit.Clear()
    Remove-Variable groupTransitiveMembership
    Remove-Variable roleAssignmentSchedulesData
    Remove-Variable roleEligibilitySchedulesData

    Get-AADAssessAppCredentialExpirationReport -Offline -ApplicationData $LookupCache.application -ServicePrincipalData $LookupCache.servicePrincipal `
    | Use-Progress -Activity 'Exporting AppCredentialsReport' -Property displayName -PassThru -WriteSummary `
    | Format-Csv `
    | Export-Csv -Path (Join-Path $OutputDirectory "AppCredentialsReport.csv") -NoTypeInformation
    $LookupCache.application.Clear()

    [array] $AppRoleAssignmentData = Import-Clixml -Path (Join-Path $SourceDirectory "appRoleAssignmentData.xml")
    # Get-AADAssessAppAssignmentReport -Offline -AppRoleAssignmentData $AppRoleAssignmentData `
    # | Use-Progress -Activity 'Exporting AppAssignmentsReport' -Property id -PassThru -WriteSummary `
    # | Format-Csv `
    # | Export-Csv -Path (Join-Path $OutputDirectory "AppAssignmentsReport.csv") -NoTypeInformation

    [array] $OAuth2PermissionGrantData = Import-Clixml -Path (Join-Path $OutputDirectory "oauth2PermissionGrantData.xml")
    Get-AADAssessConsentGrantReport -Offline -AppRoleAssignmentData $AppRoleAssignmentData -OAuth2PermissionGrantData $OAuth2PermissionGrantData -UserData $LookupCache.user -ServicePrincipalData $LookupCache.servicePrincipal `
    | Use-Progress -Activity 'Exporting ConsentGrantReport' -Property clientDisplayName -PassThru -WriteSummary `
    | Export-Csv -Path (Join-Path $OutputDirectory "ConsentGrantReport.csv") -NoTypeInformation

}

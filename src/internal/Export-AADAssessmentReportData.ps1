
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

    $OrganizationData = Get-Content -Path (Join-Path $SourceDirectory "organization.json") -Raw | ConvertFrom-Json
    [array] $DirectoryRoleData = Import-Clixml -Path (Join-Path $SourceDirectory "directoryRoleData.xml")
    Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
    Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") | Add-AadObjectToLookupCache -Type group -LookupCache $LookupCache
    Get-AADAssessNotificationEmailsReport -Offline -OrganizationData $OrganizationData -UserData $LookupCache.user -GroupData $LookupCache.group -DirectoryRoleData $DirectoryRoleData `
    | Use-Progress -Activity 'Exporting NotificationsEmailsReport' -Property recipientEmail -PassThru -WriteSummary `
    | Export-Csv -Path (Join-Path $OutputDirectory "NotificationsEmailsReport.csv") -NoTypeInformation
    Remove-Variable DirectoryRoleData
    $LookupCache.group.Clear()

    [array] $ApplicationData = Import-Clixml -Path (Join-Path $SourceDirectory "applicationData.xml")
    Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache
    Get-AADAssessAppCredentialExpirationReport -Offline -ApplicationData $ApplicationData -ServicePrincipalData $LookupCache.servicePrincipal `
    | Use-Progress -Activity 'Exporting AppCredentialsReport' -Property displayName -PassThru -WriteSummary `
    | Format-Csv `
    | Export-Csv -Path (Join-Path $OutputDirectory "AppCredentialsReport.csv") -NoTypeInformation
    Remove-Variable ApplicationData

    [array] $AppRoleAssignmentData = Import-Clixml -Path (Join-Path $SourceDirectory "appRoleAssignmentData.xml")
    # Get-AADAssessAppAssignmentReport -Offline -AppRoleAssignmentData $AppRoleAssignmentData `
    # | Use-Progress -Activity 'Exporting AppAssignmentsReport' -Property id -PassThru -WriteSummary `
    # | Format-Csv `
    # | Export-Csv -Path (Join-Path $OutputDirectory "AppAssignmentsReport.csv") -NoTypeInformation

    [array] $OAuth2PermissionGrantData = Import-Clixml -Path (Join-Path $OutputDirectory "oauth2PermissionGrantData.xml")
    Get-AADAssessConsentGrantReport -Offline -AppRoleAssignmentData $AppRoleAssignmentData -OAuth2PermissionGrantData $OAuth2PermissionGrantData -UserData $LookupCache.user -ServicePrincipalData $LookupCache.servicePrincipal `
    | Use-Progress -Activity 'Exporting ConsentGrantReport' -Property clientDisplayName -PassThru -WriteSummary `
    | Export-Csv -Path (Join-Path $OutputDirectory "ConsentGrantReport.csv") -NoTypeInformation

    Set-Content -Path (Join-Path $OutputDirectory "administrativeUnits.csv") -Value 'id,displayName,visibility,users,groups'
    Import-Clixml -Path (Join-Path $SourceDirectory "administrativeUnitsData.xml") `
    | Use-Progress -Activity 'Exporting Administrative Units' -Property displayName -PassThru -WriteSummary `
    | Select-Object id,displayName,visibility, `
        @{Name="users";Expression={($_.members | Where-Object { $_."@odata.type" -like "*.user"}).count}}, `
        @{Name="groups";Expression={($_.members | Where-Object { $_."@odata.type" -like "*.group"}).count}}`
    | Export-Csv -Path (Join-Path $OutputDirectory "administrativeUnits.csv") -NoTypeInformation

    [array] $groupTransitiveMembership = Import-Csv -Path (Join-Path $OutputDirectory "groupTransitiveMembers.csv")
    [array] $applications = Get-Content -Path (Join-Path $OutputDirectory "applications.json") | ConvertFrom-Json -Depth 5
    [array] $servicePrincipals = Import-Csv -Path (Join-Path $OutputDirectory "servicePrincipals.csv")
    [array] $administrativeUnits = Import-Csv -Path (Join-Path $OutputDirectory "administrativeUnits.csv")
    Set-Content -Path (Join-Path $OutputDirectory "roleAssignments.csv") -Value 'roleDefinitionId,directoryScopeName,directoryScopeType,memberType,assignmentType,endDateTime,principalId,principalType'
    Import-Csv -Path (Join-Path $OutputDirectory "roleAssignmentsData.csv") `
    | Use-Progress -Activity 'Exporting Role Assignments' -Property roleDefinitionId -PassThru -WriteSummary `
    | Select-Object -property *,@{Name="directoryScopeName";Expression={"Global"}},@{Name="directoryScopeType";Expression={"Directory"}}
    | ForEach-Object  {
        if ($_.directoryScopeId -ne "/") {
            # resolve scope informations (type, displayname and isolate object id)
            if ($_.directoryScopeId -like "/administrativeUnits/*") {
                # Administrative units
                $auid = $_.directoryScopeId -replace "^/administrativeUnits/",""
                $_.directoryScopeType = "AdministrativeUnit"
                $_.directoryScopeName = $auid
                $_.directoryScopeId = $auid
                $au = $administrativeUnits | Where-Object { $_.id -eq $auid } | Select-Object -First 1
                if ($au) {
                    $_.directoryScopeName = $au.displayName
                }
            } else {
                # SP or App 
                $apporspid = $_.directoryScopeId -replace "^/",""
                $_.directoryScopeType = "Object"
                $_.directoryScopeName = $apporspid
                $_.directoryScopeId = $apporspid
                # search in service principals
                $sp = $servicePrincipals | Where-Object {$_.id -eq $apporspid} | Select-Object -First 1
                if ($sp) {
                    $_.directoryScopeType = "ServicePrincipal"
                    $_.directoryScopeName = $sp.displayName
                } else {
                    # search in applications
                    $app = $applications | Where-Object {$_.id -eq $apporspid} | Select-Object -First 1
                    if ($app) {
                        $_.directoryScopeType = "Application"
                        $_.directoryScopeName = $app.displayName
                    }
                }
            }
        }
        $_
        if ($_.principalType -eq "group") {
            $groupId = $_.principalId
            # prefill resulting assignment
            $resultingAssignement = $_
            $resultingAssignement.memberType = "Group"
            $resultingAssignement.principalType = ""
            $resultingAssignement.principalId = ""
            # look for memberships
            $groupTransitiveMembership | Where-Object { $_.id -eq $groupId } | ForEach-Object {
                $resultingAssignement.principalType = $_.memberType
                $resultingAssignement.principalId = $_.memberId
                $resultingAssignement
            }
        }
    } `
    | Select-Object -Property roleDefinitionId,directoryScopeName,directoryScopeType,directoryScopeId,memberType,assignmentType,endDateTime,principalId,principalType `
    | Export-Csv -Path (Join-Path $OutputDirectory "roleAssignments.csv") -NoTypeInformation
}

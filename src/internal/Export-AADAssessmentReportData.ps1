
function Export-AADAssessmentReportData {
    [CmdletBinding()]
    param
    (
        #
        [Parameter(Mandatory = $true)]
        [string] $SourceDirectory,
        #
        [Parameter(Mandatory = $true)]
        [string] $OutputDirectory
    )

    $LookupCache = New-LookupCache

    Import-Clixml -Path (Join-Path $SourceDirectory "applicationData.xml") `
    | Use-Progress -Activity 'Exporting applications' -ScriptBlock { $args[0] } -Property displayName `
    | Export-JsonArray (Join-Path $OutputDirectory "applications.json") -Depth 5 -Compress

    Import-Clixml -Path (Join-Path $SourceDirectory "directoryRoleData.xml") `
    | Use-Progress -Activity 'Exporting directoryRoles' -ScriptBlock { $args[0] } -Property displayName `
    | Export-JsonArray (Join-Path $OutputDirectory "directoryRoles.json") -Depth 5 -Compress

    Set-Content -Path (Join-Path $OutputDirectory "appRoleAssignments.csv") -Value 'id,deletedDateTime,appRoleId,createdDateTime,principalDisplayName,principalId,principalType,resourceDisplayName,resourceId'
    Import-Clixml -Path (Join-Path $SourceDirectory "appRoleAssignmentData.xml") `
    | Use-Progress -Activity 'Exporting appRoleAssignments' -ScriptBlock { $args[0] } -Property id `
    | Export-Csv (Join-Path $OutputDirectory "appRoleAssignments.csv") -NoTypeInformation

    Set-Content -Path (Join-Path $OutputDirectory "oauth2PermissionGrants.csv") -Value 'id,consentType,clientId,principalId,resourceId,scope'
    Import-Clixml -Path (Join-Path $SourceDirectory "oauth2PermissionGrantData.xml") `
    | Use-Progress -Activity 'Exporting oauth2PermissionGrants' -ScriptBlock { $args[0] } -Property id `
    | Export-Csv (Join-Path $OutputDirectory "oauth2PermissionGrants.csv") -NoTypeInformation

    Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") `
    | Use-Progress -Activity 'Exporting servicePrincipals' -ScriptBlock { $args[0] } -Property displayName `
    | Export-JsonArray (Join-Path $OutputDirectory "servicePrincipals.json") -Depth 5 -Compress

    Set-Content -Path (Join-Path $OutputDirectory "servicePrincipals.csv") -Value 'id,appId,servicePrincipalType,displayName,accountEnabled,appOwnerOrganizationId,appRoles,oauth2PermissionScopes,keyCredentials,passwordCredentials'
    Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") `
    | Use-Progress -Activity 'Exporting servicePrincipals' -ScriptBlock { $args[0] } -Property displayName `
    | Select-Object -Property id, appId, servicePrincipalType, displayName, accountEnabled, appOwnerOrganizationId `
    | Export-Csv (Join-Path $OutputDirectory "servicePrincipals.csv") -NoTypeInformation

    # Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") `
    # | Use-Progress -Activity 'Exporting users' -ScriptBlock { $args[0] } -Property displayName `
    # | Export-JsonArray (Join-Path $OutputDirectory "users.json") -Depth 5 -Compress

    Set-Content -Path (Join-Path $OutputDirectory "users.csv") -Value 'id,userPrincipalName,userType,displayName,accountEnabled,mail,otherMails'
    Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") `
    | Use-Progress -Activity 'Exporting users' -ScriptBlock { $args[0] } -Property displayName `
    | Select-Object -Property id, userPrincipalName, userType, displayName, accountEnabled, mail, @{ Name = "otherMails"; Expression = { $_.otherMails -join ';' } } `
    | Export-Csv (Join-Path $OutputDirectory "users.csv") -NoTypeInformation

    # Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") `
    # | Use-Progress -Activity 'Exporting groups' -ScriptBlock { $args[0] } -Property displayName `
    # | Export-JsonArray (Join-Path $OutputDirectory "groups.json") -Depth 5 -Compress

    Set-Content -Path (Join-Path $OutputDirectory "groups.csv") -Value 'id,groupTypes,displayName,mail'
    Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") `
    | Use-Progress -Activity 'Exporting groups' -ScriptBlock { $args[0] } -Property displayName `
    | Select-Object -Property id, groupTypes, displayName, mail `
    | Export-Csv (Join-Path $OutputDirectory "groups.csv") -NoTypeInformation

    $OrganizationData = Get-Content -Path (Join-Path $OutputDirectoryAAD "organization.json") -Raw | ConvertFrom-Json
    [array] $DirectoryRoleData = Import-Clixml -Path (Join-Path $SourceDirectory "directoryRoleData.xml")
    Import-Clixml -Path (Join-Path $SourceDirectory "userData.xml") | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
    Import-Clixml -Path (Join-Path $SourceDirectory "groupData.xml") | Add-AadObjectToLookupCache -Type group -LookupCache $LookupCache
    Get-AADAssessNotificationEmailsReport -Offline -OrganizationData $OrganizationData -UserData $LookupCache.user -GroupData $LookupCache.group -DirectoryRoleData $DirectoryRoleData `
    | Use-Progress -Activity 'Exporting NotificationsEmailsReport' -ScriptBlock { $args[0] } `
    | Export-Csv -Path (Join-Path $OutputDirectory "NotificationsEmailsReport.csv") -NoTypeInformation
    Remove-Variable DirectoryRoleData
    $LookupCache.group.Clear()

    [array] $ApplicationData = Import-Clixml -Path (Join-Path $SourceDirectory "applicationData.xml")
    Import-Clixml -Path (Join-Path $SourceDirectory "servicePrincipalData.xml") | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache
    Get-AADAssessAppCredentialExpirationReport -Offline -ApplicationData $ApplicationData -ServicePrincipalData $LookupCache.servicePrincipal `
    | Use-Progress -Activity 'Exporting AppCredentialsReport' -ScriptBlock { $args[0] } `
    | Export-Csv -Path (Join-Path $OutputDirectory "AppCredentialsReport.csv") -NoTypeInformation
    Remove-Variable ApplicationData

    [array] $AppRoleAssignmentData = Import-Clixml -Path (Join-Path $SourceDirectory "appRoleAssignmentData.xml")
    #Get-AADAssessAppAssignmentReport -Offline -AppRoleAssignmentData $AppRoleAssignmentData `
    #| Use-Progress -Activity 'Exporting AppAssignmentsReport' -ScriptBlock { $args[0] } `
    #| Export-Csv -Path (Join-Path $OutputDirectory "AppAssignmentsReport.csv") -NoTypeInformation

    [array] $OAuth2PermissionGrantData = Import-Clixml -Path (Join-Path $OutputDirectory "oauth2PermissionGrantData.xml")
    Get-AADAssessConsentGrantReport -Offline -AppRoleAssignmentData $AppRoleAssignmentData -OAuth2PermissionGrantData $OAuth2PermissionGrantData -UserData $LookupCache.user -ServicePrincipalData $LookupCache.servicePrincipal `
    | Use-Progress -Activity 'Exporting ConsentGrantReport' -ScriptBlock { $args[0] } `
    | Export-Csv -Path (Join-Path $OutputDirectory "ConsentGrantReport.csv") -NoTypeInformation

}

<#
 .Synopsis
  Gets various email addresses that Azure AD sends notifications to

 .Description
  This functions returns a list with the email notification scope and type, the recipient name and an email address

 .Example
  Get-AADAssessNotificationEmailsReport | Export-Csv -Path ".\NotificationsEmailAddresses.csv"
#>
function Get-AADAssessNotificationEmailsReport {
    [CmdletBinding()]
    param (
        # Organization Data
        [Parameter(Mandatory = $false)]
        [object] $OrganizationData,
        # User Data
        [Parameter(Mandatory = $false)]
        [object] $UserData,
        # Group Data
        [Parameter(Mandatory = $false)]
        [object] $GroupData,
        # Directory Role Data
        [Parameter(Mandatory = $false)]
        [object] $DirectoryRoleData
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        ## Get Organization Technical Contacts
        if (!$OrganizationData) {
            $OrganizationData = Get-MsGraphResults 'organization?$select=technicalNotificationMails'
        }

        if ($OrganizationData) {
            foreach ($technicalNotificationMail in $OrganizationData.technicalNotificationMails) {
                $result = [PSCustomObject]@{
                    notificationType           = "Technical Notification"
                    notificationScope          = "Tenant"
                    recipientType              = "emailAddress"
                    recipientEmail             = $technicalNotificationMail
                    recipientEmailAlternate    = $null
                    recipientId                = $null
                    recipientUserPrincipalName = $null
                    recipientDisplayName       = $null
                }

                if (!$PSBoundParameters.ContainsKey('UserData')) {
                    $user = Get-MsGraphResults 'users?$select=id,userPrincipalName,displayName,mail,otherMails,proxyAddresses' -Filter "proxyAddresses/any(c:c eq 'smtp:$technicalNotificationMail') or otherMails/any(c:c eq '$technicalNotificationMail')" | Select-Object -First 1
                }
                else {
                    $user = $UserData | Where-Object { $_.proxyAddresses -Contains "smtp:$technicalNotificationMail" -or $_.otherMails -Contains $technicalNotificationMail } | Select-Object -First 1
                }
                if ($user) {
                    $result.recipientType = 'user'
                    $result.recipientId = $user[0].id
                    $result.recipientUserPrincipalName = $user[0].userPrincipalName
                    $result.recipientDisplayName = $user[0].displayName
                    $result.recipientEmailAlternate = $user[0].otherMails -join ';'
                }
                if (!$PSBoundParameters.ContainsKey('GroupData')) {
                    $group = Get-MsGraphResults 'groups?$select=id,displayName,mail,proxyAddresses' -Filter "proxyAddresses/any(c:c eq 'smtp:$technicalNotificationMail')" | Select-Object -First 1
                }
                else {
                    $group = $GroupData | Where-Object { $_.proxyAddresses -Contains "smtp:$technicalNotificationMail" } | Select-Object -First 1
                }
                if ($group) {
                    $result.recipientType = 'group'
                    $result.recipientId = $group[0].id
                    $result.recipientDisplayName = $group[0].displayName
                }

                Write-Output $result
            }
        }

        ## Get email addresses of all users with privileged roles
        if (!$DirectoryRoleData) {
            $DirectoryRoleData = Get-MsGraphResults 'directoryRoles?$select=id,displayName&$expand=members'
        }

        foreach ($role in $DirectoryRoleData) {
            foreach ($roleMember in $role.members) {
                [PSCustomObject]@{
                    notificationType           = $role.displayName
                    notificationScope          = 'Role'
                    recipientName              = (Get-ObjectPropertyValue $roleMember 'displayName')
                    recipientType              = (Get-ObjectPropertyValue $roleMember '@odata.type') -replace '#microsoft.graph.', ''
                    recipientEmail             = (Get-ObjectPropertyValue $roleMember 'mail')
                    recipientEmailAlternate    = (Get-ObjectPropertyValue $roleMember 'otherMails') -join ';'
                    recipientUserPrincipalName = (Get-ObjectPropertyValue $roleMember 'userPrincipalName')
                    recipientDisplayName       = (Get-ObjectPropertyValue $roleMember 'displayName')
                }
            }

            ## ToDo: Resolve group memberships?
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

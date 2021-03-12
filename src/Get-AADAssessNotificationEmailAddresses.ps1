<#
 .Synopsis
  Gets various email addresses that Azure AD sends notifications to

 .Description
  This functions returns a list with the email notification scope and type, the recipient name and an email address

 .Example
  Get-AADAssessNotificationEmailAddresses | Export-Csv -Path ".\NotificationsEmailAddresses.csv"
#>
function Get-AADAssessNotificationEmailAddresses {
    [CmdletBinding()]
    param ()

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        ## Get Organization Technical Contacts
        $orgInfo = Get-MsGraphResults 'organization?$select=technicalNotificationMails'

        if ($orgInfo) {
            foreach ($technicalNotificationMail in $orgInfo.technicalNotificationMails) {
                $result = [PSCustomObject]@{
                    notificationType           = "Technical Notification"
                    notificationScope          = "Tenant"
                    recipientType              = "emailAddress"
                    recipientEmail             = $technicalNotificationMail
                    recipientEmailAlternate    = ""
                    recipientId                = ""
                    recipientUserPrincipalName = ""
                    recipientDisplayName       = ""
                }

                [array]$user = Get-MsGraphResults 'users' -Select 'id', 'userPrincipalName', 'displayName', 'mail', 'otherMails', 'proxyAddresses' -Filter "proxyAddresses/any(c:c eq 'smtp:$technicalNotificationMail') or otherMails/any(c:c eq '$technicalNotificationMail')"
                if ($user) {
                    $result.recipientType = 'user'
                    $result.recipientId = $user[0].id
                    $result.recipientUserPrincipalName = $user[0].userPrincipalName
                    $result.recipientDisplayName = $user[0].displayName
                    $result.recipientEmailAlternate = $user[0].otherMails -join ';'
                }
                [array]$group = Get-MsGraphResults 'groups' -Select 'id', 'displayName', 'mail', 'proxyAddresses' -Filter "proxyAddresses/any(c:c eq 'smtp:$technicalNotificationMail')"
                if ($group) {
                    $result.recipientType = 'group'
                    $result.recipientId = $group[0].id
                    $result.recipientDisplayName = $group[0].displayName
                }

                Write-Output $result
            }
        }

        ## Get email addresses of all users with privileged roles
        $aadRoles = Get-MsGraphResults 'directoryRoles?$select=displayName&$expand=members'

        foreach ($role in $aadRoles) {
            foreach ($roleMember in $role.members) {
                $result = [PSCustomObject]@{
                    notificationType           = $role.displayName
                    notificationScope          = 'Role'
                    recipientName              = (Get-ObjectPropertyValue $roleMember 'displayName')
                    recipientType              = (Get-ObjectPropertyValue $roleMember '@odata.type') -replace '#microsoft.graph.', ''
                    recipientEmail             = (Get-ObjectPropertyValue $roleMember 'mail')
                    recipientEmailAlternate    = (Get-ObjectPropertyValue $roleMember 'otherMails') -join ';'
                    recipientUserPrincipalName = (Get-ObjectPropertyValue $roleMember 'userPrincipalName')
                    recipientDisplayName       = (Get-ObjectPropertyValue $roleMember 'displayName')
                }

                Write-Output $result
            }

            ## ToDo: Resolve group memberships?
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

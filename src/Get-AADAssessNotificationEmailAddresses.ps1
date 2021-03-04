<# 
 .Synopsis
  Gets various email addresses that Azure AD sends notifications to

 .Description
  This functions returns a list with the email notification scope and type, the recipient name and an email address

 .Example
  Get-AADAssessNotificationEmailAddresses | Export-Csv -Path ".\NotificationsEmailAddresses.csv" 
#>
function Get-AADAssessNotificationEmailAddresses {

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        $orgInfo = Get-MsGraphResults 'organization?$select=technicalNotificationMails'
        $result = [PSCustomObject]@{
            RecipientName            = "N/A"
            RoleMemberObjectType     = "email address"
            RoleMemberAlternateEmail = "N/A"
            NotificationType         = "Technical Notification"
            NotificationEmailScope   = "Tenant"
            EmailAddress             = (Get-ObjectPropertyValue $orgInfo 'value' 'technicalNotificationMails')
            RoleMemberUPN            = "N/A"
        }
        # $result = [PSCustomObject]@{
        #     RecipientName              = ""
        #     RecipientObjectType        = "emailAddress"
        #     NotificationType           = "Technical Notification"
        #     NotificationEmailScope     = "Tenant"
        #     RecipientEmailAddress      = (Get-ObjectPropertyValue $orgInfo 'value' 'technicalNotificationMails')
        #     RecipientAlternateEmail    = ""
        #     RecipientUserPrincipalName = ""
        # } 
        Write-Output $result

        #Get email addresses of all users with privileged roles
        $aadRoles = Get-MsGraphResults 'directoryRoles?$select=displayName&$expand=members'

        ## ToDo: Resolve group memberships

        foreach ($role in $aadRoles) {
            foreach ($roleMember in $role.members) {
                $result = [PSCustomObject]@{
                    RecipientName            = (Get-ObjectPropertyValue $roleMember 'displayName')
                    RoleMemberObjectType     = (Get-ObjectPropertyValue $roleMember '@odata.type') -replace '#microsoft.graph.', ''
                    RoleMemberAlternateEmail = (Get-ObjectPropertyValue $roleMember 'otherMails') -join ';'
                    NotificationType         = (Get-ObjectPropertyValue $role 'displayName')
                    NotificationEmailScope   = 'Role'
                    EmailAddress             = (Get-ObjectPropertyValue $roleMember 'mail')
                    RoleMemberUPN            = (Get-ObjectPropertyValue $roleMember 'userPrincipalName')
                }
                # $result = [PSCustomObject]@{
                #     RecipientName              = (Get-ObjectPropertyValue $roleMember 'displayName')
                #     RecipientObjectType        = (Get-ObjectPropertyValue $roleMember '@odata.type') -replace '#microsoft.graph.', ''
                #     NotificationType           = (Get-ObjectPropertyValue $role 'displayName')
                #     NotificationEmailScope     = 'Role'
                #     RecipientEmailAddress      = (Get-ObjectPropertyValue $roleMember 'mail')
                #     RecipientAlternateEmail    = (Get-ObjectPropertyValue $roleMember 'otherMails') -join ';'
                #     RecipientUserPrincipalName = (Get-ObjectPropertyValue $roleMember 'userPrincipalName')
                # } 
                Write-Output $result
            }
        }
    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $true }
}

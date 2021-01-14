<# 
 .Synopsis
  Gets various email addresses that Azure AD sends notifications to

 .Description
  This functions returns a list with the email notification scope and type, the recipient name and an email address

 .Example
  Get-AADAssessNotificationEmailAddresses | Export-Csv -Path ".\NotificationsEmailAddresses.csv" 
#>
function Get-AADAssessNotificationEmailAddresses {
 
    $orgInfo = Get-MsGraphResults 'organization?$select=technicalNotificationMails'
    $result = [PSCustomObject]@{
        RecipientName              = ""
        RecipientObjectType        = "emailAddress"
        NotificationType           = "Technical Notification"
        NotificationEmailScope     = "Tenant"
        RecipientEmailAddress      = (Get-ObjectProperty $orgInfo 'value' 'technicalNotificationMails')
        RecipientAlternateEmail    = ""
        RecipientUserPrincipalName = ""
    } 
    Write-Output $result

    #Get email addresses of all users with privileged roles
    $aadRoles = Get-MsGraphResults 'directoryRoles?$select=displayName&$expand=members' }

    ## ToDo: Resolve group memberships

    foreach ($role in $aadRoles) {
        foreach ($roleMember in $role.members) {
            $result = [PSCustomObject]@{
                RecipientName              = (Get-ObjectProperty $roleMember 'displayName')
                RecipientObjectType        = (Get-ObjectProperty $roleMember '@odata.type') -replace '#microsoft.graph.', ''
                NotificationType           = (Get-ObjectProperty $role 'displayName')
                NotificationEmailScope     = 'Role'
                RecipientEmailAddress      = (Get-ObjectProperty $roleMember 'mail')
                RecipientAlternateEmail    = (Get-ObjectProperty $roleMember 'otherMails') -join ';'
                RecipientUserPrincipalName = (Get-ObjectProperty $roleMember 'userPrincipalName')
            } 
            Write-Output $result
        }
    }
}

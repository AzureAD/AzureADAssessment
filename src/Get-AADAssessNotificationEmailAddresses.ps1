<# 
 .Synopsis
  Gets various email addresses that Azure AD sends notifications to

 .Description
  This functions returns a list with the email notification scope and type, the recipient name and an email address

 .Example
  Get-AADAssessNotificationEmailAddresses | Export-Csv -Path ".\NotificationsEmailAddresses.csv" 
#>
function Get-AADAssessNotificationEmailAddresses {
    

    $orgInfo = Invoke-MgGraphQuery -RelativeUri 'organization?$select=technicalNotificationMails'
    $technicalNotificationEmail = $orgInfo.value.technicalNotificationMails    
    $result = [PSCustomObject]@{
        RecipientName            = "N/A" ;
        RoleMemberObjectType     = "email address"; 
        RoleMemberAlternateEmail = "N/A";
        NotificationType         = "Technical Notification"; 
        NotificationEmailScope   = "Tenant";
        EmailAddress             = $technicalNotificationEmail; 
        RoleMemberUPN            = "N/A"
    } 

    Write-Output $result

    #Get email addresses of all users with privileged roles

    $aadRoles = Invoke-MgGraphQuery -RelativeUri 'directoryRoles?$select=displayName&$expand=members'

    foreach ($role in $aadRoles.value) {
        foreach ($roleMember in $role.members) {
            $alternateEmail = ""
            if($roleMember.otherMails) {$alternateEmail = $roleMember.otherMails -join ";"}
            
            $memberObjectType = "ServicePrincipal"
            if($roleMember.UserType) { $memberObjectType = "User" }
            

            $result = [PSCustomObject]@{
                RecipientName            = $roleMember.displayName ;
                RoleMemberObjectType     = $memberObjectType;
                RoleMemberAlternateEmail = $alternateEmail;
                NotificationType         = $role.displayName; 
                NotificationEmailScope   = "Role";
                EmailAddress             = $roleMember.mail; 
                RoleMemberUPN            = $roleMember.userPrincipalName
            } 
            Write-Output $result
        }
    }
}

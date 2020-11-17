<# 
 .Synopsis
  Gets various email addresses that Azure AD sends notifications to

 .Description
  This functions returns a list with the email notification scope and type, the recipient name and an email address

 .Example
  Get-AADAssessNotificationEmailAddresses | Export-Csv -Path ".\NotificationsEmailAddresses.csv" 
#>
function Get-AADAssessNotificationEmailAddresses {
    

    $technicalNotificationEmail = Get-MSOLCompanyInformation | Select-Object -ExpandProperty TechnicalNotificationEmails
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

    $roles = Get-AzureADDirectoryRole

    foreach ($role in $roles) {
        $roleMembers = Get-AzureADDirectoryRoleMember -ObjectId $role.ObjectId
        foreach ($roleMember in $roleMembers) {
            $alternateEmail = $roleMember.OtherMails -join ";"

            $result = [PSCustomObject]@{
                RecipientName            = $roleMember.DisplayName ;
                RoleMemberObjectType     = $roleMember.ObjectType; 
                RoleMemberAlternateEmail = $alternateEmail;
                NotificationType         = $role.DisplayName; 
                NotificationEmailScope   = "Role";
                EmailAddress             = $roleMember.Mail; 
                RoleMemberUPN            = $roleMember.UserPrincipalName
            } 
            Write-Output $result
        }
    }
}

<# 
 .Synopsis
  Produces the Azure AD Conditional Access reports required by the Azure AD assesment
 .Description
  This cmdlet reads the conditional access from the target Azure AD Tenant and produces the output files 
  in a target directory

 .PARAMETER OutputDirectory
    Full path of the directory where the output files will be generated.

.EXAMPLE
   .\Get-AADAssessCAPolicyReports -OutputDirectory "c:\temp\contoso" 

#>
function Get-AADAssessCAPolicyReports {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $OutputDirectory 
    )    

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Reading policies and named locations" 
        $policies = Get-MsGraphResults "identity/conditionalAccess/policies"
        $namedLocations = Get-MsGraphResults "identity/conditionalAccess/namedLocations"

        Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Consolidating object references"
        $userIds = [array](Get-ObjectPropertyValue $policies 'conditions' 'users' 'includeUsers') + (Get-ObjectPropertyValue $policies 'conditions' 'users' 'excludeUsers') | Sort-Object | Get-Unique | Where-Object { $_ -notin 'All', 'GuestsOrExternalUsers' }
        $groupIds = [array](Get-ObjectPropertyValue $policies 'conditions' 'users' 'includeGroups') + (Get-ObjectPropertyValue $policies 'conditions' 'users' 'excludeGroups') | Sort-Object | Get-Unique
        $appIds = [array](Get-ObjectPropertyValue $policies 'conditions' 'applications' 'includeApplications') + (Get-ObjectPropertyValue $policies 'conditions' 'applications' 'excludeApplications') | Sort-Object | Get-Unique | Where-Object { $_ -notin 'All', 'None', 'Office365' }
        
        Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Querying referenced objects" 
        $referencedUsers = Get-MsGraphResults 'users' -UniqueId $userIds -Select 'id,userPrincipalName,displayName'
        $referencedGroups = Get-MsGraphResults 'groups' -UniqueId $groupIds -Select 'id,displayName'
        $referencedApps = Get-MsGraphResults ($appIds | ForEach-Object { "servicePrincipals?`$filter=appId eq '$_'" }) -Select 'id,appId,displayName'

        Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Saving Reports"
        $policies | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CAPolicies.json" -Force
        $namedLocations | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\NamedLocations.json" -Force

        $referencedUsers | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefUsers.json" -Force
        $referencedGroups | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefGroups.json" -Force
        $referencedApps | Sort-Object appId | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefApps.json" -Force
    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $true }
}

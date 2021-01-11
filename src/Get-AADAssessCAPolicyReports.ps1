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

    Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Reading policies and named locations" 
    #$policies = Invoke-MSGraphQuery -Method GET -endpoint "identity/conditionalAccess/policies"
    #$namedLocations = Invoke-MSGraphQuery -Method GET -endpoint "identity/conditionalAccess/namedLocations"  
    $policies = Invoke-MgGraphQuery -RelativeUri "identity/conditionalAccess/policies" -ReturnAllResults
    $namedLocations = Invoke-MgGraphQuery -RelativeUri "identity/conditionalAccess/namedLocations" -ReturnAllResults

    Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Consolidating object references"
    #$userIds = $policies.conditions.users.includeUsers + $policies.conditions.users.excludeUsers | Sort-Object | Get-Unique
    #$groupIds = $policies.conditions.users.includeGroups + $policies.conditions.users.excludeGroups | Sort-Object | Get-Unique
    #$appIds = $policies.conditions.applications.includeApplications + $policies.conditions.applications.excludeApplications | Sort-Object | Get-Unique
    $userIds = (Get-ObjectProperty $policies.value -Property 'conditions', 'users', 'includeUsers') + (Get-ObjectProperty $policies.value -Property 'conditions', 'users', 'excludeUsers') | Sort-Object | Get-Unique | Where-Object { $_ -notin 'All', 'GuestsOrExternalUsers' }
    $groupIds = (Get-ObjectProperty $policies.value -Property 'conditions', 'users', 'includeGroups') + (Get-ObjectProperty $policies.value -Property 'conditions', 'users', 'excludeGroups') | Sort-Object | Get-Unique
    $appIds = (Get-ObjectProperty $policies.value -Property 'conditions', 'applications', 'includeApplications') + (Get-ObjectProperty $policies.value -Property 'conditions', 'applications', 'excludeApplications') | Sort-Object | Get-Unique | Where-Object { $_ -notin 'All', 'None', 'Office365' }
    
    #$usersBatch = Expand-AzureADCAPolicyReferencedObjects -ObjectIds $UserIds -Endpoint "users" -SelectProperties "id,userprincipalName" 
    #$groupsBatch = Expand-AzureADCAPolicyReferencedObjects -ObjectIds $groupIds -Endpoint "groups" -SelectProperties "id,displayName" 
    #$appsBatch = @()
    #$appsBatch += Expand-AzureADCAPolicyReferencedObjects -ObjectIds $appIds -Endpoint "applications" -SelectProperties "appId,displayName" -FilterProperty "appId"
    #$appsBatch += Expand-AzureADCAPolicyReferencedObjects -ObjectIds $appIds -Endpoint "servicePrincipals" -SelectProperties "appId,displayName" -FilterProperty "appId"

    Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Querying referenced objects" 
    #$referencedUsers = Invoke-MSGraphBatch -requests $usersBatch 
    #$referencedGroups = Invoke-MSGraphBatch -requests $groupsBatch 
    #$referencedApps = Invoke-MSGraphBatch -requests $appsBatch 
    $referencedUsers = Invoke-MgGraphQuery -RelativeUri 'users' -UniqueId $userIds -Select 'id,userPrincipalName,displayName' -ReturnAllResults -BatchRequests
    $referencedGroups = Invoke-MgGraphQuery -RelativeUri 'groups' -UniqueId $groupIds -Select 'id,displayName' -ReturnAllResults -BatchRequests
    $referencedApps = Invoke-MgGraphQuery -RelativeUri ($appIds | ForEach-Object { "servicePrincipals?`$filter=appId eq '$_'" }) -Select 'id,appId,displayName' -ReturnAllResults -BatchRequests

    Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Saving Reports"
    $policies | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CAPolicies.json" -Force
    $namedLocations | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\NamedLocations.json" -Force

    #$referencedUsers.responses.body.value | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefUsers.json" -Force
    #$referencedGroups.responses.body.value | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefGroups.json" -Force
    #$referencedApps.responses.body.value | Sort-Object appId | Select-Object -Property appId, displayname -Unique | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefApps.json" -Force
    $referencedUsers | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefUsers.json" -Force
    $referencedGroups | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefGroups.json" -Force
    $referencedApps.value | Sort-Object appId | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefApps.json" -Force
}

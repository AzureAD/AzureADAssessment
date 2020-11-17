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
    $policies = Invoke-MSGraphQuery -Method GET -endpoint "identity/conditionalAccess/policies"
    $namedLocations = Invoke-MSGraphQuery -Method GET -endpoint "identity/conditionalAccess/namedLocations"  
    
    Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Consolidating object references" 
    $userIds = $policies.conditions.users.includeUsers + $policies.conditions.users.excludeUsers | Sort-Object | Get-Unique
    $groupIds = $policies.conditions.users.includeGroups + $policies.conditions.users.excludeGroups | Sort-Object | Get-Unique
    $appIds = $policies.conditions.applications.includeApplications + $policies.conditions.applications.excludeApplications | Sort-Object | Get-Unique

    
    
    $usersBatch = Expand-AzureADCAPolicyReferencedObjects -ObjectIds $UserIds -Endpoint "users" -SelectProperties "id,userprincipalName" 
    $groupsBatch = Expand-AzureADCAPolicyReferencedObjects -ObjectIds $groupIds -Endpoint "groups" -SelectProperties "id,displayName" 
    $appsBatch = @()
    $appsBatch += Expand-AzureADCAPolicyReferencedObjects -ObjectIds $appIds -Endpoint "applications" -SelectProperties "appId,displayName" -FilterProperty "appId"
    $appsBatch += Expand-AzureADCAPolicyReferencedObjects -ObjectIds $appIds -Endpoint "servicePrincipals" -SelectProperties "appId,displayName" -FilterProperty "appId"

    Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Querying referenced objects" 
    $referencedUsers = Invoke-MSGraphBatch -requests $usersBatch 
    $referencedGroups = Invoke-MSGraphBatch -requests $groupsBatch 
    $referencedApps = Invoke-MSGraphBatch -requests $appsBatch 

    Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Saving Reports"
    $policies | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CAPolicies.json" -Force
    $namedLocations | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\NamedLocations.json" -Force

    $referencedUsers.responses.body.value | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefUsers.json" -Force
    $referencedGroups.responses.body.value | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefGroups.json" -Force
    $referencedApps.responses.body.value | Sort-Object appId | Select-Object -Property appId, displayname -Unique | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefApps.json" -Force
}

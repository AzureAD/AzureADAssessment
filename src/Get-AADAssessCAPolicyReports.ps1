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
    $policyUserIds = @()
    $policyGroupIds = @()
    $policyAppIds = @()
    $usersBatch = @()
    $groupsBatch = @()

    if((HasProperty $policies "conditions") -eq $false){
        Write-Host "Skipped creating CA policy files. No CA policies defined in this tenant"
        return
    }

    if(HasProperty $policies.conditions.users "includeUsers") { $policyUserIds += $policies.conditions.users.includeUsers}
    if(HasProperty $policies.conditions.users "excludeUsers") { $policyUserIds += $policies.conditions.users.excludeUsers}
    $userIds = $policyUserIds | Sort-Object | Get-Unique

    
    if(HasProperty $policies.conditions.users "includeGroups") { $policyGroupIds += $policies.conditions.users.includeGroups}
    if(HasProperty $policies.conditions.users "excludeGroups") { $policyGroupIds += $policies.conditions.users.excludeGroups}
    $groupIds = $policyGroupIds | Sort-Object | Get-Unique

    
    if(HasProperty $policies.conditions.applications "includeApplications") { $policyAppIds += $policies.conditions.applications.includeApplications}
    if(HasProperty $policies.conditions.applications "excludeApplications") { $policyAppIds += $policies.conditions.applications.excludeApplications}
    $appIds = $policyAppIds | Sort-Object | Get-Unique
    
    
    if($null -ne $userIds) { $usersBatch = Expand-AzureADCAPolicyReferencedObjects -ObjectIds $userIds -Endpoint "users" -SelectProperties "id,userprincipalName" }

    
    if($null -ne $groupIds) { $groupsBatch = Expand-AzureADCAPolicyReferencedObjects -ObjectIds $groupIds -Endpoint "groups" -SelectProperties "id,displayName" }
    
    $appsBatch = @()
    if($null -ne $appIds){
        $appsBatch += Expand-AzureADCAPolicyReferencedObjects -ObjectIds $appIds -Endpoint "applications" -SelectProperties "appId,displayName" -FilterProperty "appId"
        $appsBatch += Expand-AzureADCAPolicyReferencedObjects -ObjectIds $appIds -Endpoint "servicePrincipals" -SelectProperties "appId,displayName" -FilterProperty "appId"
    }

    Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Querying referenced objects" 
    $referencedUsers = Invoke-MSGraphBatch -requests $usersBatch
    $referencedGroups = Invoke-MSGraphBatch -requests $groupsBatch
    $referencedApps = Invoke-MSGraphBatch -requests $appsBatch

    Write-Progress -Activity "Reading Azure AD Conditional Access Policies" -CurrentOperation "Saving Reports"
    $policies | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CAPolicies.json" -Force
    $namedLocations | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\NamedLocations.json" -Force

    if(HasProperty $referencedUsers "responses") { $referencedUsers.responses.body.value | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefUsers.json" -Force }
    if(HasProperty $referencedGroups "responses") { $referencedGroups.responses.body.value | Sort-Object id | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefGroups.json" -Force  }
    if(HasProperty $referencedApps "responses") { $referencedApps.responses.body.value | Sort-Object appId | Select-Object -Property appId, displayname -Unique | ConvertTo-Json -Depth 100 | Out-File "$OutputDirectory\CARefApps.json" -Force  }
}

function HasProperty($obj, $propName) {
    $hasProperty = $false
    if($null -ne $obj){
        $hasProperty = $obj.PSobject.Properties.Name -match $propName
    }
    return $hasProperty
}

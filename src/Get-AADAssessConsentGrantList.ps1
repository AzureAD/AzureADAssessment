<# 
 .Synopsis
  Gets a report of all members of roles 

 .Description
  This functions returns a list of consent grants in the directory

 .Example
  Get-AADAssessConsentGrantList | Export-Csv -Path ".\ConsentGrantList.csv" 
#>

<# 
.SYNOPSIS
    Lists delegated permissions (OAuth2PermissionGrants) and application permissions (AppRoleAssignments).

.PARAMETER PrecacheSize
    The number of users to pre-load into a cache. For tenants with over a thousand users,
    increasing this may improve performance of the script.

.EXAMPLE
    PS C:\> .\Get-AzureADPSPermissions.ps1 | Export-Csv -Path "permissions.csv" -NoTypeInformation
    Generates a CSV report of all permissions granted to all apps.

.EXAMPLE
    PS C:\> .\Get-AzureADPSPermissions.ps1 -ApplicationPermissions -ShowProgress | Where-Object { $_.Permission -eq "Directory.Read.All" }
    Get all apps which have application permissions for Directory.Read.All.
#>
Function Get-AADAssessConsentGrantList {
    [CmdletBinding()]
    param(
        [int] $PrecacheSize = 999
    )
    # An in-memory cache of objects by {object ID} andy by {object class, object ID} 
    $script:ObjectByObjectId = @{ }
    $script:ObjectByObjectClassId = @{ }

    # Function to add an object to the cache
    function CacheObject($Object) {
        if ($Object) {
            if (-not $script:ObjectByObjectClassId.ContainsKey($Object.ObjectType)) {
                $script:ObjectByObjectClassId[$Object.ObjectType] = @{ }
            }
            $script:ObjectByObjectClassId[$Object.ObjectType][$Object.ObjectId] = $Object
            $script:ObjectByObjectId[$Object.ObjectId] = $Object
        }
    }

    # Function to retrieve an object from the cache (if it's there), or from Azure AD (if not).
    function GetObjectByObjectId($ObjectId) {
        if (-not $script:ObjectByObjectId.ContainsKey($ObjectId)) {
            Write-Verbose ("Querying Azure AD for object '{0}'" -f $ObjectId)
            try {
                $object = Get-AzureADObjectByObjectId -ObjectId $ObjectId
                CacheObject -Object $object
            }
            catch { 
                Write-Verbose "Object not found."
            }
        }
        return $script:ObjectByObjectId[$ObjectId]
    }
   
    # Step 1: Get all ServicePrincipal objects and add to the cache
    Reset-MSCloudIdSession	
    Write-Verbose "Retrieving ServicePrincipal objects..."
    $servicePrincipals = Get-AzureADServicePrincipal -All $true 

    #there is a limitation on how Azure AD Graph retrieves the list of OAuth2PermissionGrants
    #we have to traverse all service principals and gather them separately.
    # Originally, we could have done this 
    # $Oauth2PermGrants = Get-AzureADOAuth2PermissionGrant -All $true 
    
    $Oauth2PermGrants = @()

    foreach ($sp in $servicePrincipals) {
        Reset-MSCloudIdSession
        CacheObject -Object $sp
        $spPermGrants = Get-AzureADServicePrincipalOAuth2PermissionGrant -ObjectId $sp.ObjectId -All $true
        $Oauth2PermGrants += $spPermGrants
    }  

    # Get one page of User objects and add to the cache
    Write-Verbose "Retrieving User objects..."
    Reset-MSCloudIdSession
    Get-AzureADUser -Top $PrecacheSize | ForEach-Object { CacheObject -Object $_ }

    # Get all existing OAuth2 permission grants, get the client, resource and scope details
    foreach ($grant in $Oauth2PermGrants) {
        if ($grant.Scope) {
            Reset-MSCloudIdSession
            $grant.Scope.Split(" ") | Where-Object { $_ } | ForEach-Object {               
                $scope = $_
                $client = GetObjectByObjectId -ObjectId $grant.ClientId
                $resource = GetObjectByObjectId -ObjectId $grant.ResourceId
                $principalDisplayName = ""
                if ($grant.PrincipalId) {
                    $principal = GetObjectByObjectId -ObjectId $grant.PrincipalId
                    $principalDisplayName = $principal.DisplayName
                }

                New-Object PSObject -Property ([ordered]@{
                        "PermissionType"       = "Delegated"
                                    
                        "ClientObjectId"       = $grant.ClientId
                        "ClientDisplayName"    = $client.DisplayName
                    
                        "ResourceObjectId"     = $grant.ResourceId
                        "ResourceDisplayName"  = $resource.DisplayName
                        "Permission"           = $scope

                        "ConsentType"          = $grant.ConsentType
                        "PrincipalObjectId"    = $grant.PrincipalId
                        "PrincipalDisplayName" = $principalDisplayName

                        "AppOwnerTenantId"     = $client.AppOwnerTenantId
                    })
            }
        }
    }
    

    # Iterate over all ServicePrincipal objects and get app permissions
    Write-Verbose "Retrieving AppRoleAssignments..."
    $script:ObjectByObjectClassId['ServicePrincipal'].GetEnumerator() | ForEach-Object {
        $sp = $_.Value
        Reset-MSCloudIdSession
        Get-AzureADServiceAppRoleAssignedTo -ObjectId $sp.ObjectId  -All $true `
        | Where-Object { $_.PrincipalType -eq "ServicePrincipal" } | ForEach-Object {
            $assignment = $_
            
            $client = GetObjectByObjectId -ObjectId $assignment.PrincipalId
            $resource = GetObjectByObjectId -ObjectId $assignment.ResourceId            
            $appRole = $resource.AppRoles | Where-Object { $_.Id -eq $assignment.Id }

            New-Object PSObject -Property ([ordered]@{
                    "PermissionType"      = "Application"
                
                    "ClientObjectId"      = $assignment.PrincipalId
                    "ClientDisplayName"   = $client.DisplayName
                
                    "ResourceObjectId"    = $assignment.ResourceId
                    "ResourceDisplayName" = $resource.DisplayName
                    "Permission"          = $appRole.Value

                    "AppOwnerTenantId"    = $client.AppOwnerTenantId
                })
        }
    }
}

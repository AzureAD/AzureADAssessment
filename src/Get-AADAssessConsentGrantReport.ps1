<#
 .Synopsis
  Gets a report of all members of roles

 .Description
  This functions returns a list of consent grants in the directory

 .Example
  Get-AADAssessConsentGrantReport | Export-Csv -Path ".\ConsentGrantList.csv"
#>
function Get-AADAssessConsentGrantReport {
    [CmdletBinding()]
    param(
        # User Data
        [Parameter(Mandatory = $false)]
        [object] $UserData,
        # Service Principal Data
        [Parameter(Mandatory = $false)]
        [object] $ServicePrincipalData,
        # OAuth2 Permission Grants Data
        [Parameter(Mandatory = $false)]
        [object] $OAuth2PermissionGrantData
        # App Role Assignment Data
        #[Parameter(Mandatory = $false)]
        #[object] $AppRoleAssignmentData
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        function Process-OAuth2PermissionGrant {
            param (
                #
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [object] $InputObject,
                #
                [Parameter(Mandatory = $true)]
                [object] $LookupCache
            )

            process {
                $grant = $InputObject
                if ($grant.scope) {
                    [string[]] $scopes = $grant.scope.Trim().Split(" ")
                    foreach ($scope in $scopes) {
                        $client = Get-AadObjectById $grant.clientId -Type servicePrincipal -LookupCache $LookupCache
                        $resource = Get-AadObjectById $grant.resourceId -Type servicePrincipal -LookupCache $LookupCache
                        if ($grant.principalId) {
                            $principal = Get-AadObjectById $grant.principalId -Type user -LookupCache $LookupCache
                        }

                        [PSCustomObject]@{
                            permission           = $scope
                            permissionType       = 'Delegated'
                            clientId             = $grant.clientId
                            clientDisplayName    = $client.displayName
                            clientOwnerTenantId  = $client.appOwnerOrganizationId
                            resourceObjectId     = $grant.resourceId
                            resourceDisplayName  = $resource.displayName
                            consentType          = $grant.consentType
                            principalObjectId    = $grant.principalId
                            principalDisplayName = if ($grant.principalId) { $principal.displayName } else { $null }
                        }
                    }
                }
            }
        }

        function Process-AppRoleAssignment {
            param (
                #
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [object] $InputObject,
                #
                [Parameter(Mandatory = $true)]
                [object] $LookupCache
            )

            process {
                foreach ($assignment in $InputObject.appRoleAssignedTo) {
                    if ($assignment.principalType -eq "ServicePrincipal") {
                        $client = Get-AadObjectById $assignment.PrincipalId -Type $assignment.PrincipalType -LookupCache $LookupCache
                        $resource = Get-AadObjectById $assignment.resourceId -Type servicePrincipal -LookupCache $LookupCache
                        $appRole = $resource.appRoles | Where-Object id -EQ $assignment.appRoleId

                        [PSCustomObject]@{
                            permission           = $appRole.value
                            permissionType       = 'Application'
                            clientId             = $assignment.principalId
                            clientDisplayName    = $client.displayName
                            clientOwnerTenantId  = $client.appOwnerOrganizationId
                            resourceObjectId     = $assignment.ResourceId
                            resourceDisplayName  = $resource.displayName
                            consentType          = $null
                            principalObjectId    = $null
                            principalDisplayName = $null
                        }
                    }
                }
            }
        }

        $LookupCache = New-LookupCache
        if ($UserData) {
            if ($UserData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
               $LookupCache.user = $UserData
            }
            else {
                $UserData | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
            }
        }

        ## Get Application Permissions
        if ($ServicePrincipalData) {
            if ($ServicePrincipalData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $LookupCache.servicePrincipal = $ServicePrincipalData
            }
            else {
                $ServicePrincipalData | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache
            }
            $LookupCache.servicePrincipal.Values | Process-AppRoleAssignment -LookupCache $LookupCache
        }
        else {
            Write-Verbose "Getting serviceprincipals..."
            Get-MsGraphResults 'serviceprincipals?$select=id,displayName,appOwnerOrganizationId,appRoles&$expand=appRoleAssignedTo' -Top 999 `
            | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache `
            | Process-AppRoleAssignment -LookupCache $LookupCache
        }

        ## Get OAuth2 Permission Grants
        if ($OAuth2PermissionGrantData) {
            $OAuth2PermissionGrantData | Process-OAuth2PermissionGrant -LookupCache $LookupCache
        }
        else {
            Write-Verbose "Getting oauth2PermissionGrants..."
            ## https://graph.microsoft.com/v1.0/oauth2PermissionGrants cannot be used for large tenants because it eventually fails with "Service is temorarily unavailable."
            #Get-MsGraphResults 'oauth2PermissionGrants' -Top 999
            Get-MsGraphResults 'serviceprincipals/{0}/oauth2PermissionGrants' -UniqueId $LookupCache.servicePrincipal.Keys -Top 999 `
            | Process-OAuth2PermissionGrant -LookupCache $LookupCache
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

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
        [object] $OAuth2PermissionGrantData,
        # App Role Assignment Data
        [Parameter(Mandatory = $false)]
        [object] $AppRoleAssignmentData
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        function Resolve-Object {
            param (
                # Object Id
                [Parameter(Mandatory = $true)]
                [string] $ObjectId,
                # User Data
                [Parameter(Mandatory = $false)]
                [object] $UserData,
                # Group Data
                [Parameter(Mandatory = $false)]
                [object] $GroupData,
                # Service Principal Data
                [Parameter(Mandatory = $false)]
                [object] $ServicePrincipalData
            )

            if ($UserData) {
                $User = $UserData | Where-Object id -EQ $ObjectId
                if ($User) { return $User }
            }
            if ($GroupData) {
                $Group = $GroupData | Where-Object id -EQ $ObjectId
                if ($Group) { return $Group }
            }
            if ($ServicePrincipalData) {
                $ServicePrincipal = $ServicePrincipalData | Where-Object id -EQ $ObjectId
                if ($ServicePrincipal) { return $ServicePrincipal }
            }
        }

        ## Collect Data
        if (!$ServicePrincipalData) {
            Write-Verbose "Getting serviceprincipals..."
            $ServicePrincipalData = Get-MsGraphResults 'serviceprincipals?$select=id,displayName,appOwnerOrganizationId,appRoles' -Top 999
        }

        if (!$OAuth2PermissionGrantData) {
            Write-Verbose "Getting oauth2PermissionGrants..."
            #$OAuth2PermissionGrantData = Get-MsGraphResults 'serviceprincipals/{0}/oauth2PermissionGrants' -UniqueId $ServicePrincipalData.id -Top 999
            $OAuth2PermissionGrantData = Get-MsGraphResults 'oauth2PermissionGrants' -Top 999
        }

        if (!$AppRoleAssignmentData) {
            Write-Verbose "Getting serviceprincipals appRoleAssignedTo..."
            $AppRoleAssignmentData = Get-MsGraphResults 'serviceprincipals/{0}/appRoleAssignedTo' -UniqueId $ServicePrincipalData.id -Top 999
        }

        if (!$UserData) {
            Write-Verbose "Getting users..."
            $UserData = Get-MsGraphResults 'users?$select=id,displayName' -UniqueId $OAuth2PermissionGrantData.principalId -Top 999
        }

        ## Get OAuth2 Permission Grants
        foreach ($grant in $OAuth2PermissionGrantData) {
            if ($grant.scope) {
                [string[]] $scopes = $grant.scope.Trim().Split(" ")
                foreach ($scope in $scopes) {
                    $client = $ServicePrincipalData | Where-Object id -EQ $grant.clientId
                    $resource = $ServicePrincipalData | Where-Object id -EQ $grant.resourceId
                    if ($grant.principalId) {
                        $principal = $UserData | Where-Object id -EQ $grant.principalId
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

        ## Get Application Permissions
        foreach ($assignment in $AppRoleAssignmentData) {
            if ($assignment.principalType -eq "ServicePrincipal") {
                $client = Resolve-Object $assignment.PrincipalId -UserData $UserData -ServicePrincipalData $ServicePrincipalData
                $resource = $ServicePrincipalData | Where-Object id -EQ $assignment.resourceId
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
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

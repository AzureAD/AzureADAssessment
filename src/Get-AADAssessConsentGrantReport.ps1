<#
.SYNOPSIS
    Gets a report of all members of roles
.DESCRIPTION
    This functions returns a list of consent grants in the directory
.EXAMPLE
    PS C:\> Get-AADAssessConsentGrantReport | Export-Csv -Path ".\ConsentGrantReport.csv"
#>
function Get-AADAssessConsentGrantReport {
    [CmdletBinding()]
    param(
        # App Role Assignment Data
        [Parameter(Mandatory = $false)]
        [psobject] $AppRoleAssignmentData,
        # OAuth2 Permission Grants Data
        [Parameter(Mandatory = $false)]
        [psobject] $OAuth2PermissionGrantData,
        # User Data
        [Parameter(Mandatory = $false)]
        [psobject] $UserData,
        # Service Principal Data
        [Parameter(Mandatory = $false)]
        [psobject] $ServicePrincipalData,
        # Generate Report Offline, only using the data passed in parameters
        [Parameter(Mandatory = $false)]
        [switch] $Offline
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        if ($Offline -and (!$PSBoundParameters['AppRoleAssignmentData'] -or !$PSBoundParameters['OAuth2PermissionGrantData'] -or !$PSBoundParameters['UserData'] -or !$PSBoundParameters['ServicePrincipalData'])) {
            Write-Error -Exception (New-Object System.Management.Automation.ItemNotFoundException -ArgumentList 'Use of the offline parameter requires that all data be provided using the data parameters.') -ErrorId 'DataParametersRequired' -Category ObjectNotFound
            return
        }

        function Extract-AppRoleAssignments {
            param (
                #
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [psobject] $InputObject,
                #
                [Parameter(Mandatory = $true)]
                [psobject] $ListVariable,
                #
                [Parameter(Mandatory = $false)]
                [switch] $PassThru
            )

            process {
                [PSCustomObject[]] $AppRoleAssignment = $InputObject.appRoleAssignedTo
                $ListVariable.AddRange($AppRoleAssignment)
                if ($PassThru) { return $InputObject }
            }
        }

        function Process-OAuth2PermissionGrant {
            param (
                #
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [psobject] $InputObject,
                #
                [Parameter(Mandatory = $true)]
                [psobject] $LookupCache,
                #
                [Parameter(Mandatory = $false)]
                [switch] $UseLookupCacheOnly
            )

            process {
                $oauth2PermissionGrant = $InputObject
                if ($oauth2PermissionGrant.scope) {
                    [string[]] $scopes = $oauth2PermissionGrant.scope.Trim().Split(" ")
                    foreach ($scope in $scopes) {
                        $client = Get-AadObjectById $oauth2PermissionGrant.clientId -Type servicePrincipal -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName,appOwnerOrganizationId,appRoles'
                        $resource = Get-AadObjectById $oauth2PermissionGrant.resourceId -Type servicePrincipal -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName,appOwnerOrganizationId,appRoles'
                        if ($oauth2PermissionGrant.principalId) {
                            $principal = Get-AadObjectById $oauth2PermissionGrant.principalId -Type user -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName'
                        }

                        [PSCustomObject]@{
                            permission           = $scope
                            permissionType       = 'Delegated'
                            clientId             = $oauth2PermissionGrant.clientId
                            clientDisplayName    = if ($client) { $client.displayName } else { $null }
                            clientOwnerTenantId  = if ($client) { $client.appOwnerOrganizationId } else { $null }
                            resourceObjectId     = $oauth2PermissionGrant.resourceId
                            resourceDisplayName  = if ($resource) { $resource.displayName } else { $null }
                            consentType          = $oauth2PermissionGrant.consentType
                            principalObjectId    = $oauth2PermissionGrant.principalId
                            principalDisplayName = if ($oauth2PermissionGrant.principalId -and $principal) { $principal.displayName } else { $null }
                        }
                    }
                }
            }
        }

        function Process-AppRoleAssignment {
            param (
                #
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [psobject] $InputObject,
                #
                [Parameter(Mandatory = $true)]
                [psobject] $LookupCache,
                #
                [Parameter(Mandatory = $false)]
                [switch] $UseLookupCacheOnly
            )

            process {
                $appRoleAssignment = $InputObject
                if ($appRoleAssignment.principalType -eq "ServicePrincipal") {
                    $client = Get-AadObjectById $appRoleAssignment.principalId -Type $appRoleAssignment.principalType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName,appOwnerOrganizationId,appRoles'
                    $resource = Get-AadObjectById $appRoleAssignment.resourceId -Type servicePrincipal -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName,appOwnerOrganizationId,appRoles'
                    $appRole = $resource.appRoles | Where-Object id -EQ $appRoleAssignment.appRoleId

                    [PSCustomObject]@{
                        permission           = if ($appRole) { $appRole.value } else { $null }
                        permissionType       = 'Application'
                        clientId             = $appRoleAssignment.principalId
                        clientDisplayName    = if ($client) { $client.displayName } else { $null }
                        clientOwnerTenantId  = if ($client) { $client.appOwnerOrganizationId } else { $null }
                        resourceObjectId     = $appRoleAssignment.ResourceId
                        resourceDisplayName  = if ($resource) { $resource.displayName } else { $null }
                        consentType          = $null
                        principalObjectId    = $null
                        principalDisplayName = $null
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
        if ($ServicePrincipalData) {
            if ($ServicePrincipalData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $LookupCache.servicePrincipal = $ServicePrincipalData
            }
            else {
                $ServicePrincipalData | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache
            }
        }

        ## Get Service Principal Permissions
        if ($AppRoleAssignmentData) {
            $AppRoleAssignmentData | Process-AppRoleAssignment -LookupCache $LookupCache -UseLookupCacheOnly:$Offline
        }
        else {
            Write-Verbose "Getting servicePrincipals..."
            $listAppRoleAssignments = New-Object 'System.Collections.Generic.List[psobject]'
            Get-MsGraphResults 'servicePrincipals?$select=id,displayName,appOwnerOrganizationId,appRoles&$expand=appRoleAssignedTo' -Top 999 `
            | Extract-AppRoleAssignments -ListVariable $listAppRoleAssignments -PassThru `
            | Select-Object -Property "*" -ExcludeProperty 'appRoleAssignedTo', 'appRoleAssignedTo@odata.context' `
            | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache

            $listAppRoleAssignments | Process-AppRoleAssignment -LookupCache $LookupCache
            Remove-Variable listAppRoleAssignments
        }

        ## Get OAuth2 Permission Grants
        if ($OAuth2PermissionGrantData) {
            $OAuth2PermissionGrantData | Process-OAuth2PermissionGrant -LookupCache $LookupCache -UseLookupCacheOnly:$Offline
        }
        else {
            Write-Verbose "Getting oauth2PermissionGrants..."
            ## https://graph.microsoft.com/v1.0/oauth2PermissionGrants cannot be used for large tenants because it eventually fails with "Service is temorarily unavailable."
            #Get-MsGraphResults 'oauth2PermissionGrants' -Top 999
            $LookupCache.servicePrincipal.Keys | Get-MsGraphResults 'servicePrincipals/{0}/oauth2PermissionGrants' -Top 999 -TotalRequests $LookupCache.servicePrincipal.Count -DisableUniqueIdDeduplication `
            | Process-OAuth2PermissionGrant -LookupCache $LookupCache
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

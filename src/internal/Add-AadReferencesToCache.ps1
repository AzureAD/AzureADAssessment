
function Add-AadReferencesToCache {
    param (
        #
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject] $InputObject,
        #
        [Parameter(Mandatory = $true)]
        [Alias('Type')]
        [ValidateSet('appRoleAssignment', 'oauth2PermissionGrant', 'servicePrincipal', 'group', 'directoryRole', 'conditionalAccessPolicy', 'roleAssignmentSchedules')]
        [string] $ObjectType,
        #
        [Parameter(Mandatory = $true)]
        [psobject] $ReferencedIdCache,
        #
        [Parameter(Mandatory = $false)]
        [string[]] $ReferencedTypes = @('#microsoft.graph.user', '#microsoft.graph.group', '#microsoft.graph.servicePrincipal'),
        #
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    begin {
        function Expand-PropertyToCache ($InputObject, $PropertyName) {
            if ($InputObject.psobject.Properties.Name.Contains($PropertyName)) {
                foreach ($Object in $InputObject.$PropertyName) {
                    if ($Object.'@odata.type' -in $ReferencedTypes) {
                        $ObjectType = $Object.'@odata.type' -replace '#microsoft.graph.', ''
                        [void] $ReferencedIdCache.$ObjectType.Add($Object.id)
                    }
                }
            }
        }
    }

    process {
        switch ($ObjectType) {
            appRoleAssignment {
                [void] $ReferencedIdCache.servicePrincipal.Add($InputObject.resourceId)
                [void] $ReferencedIdCache.$($InputObject.principalType).Add($InputObject.principalId)
                break
            }
            oauth2PermissionGrant {
                [void] $ReferencedIdCache.servicePrincipal.Add($InputObject.clientId)
                [void] $ReferencedIdCache.servicePrincipal.Add($InputObject.resourceId)
                if ($InputObject.principalId) { [void] $ReferencedIdCache.user.Add($InputObject.principalId) }
                break
            }
            servicePrincipal {
                if ($InputObject.psobject.Properties.Name.Contains('appRoleAssignedTo')) {
                    $InputObject.appRoleAssignedTo | Add-AadReferencesToCache -Type appRoleAssignment
                }
                break
            }
            group {
                Expand-PropertyToCache $InputObject 'members'
                Expand-PropertyToCache $InputObject 'transitiveMembers'
                Expand-PropertyToCache $InputObject 'owners'
                break
            }
            directoryRole {
                Expand-PropertyToCache $InputObject 'members'
                break
            }
            conditionalAccessPolicy {
                $InputObject.conditions.users.includeUsers | Where-Object { $_ -notin 'None', 'All', 'GuestsOrExternalUsers' } | ForEach-Object { [void]$ReferencedIdCache.user.Add($_) }
                $InputObject.conditions.users.excludeUsers | Where-Object { $_ -notin 'GuestsOrExternalUsers' } | ForEach-Object { [void]$ReferencedIdCache.user.Add($_) }
                $InputObject.conditions.users.includeGroups | Where-Object { $_ -notin 'All' } | ForEach-Object { [void]$ReferencedIdCache.group.Add($_) }
                $InputObject.conditions.users.excludeGroups | ForEach-Object { [void]$ReferencedIdCache.group.Add($_) }
                $InputObject.conditions.applications.includeApplications | Where-Object { $_ -notin 'None', 'All', 'Office365' } | ForEach-Object { [void]$ReferencedIdCache.appId.Add($_) }
                $InputObject.conditions.applications.excludeApplications | Where-Object { $_ -notin 'Office365' } | ForEach-Object { [void]$ReferencedIdCache.appId.Add($_) }
                break
            }
            # roleDefinition {
            #     [void] $ReferencedIdCache.roleDefinition.Add($InputObject.id)
            # }
            roleAssignmentSchedules {
                if ($InputObject.directoryScopeId -match '/(?:(.+)s/)([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
                    $directoryScopeType = $Matches[1]
                    [void] $ReferencedIdCache.$directoryScopeType.Add($Matches[2])
                }
                elseif ($InputObject.directoryScopeId -match '/([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
                    [void] $ReferencedIdCache.UnknownType.Add($Matches[1])
                }
                $principalType = $InputObject.principal.'@odata.type' -replace '#microsoft.graph.', ''
                [void] $ReferencedIdCache.$principalType.Add($InputObject.principal.id)
                if ($principalType -eq 'group') {
                    [void] $ReferencedIdCache.roleGroup.Add($InputObject.principal.id)
                }
            }
            # aadRoleAssignment {
            #     if ($InputObject.directoryScopeId -like "/administrativeUnits/*") {
            #         $id = $InputObject.directoryScopeId -replace "^/administrativeUnits/",""
            #         [void] $ReferencedIdCache.administrativeUnit.Add($id)
            #     } elseif ($InputObject.directoryScopeId -match "^/[0-9a-f-]+$") {
            #         $id = $InputObject.directoryScopeId -replace "^/",""
            #         [void] $ReferencedIdCache.directoryScopeId.Add($id)
            #     }
            #     if ($InputObject.principalType -ieq "group") {
            #         # add groups to role groups on role assignements to have a specific pointer to look at transitive memberships
            #         [void] $ReferencedIdCache.roleGroup.Add($InputObject.principalId)
            #         # add group to cache directly to get those groups information
            #         [void] $ReferencedIdCache.group.Add($InputObject.principalId)
            #     } else {
            #         [void] $ReferencedIdCache.$($InputObject.principalType).Add($InputObject.principalId)
            #     }
            #     break
            # }
        }
        if ($PassThru) { return $InputObject }
    }
}

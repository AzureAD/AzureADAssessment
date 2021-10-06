
function Add-AadReferencesToCache {
    param (
        #
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject] $InputObject,
        #
        [Parameter(Mandatory = $true)]
        [Alias('Type')]
        [ValidateSet('appRoleAssignment', 'oauth2PermissionGrants', 'servicePrincipal', 'directoryRoles', 'conditionalAccessPolicy', 'aadRoleAssignment')]
        [string] $ObjectType,
        #
        [Parameter(Mandatory = $true)]
        [psobject] $ReferencedIdCache,
        #
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    process {
        switch ($ObjectType) {
            appRoleAssignment {
                [void] $ReferencedIdCache.servicePrincipal.Add($InputObject.resourceId)
                [void] $ReferencedIdCache.$($InputObject.principalType).Add($InputObject.principalId)
                break
            }
            oauth2PermissionGrants {
                [void] $ReferencedIdCache.servicePrincipal.Add($InputObject.clientId)
                [void] $ReferencedIdCache.servicePrincipal.Add($InputObject.resourceId)
                if ($InputObject.principalId) { [void] $ReferencedIdCache.user.Add($InputObject.principalId) }
                break
            }
            servicePrincipal {
                $InputObject.appRoleAssignedTo | Add-AadReferencesToCache -Type appRoleAssignment
                break
            }
            directoryRoles {
                foreach ($member in $InputObject.members) {
                    $MemberType = $member.'@odata.type' -replace '#microsoft.graph.', ''
                    [void] $ReferencedIdCache.$MemberType.Add($member.id)
                }
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
            aadRoleAssignment {
                [void] $ReferencedIdCache.$($InputObject.subject.Type).Add($InputObject.subject.id)
                # switch ($InputObject.subject.Type) {
                #     User {
                #         [void] $ReferencedIdCache.user.Add($InputObject.subject.id)
                #         break
                #     }
                #     Group {
                #         [void] $ReferencedIdCache.group.Add($InputObject.subject.id)
                #         break
                #     }
                #     ServicePrincipal {
                #         [void] $ReferencedIdCache.servicePrincipal.Add($InputObject.subject.id)
                #         break
                #     }
                # }
                break
            }
        }
        if ($PassThru) { return $InputObject }
    }
}

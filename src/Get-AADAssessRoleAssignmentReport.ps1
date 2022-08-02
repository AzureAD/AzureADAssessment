<#
.SYNOPSIS
    Gets a report of all role assignments
.DESCRIPTION
    This function returns a list of role assignments
.EXAMPLE
    PS C:\> Get-AADAssessRoleAssignmentReport | Export-Csv -Path ".\RoleAssignmentReport.csv"
#>
function Get-AADAssessRoleAssignmentReport {
    [CmdletBinding()]
    param (
        # Tenant has P2
        [Parameter(Mandatory = $false)]
        [bool] $TenantHasP2 = $true,
        # Role Assignments
        [Parameter(Mandatory = $false)]
        [psobject] $RoleAssignmentsData,
        # Role Assignment Schedule Data
        [Parameter(Mandatory = $false)]
        [psobject] $RoleAssignmentSchedulesData,
        # Role Eligible Schedule Data
        [Parameter(Mandatory = $false)]
        [psobject] $RoleEligibilitySchedulesData,
        # Organization Data
        [Parameter(Mandatory = $false)]
        [psobject] $OrganizationData,
        # Administrative Unit Data
        [Parameter(Mandatory = $false)]
        [psobject] $AdministrativeUnitsData,
        # User Data
        [Parameter(Mandatory = $false)]
        [psobject] $UsersData,
        # Group Data
        [Parameter(Mandatory = $false)]
        [psobject] $GroupsData,
        # Application Data
        [Parameter(Mandatory = $false)]
        [psobject] $ApplicationsData,
        # Service Principal Data
        [Parameter(Mandatory = $false)]
        [psobject] $ServicePrincipalsData,
        # Generate Report Offline, only using the data passed in parameters
        [Parameter(Mandatory = $false)]
        [switch] $Offline
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        # there may be no elegibile roles so it isn't counted to check for offline but collection will be prevented
        # role assignement should have some members if at least for one global administrator
        if ($Offline -and (($TenantHasP2 -and !$PSBoundParameters['roleAssignmentSchedulesData']) -or (!$TenantHasP2 -and !$PSBoundParameters['roleAssignmentsData']))) {
            Write-Error -Exception (New-Object System.Management.Automation.ItemNotFoundException -ArgumentList 'Use of the offline parameter requires that all data be provided using the data parameters.') -ErrorId 'DataParametersRequired' -Category ObjectNotFound
            return
        }

        function Process-RoleAssignment {
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
                $RoleSchedules = $InputObject
                foreach ($RoleSchedule in $RoleSchedules) {

                    # get details of directory scope
                    if ($RoleSchedule.directoryScopeId -match '/(?:(.+)s/)?([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
                        $ObjectId = $Matches[2]
                        $directoryScopeType = $Matches[1]
                        if ($directoryScopeType) {
                            $directoryScope = Get-AadObjectById $ObjectId -Type $directoryScopeType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly
                        }
                        else {
                            $directoryScope = Get-AadObjectById $ObjectId -Type servicePrincipal -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly
                            if ($directoryScope) { $directoryScopeType = 'servicePrincipal' }
                            else {
                                $directoryScope = Get-AadObjectById $ObjectId -Type application -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly
                                if ($directoryScope) { $directoryScopeType = 'application' }
                            }
                        }
                    }
                    else {
                        $directoryScopeType = "tenant"
                        $directoryScope = @{
                            id          = $OrganizationData.id
                            displayName = $OrganizationData.displayName
                        }
                    }

                    # get details of principal
                    $principalType = 'user'
                    $principal = Get-AadObjectById $RoleSchedule.principalId -Type $principalType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName'
                    if (!$principal) {
                        $principalType = 'group'
                        $principal = Get-AadObjectById $RoleSchedule.principalId -Type $principalType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName'
                    } 
                    if (!$principal) {
                        $principalType = 'servicePrincipal'
                        $principal = Get-AadObjectById $RoleSchedule.principalId -Type $principalType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName'
                    }
                    if (!$principal) {
                        $principalType = 'unknown'
                    }

                    # get start and end datetime
                    $startDateTime = $null
                    $endDateTime = $null
                    if ($RoleSchedule.psobject.Properties.Name.Contains('scheduleInfo')) {
                        $startDateTime = $RoleSchedule.scheduleInfo.startDateTime
                        $endDateTime = $RoleSchedule.scheduleInfo.expiration.endDateTime
                    }

                    $OutputObject = [PSCustomObject]@{
                        id                        = $RoleSchedule.id
                        directoryScopeId          = $RoleSchedule.directoryScopeId
                        directoryScopeObjectId    = if ($directoryScope) { $directoryScope.id } else { $null }
                        directoryScopeDisplayName = if ($directoryScope) { $directoryScope.displayName } else { $null }
                        directoryScopeType        = $directoryScopeType
                        roleDefinitionId          = $RoleSchedule.roleDefinition.id
                        roleDefinitionTemplateId  = $RoleSchedule.roleDefinition.templateId
                        roleDefinitionDisplayName = $RoleSchedule.roleDefinition.displayName
                        principalId               = $RoleSchedule.principalId
                        principalDisplayName      = if ($principal) { $principal.displayName } else { $null }
                        principalType             = $principalType
                        memberType                = $RoleSchedule.memberType
                        status                    = $RoleSchedule.status
                        assignmentType            = $RoleSchedule.assignmentType
                        startDateTime             = $startDateTime
                        endDateTime               = $endDateTime
                    }
                    $OutputObject

                    if ($principalType -eq 'group') {
                        $OutputObject.memberType = 'Group'

                        if ($UseLookupCacheOnly) {
                            Expand-GroupTransitiveMembership $RoleSchedule.principalId -LookupCache $LookupCache `
                            | ForEach-Object {
                                $principalType = $_.'@odata.type' -replace '#microsoft.graph.', ''
                                $principal = Get-AadObjectById $_.id -Type $principalType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly
                                $OutputObject.principalId = $_.id
                                $OutputObject.principalDisplayName = if ($principal) { $principal.displayName } else { $null }
                                $OutputObject.principalType = $principalType
                                $OutputObject
                            }
                        }
                        else {
                            Get-MsGraphResults 'groups/{0}/transitiveMembers' -UniqueId $RoleSchedule.principalId -Select id, displayName -Top 999 -DisableUniqueIdDeduplication `
                            | ForEach-Object {
                                $OutputObject.principalId = $_.id
                                $OutputObject.principalDisplayName = $_.displayName
                                $OutputObject.principalType = $_.'@odata.type' -replace '#microsoft.graph.', ''
                                $OutputObject
                            }
                        }
                    }
                }
            }
        }

        if (!$OrganizationData) {
            $OrganizationData = Get-MsGraphResults 'organization?$select=id,displayName'
        }

        $LookupCache = New-LookupCache
        if ($AdministrativeUnitsData) {
            if ($AdministrativeUnitsData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $LookupCache.administrativeUnit = $AdministrativeUnitsData
            }
            else {
                $AdministrativeUnitsData | Add-AadObjectToLookupCache -Type administrativeUnit -LookupCache $LookupCache
            }
        }

        if ($UsersData) {
            if ($UsersData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $LookupCache.user = $UsersData
            }
            else {
                $UsersData | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
            }
        }

        if ($GroupsData) {
            if ($GroupsData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $LookupCache.group = $GroupsData
            }
            else {
                $GroupsData | Add-AadObjectToLookupCache -Type group -LookupCache $LookupCache
            }
        }

        if ($ApplicationsData) {
            if ($ApplicationsData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $LookupCache.application = $ApplicationsData
            }
            else {
                $ApplicationsData | Add-AadObjectToLookupCache -Type application -LookupCache $LookupCache
            }
        }

        if ($ServicePrincipalsData) {
            if ($ServicePrincipalsData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $LookupCache.servicePrincipal = $ServicePrincipalsData
            }
            else {
                $ServicePrincipalsData | Add-AadObjectToLookupCache -Type servicePrincipal -LookupCache $LookupCache
            }
        }

        ## Get Role Assignments
        if ($TenantHasP2) {
            if ($RoleAssignmentSchedulesData) {
                $RoleAssignmentSchedulesData | Process-RoleAssignment -LookupCache $LookupCache -UseLookupCacheOnly:$Offline
            }
            else {
                Write-Verbose "Getting roleAssignmentSchedules..."
                Get-MsGraphResults 'roleManagement/directory/roleAssignmentSchedules' -Select 'id,directoryScopeId,memberType,scheduleInfo,status,assignmentType' -Filter "status eq 'Provisioned' and assignmentType eq 'Assigned'" -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } -ApiVersion 'beta' `
                | Process-RoleAssignment -LookupCache $LookupCache
            }

            if ($RoleEligibilitySchedulesData) {
                $RoleEligibilitySchedulesData | Select-Object -Property *,@{Name="assignmentType"; Expression={"Assigned"}} `
                | Process-RoleAssignment -LookupCache $LookupCache -UseLookupCacheOnly:$Offline
            }
            elseif (!$Offline) {
                Get-MsGraphResults 'roleManagement/directory/roleEligibilitySchedules' -Select 'id,directoryScopeId,memberType,scheduleInfo,status' -Filter "status eq 'Provisioned'" -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } -ApiVersion 'beta' `
                | Select-Object -Property *,@{Name="assignmentType"; Expression={"Assigned"}} `
                | Process-RoleAssignment -LookupCache $LookupCache
            }
        } else {
            if ($RoleAssignmentsData) {
                $RoleAssignmentsData | Select-Object -Property *,@{Name="status"; Expression={"Grandted"}},@{Name="memberType"; Expression={"Direct"}},@{Name="assignmentType"; Expression={"Assigned"}} `
                | Process-RoleAssignment -LookupCache $LookupCache -UseLookupCacheOnly:$Offline
            } else  {
                Write-Verbose "Getting roleDefinitions..."
                $roleDefinitions = Get-MsGraphResults 'roleManagement/directory/roleDefinitions' -Select 'id,templateId,displayName,isBuiltIn,isEnabled' -ApiVersion 'v1.0' -OutVariable roleDefinitions `
                | Where-Object { $_.isEnabled } `
                | Select-Object id, templateId, displayName, isBuiltIn, isEnabled 
                Write-Verbose "Getting roleAssignments..."
                $roleDefinitions | Get-MsGraphResults 'roleManagement/directory/roleAssignments' -Select 'id,directoryScopeId' -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } -Filter "roleDefinitionId eq '{0}'" `
                | Select-Object -Property *,@{Name="status"; Expression={"Grandted"}},@{Name="memberType"; Expression={"Direct"}},@{Name="assignmentType"; Expression={"Assigned"}} `
                | Process-RoleAssignment -LookupCache $LookupCache
            }
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

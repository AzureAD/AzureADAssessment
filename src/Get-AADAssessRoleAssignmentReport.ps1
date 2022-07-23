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
        # Role Assignments
        [Parameter(Mandatory = $false)]
        [psobject] $RoleAssignmentsData,
        # Role Assignment Schedule Instance Data
        [Parameter(Mandatory = $false)]
        [psobject] $RoleAssignmentScheduleInstancesData,
        # Role Eligible Schedule Instance Data
        [Parameter(Mandatory = $false)]
        [psobject] $RoleEligibilityScheduleInstancesData,
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
        if ($Offline -and (!($PSBoundParameters['RoleAssignmentScheduleInstancesData'] -or $PSBoundParameters['RoleEligibilityScheduleInstancesData']) -and !$PSBoundParameters['roleAssignmentsData'])) {
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
                $RoleScheduleInstances = $InputObject
                foreach ($RoleScheduleInstance in $RoleScheduleInstances) {

                    # get details of directory scope
                    if ($RoleScheduleInstance.directoryScopeId -match '/(?:(.+)s/)?([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
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
                    $principal = Get-AadObjectById $RoleScheduleInstance.principalId -Type $principalType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName,mail,otherMails'
                    if (!$principal) {
                        $principalType = 'group'
                        $principal = Get-AadObjectById $RoleScheduleInstance.principalId -Type $principalType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName,mail'
                    } 
                    if (!$principal) {
                        $principalType = 'servicePrincipal'
                        $principal = Get-AadObjectById $RoleScheduleInstance.principalId -Type $principalType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly -Properties 'id,displayName'
                    }
                    if (!$principal) {
                        $principalType = 'unknown'
                    }

                    $OutputObject = [PSCustomObject]@{
                        id                        = $RoleScheduleInstance.id
                        directoryScopeId          = $RoleScheduleInstance.directoryScopeId
                        directoryScopeObjectId    = if ($directoryScope) { $directoryScope.id } else { $null }
                        directoryScopeDisplayName = if ($directoryScope) { $directoryScope.displayName } else { $null }
                        directoryScopeType        = $directoryScopeType
                        roleDefinitionId          = $RoleScheduleInstance.roleDefinition.id
                        roleDefinitionTemplateId  = $RoleScheduleInstance.roleDefinition.templateId
                        roleDefinitionDisplayName = $RoleScheduleInstance.roleDefinition.displayName
                        principalId               = $RoleScheduleInstance.principalId
                        principalDisplayName      = if ($principal) { $principal.displayName } else { $null }
                        principalType             = $principalType
                        principalMail             = if ($principal) { Get-ObjectPropertyValue $principal mail } else { $null }
                        principalOtherMails       = if ($principal) { Get-ObjectPropertyValue $principal otherMails } else { $null }
                        memberType                = $RoleScheduleInstance.memberType
                        assignmentType            = $RoleScheduleInstance.assignmentType
                        startDateTime             = if ($RoleScheduleInstance.psobject.Properties.Name.Contains('startDateTime')) { $RoleScheduleInstance.startDateTime } else { $null }
                        endDateTime               = if ($RoleScheduleInstance.psobject.Properties.Name.Contains('endDateTime')) { $RoleScheduleInstance.endDateTime } else { $null }
                    }
                    $OutputObject

                    if ($principalType -eq 'group') {
                        $OutputObject.memberType = 'Group'

                        if ($UseLookupCacheOnly) {
                            Expand-GroupTransitiveMembership $RoleScheduleInstance.principal.id -LookupCache $LookupCache `
                            | ForEach-Object {
                                $principalType = $_.'@odata.type' -replace '#microsoft.graph.', ''
                                $principal = Get-AadObjectById $_.id -Type $principalType -LookupCache $LookupCache -UseLookupCacheOnly:$UseLookupCacheOnly
                                $OutputObject.principalId = $_.id
                                $OutputObject.principalDisplayName = if ($principal) { $principal.displayName } else { $null }
                                $OutputObject.principalType = $principalType
                                $OutputObject.principalMail = if ($principal) { Get-ObjectPropertyValue $principal mail } else { $null }
                                $OutputObject.principalOtherMails = if ($principal) { Get-ObjectPropertyValue $principal otherMails } else { $null }
                                $OutputObject
                            }
                        }
                        else {
                            Get-MsGraphResults 'groups/{0}/transitiveMembers' -UniqueId $RoleScheduleInstance.principal.id -Select id, displayName, mail, otherMails -Top 999 -DisableUniqueIdDeduplication `
                            | ForEach-Object {
                                $OutputObject.principalId = $_.id
                                $OutputObject.principalDisplayName = $_.displayName
                                $OutputObject.principalType = $_.'@odata.type' -replace '#microsoft.graph.', ''
                                $OutputObject.principalMail = if ($principal) { Get-ObjectPropertyValue $principal mail } else { $null }
                                $OutputObject.principalOtherMails = if ($principal) { Get-ObjectPropertyValue $principal otherMails } else { $null }
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
        [bool] $isAadP2Tenant = $true
        if ($RoleAssignmentScheduleInstancesData) {
            $isAadP2Tenant = $true
            $RoleAssignmentScheduleInstancesData | Process-RoleAssignment -LookupCache $LookupCache -UseLookupCacheOnly:$Offline
        }
        elseif ($RoleAssignmentsData) {
            $isAadP2Tenant = $false
            $RoleAssignmentsData | Select-Object -Property *, @{Name = "memberType"; Expression = { "Direct" } }, @{Name = "assignmentType"; Expression = { "Assigned" } } `
            | Process-RoleAssignment -LookupCache $LookupCache -UseLookupCacheOnly:$Offline
        }
        elseif (!$Offline) {
            try { Get-MsGraphResults 'https://graph.microsoft.com/beta/roleManagement/directory/roleAssignmentScheduleInstances?$top=1' -ApiVersion beta -DisablePaging -ErrorAction Stop | Out-Null }
            catch { $isAadP2Tenant = $false }

            if ($isAadP2Tenant) {
                Write-Verbose "Getting roleAssignmentScheduleInstances..."
                #Get-MsGraphResults 'roleManagement/directory/roleAssignmentSchedules' -Select 'id,directoryScopeId,memberType,scheduleInfo,status,assignmentType' -Filter "status eq 'Provisioned' and assignmentType eq 'Assigned'" -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } -ApiVersion 'beta' `
                Get-MsGraphResults 'roleManagement/directory/roleAssignmentScheduleInstances' -Select 'id,directoryScopeId,assignmentType,memberType,principalId,startDateTime,endDateTime' -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } `
                | Process-RoleAssignment -LookupCache $LookupCache
            }
            else {
                Write-Verbose "Getting roleAssignments..."
                Get-MsGraphResults 'roleManagement/directory/roleAssignments' -Select 'id,directoryScopeId,principalId' -QueryParameters @{ '$expand' = 'roleDefinition($select=id,templateId,displayName)' } `
                | Select-Object -Property *, @{Name = "memberType"; Expression = { "Direct" } }, @{Name = "assignmentType"; Expression = { "Assigned" } } `
                | Process-RoleAssignment -LookupCache $LookupCache
            }
        }

        if ($RoleEligibilityScheduleInstancesData) {
            $RoleEligibilityScheduleInstancesData | Select-Object -Property *, @{Name = "assignmentType"; Expression = { "Eligible" } } `
            | Process-RoleAssignment -LookupCache $LookupCache -UseLookupCacheOnly:$Offline
        }
        elseif (!$Offline -and $isAadP2Tenant) {
            Write-Verbose "Getting roleEligibleScheduleInstances..."
            #Get-MsGraphResults 'roleManagement/directory/roleEligibilitySchedules' -Select 'id,directoryScopeId,memberType,scheduleInfo,status' -Filter "status eq 'Provisioned'" -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } -ApiVersion 'beta' `
            Get-MsGraphResults 'roleManagement/directory/roleEligibilityScheduleInstances' -Select 'id,directoryScopeId,memberType,principalId,startDateTime,endDateTime' -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' }
            | Select-Object -Property *, @{Name = "assignmentType"; Expression = { "Eligible" } } `
            | Process-RoleAssignment -LookupCache $LookupCache
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

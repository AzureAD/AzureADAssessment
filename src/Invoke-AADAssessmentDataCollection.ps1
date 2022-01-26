<#
.SYNOPSIS
    Produces the Azure AD Configuration reports required by the Azure AD assesment
.DESCRIPTION
    This cmdlet reads the configuration information from the target Azure AD Tenant and produces the output files in a target directory
.EXAMPLE
    PS C:\> Invoke-AADAssessmentDataCollection
    Collect and package assessment data to "C:\AzureADAssessment".
.EXAMPLE
    PS C:\> Invoke-AADAssessmentDataCollection -OutputDirectory "C:\Temp"
    Collect and package assessment data to "C:\Temp".
#>
function Invoke-AADAssessmentDataCollection {
    [CmdletBinding()]
    param (
        # Full path of the directory where the output files will be generated.
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory = (Join-Path $env:SystemDrive 'AzureADAssessment'),
        # Generate Reports
        [Parameter(Mandatory = $false)]
        [switch] $SkipReportOutput,
        # Skip Packaging
        [Parameter(Mandatory = $false)]
        [switch] $SkipPackaging,
        [Parameter(Mandatory = $false)]
        [switch] $UnifiedRole
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        $ReferencedIdCache = New-AadReferencedIdCache
        #$ReferencedIdCacheCA = New-AadReferencedIdCache

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

        if ($MyInvocation.CommandOrigin -eq 'Runspace') {
            ## Reset Parent Progress Bar
            New-Variable -Name stackProgressId -Scope Script -Value (New-Object 'System.Collections.Generic.Stack[int]') -ErrorAction SilentlyContinue
            $stackProgressId.Clear()
            $stackProgressId.Push(0)
        }

        ### Initalize Directory Paths
        #$OutputDirectory = Join-Path $OutputDirectory "AzureADAssessment"
        $OutputDirectoryData = Join-Path $OutputDirectory "AzureADAssessmentData"
        $AssessmentDetailPath = Join-Path $OutputDirectoryData "AzureADAssessment.json"
        $PackagePath = Join-Path $OutputDirectory "AzureADAssessmentData.zip"

        ### Organization Data - 0
        Write-Progress -Id 0 -Activity 'Microsoft Azure AD Assessment Data Collection' -Status 'Organization Details' -PercentComplete 0
        $OrganizationData = Get-MsGraphResults 'organization?$select=id,verifiedDomains,technicalNotificationMails' -ErrorAction Stop
        $InitialTenantDomain = $OrganizationData.verifiedDomains | Where-Object isInitial -EQ $true | Select-Object -ExpandProperty name -First 1
        $PackagePath = $PackagePath.Replace("AzureADAssessmentData.zip", "AzureADAssessmentData-$InitialTenantDomain.zip")
        $OutputDirectoryAAD = Join-Path $OutputDirectoryData "AAD-$InitialTenantDomain"
        Assert-DirectoryExists $OutputDirectoryAAD

        #Export-Clixml -InputObject $OrganizationData -Depth 10 -Path (Join-Path $OutputDirectoryAAD "organizationData.xml")
        ConvertTo-Json -InputObject $OrganizationData -Depth 10 | Set-Content (Join-Path $OutputDirectoryAAD "organization.json")

        ### Generate Assessment Data
        Assert-DirectoryExists $OutputDirectoryData
        ConvertTo-Json -InputObject @{
            AssessmentId           = if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) { $script:AppInsightsRuntimeState.OperationStack.Peek().Id } else { New-Guid }
            AssessmentVersion      = $MyInvocation.MyCommand.Module.Version.ToString()
            AssessmentTenantId     = $OrganizationData.id
            AssessmentTenantDomain = $InitialTenantDomain
        } | Set-Content $AssessmentDetailPath

        ### Licenses - 1
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Subscribed SKU' -PercentComplete 5
        Get-MsGraphResults "subscribedSkus" -Select "prepaidunits", "consumedunits", "skuPartNumber", "servicePlans" `
        | Export-JsonArray (Join-Path $OutputDirectoryAAD "subscribedSkus.json") -Depth 5 -Compress

        ### Conditional Access policies - 2
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Conditional Access Policies' -PercentComplete 10
        #Get-MsGraphResults "identity/conditionalAccess/policies" -ErrorAction Stop `
        Get-MsGraphResults "identity/conditionalAccess/policies" `
        | Add-AadReferencesToCache -Type conditionalAccessPolicy -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-JsonArray (Join-Path $OutputDirectoryAAD "conditionalAccessPolicies.json") -Depth 5 -Compress

        ### Named location - 3
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Conditional Access Named locations' -PercentComplete 15
        Get-MsGraphResults "identity/conditionalAccess/namedLocations" `
        | Export-JsonArray (Join-Path $OutputDirectoryAAD "namedLocations.json") -Depth 5 -Compress

        ### EOTP Policy - 4
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Email Auth Method Policy' -PercentComplete 20
        Get-MsGraphResults "policies/authenticationMethodsPolicy/authenticationMethodConfigurations/email" -ErrorAction SilentlyContinue `
        | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path (Join-Path $OutputDirectoryAAD "emailOTPMethodPolicy.json")
        if (-not (Test-Path -PathType Leaf -Path (Join-Path $OutputDirectoryAAD "emailOTPMethodPolicy.json"))) {
            Write-Warning "Getting Email Authentication Method Configuration requires the Global Administrator role. The policy information will be omitted"
        }

        ### Directory Role Data - 5
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Directory Roles' -PercentComplete 25
        ## $expand on directoryRole members caps results at 20 members with no NextLink so call members endpoint for each.
        Get-MsGraphResults 'directoryRoles?$select=id,displayName,roleTemplateId' -DisableUniqueIdDeduplication `
        | Expand-MsGraphRelationship -ObjectType directoryRoles -PropertyName members -References `
        | Add-AadReferencesToCache -Type directoryRole -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "directoryRoleData.xml")

        ### Directory Role Definitions - 6
        # TODO: currently limit to native roles. Custom are not returned by assignments
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Directory Role Definitions' -PercentComplete 30
        Get-MsGraphResults 'roleManagement/directory/roleDefinitions' -Select 'id,displayName,isBuiltIn,isEnabled' -ApiVersion 'beta' `
        | Where-Object { $_.isEnabled -and $_.isBuiltIn} `
        | Select-Object id,displayName,isBuiltIn `
        | Add-AadReferencesToCache -Type roleDefinition -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Csv (Join-Path $OutputDirectoryAAD "roleDefinitions.csv") -NoTypeInformation

        ### Privileged Access AAD role Assignments - 7
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'PIM AAD Roles' -PercentComplete 35
        if (!$UnifiedRole) {
            Get-MsGraphResults 'privilegedAccess/aadRoles/roleAssignments' -Select 'id,roleDefinitionId,memberType,assignmentState,endDateTime,linkedEligibleRoleAssignmentId' -Filter "resourceId eq '$($OrganizationData.id)'" -Top 999 -ApiVersion 'beta' -QueryParameters @{ '$expand' = 'subject($select=id,type)' } `
            | Where-Object { !$_.linkedEligibleRoleAssignmentId } `
            | Select-Object -Property roleDefinitionId, `
            @{ Name = "directoryScopeId"; Expression = {
                "unknown"
            }},memberType, `
            @{ Name = "assignmentType"; Expression = {
                $_.assignmentState
            }},endDateTime, `
            @{ Name = "principalId"; Expression = {
                $_.subject.id
            }}, `
            @{ Name = "principalType"; Expression = {
                $tmp = $_.subject.type.ToCharArray()
                $tmp[0] = [char]::ToLower($tmp[0])
                new-object -typeName string -ArgumentList (,$tmp)
            }} `
            | Add-AadReferencesToCache -Type aadRoleAssignment -ReferencedIdCache $ReferencedIdCache -PassThru `
            | Export-Csv (Join-Path $OutputDirectoryAAD "roleAssignmentsData.csv") -NoTypeInformation
        } else {
            # Getting role assignments via unified role API
            $ReferencedIdCache.roleDEfinition | Get-MsGraphResults "roleManagement/directory/roleAssignmentSchedules?`$filter=roleDefinitionId+eq+'{0}'&`$select=id,roleDefinitionId,directoryScopeId,memberType,scheduleInfo,status,assignmentType" -QueryParameters @{ '$expand' = 'principal($select=id)' } -ApiVersion 'beta' `
            | Where-Object { $_.status -eq 'Provisioned' -and $_.assignmentType -eq 'Assigned'} `
            | Select-Object -Property roleDefinitionId,directoryScopeId,memberType, `
            @{ Name = "assignmentType"; Expression = {
                "Active"
            }}, `
            @{ Name = 'endDateTime'; Expression = {
                $_.scheduleInfo.expiration.endDateTime
            }}, `
            @{ Name = 'principalId'; Expression = {
                $_.principal.id
            }}, `
            @{ Name = 'principalType'; Expression = {
                $_.principal.'@odata.type' -replace '#microsoft.graph.',''
            }} `
            | Add-AadReferencesToCache -Type aadRoleAssignment -ReferencedIdCache $ReferencedIdCache -PassThru `
            | Export-Csv (Join-Path $OutputDirectoryAAD "roleAssignmentsData.csv") -NoTypeInformation

            # Getting role elligibility via unified role API
            $ReferencedIdCache.roleDEfinition | Get-MsGraphResults "roleManagement/directory/roleEligibilitySchedules?`$filter=roleDefinitionId+eq+'{0}'&`$select=id,roleDefinitionId,directoryScopeId,memberType,scheduleInfo,status" -QueryParameters @{ '$expand' = 'principal($select=id)' } -ApiVersion 'beta' `
            | Where-Object { $_.status -eq 'Provisioned'} `
            | Select-Object -Property roleDefinitionId,directoryScopeId,memberType, `
            @{ Name = "assignmentType"; Expression = {
                "Eligible"
            }}, `
            @{ Name = 'EndDateTime'; Expression = {
                $_.scheduleInfo.expiration.endDateTime
            }}, `
            @{ Name = 'principalId'; Expression = {
                $_.principal.id
            }}, `
            @{ Name = 'principalType'; Expression = {
                $_.principal.'@odata.type' -replace '#microsoft.graph.',''
            }} `
            | Add-AadReferencesToCache -Type aadRoleAssignment -ReferencedIdCache $ReferencedIdCache -PassThru `
            | Export-Csv (Join-Path $OutputDirectoryAAD "roleAssignmentsData.csv") -NoTypeInformation -Append
        }

        ### Application Data - 8
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Applications' -PercentComplete 40
        Get-MsGraphResults 'applications?$select=id,appId,displayName,appRoles,keyCredentials,passwordCredentials' -Top 999 -ApiVersion 'beta' `
        | Where-Object { $_.keyCredentials.Count -or $_.passwordCredentials.Count -or $ReferencedIdCache.appId.Contains($_.appId) -or $ReferencedIdCache.directoryScopeId.Contains($_.id)} `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "applicationData.xml")

        ### Service Principal Data - 9
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Service Principals' -PercentComplete 45
        ## Option 1: Get servicePrincipal objects without appRoleAssignments. Get appRoleAssignments
        # $servicePrincipalsCount = Get-MsGraphResults 'servicePrincipals/$count' `
        # ## Although much more performant, $expand on servicePrincipal appRoleAssignedTo appears to miss certain appRoleAssignments.
        # Get-MsGraphResults 'servicePrincipals?$select=id,appId,servicePrincipalType,displayName,accountEnabled,appOwnerOrganizationId,appRoles,oauth2PermissionScopes,keyCredentials,passwordCredentials' -Top 999 `
        # | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml")
        ## Option 2: Expand appRoleAssignedTo when retrieving servicePrincipal object. This is at least 50x faster but appears to miss some appRoleAssignments.
        $listAppRoleAssignments = New-Object 'System.Collections.Generic.List[psobject]'
        Get-MsGraphResults 'servicePrincipals?$select=id,appId,servicePrincipalType,displayName,accountEnabled,appOwnerOrganizationId,appRoles,oauth2PermissionScopes,keyCredentials,passwordCredentials&$expand=appRoleAssignedTo' -Top 999 -ApiVersion 'beta' `
        | Extract-AppRoleAssignments -ListVariable $listAppRoleAssignments -PassThru `
        | Select-Object -Property "*" -ExcludeProperty 'appRoleAssignedTo', 'appRoleAssignedTo@odata.context' `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml")

        ### App Role Assignments Data - 10
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'App Role Assignments' -PercentComplete 50
        ## Option 1: Loop through all servicePrincipals to get appRoleAssignments
        # Import-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml") `
        # | Get-MsGraphResults 'servicePrincipals/{0}/appRoleAssignedTo' -Top 999 -TotalRequests $servicePrincipalsCount -DisableUniqueIdDeduplication `
        # | Add-AadReferencesToCache -Type appRoleAssignment -ReferencedIdCache $ReferencedIdCache -PassThru `
        # | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "appRoleAssignmentData.xml")
        ## Option 2: Use expanded appRoleAssignedTo from servicePrincipals. This is at least 50x faster but appears to miss some appRoleAssignments.
        $listAppRoleAssignments `
        | Add-AadReferencesToCache -Type appRoleAssignment -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "appRoleAssignmentData.xml")
        Remove-Variable listAppRoleAssignments

        ### OAuth2 Permission Grants Data - 11
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'OAuth2 Permission Grants' -PercentComplete 55
        ## https://graph.microsoft.com/v1.0/oauth2PermissionGrants fails with "Service is temorarily unavailable" if too much data is returned in a single request. 600 works on microsoft.onmicrosoft.com.
        Get-MsGraphResults 'oauth2PermissionGrants' -Top 600 `
        | Add-AadReferencesToCache -Type oauth2PermissionGrant -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "oauth2PermissionGrantData.xml")

        ### Filter Service Principals - 12
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Filtering Service Principals' -PercentComplete 60
        Remove-Item (Join-Path $OutputDirectoryAAD "servicePrincipalData-Unfiltered.xml") -ErrorAction Ignore
        Rename-Item (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml") -NewName "servicePrincipalData-Unfiltered.xml"
        Import-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData-Unfiltered.xml") `
        | Where-Object { $_.keyCredentials.Count -or $_.passwordCredentials.Count -or $ReferencedIdCache.servicePrincipal.Contains($_.id) -or $ReferencedIdCache.appId.Contains($_.appId) -or $ReferencedIdCache.directoryScopeId.Contains($_.id)} `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml")
        Remove-Item (Join-Path $OutputDirectoryAAD "servicePrincipalData-Unfiltered.xml") -Force
        $ReferencedIdCache.servicePrincipal.Clear()

        ### Administrative units data - 13
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Administrative Units' -PercentComplete 65
        $ReferencedIdCache.administrativeUnit | Get-MsGraphResults 'directory/administrativeUnits/{0}' -Select 'id,displayName,Visibility' -QueryParameters @{ '$expand' = 'members($select=id)' } -TotalRequests $ReferencedIdCache.administrativeUnit.Count `
        | Export-Clixml (Join-Path $OutputDirectoryAAD "administrativeUnitsData.xml")
        $ReferencedIdCache.administrativeUnit.Clear()

        ### Group Data - 14
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Groups' -PercentComplete 70
        # add technical notifications groups
        if ($OrganizationData) {
            $OrganizationData.technicalNotificationMails | Get-MsGraphResults 'groups?$select=id' -Filter "proxyAddresses/any(c:c eq 'smtp:{0}')" `
            | ForEach-Object { [void]$ReferencedIdCache.group.Add($_.id) }
        }
        # Add nested groups
        $ReferencedIdCache.roleGroup.guid | Get-MsGraphResults 'groups/{0}/transitiveMembers/microsoft.graph.group?$count=true&$select=id' -Top 999 -TotalRequests $ReferencedIdCache.group.Count -DisableUniqueIdDeduplication `
        | ForEach-Object { [void]$ReferencedIdCache.group.Add($_.id) }

        ## Option 1: Populate direct members on groups (including nested groups) and calculate transitiveMembers later.
        ## $expand on group members caps results at 20 members with no NextLink so call members endpoint for each.
        # $ReferencedIdCache.group | Get-MsGraphResults 'groups?$select=id,groupTypes,displayName,mail,proxyAddresses' -TotalRequests $ReferencedIdCache.group.Count -DisableUniqueIdDeduplication -BatchSize 1 -GetByIdsBatchSize 20 `
        # | Expand-MsGraphRelationship -ObjectType groups -PropertyName members -References -Top 999 `
        # | Select-Object -Property "*" -ExcludeProperty '@odata.type' `
        # | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "groupData.xml")

        ## Option 2: Get groups without member data and let Azure AD calculate transitiveMembers.
        $ReferencedIdCache.group | Get-MsGraphResults 'groups?$select=id,groupTypes,displayName,mail,proxyAddresses,mailEnabled,securityEnabled' -TotalRequests $ReferencedIdCache.group.Count -DisableUniqueIdDeduplication `
        | Select-Object -Property "*" -ExcludeProperty '@odata.type' `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "groupData.xml")

        ### Group Transitive members - 15
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Group Transitive Membership' -PercentComplete 75
        $ReferencedIdCache.group | Get-MsGraphResults 'groups/{0}/transitiveMembers/$ref' -Top 999 -TotalRequests $ReferencedIdCache.group.Count -IncapsulateReferenceListInParentObject -DisableUniqueIdDeduplication `
        | ForEach-Object {
            $group = $_
            #[array] $directMembers = Get-MsGraphResults 'groups/{0}/members/$ref' -UniqueId $_.id -Top 999 -DisableUniqueIdDeduplication | Expand-ODataId | Select-Object -ExpandProperty id
            $group.transitiveMembers | Expand-ODataId | ForEach-Object {
                if ($_.'@odata.type' -eq '#microsoft.graph.user') { [void]$ReferencedIdCache.user.Add($_.id) }
                [PSCustomObject]@{
                    id         = $group.id
                    #'@odata.type' = $group.'@odata.type'
                    memberId   = $_.id
                    memberType = $_.'@odata.type' -replace '#microsoft.graph.', ''
                    #direct     = $directMembers -and $directMembers.Contains($_.id)
                }
            }
        } `
        | Export-Csv (Join-Path $OutputDirectoryAAD "groupTransitiveMembers.csv") -NoTypeInformation
        $ReferencedIdCache.group.Clear()

        ### User Data - 16
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Users' -PercentComplete 80
        # add technical notifications users
        if ($OrganizationData) {
            $OrganizationData.technicalNotificationMails | Get-MsGraphResults 'users?$select=id' -Filter "proxyAddresses/any(c:c eq 'smtp:{0}') or otherMails/any(c:c eq '{0}')" `
            | ForEach-Object { [void]$ReferencedIdCache.user.Add($_.id) }
        }
        # get userinformations
        $ReferencedIdCache.user | Get-MsGraphResults 'users/{0}?$select=id,userPrincipalName,userType,displayName,accountEnabled,onPremisesSyncEnabled,onPremisesImmutableId,mail,otherMails,proxyAddresses,assignedPlans,signInActivity' -TotalRequests $ReferencedIdCache.user.Count -DisableUniqueIdDeduplication -ApiVersion 'beta' `
        | Select-Object -Property "*" -ExcludeProperty '@odata.type' `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "userData.xml")
        $ReferencedIdCache.user.Clear()

        ### Generate Reports
        if (!$SkipReportOutput) {
            Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Output Report Data' -PercentComplete 85
            Export-AADAssessmentReportData -SourceDirectory $OutputDirectoryAAD -OutputDirectory $OutputDirectoryAAD

            ## Remove Raw Data Output
            Remove-Item -Path (Join-Path $OutputDirectoryAAD "*") -Include "*Data.xml" -ErrorAction Ignore
            Remove-Item -Path (Join-Path $OutputDirectoryAAD "*") -Include "*Data.csv" -ErrorAction Ignore
        }

        ### Complete
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Completed

        ### Write Custom Event
        Write-AppInsightsEvent 'AAD Assessment Data Collection Complete' -OverrideProperties -Properties @{
            AssessmentId       = if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) { $script:AppInsightsRuntimeState.OperationStack.Peek().Id } else { New-Guid }
            AssessmentVersion  = $MyInvocation.MyCommand.Module.Version.ToString()
            AssessmentTenantId = $OrganizationData.id
        }

        if (!$SkipPackaging) {
            ### Package Output
            Compress-Archive (Join-Path $OutputDirectoryData '\*') -DestinationPath $PackagePath -Force -ErrorAction Stop

            ### Clean-Up Data Files
            Remove-Item $OutputDirectoryData -Recurse -Force
        }

        ### Open Directory
        Invoke-Item $OutputDirectory

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

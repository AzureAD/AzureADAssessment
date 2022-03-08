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
        $OrganizationData = Get-MsGraphResults 'organization?$select=id,displayName,verifiedDomains,technicalNotificationMails' -ErrorAction Stop
        $InitialTenantDomain = $OrganizationData.verifiedDomains | Where-Object isInitial -EQ $true | Select-Object -ExpandProperty name -First 1
        $PackagePath = $PackagePath.Replace("AzureADAssessmentData.zip", "AzureADAssessmentData-$InitialTenantDomain.zip")
        $OutputDirectoryAAD = Join-Path $OutputDirectoryData "AAD-$InitialTenantDomain"
        Assert-DirectoryExists $OutputDirectoryAAD

        ConvertTo-Json -InputObject $OrganizationData -Depth 10 | Set-Content (Join-Path $OutputDirectoryAAD "organization.json")

        ### Generate Assessment Data
        $AssessmentData = [PSCustomObject]@{
            AssessmentDateTime     = Get-Date
            AssessmentId           = if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) { $script:AppInsightsRuntimeState.OperationStack.Peek().Id.ToString() } else { (New-Guid).ToString() }
            AssessmentVersion      = $MyInvocation.MyCommand.Module.Version.ToString()
            AssessmentTenantId     = $OrganizationData.id
            AssessmentTenantDomain = $InitialTenantDomain
        }
        Assert-DirectoryExists $OutputDirectoryData
        ConvertTo-Json -InputObject $AssessmentData | Set-Content $AssessmentDetailPath

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
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Directory Roles' -PercentComplete 21
        ## $expand on directoryRole members caps results at 20 members with no NextLink so call members endpoint for each.
        Get-MsGraphResults 'directoryRoles?$select=id,displayName,roleTemplateId' -DisableUniqueIdDeduplication `
        | Expand-MsGraphRelationship -ObjectType directoryRoles -PropertyName members -References `
        | Add-AadReferencesToCache -Type directoryRole -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "directoryRoleData.xml")

        ### Directory Role Definitions - 6
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Directory Role Definitions' -PercentComplete 25
        Get-MsGraphResults 'roleManagement/directory/roleDefinitions' -Select 'id,templateId,displayName,isBuiltIn,isEnabled' -ApiVersion 'v1.0' -OutVariable roleDefinitions `
        | Where-Object { $_.isEnabled } `
        | Select-Object id, templateId, displayName, isBuiltIn, isEnabled `
        | Export-Csv (Join-Path $OutputDirectoryAAD "roleDefinitions.csv") -NoTypeInformation

        ### Directory Role Assignments - 7
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Directory Role Assignments' -PercentComplete 30
        ## Getting role assignments via unified role API
        # Get-MsGraphResults 'roleManagement/directory/roleAssignmentSchedules' -Select 'id,directoryScopeId,memberType,scheduleInfo,status,assignmentType' -Filter "status eq 'Provisioned' and assignmentType eq 'Assigned'" -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } -ApiVersion 'beta' `
        # | Add-AadReferencesToCache -Type roleAssignmentSchedules -ReferencedIdCache $ReferencedIdCache -PassThru `
        # | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "roleAssignmentSchedulesData.xml")

        # List roleAssignmentSchedules above is not returning non-root scoped assignments so working around with one query of all root assignments including custom roles and another query of all non-root assignments for build-in roles. Also, because roleDefinitions are not returning the correct id, it is not possible to get custom roles assigned to non-root scopes.
        $roleAssignmentSchedules = Get-MsGraphResults 'roleManagement/directory/roleAssignmentSchedules' -Select 'id,directoryScopeId,memberType,scheduleInfo,status,assignmentType' -Filter "status eq 'Provisioned' and assignmentType eq 'Assigned' and directoryScopeId eq '/'" -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } -ApiVersion 'beta'
        $roleAssignmentSchedulesAdditional = $roleDefinitions | Where-Object isBuiltIn -EQ $true | Get-MsGraphResults 'roleManagement/directory/roleAssignmentSchedules' -Select 'id,directoryScopeId,memberType,scheduleInfo,status,assignmentType' -Filter "status eq 'Provisioned' and assignmentType eq 'Assigned' and roleDefinitionId eq '{0}' and directoryScopeId ne '/'" -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } -ApiVersion 'beta'
        $roleAssignmentSchedules + $roleAssignmentSchedulesAdditional `
        | Add-AadReferencesToCache -Type roleAssignmentSchedules -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "roleAssignmentSchedulesData.xml")
        Remove-Variable roleDefinitions, roleAssignmentSchedules, roleAssignmentSchedulesAdditional

        ### Directory Role Eligibility - 8
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Directory Role Eligibility' -PercentComplete 35
        # Getting role eligibility via unified role API
        Get-MsGraphResults 'roleManagement/directory/roleEligibilitySchedules' -Select 'id,directoryScopeId,memberType,scheduleInfo,status' -Filter "status eq 'Provisioned'" -QueryParameters @{ '$expand' = 'principal($select=id),roleDefinition($select=id,templateId,displayName)' } -ApiVersion 'beta' `
        | Add-AadReferencesToCache -Type roleAssignmentSchedules -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "roleEligibilitySchedulesData.xml")
        #| Export-JsonArray (Join-Path $OutputDirectoryAAD "roleEligibilitySchedules.json") -Depth 5 -Compress

        # Lookup ObjectIds with Unknown Types
        $ReferencedIdCache.unknownType | Get-MsGraphResults 'directoryObjects' -Select 'id' `
        | ForEach-Object {
            $ObjectType = $_.'@odata.type' -replace '#microsoft.graph.', ''
            [void] $ReferencedIdCache.$ObjectType.Add($_.id)
        }
        $ReferencedIdCache.unknownType.Clear()

        ### Application Data - 9
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Applications' -PercentComplete 40
        Get-MsGraphResults 'applications?$select=id,appId,displayName,appRoles,keyCredentials,passwordCredentials' -Top 999 -ApiVersion 'beta' `
        | Where-Object { $_.keyCredentials.Count -or $_.passwordCredentials.Count -or $ReferencedIdCache.application.Contains($_.id) -or $ReferencedIdCache.appId.Contains($_.appId) } `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "applicationData.xml")

        ### Service Principal Data - 10
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

        ### App Role Assignments Data - 11
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

        ### OAuth2 Permission Grants Data - 12
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'OAuth2 Permission Grants' -PercentComplete 55
        ## https://graph.microsoft.com/v1.0/oauth2PermissionGrants fails with "Service is temorarily unavailable" if too much data is returned in a single request. 600 works on microsoft.onmicrosoft.com.
        Get-MsGraphResults 'oauth2PermissionGrants' -Top 600 `
        | Add-AadReferencesToCache -Type oauth2PermissionGrant -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "oauth2PermissionGrantData.xml")

        ### Filter Service Principals - 13
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Filtering Service Principals' -PercentComplete 60
        Remove-Item (Join-Path $OutputDirectoryAAD "servicePrincipalData-Unfiltered.xml") -ErrorAction Ignore
        Rename-Item (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml") -NewName "servicePrincipalData-Unfiltered.xml"
        Import-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData-Unfiltered.xml") `
        | Where-Object { $_.keyCredentials.Count -or $_.passwordCredentials.Count -or $ReferencedIdCache.servicePrincipal.Contains($_.id) -or $ReferencedIdCache.appId.Contains($_.appId) } `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml")
        Remove-Item (Join-Path $OutputDirectoryAAD "servicePrincipalData-Unfiltered.xml") -Force
        $ReferencedIdCache.servicePrincipal.Clear()

        ### Administrative units data - 14
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Administrative Units' -PercentComplete 65
        Get-MsGraphResults 'directory/administrativeUnits' -Select 'id,displayName,visibility' `
        | Export-Csv (Join-Path $OutputDirectoryAAD "administrativeUnits.csv")

        ### Registration details data - 15
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Registration Details' -PercentComplete 70
        Get-MsGraphResults 'reports/authenticationMethods/userRegistrationDetails' -ApiVersion 'beta' `
        | Export-JsonArray (Join-Path $OutputDirectoryAAD "userRegistrationDetails.json") -Depth 5 -Compress

        ### Group Data - 16
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Groups' -PercentComplete 75
        # add technical notifications groups
        if ($OrganizationData) {
            $OrganizationData.technicalNotificationMails | Get-MsGraphResults 'groups?$select=id' -Filter "proxyAddresses/any(c:c eq 'smtp:{0}')" `
            | ForEach-Object { [void]$ReferencedIdCache.group.Add($_.id) }
        }
        # Add nested groups
        $ReferencedIdCache.roleGroup.guid | Get-MsGraphResults 'groups/{0}/transitiveMembers/microsoft.graph.group?$count=true&$select=id' -Top 999 -TotalRequests $ReferencedIdCache.roleGroup.Count -DisableUniqueIdDeduplication `
        | ForEach-Object { [void]$ReferencedIdCache.group.Add($_.id) }

        ## Option 1: Populate direct members on groups (including nested groups) and calculate transitiveMembers later.
        ## $expand on group members caps results at 20 members with no NextLink so call members endpoint for each.
        $ReferencedIdCache.group | Get-MsGraphResults 'groups?$select=id,groupTypes,displayName,mail,proxyAddresses,mailEnabled,securityEnabled,onPremisesSyncEnabled' -TotalRequests $ReferencedIdCache.group.Count -DisableUniqueIdDeduplication -BatchSize 1 -GetByIdsBatchSize 20 `
        | Expand-MsGraphRelationship -ObjectType groups -PropertyName members -References -Top 999 `
        | Add-AadReferencesToCache -Type group -ReferencedIdCache $ReferencedIdCache -ReferencedTypes '#microsoft.graph.user', '#microsoft.graph.servicePrincipal' -PassThru `
        | Select-Object -Property "*" -ExcludeProperty '@odata.type' `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "groupData.xml")

        # | ForEach-Object {
        #     foreach ($Object in $_.member) {
        #         if ($Object.'@odata.type' -in ('#microsoft.graph.user', '#microsoft.graph.servicePrincipal')) {
        #             $ObjectType = $Object.'@odata.type' -replace '#microsoft.graph.', ''
        #             [void] $ReferencedIdCache.$ObjectType.Add($Object.id)
        #         }
        #     }
        # }

        ## Option 2: Get groups without member data and let Azure AD calculate transitiveMembers.
        # $ReferencedIdCache.group | Get-MsGraphResults 'groups?$select=id,groupTypes,displayName,mail,proxyAddresses,mailEnabled,securityEnabled' -TotalRequests $ReferencedIdCache.group.Count -DisableUniqueIdDeduplication `
        # | Select-Object -Property "*" -ExcludeProperty '@odata.type' `
        # | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "groupData.xml")

        # ### Group Transitive members - 16
        # Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Group Transitive Membership' -PercentComplete 75
        # $ReferencedIdCache.group | Get-MsGraphResults 'groups/{0}/transitiveMembers/$ref' -Top 999 -TotalRequests $ReferencedIdCache.group.Count -IncapsulateReferenceListInParentObject -DisableUniqueIdDeduplication `
        # | ForEach-Object {
        #     $group = $_
        #     #[array] $directMembers = Get-MsGraphResults 'groups/{0}/members/$ref' -UniqueId $_.id -Top 999 -DisableUniqueIdDeduplication | Expand-ODataId | Select-Object -ExpandProperty id
        #     $group.transitiveMembers | Expand-ODataId | ForEach-Object {
        #         if ($_.'@odata.type' -eq '#microsoft.graph.user') { [void]$ReferencedIdCache.user.Add($_.id) }
        #         [PSCustomObject]@{
        #             id         = $group.id
        #             #'@odata.type' = $group.'@odata.type'
        #             memberId   = $_.id
        #             memberType = $_.'@odata.type' -replace '#microsoft.graph.', ''
        #             #direct     = $directMembers -and $directMembers.Contains($_.id)
        #         }
        #     }
        # } `
        # | Export-Csv (Join-Path $OutputDirectoryAAD "groupTransitiveMembers.csv") -NoTypeInformation
        $ReferencedIdCache.group.Clear()

        ### User Data - 17
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Users' -PercentComplete 80
        # add technical notifications users
        if ($OrganizationData) {
            $OrganizationData.technicalNotificationMails | Get-MsGraphResults 'users?$select=id' -Filter "proxyAddresses/any(c:c eq 'smtp:{0}') or otherMails/any(c:c eq '{0}')" `
            | ForEach-Object { [void]$ReferencedIdCache.user.Add($_.id) }
        }
        # get user information
        #$ReferencedIdCache.user | Get-MsGraphResults 'users/{0}?$select=id,userPrincipalName,userType,displayName,accountEnabled,onPremisesSyncEnabled,onPremisesImmutableId,mail,otherMails,proxyAddresses,assignedPlans,signInActivity' -TotalRequests $ReferencedIdCache.user.Count -DisableUniqueIdDeduplication -ApiVersion 'beta' `
        #$ReferencedIdCache.user | Get-MsGraphResults 'users/{0}?$select=id,userPrincipalName,userType,displayName,accountEnabled,onPremisesSyncEnabled,onPremisesImmutableId,mail,otherMails,proxyAddresses,assignedPlans,signInActivity' -TotalRequests $ReferencedIdCache.user.Count -DisableUniqueIdDeduplication -ApiVersion 'beta' `
        $ReferencedIdCache.user | Get-MsGraphResults 'users' -Select 'id,userPrincipalName,userType,displayName,accountEnabled,onPremisesSyncEnabled,onPremisesImmutableId,mail,otherMails,proxyAddresses,assignedPlans,signInActivity' -TotalRequests $ReferencedIdCache.user.Count -DisableUniqueIdDeduplication -EnableInFilter -ApiVersion 'beta' `
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
            AssessmentId       = $AssessmentData.AssessmentId
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

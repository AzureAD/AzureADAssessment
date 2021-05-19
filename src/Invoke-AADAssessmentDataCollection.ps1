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
        [switch] $SkipPackaging
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

        ### Organization Data
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

        ### Policy Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Policy' -PercentComplete 5
        #Get-MsGraphResults "identity/conditionalAccess/policies" -ErrorAction Stop `
        Get-MsGraphResults "identity/conditionalAccess/policies" `
        | Add-AadReferencesToCache -Type conditionalAccessPolicy -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-JsonArray (Join-Path $OutputDirectoryAAD "conditionalAccessPolicies.json") -Depth 5 -Compress

        Get-MsGraphResults "identity/conditionalAccess/namedLocations" `
        | Export-JsonArray (Join-Path $OutputDirectoryAAD "namedLocations.json") -Depth 5 -Compress

        Get-MsGraphResults "policies/authenticationMethodsPolicy/authenticationMethodConfigurations/email" `
        | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path (Join-Path $OutputDirectoryAAD "emailOTPMethodPolicy.json")

        ### Directory Role Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Directory Roles' -PercentComplete 10
        Get-MsGraphResults 'directoryRoles?$select=id,displayName&$expand=members' `
        | Where-Object { $_.members.Count } `
        | Add-AadReferencesToCache -Type directoryRoles -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "directoryRoleData.xml")

        ### Application Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Applications' -PercentComplete 20
        Get-MsGraphResults 'applications?$select=id,appId,displayName,appRoles,keyCredentials,passwordCredentials' -Top 999 `
        | Where-Object { $_.keyCredentials.Count -or $_.passwordCredentials.Count -or $ReferencedIdCache.appId.Contains($_.appId) } `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "applicationData.xml")

        ### Service Principal Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Service Principals' -PercentComplete 30
        #$servicePrincipalIds = New-Object 'System.Collections.Generic.HashSet[guid]'
        $listAppRoleAssignments = New-Object 'System.Collections.Generic.List[psobject]'
        Get-MsGraphResults 'servicePrincipals?$select=id,appId,servicePrincipalType,displayName,accountEnabled,appOwnerOrganizationId,appRoles,oauth2PermissionScopes,keyCredentials,passwordCredentials&$expand=appRoleAssignedTo' -Top 999 `
        | Extract-AppRoleAssignments -ListVariable $listAppRoleAssignments -PassThru `
        | Select-Object -Property "*" -ExcludeProperty 'appRoleAssignedTo', 'appRoleAssignedTo@odata.context' `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml")
        #| ForEach-Object { [void]$servicePrincipalIds.Add($_.id); $_ } `
        # Import-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml") `
        # | ForEach-Object { [void]$servicePrincipalIds.Add($_.id) }

        ### App Role Assignments Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'App Role Assignments' -PercentComplete 35
        $listAppRoleAssignments `
        | Add-AadReferencesToCache -Type appRoleAssignment -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "appRoleAssignmentData.xml")
        Remove-Variable listAppRoleAssignments
        # Import-Clixml -Path (Join-Path $OutputDirectoryAAD "appRoleAssignmentData.xml") `
        # | Add-AadReferencesToCache -Type appRoleAssignment -ReferencedIdCache $ReferencedIdCache

        ### OAuth2 Permission Grants Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'OAuth2 Permission Grants' -PercentComplete 40
        #$servicePrincipalIds | Get-MsGraphResults 'serviceprincipals/{0}/oauth2PermissionGrants' -Top 999 -TotalRequests $servicePrincipalIds.Count -DisableUniqueIdDeduplication `
        ## https://graph.microsoft.com/v1.0/oauth2PermissionGrants fails with "Service is temorarily unavailable" if too much data is returned in a single request. 600 works on microsoft.onmicrosoft.com.
        Get-MsGraphResults 'oauth2PermissionGrants' -Top 600 `
        | Add-AadReferencesToCache -Type oauth2PermissionGrants -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "oauth2PermissionGrantData.xml")
        #Remove-Variable servicePrincipalIds

        ### Filter Service Principals
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Filtering Service Principals' -PercentComplete 50
        Remove-Item (Join-Path $OutputDirectoryAAD "servicePrincipalData-Unfiltered.xml") -ErrorAction Ignore
        Rename-Item (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml") -NewName "servicePrincipalData-Unfiltered.xml"
        Import-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData-Unfiltered.xml") `
        | Where-Object { $_.keyCredentials.Count -or $_.passwordCredentials.Count -or $ReferencedIdCache.servicePrincipal.Contains($_.id) -or $ReferencedIdCache.appId.Contains($_.appId) } `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "servicePrincipalData.xml")
        Remove-Item (Join-Path $OutputDirectoryAAD "servicePrincipalData-Unfiltered.xml") -Force
        $ReferencedIdCache.servicePrincipal.Clear()

        ### User Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Users' -PercentComplete 60
        if ($OrganizationData) {
            $OrganizationData.technicalNotificationMails | Get-MsGraphResults 'users?$select=id' -Filter "proxyAddresses/any(c:c eq 'smtp:{0}') or otherMails/any(c:c eq '{0}')" `
            | Foreach-Object { [void]$ReferencedIdCache.user.Add($_.id) }
        }
        #Get-MsGraphResults 'users?$select=id,userPrincipalName,displayName,mail,otherMails,proxyAddresses' `
        #| Where-Object { $ReferencedIdCache.user.Contains($_.id) } `
        $ReferencedIdCache.user | Get-MsGraphResults 'users?$select=id,userPrincipalName,userType,displayName,accountEnabled,mail,otherMails,proxyAddresses' -TotalRequests $ReferencedIdCache.user.Count -DisableUniqueIdDeduplication `
        | Select-Object -Property "*" -ExcludeProperty '@odata.type' `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "userData.xml")
        $ReferencedIdCache.user.Clear()

        ### Group Data
        Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Groups' -PercentComplete 70
        if ($OrganizationData) {
            $OrganizationData.technicalNotificationMails | Get-MsGraphResults 'groups?$select=id' -Filter "proxyAddresses/any(c:c eq 'smtp:{0}')" `
            | Foreach-Object { [void]$ReferencedIdCache.group.Add($_.id) }
        }
        $ReferencedIdCache.group | Get-MsGraphResults 'groups?$select=id,groupTypes,displayName,mail,proxyAddresses' -TotalRequests $ReferencedIdCache.group.Count -DisableUniqueIdDeduplication `
        | Select-Object -Property "*" -ExcludeProperty '@odata.type' `
        | Export-Clixml -Path (Join-Path $OutputDirectoryAAD "groupData.xml")
        $ReferencedIdCache.group.Clear()

        ### Generate Reports
        if (!$SkipReportOutput) {
            Write-Progress -Id 0 -Activity ('Microsoft Azure AD Assessment Data Collection - {0}' -f $InitialTenantDomain) -Status 'Output Report Data' -PercentComplete 90
            Export-AADAssessmentReportData -SourceDirectory $OutputDirectoryAAD -OutputDirectory $OutputDirectoryAAD

            ## Remove Raw Data Output
            Remove-Item -Path (Join-Path $OutputDirectoryAAD "*") -Include "*Data.xml" -ErrorAction Ignore
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

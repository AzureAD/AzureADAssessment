<#
.SYNOPSIS
    Produces the Azure AD Conditional Access reports required by the Azure AD assesment
.DESCRIPTION
    This cmdlet reads the conditional access from the target Azure AD Tenant and produces the output files
    in a target directory
.EXAMPLE
   .\Export-AADAssessConditionalAccessData -OutputDirectory "c:\temp\contoso"
#>
function Export-AADAssessConditionalAccessData {
    [CmdletBinding()]
    param (
        # Full path of the directory where the output files will be generated.
        [Parameter(Mandatory = $true)]
        [string] $OutputDirectory
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        ## Create Cache for Referenced IDs
        $ReferencedIdCache = New-AadReferencedIdCache

        ## Get Conditional Access Policies
        Get-MsGraphResults "identity/conditionalAccess/policies" `
        | Use-Progress -Activity 'Exporting conditionalAccessPolicies' -Property displayName -PassThru `
        | Add-AadReferencesToCache -Type conditionalAccessPolicy -ReferencedIdCache $ReferencedIdCache -PassThru `
        | Export-JsonArray (Join-Path $OutputDirectory "conditionalAccessPolicies.json") -Depth 5 -Compress

        ## Get Named Locations
        Get-MsGraphResults "identity/conditionalAccess/namedLocations" `
        | Use-Progress -Activity 'Exporting namedLocations' -Property displayName -PassThru `
        | Export-JsonArray (Join-Path $OutputDirectory "namedLocations.json") -Depth 5 -Compress

        ## Get Referenced Users
        Set-Content -Path (Join-Path $OutputDirectory "users.csv") -Value 'id,userPrincipalName,displayName'
        Get-MsGraphResults 'users?$select=id,userPrincipalName,displayName' -UniqueId $ReferencedIdCache.user -DisableUniqueIdDeduplication `
        | Use-Progress -Activity 'Exporting referenced users' -Property displayName -PassThru `
        | Select-Object -Property "*" -ExcludeProperty '@odata.type' `
        | Export-Csv (Join-Path $OutputDirectory "users.csv") -NoTypeInformation
        #| Export-JsonArray (Join-Path $OutputDirectory "users.json") -Depth 5 -Compress

        ## Get Referenced Groups
        Set-Content -Path (Join-Path $OutputDirectory "groups.csv") -Value 'id,displayName'
        Get-MsGraphResults 'groups?$select=id,displayName' -UniqueId $ReferencedIdCache.group -DisableUniqueIdDeduplication `
        | Use-Progress -Activity 'Exporting referenced groups' -Property displayName -PassThru `
        | Select-Object -Property "*" -ExcludeProperty '@odata.type' `
        | Export-Csv (Join-Path $OutputDirectory "groups.csv") -NoTypeInformation
        #| Export-JsonArray (Join-Path $OutputDirectory "groups.json") -Depth 5 -Compress

        ## Get Referenced ServicePrincipals (AppIDs)
        Set-Content -Path (Join-Path $OutputDirectory "servicePrincipals.csv") -Value 'id,appId,displayName'
        Get-MsGraphResults 'servicePrincipals?$select=id,appId,displayName' -Filter "appId eq '{0}'" -UniqueId $ReferencedIdCache.appId -DisableUniqueIdDeduplication `
        | Use-Progress -Activity 'Exporting referenced apps/servicePrincipals' -Property displayName -PassThru `
        | Export-Csv (Join-Path $OutputDirectory "servicePrincipals.csv") -NoTypeInformation
        #| Export-JsonArray (Join-Path $OutputDirectory "servicePrincipals.json") -Depth 5 -Compress

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException -ErrorRecord $_ }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

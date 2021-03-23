<#
 .Synopsis
  Gets a report of all assignments to all applications

 .Description
  This functions returns a list indicating the applications and their user/groups assignments

 .Example
  Get-AADAssessAppAssignmentReport | Export-Csv -Path ".\AppAssignments.csv"
#>
function Get-AADAssessAppAssignmentReport {
    [CmdletBinding()]
    param (
        # Service Principal Data
        [Parameter(Mandatory = $false)]
        [object] $ServicePrincipalData
        # App Role Assignment Data
        #[Parameter(Mandatory = $false)]
        #[object] $AppRoleAssignmentData
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        ## Get Application Assignments
        if ($ServicePrincipalData) {
            if ($ServicePrincipalData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $ServicePrincipalData.Values | Select-Object -ExpandProperty appRoleAssignedTo
            }
            else {
                $ServicePrincipalData | Select-Object -ExpandProperty appRoleAssignedTo
            }
        }
        else {
            Write-Verbose "Getting serviceprincipals..."
            Get-MsGraphResults 'serviceprincipals?$select=id,displayName,appOwnerOrganizationId,appRoles&$expand=appRoleAssignedTo' -Top 999 `
            | Select-Object -ExpandProperty appRoleAssignedTo
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

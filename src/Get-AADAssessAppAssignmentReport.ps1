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
        [object] $ServicePrincipalData,
        # App Role Assignment Data
        [Parameter(Mandatory = $false)]
        [object] $AppRoleAssignmentData
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        ## Load Data
        if (!$AppRoleAssignmentData -and !$ServicePrincipalData) {
            $ServicePrincipalData = Get-MsGraphResults 'serviceprincipals' -Select 'id' -Top 999
        }

        ## Get App Role Assignments
        if (!$AppRoleAssignmentData) {
            Get-MsGraphResults 'serviceprincipals/{0}/appRoleAssignedTo' -UniqueId $ServicePrincipalData.id -Top 999 -OutVariable AppRoleAssignmentData
        }
        else {
            $AppRoleAssignmentData
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

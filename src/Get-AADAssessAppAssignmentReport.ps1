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
    param ()

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        #Get all app assignemnts using "all users" group
        #Get all app assignments to users directly

        ## Get all service principals
        $servicePrincipals = Get-MsGraphResults 'serviceprincipals' -Select 'id' -Top 999

        ## Get all assignments to each service principal
        Get-MsGraphResults 'serviceprincipals/{0}/appRoleAssignedTo' -UniqueId $servicePrincipals.id -Top 999

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

<#
.SYNOPSIS
    Gets a report of all assignments to all applications
.DESCRIPTION
    This functions returns a list indicating the applications and their user/groups assignments
.EXAMPLE
    PS C:\> Get-AADAssessAppAssignmentReport | Export-Csv -Path ".\AppAssignmentsReport.csv"
#>
function Get-AADAssessAppAssignmentReport {
    [CmdletBinding()]
    param (
        # App Role Assignment Data
        [Parameter(Mandatory = $false)]
        [psobject] $AppRoleAssignmentData,
        # Generate Report Offline, only using the data passed in parameters
        [Parameter(Mandatory = $false)]
        [switch] $Offline
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        if ($Offline -and (!$PSBoundParameters['AppRoleAssignmentData'])) {
            Write-Error -Exception (New-Object System.Management.Automation.ItemNotFoundException -ArgumentList 'Use of the offline parameter requires that all data be provided using the data parameters.') -ErrorId 'DataParametersRequired' -Category ObjectNotFound
            return
        }

        if ($AppRoleAssignmentData) {
            $AppRoleAssignmentData
        }
        else {
            Write-Verbose "Getting servicePrincipals..."
            Get-MsGraphResults 'servicePrincipals?$select=id,displayName,appOwnerOrganizationId,appRoles&$expand=appRoleAssignedTo' -Top 999 `
            | Select-Object -ExpandProperty appRoleAssignedTo
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception -Properties @{ ScriptStackTrace = $_.ScriptStackTrace } }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

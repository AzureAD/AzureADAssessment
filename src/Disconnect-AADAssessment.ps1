<#
.SYNOPSIS
    Disconnects the current session from an Azure Active Directory tenant.
.EXAMPLE
    PS C:\>Disconnect-AADAssessment
    This command disconnects your session from a tenant.
#>
function Disconnect-AADAssessment {
    [CmdletBinding()]
    param ()

    ## Track Command Execution and Performance
    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        $script:ConnectState = @{
            ClientApplication = $null
            CloudEnvironment  = $null
            MsGraphToken      = $null
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException -ErrorRecord $_ -IncludeProcessStatistics }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}

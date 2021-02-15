<#
.SYNOPSIS
    Disable module telemetry
.EXAMPLE
    PS C:\>Disable-AADAssessmentTelemetry
    Disable module telemetry
#>
function Disable-AADAssessmentTelemetry {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        # Forces the command to run without asking for user confirmation.
        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    if ($Force -or $PSCmdlet.ShouldProcess("Do you want to disable telemetry for PnP PowerShell?", "Confirm")) {
        Set-Config -AIDisabled $true
    }
}

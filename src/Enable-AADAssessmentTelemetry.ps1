<#
.SYNOPSIS
    Enable module telemetry
.EXAMPLE
    PS C:\>Enable-AADAssessmentTelemetry
    Enable module telemetry
#>
function Enable-AADAssessmentTelemetry {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        # Forces the command to run without asking for user confirmation.
        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    if ($Force -or $PSCmdlet.ShouldProcess("Do you want to enable telemetry for PnP PowerShell?", "Confirm")) {
        Set-Config -AIDisabled $false
    }
}

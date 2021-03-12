<#
.SYNOPSIS
    Write Request to Application Insights.
.EXAMPLE
    PS C:\>Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $true
    Write Request to Application Insights.
.INPUTS
    System.String
#>
function Complete-AppInsightsRequest {
    [CmdletBinding()]
    [Alias('Complete-AIRequest')]
    param (
        # Request Name
        [Parameter(Mandatory = $false)]
        [string] $Name,
        # Request Result
        [Parameter(Mandatory = $true)]
        [bool] $Success
    )

    ## Return Immediately when Telemetry is Disabled
    if ($script:ModuleConfig.'ai.disabled') { return }

    $Operation = $script:AppInsightsRuntimeState.OperationStack.Peek()
    $Operation.Stopwatch.Stop()

    Write-AppInsightsRequest $Name -Duration $Operation.Stopwatch.Elapsed -Success $Success

    [void] $script:AppInsightsRuntimeState.OperationStack.Pop()
}

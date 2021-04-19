<#
.SYNOPSIS
    Write Request to Application Insights.
.EXAMPLE
    PS C:\>Write-AppInsightsRequest
    Write Request to Application Insights.
.INPUTS
    System.String
#>
function Write-AppInsightsRequest {
    [CmdletBinding()]
    [Alias('Write-AIRequest')]
    param (
        # Request Name
        [Parameter(Mandatory = $true)]
        [string] $Name,
        # Request Start Time
        [Parameter(Mandatory = $false)]
        [datetime] $StartTime,
        # Request Duration
        [Parameter(Mandatory = $true)]
        [timespan] $Duration,
        # Request Response Code
        [Parameter(Mandatory = $false)]
        [string] $responseCode,
        # Request Result
        [Parameter(Mandatory = $true)]
        [bool] $Success,
        # Custom Properties
        [Parameter(Mandatory = $false)]
        [hashtable] $Properties,
        # Instrumentation Key
        [Parameter(Mandatory = $false)]
        [string] $InstrumentationKey = $script:ModuleConfig.'ai.instrumentationKey',
        # Ingestion Endpoint
        [Parameter(Mandatory = $false)]
        [string] $IngestionEndpoint = $script:ModuleConfig.'ai.ingestionEndpoint'
    )

    ## Return Immediately when Telemetry is Disabled
    if ($script:ModuleConfig.'ai.disabled') { return }

    ## Initialize Parameters
    if (!$StartTime) { $StartTime = (Get-Date).Subtract($Duration) }

    ## Get New Telemetry Entry
    $AppInsightsTelemetry = New-AppInsightsTelemetry 'AppRequests' -InstrumentationKey $InstrumentationKey

    ## Update Telemetry Data
    $AppInsightsTelemetry['time'] = $StartTime.ToUniversalTime().ToString('o')
    $AppInsightsTelemetry.data.baseData['id'] = (New-Guid).ToString()
    $AppInsightsTelemetry.data.baseData['name'] = $Name
    $AppInsightsTelemetry.data.baseData['responseCode'] = if ($Success) { 'Success' } else { 'Failure' }
    $AppInsightsTelemetry.data.baseData['duration'] = $Duration.ToString()
    $AppInsightsTelemetry.data.baseData['success'] = $Success
    if ($Properties) { $AppInsightsTelemetry.data.baseData['properties'] += $Properties }

    ## Write Data to Application Insights
    Write-Debug ($AppInsightsTelemetry | ConvertTo-Json -Depth 3)
    try { $result = Invoke-RestMethod -UseBasicParsing -Method Post -Uri $IngestionEndpoint -ContentType 'application/json' -Body ($AppInsightsTelemetry | ConvertTo-Json -Depth 3 -Compress) -Verbose:$false -ErrorAction SilentlyContinue }
    catch {}
}

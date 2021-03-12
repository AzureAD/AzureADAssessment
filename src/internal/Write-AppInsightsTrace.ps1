<#
.SYNOPSIS
    Write Trace Message to Application Insights.
.EXAMPLE
    PS C:\>Write-AppInsightsEvent 'Message'
    Write Trace Message to Application Insights.
.INPUTS
    System.String
#>
function Write-AppInsightsTrace {
    [CmdletBinding()]
    [Alias('Write-AITrace')]
    param (
        # Event Name
        [Parameter(Mandatory = $true)]
        [string] $Message,
        # Severity Level
        [Parameter(Mandatory = $false)]
        [ValidateSet('Verbose', 'Information', 'Warning', 'Error', 'Critical')]
        [string] $SeverityLevel,
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

    ## Get New Telemetry Entry
    $AppInsightsTelemetry = New-AppInsightsTelemetry 'AppTraces' -InstrumentationKey $InstrumentationKey

    ## Update Telemetry Data
    $AppInsightsTelemetry.data.baseData['message'] = $Message
    if ($SeverityLevel) { $AppInsightsTelemetry.data.baseData['severityLevel'] = $SeverityLevel }
    if ($Properties) { $AppInsightsTelemetry.data.baseData['properties'] += $Properties }

    ## Write Data to Application Insights
    Write-Debug ($AppInsightsTelemetry | ConvertTo-Json -Depth 3)
    try { $result = Invoke-RestMethod -UseBasicParsing -Method Post -Uri $IngestionEndpoint -ContentType 'application/json' -Body ($AppInsightsTelemetry | ConvertTo-Json -Depth 3 -Compress) -Verbose:$false -ErrorAction SilentlyContinue }
    catch {}
}

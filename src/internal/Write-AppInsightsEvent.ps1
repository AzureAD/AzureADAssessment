<#
.SYNOPSIS
    Write Custom Event to Application Insights.
.EXAMPLE
    PS C:\>Write-AppInsightsEvent 'EventName'
    Write Custom Event to Application Insights.
.INPUTS
    System.String
#>
function Write-AppInsightsEvent {
    [CmdletBinding()]
    param (
        # Event Name
        [Parameter(Mandatory = $true)]
        [string] $Name,
        # Custom Properties
        [Parameter(Mandatory = $false)]
        [hashtable] $Properties,
        # Override Default Custom Properties
        [Parameter(Mandatory = $false)]
        [switch] $OverrideProperties,
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
    $AppInsightsTelemetry = New-AppInsightsTelemetry 'AppEvents' -InstrumentationKey $InstrumentationKey

    ## Update Telemetry Data
    $AppInsightsTelemetry.data.baseData['name'] = $Name
    if ($OverrideProperties) { $AppInsightsTelemetry.data.baseData['properties'] = @{} }
    if ($Properties) { $AppInsightsTelemetry.data.baseData['properties'] += $Properties }
    
    ## Write Data to Application Insights
    Write-Debug ($AppInsightsTelemetry | ConvertTo-Json -Depth 3)
    $result = Invoke-RestMethod -UseBasicParsing -Method Post -Uri $IngestionEndpoint -ContentType 'application/json' -Body ($AppInsightsTelemetry | ConvertTo-Json -Depth 3) -Verbose:$false
}

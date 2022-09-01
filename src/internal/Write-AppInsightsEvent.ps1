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
    [Alias('Write-AIEvent')]
    param (
        # Event Name
        [Parameter(Mandatory = $true)]
        [string] $Name,
        # Custom Properties
        [Parameter(Mandatory = $false)]
        [hashtable] $Properties,
        # Custom Ordered Properties. An ordered dictionary can be defined as: [ordered]@{ first = '1'; second = '2' }
        [Parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary] $OrderedProperties,
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
    if ($OrderedProperties) { $AppInsightsTelemetry.data.baseData['properties'] += $OrderedProperties }
    if ($Properties) { $AppInsightsTelemetry.data.baseData['properties'] += $Properties }

    ## Write Data to Application Insights
    Write-Debug ($AppInsightsTelemetry | ConvertTo-Json -Depth 3)
    try { $result = Invoke-RestMethod -UseBasicParsing -Method Post -Uri $IngestionEndpoint -ContentType 'application/json' -Body ($AppInsightsTelemetry | ConvertTo-Json -Depth 3 -Compress) -Verbose:$false -ErrorVariable SilentlyContinue }
    catch {}
}

<#
.SYNOPSIS
    Write Dependency to Application Insights.
.EXAMPLE
    PS C:\>Write-AppInsightsDependency
    Write Dependency to Application Insights.
.INPUTS
    System.String
#>
function Write-AppInsightsDependency {
    [CmdletBinding()]
    [Alias('Write-AIDependency')]
    param (
        # Dependency Name
        [Parameter(Mandatory = $true)]
        [string] $Name,
        # Dependency Type Name
        [Parameter(Mandatory = $false)]
        [string] $Type,
        # Dependency Data
        [Parameter(Mandatory = $true)]
        [string] $Data,
        # Dependency Start Time
        [Parameter(Mandatory = $false)]
        [datetime] $StartTime,
        # Dependency Duration
        [Parameter(Mandatory = $true)]
        [timespan] $Duration,
        # Dependency Result
        [Parameter(Mandatory = $true)]
        [bool] $Success,
        # Custom Properties
        [Parameter(Mandatory = $false)]
        [hashtable] $Properties,
        # Custom Ordered Properties. An ordered dictionary can be defined as: [ordered]@{ first = '1'; second = '2' }
        [Parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary] $OrderedProperties,
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
    Set-Variable 'MaxDataLength' -Value (8 * 1024) -Option Constant

    ## Get New Telemetry Entry
    $AppInsightsTelemetry = New-AppInsightsTelemetry 'AppDependencies' -InstrumentationKey $InstrumentationKey

    ## Update Telemetry Data
    $AppInsightsTelemetry['time'] = $StartTime.ToUniversalTime().ToString('o')
    if ($Type) { $AppInsightsTelemetry.data.baseData['type'] = $Type }
    $AppInsightsTelemetry.data.baseData['name'] = $Name
    $AppInsightsTelemetry.data.baseData['data'] = $Data
    $AppInsightsTelemetry.data.baseData['duration'] = $Duration.ToString()
    $AppInsightsTelemetry.data.baseData['success'] = $Success
    if ($OrderedProperties) { $AppInsightsTelemetry.data.baseData['properties'] += $OrderedProperties }
    if ($Properties) { $AppInsightsTelemetry.data.baseData['properties'] += $Properties }

    if ($AppInsightsTelemetry.data.baseData['data'].Length -gt $MaxDataLength) { $AppInsightsTelemetry.data.baseData['data'].Substring(0, $MaxDataLength) }

    ## Write Data to Application Insights
    Write-Debug ($AppInsightsTelemetry | ConvertTo-Json -Depth 3)
    try { $result = Invoke-RestMethod -UseBasicParsing -Method Post -Uri $IngestionEndpoint -ContentType 'application/json' -Body ($AppInsightsTelemetry | ConvertTo-Json -Depth 3 -Compress) -Verbose:$false -ErrorAction SilentlyContinue }
    catch {}
}

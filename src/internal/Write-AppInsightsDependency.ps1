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
    $AppInsightsTelemetry = New-AppInsightsTelemetry 'AppDependencies' -InstrumentationKey $InstrumentationKey

    ## Update Telemetry Data
    $AppInsightsTelemetry['time'] = $StartTime.ToUniversalTime().ToString('o')
    if ($Type) { $AppInsightsTelemetry.data.baseData['type'] = $Type }
    $AppInsightsTelemetry.data.baseData['name'] = $Name
    $AppInsightsTelemetry.data.baseData['data'] = $Data
    $AppInsightsTelemetry.data.baseData['duration'] = $Duration.ToString()
    $AppInsightsTelemetry.data.baseData['success'] = $Success
    if ($Properties) { $AppInsightsTelemetry.data.baseData['properties'] += $Properties }
    
    ## Write Data to Application Insights
    Write-Debug ($AppInsightsTelemetry | ConvertTo-Json -Depth 3)
    $result = Invoke-RestMethod -UseBasicParsing -Method Post -Uri $IngestionEndpoint -ContentType 'application/json' -Body ($AppInsightsTelemetry | ConvertTo-Json -Depth 3) -Verbose:$false -ErrorAction SilentlyContinue
}

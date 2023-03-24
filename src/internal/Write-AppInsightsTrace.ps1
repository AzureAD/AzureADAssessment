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
        # Custom Ordered Properties. An ordered dictionary can be defined as: [ordered]@{ first = '1'; second = '2' }
        [Parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary] $OrderedProperties,
        # Include process processor and memory usage statistics.
        [Parameter(Mandatory = $false)]
        [switch] $IncludeProcessStatistics,
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

    if ($IncludeProcessStatistics) {
        $PsProcess = Get-Process -PID $PID
        $AppInsightsTelemetry.data.baseData['properties']['TotalProcessorTime'] = $PsProcess.TotalProcessorTime.ToString()

        $AppInsightsTelemetry.data.baseData['properties']['VirtualMemorySize'] = Format-DataSize $PsProcess.VM
        $AppInsightsTelemetry.data.baseData['properties']['WorkingSetMemorySize'] = Format-DataSize $PsProcess.WS
        $AppInsightsTelemetry.data.baseData['properties']['PagedMemorySize'] = Format-DataSize $PsProcess.PM
        $AppInsightsTelemetry.data.baseData['properties']['NonpagedMemorySize'] = Format-DataSize $PsProcess.NPM

        $AppInsightsTelemetry.data.baseData['properties']['PeakVirtualMemorySize'] = Format-DataSize $PsProcess.PeakVirtualMemorySize64
        $AppInsightsTelemetry.data.baseData['properties']['PeakWorkingSetMemorySize'] = Format-DataSize $PsProcess.PeakWorkingSet64
        $AppInsightsTelemetry.data.baseData['properties']['PeakPagedMemorySize'] = Format-DataSize $PsProcess.PeakPagedMemorySize64

        $AppInsightsTelemetry.data.baseData['properties']['TotalProcessorTimeInSeconds'] = $PsProcess.CPU

        $AppInsightsTelemetry.data.baseData['properties']['VirtualMemoryInBytes'] = $PsProcess.VM
        $AppInsightsTelemetry.data.baseData['properties']['WorkingSetMemoryInBytes'] = $PsProcess.WS
        $AppInsightsTelemetry.data.baseData['properties']['PagedMemoryInBytes'] = $PsProcess.PM
        $AppInsightsTelemetry.data.baseData['properties']['NonpagedMemoryInBytes'] = $PsProcess.NPM

        $AppInsightsTelemetry.data.baseData['properties']['PeakVirtualMemoryInBytes'] = $PsProcess.PeakVirtualMemorySize64
        $AppInsightsTelemetry.data.baseData['properties']['PeakWorkingSetMemoryInBytes'] = $PsProcess.PeakWorkingSet64
        $AppInsightsTelemetry.data.baseData['properties']['PeakPagedMemoryInBytes'] = $PsProcess.PeakPagedMemorySize64
    }

    if ($OrderedProperties) { $AppInsightsTelemetry.data.baseData['properties'] += $OrderedProperties }
    if ($Properties) { $AppInsightsTelemetry.data.baseData['properties'] += $Properties }

    ## Write Data to Application Insights
    Write-Debug ($AppInsightsTelemetry | ConvertTo-Json -Depth 3)
    try { $result = Invoke-RestMethod -UseBasicParsing -Method Post -Uri $IngestionEndpoint -ContentType 'application/json' -Body ($AppInsightsTelemetry | ConvertTo-Json -Depth 3 -Compress) -Verbose:$false -ErrorAction SilentlyContinue }
    catch {}
}
